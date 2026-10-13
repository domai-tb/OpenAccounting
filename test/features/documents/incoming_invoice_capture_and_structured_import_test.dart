import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

Future<AppDatabase> _openDb() async {
  final Directory profile = await Directory.systemTemp.createTemp('incoming-invoice-');
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profile.path);
  addTearDown(() async {
    await db.close();
    await profile.delete(recursive: true);
  });
  await db.ensureOpen();
  return db;
}

Future<void> _seedRanges(AppDatabase db) async {
  await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'LS-YY####', naechste_nummer = 1 WHERE typ = 'lieferschein'",
  );
}

RechnungenUseCases _useCases(AppDatabase db) {
  return RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
}

const List<RechnungPositionItem> _positionen = <RechnungPositionItem>[
  RechnungPositionItem(bezeichnung: 'Leistung', menge: 1, einzelpreis: 5000, gesamt: 5000),
];

void main() {
  group('incoming-invoice-capture-and-structured-import / document lifecycle', () {
    test('test_draft_not_in_euer', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final RechnungenUseCases useCases = _useCases(db);
      final RechnungItem draft = await useCases.createDraftRechnung(datum: '2026-04-01', positionen: _positionen);

      final result = await EuerService(db.executor).generate(jahr: 2026);

      final List<Map<String, Object?>> totals = await db.executor.runSelect(
        'SELECT brutto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[draft.id],
      );
      expect(num.parse(totals.single['brutto_betrag'].toString()), 5950);
      expect(result.gewinn, '0.00');
      expect(result.zeile(12), '0.00');
    });

    test('test_draft_editable', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final RechnungenUseCases useCases = _useCases(db);
      final RechnungItem draft = await useCases.createDraftRechnung(datum: '2026-04-01', positionen: _positionen);

      final RechnungItem updated = await useCases.updateDraftRechnung(
        rechnungId: draft.id,
        datum: '2026-04-02',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Geänderte Leistung', menge: 2, einzelpreis: 120, gesamt: 240),
        ],
      );

      expect(updated.istEntwurfDokument, isTrue);
      expect(updated.datum, '2026-04-02');
      expect(updated.positionen.single.bezeichnung, 'Geänderte Leistung');
      expect(updated.positionen.single.menge, 2);
      final List<Map<String, Object?>> totals = await db.executor.runSelect(
        'SELECT brutto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[updated.id],
      );
      expect(num.parse(totals.single['brutto_betrag'].toString()), closeTo(285.6, 0.001));
    });

    test('test_incoming_invoice_supports_draft_state', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);

      final RechnungItem draft = await _useCases(db)
          .createDraftRechnung(datum: '2026-04-01', positionen: _positionen, typ: 'rechnung_eingang');
      final List<Map<String, Object?>> journal = await db.executor.runSelect(
        'SELECT id FROM journal WHERE rechnung_id = ?',
        <Object?>[draft.id],
      );
      final List<Map<String, Object?>> claims = await db.executor.runSelect(
        'SELECT id FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[draft.id],
      );

      expect(draft.typ, 'rechnung_eingang');
      expect(draft.istEntwurf, isTrue);
      expect(draft.status, 'entwurf');
      expect(journal, isEmpty);
      expect(claims, isEmpty);
    });

    test('test_lieferschein_created_without_draft_state', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);

      final RechnungItem lieferschein = await _useCases(db)
          .createDokument(typ: 'lieferschein', datum: '2026-04-01', positionen: _positionen);

      expect(lieferschein.istEntwurf, isFalse);
      expect(lieferschein.status, isNot('entwurf'));
      expect(lieferschein.rechnungsnummer, isNotNull);
    });
  });
}
