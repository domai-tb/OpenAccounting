import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Score-based matching: ranking, labels, ties, unavailable (bank-import section 1).
void main() {
  group('Score matching', () {
    late AppDatabase db;
    late BankImportService service;
    late int kontoId;
    late int kategorieId;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      service = BankImportService(db.executor);
      kontoId = await db.executor.runInsert('INSERT INTO konten (name, iban) VALUES (?, ?)', const <Object?>[
        'Giro',
        'DE001',
      ]);
      kategorieId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Matchkat', 1)",
        const <Object?>[],
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> addJournal({required String betrag, required String datum, required String beschreibung}) {
      return db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, beschreibung, kategorieId, betrag, 'Einnahme'],
      );
    }

    RawTx tx({required String betrag, required String datum, required String partner}) {
      return RawTx(
        datum: DateTime.parse(datum),
        betrag: betrag,
        verwendungszweck: 'Rechnung $partner',
        partner: partner,
      );
    }

    test('test_high_confidence_match', () async {
      final int journalId = await addJournal(betrag: '100.00', datum: '2026-03-10', beschreibung: 'Amazon Bestellung');
      final ranked = await service.rankCandidates(tx(betrag: '100.00', datum: '2026-03-12', partner: 'Amazon'));
      expect(ranked.single.journalId, journalId);
      expect(ranked.single.score, 100);
      final l10n = lookupAppLocalizations(const Locale('de'));
      expect(service.confidenceLabel(100, l10n), l10n.bankConfidenceHigh);
    });

    test('test_no_match', () async {
      await addJournal(betrag: '9999.00', datum: '2026-01-01', beschreibung: 'Unrelated');
      final ranked = await service.rankCandidates(tx(betrag: '1.00', datum: '2026-06-01', partner: 'Niemand'));
      expect(ranked.single.score, 0);
      final l10n = lookupAppLocalizations(const Locale('de'));
      expect(service.confidenceLabel(0, l10n), l10n.bankConfidenceNone);
    });

    test('test_tied_top_candidates_are_not_auto_linked', () async {
      await addJournal(betrag: '50.00', datum: '2026-04-01', beschreibung: 'Shop Kauf');
      await addJournal(betrag: '50.00', datum: '2026-04-01', beschreibung: 'Shop Kauf');
      final ranked = await service.rankCandidates(tx(betrag: '50.00', datum: '2026-04-02', partner: 'Shop'));
      expect(ranked[0].score, 100);
      expect(ranked[1].score, 100);
      expect(ranked[0].journalId, lessThan(ranked[1].journalId));

      final result = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[tx(betrag: '50.00', datum: '2026-04-02', partner: 'Shop')],
        mode: 'automatisch',
        locale: 'de_DE',
      );
      final rows = await db.executor.runSelect('SELECT journal_id FROM bank_transaktionen', const []);
      expect(rows.single['journal_id'], isNull);
      expect(result.candidatesUnavailable, isFalse);
    });

    test('test_candidate_query_failure_is_not_a_no_match', () async {
      final failing = _FailingService(db.executor);
      await expectLater(
        failing.rankCandidates(tx(betrag: '10.00', datum: '2026-05-01', partner: 'X')),
        throwsA(isA<StateError>()),
      );
      final result = await failing.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[tx(betrag: '10.00', datum: '2026-05-01', partner: 'X')],
        mode: 'automatisch',
        locale: 'de_DE',
      );
      expect(result.candidatesUnavailable, isTrue);
      final rows = await db.executor.runSelect('SELECT journal_id FROM bank_transaktionen', const []);
      expect(rows.single['journal_id'], isNull);
    });
  });
}

class _FailingService extends BankImportService {
  _FailingService(super.executor);

  @override
  Future<List<Map<String, Object?>>> loadMatchCandidates() => throw StateError('candidate store unavailable');
}
