import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Score-based matching: ranking, labels, ties, unavailable (bank-import section 1).
/// Bank transactions table: storage, links, and review status (section 7).
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

  group('Bank transactions table', () {
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
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Tabkat', 1)",
        const <Object?>[],
      );
    });

    tearDown(() async {
      await db.close();
    });

    RawTx row({int? kategorieId, int? journalId, String betrag = '20.00'}) {
      return RawTx(
        datum: DateTime.parse('2026-05-01'),
        betrag: betrag,
        verwendungszweck: 'Beitrag',
        partner: 'Verein',
        kategorieId: kategorieId,
        journalId: journalId,
      );
    }

    Future<Map<String, Object?>> storedRow() async {
      final rows = await db.executor.runSelect('SELECT * FROM bank_transaktionen', const []);
      return rows.single;
    }

    test('test_transaction_linked_to_journal_entry', () async {
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-05-01', 'Beitrag', kategorieId, '20.00', 'Einnahme'],
      );
      final before = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[row(journalId: journalId)],
        locale: 'de_DE',
      );
      final stored = await storedRow();
      expect(stored['journal_id'], journalId);
      expect(stored['status'], 'gebucht');
      final after = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      expect(after.single['c'], before.single['c'], reason: 'no journal entry is created');
    });

    test('test_transaction_stored_without_journal_link', () async {
      await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[row()], locale: 'de_DE');
      final stored = await storedRow();
      expect(stored['journal_id'], isNull);
      expect(stored['betrag'].toString(), contains('20'));
      expect(stored['verwendungszweck'], 'Beitrag');
    });

    test('test_import_assigns_row_review_status_from_its_decisions', () async {
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-05-01', 'Beitrag', kategorieId, '20.00', 'Einnahme'],
      );
      await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[
          row(journalId: journalId),
          row(kategorieId: kategorieId, betrag: '21.00'),
          row(betrag: '22.00'),
        ],
        locale: 'de_DE',
      );
      final rows = await db.executor.runSelect('SELECT status FROM bank_transaktionen ORDER BY id', const []);
      expect(rows.map((r) => r['status']), <Object?>['gebucht', 'geprueft', 'neu']);
    });

    test('test_automatic_mode_does_not_link_a_low_confidence_candidate', () async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-01-01', 'Fremd', kategorieId, '9999.00', 'Einnahme'],
      );
      final before = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[row()], mode: 'automatisch', locale: 'de_DE');
      final stored = await storedRow();
      expect(stored['journal_id'], isNull);
      expect(stored['status'], 'neu');
      final after = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      expect(after.single['c'], before.single['c']);
    });

    test('test_explicit_review_closes_a_new_row', () async {
      await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[row()], locale: 'de_DE');
      final created = await storedRow();
      expect(created['status'], 'neu');
      final int rowId = (created['id']! as num).toInt();

      expect(await service.unresolvedReviewRows(), hasLength(1));
      await service.reviewTransaction(id: rowId, kategorieId: kategorieId);
      final reviewed = await storedRow();
      expect(reviewed['status'], 'geprueft');
      expect(await service.unresolvedReviewRows(), isEmpty);

      await expectLater(
        service.reviewTransaction(id: rowId + 9999, kategorieId: kategorieId),
        throwsA(isA<BankImportException>()),
      );
      await expectLater(service.reviewTransaction(id: rowId), throwsA(isA<BankImportException>()));
    });
  });
}

class _FailingService extends BankImportService {
  _FailingService(super.executor);

  @override
  Future<List<Map<String, Object?>>> loadMatchCandidates() => throw StateError('candidate store unavailable');
}
