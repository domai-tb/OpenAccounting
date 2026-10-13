import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

Future<AppDatabase> _openProfileDb() async {
  final Directory profile = await Directory.systemTemp.createTemp('correction-flow-');
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profile.path);
  addTearDown(() async {
    await db.close();
    await profile.delete(recursive: true);
  });
  await db.ensureOpen();
  return db;
}

void main() {
  test('test_invoice_gutschrift_links_source_and_uses_gs_number', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 500, gesamt: 500)],
    );
    final fin = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final gs = await uc.createGutschrift(vonRechnungId: fin.id, grund: 'Mangel');
    expect(gs.typ, 'gutschrift');
    expect(gs.rechnungsnummer, 'GS-260001');
    expect(gs.positionen.single.gesamt, -500);
    final rows = await db.executor.runSelect('SELECT gutschrift_von FROM rechnungen WHERE id = ?', [gs.id]);
    expect(rows.single['gutschrift_von'], fin.id);
  });

  test('test_standalone_gutschrift_has_gs_number_and_no_source_reference', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final gs = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Gutschrift', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    expect(gs.typ, 'gutschrift');
    expect(gs.rechnungsnummer, 'GS-260001');
    expect(gs.positionen.single.gesamt, -100);
    final totals = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [gs.id],
    );
    expect(totals.single['netto_betrag'], -100);
    expect(totals.single['ust_betrag'], -19);
    expect(totals.single['brutto_betrag'], -119);
    final rows = await db.executor.runSelect('SELECT gutschrift_von FROM rechnungen WHERE id = ?', [gs.id]);
    expect(rows.single['gutschrift_von'], isNull);
  });

  test('ersatzrechnung bidirectional link only from storniert', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final fin = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    await expectLater(
      uc.createErsatzRechnung(vonRechnungId: fin.id),
      throwsA(predicate((e) => e.toString().contains('stornierter'))),
    );
    await uc.stornoRechnung(rechnungId: fin.id, grund: 'Fehler');
    final ersatz = await uc.createErsatzRechnung(vonRechnungId: fin.id);
    final origRows = await db.executor.runSelect('SELECT ersatzrechnung_id FROM rechnungen WHERE id = ?', [fin.id]);
    final ersatzRows = await db.executor.runSelect('SELECT ersatz_fuer FROM rechnungen WHERE id = ?', [ersatz.id]);
    expect(origRows.single['ersatzrechnung_id'], ersatz.id);
    expect(ersatzRows.single['ersatz_fuer'], fin.id);
  });

  test('gutschrift can be storniert', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final gs = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'G', menge: 1, einzelpreis: 200, gesamt: 200)],
    );
    final storno = await uc.stornoRechnung(rechnungId: gs.id, grund: 'Storno Gutschrift');
    expect(storno.typ, 'storno');
    expect(storno.positionen.single.gesamt, 200);
  });

  test('test_rechnung_correction_and_standalone_gutschrift_have_negative_totals', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );

    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final invoice = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final fromInvoice = await uc.createGutschrift(vonRechnungId: invoice.id, grund: 'Korrektur');
    final standalone = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100)],
    );

    for (final credit in [fromInvoice, standalone]) {
      final totals = await db.executor.runSelect(
        'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
        [credit.id],
      );
      expect(credit.positionen.single.gesamt, -100);
      expect(totals.single['netto_betrag'], -100);
      expect(totals.single['ust_betrag'], -19);
      expect(totals.single['brutto_betrag'], -119);
    }
  });

  test('test_invoice_gutschrift_reverses_discounted_totals', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );

    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100)],
      rabattProzent: 10,
    );
    final invoice = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final credit = await uc.createGutschrift(vonRechnungId: invoice.id, grund: 'Rabattkorrektur');
    final totals = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag, rabatt_prozent FROM rechnungen WHERE id = ?',
      [credit.id],
    );

    expect(totals.single['netto_betrag'], -90);
    expect(totals.single['ust_betrag'], -17.1);
    expect(totals.single['brutto_betrag'], -107.1);
    expect(totals.single['rabatt_prozent'], 10);
  });

  test('test_standalone_gutschrift_persists_negative_totals_without_source', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );

    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final credit = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final totals = await db.executor.runSelect(
      'SELECT gutschrift_von, netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [credit.id],
    );

    expect(totals.single['gutschrift_von'], isNull);
    expect(credit.positionen.single.gesamt, -100);
    expect(totals.single['netto_betrag'], -100);
    expect(totals.single['ust_betrag'], -19);
    expect(totals.single['brutto_betrag'], -119);
  });
}
