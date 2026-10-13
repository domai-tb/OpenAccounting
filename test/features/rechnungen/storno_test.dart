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
  test('test_rechnung_storno_reverses_positive_balances', () async {
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
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 200)],
    );
    final finalized = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final storno = await uc.stornoRechnung(rechnungId: finalized.id, grund: 'Falsch berechnet');
    expect(storno.typ, 'storno');
    expect(storno.rechnungsnummer, 'ST-260001');
    expect(storno.positionen.single.gesamt, -200);
    final totals = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [storno.id],
    );
    expect(totals.single['netto_betrag'], -200);
    expect(totals.single['ust_betrag'], -38);
    expect(totals.single['brutto_betrag'], -238);
    expect(storno.positionen.single.menge, 2);
    final rows = await db.executor.runSelect(
      'SELECT storno_grund, storno_datum, storno_von FROM rechnungen WHERE id = ?',
      [storno.id],
    );
    expect(rows.single['storno_grund'], 'Falsch berechnet');
    expect(rows.single['storno_datum'], isNotNull);
    expect(rows.single['storno_von'], finalized.id);
    final orig = await db.executor.runSelect('SELECT status FROM rechnungen WHERE id = ?', [finalized.id]);
    expect(orig.single['status'], 'storniert');
  });

  test('test_storno_requires_non_empty_reason', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final finalized = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    await expectLater(
      uc.stornoRechnung(rechnungId: finalized.id, grund: ''),
      throwsA(predicate((e) => e.toString().contains('Stornogrund'))),
    );
    await expectLater(
      uc.stornoRechnung(rechnungId: finalized.id, grund: '   '),
      throwsA(predicate((e) => e.toString().contains('Stornogrund'))),
    );

    final String tooLongReason = List<String>.filled(501, 'x').join();
    await expectLater(
      uc.stornoRechnung(rechnungId: finalized.id, grund: tooLongReason),
      throwsA(predicate((e) => e.toString().contains('Stornogrund zu lang'))),
    );
    final List<Map<String, Object?>> uncreatedStorno = await db.executor.runSelect(
      'SELECT id FROM rechnungen WHERE storno_von = ?',
      <Object?>[finalized.id],
    );
    expect(uncreatedStorno, isEmpty);

    final String maxLengthReason = List<String>.filled(500, 'x').join();
    final storno = await uc.stornoRechnung(rechnungId: finalized.id, grund: maxLengthReason);
    final List<Map<String, Object?>> createdStorno = await db.executor.runSelect(
      'SELECT storno_grund FROM rechnungen WHERE id = ?',
      <Object?>[storno.id],
    );
    expect(createdStorno.single['storno_grund'], maxLengthReason);
  });

  test('test_already_storniert_invoice_cannot_be_storniert_again', () async {
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
    await uc.stornoRechnung(rechnungId: fin.id, grund: 'Grund');
    await expectLater(
      uc.stornoRechnung(rechnungId: fin.id, grund: 'Erneut'),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('nicht zulässig'))),
    );
  });

  test('test_storno_restores_stock_from_source_movement', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    await db.executor.runCustom("INSERT INTO artikel (bezeichnung, vk_netto, bestand) VALUES ('Widget', 10, 20)");
    final art = await db.executor.runSelect('SELECT id FROM artikel WHERE bezeichnung = ?', ['Widget']);
    final int artikelId = (art.single['id'] as num?)?.toInt() ?? 0;
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: [
        RechnungPositionItem(artikelId: artikelId, bezeichnung: 'Widget', menge: 10, einzelpreis: 10, gesamt: 100),
      ],
    );
    final fin = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    var stock = await db.executor.runSelect('SELECT bestand FROM artikel WHERE id = ?', [artikelId]);
    expect(stock.single['bestand'], 10);
    await uc.stornoRechnung(rechnungId: fin.id, grund: 'Retoure');
    stock = await db.executor.runSelect('SELECT bestand FROM artikel WHERE id = ?', [artikelId]);
    expect(stock.single['bestand'], 20);
  });

  test('storno of draft blocked', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');

    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    await expectLater(
      uc.stornoRechnung(rechnungId: draft.id, grund: 'Grund'),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('nicht zulässig'))),
    );
  });

  test('test_gutschrift_storno_reverses_negative_balances', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );

    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final gutschrift = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'G', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final storno = await uc.stornoRechnung(rechnungId: gutschrift.id, grund: 'Gutschrift ausgleichen');
    final sourceTotals = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [gutschrift.id],
    );
    final totals = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [storno.id],
    );

    expect(gutschrift.positionen.single.gesamt, -100);
    expect(sourceTotals.single['netto_betrag'], -100);
    expect(sourceTotals.single['ust_betrag'], -19);
    expect(sourceTotals.single['brutto_betrag'], -119);
    expect(storno.positionen.single.gesamt, 100);
    expect(totals.single['netto_betrag'], 100);
    expect(totals.single['ust_betrag'], 19);
    expect(totals.single['brutto_betrag'], 119);
  });

  test('test_gutschrift_storno_is_exact_positive_inverse', () async {
    final db = await _openProfileDb();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );

    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100)],
      rabattProzent: 10,
    );
    final invoice = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final gutschrift = await uc.createGutschrift(vonRechnungId: invoice.id, grund: 'Preisnachlass');
    final storno = await uc.stornoRechnung(rechnungId: gutschrift.id, grund: 'Gutschrift ersetzen');
    final totals = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [storno.id],
    );

    expect(totals.single['netto_betrag'], 90);
    expect(totals.single['ust_betrag'], 17.1);
    expect(totals.single['brutto_betrag'], 107.1);
  });
}
