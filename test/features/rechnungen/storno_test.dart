import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

void main() {
  test('storno creates negative amounts with own nummernkreis and links original', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 200)],
    );
    final finalized = await uc.finalizeRechnung(rechnungId: draft.id);
    final storno = await uc.stornoRechnung(rechnungId: finalized.id, grund: 'Falsch berechnet');
    expect(storno.typ, 'storno');
    expect(storno.rechnungsnummer, 'ST-260001');
    expect(storno.positionen.single.gesamt, -200);
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

  test('storno requires grund', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final finalized = await uc.finalizeRechnung(rechnungId: draft.id);
    await expectLater(
      uc.stornoRechnung(rechnungId: finalized.id, grund: ''),
      throwsA(predicate((e) => e.toString().contains('Stornogrund'))),
    );
    await expectLater(
      uc.stornoRechnung(rechnungId: finalized.id, grund: '   '),
      throwsA(predicate((e) => e.toString().contains('Stornogrund'))),
    );
  });

  test('duplicate storno blocked', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final fin = await uc.finalizeRechnung(rechnungId: draft.id);
    await uc.stornoRechnung(rechnungId: fin.id, grund: 'Grund');
    await expectLater(
      uc.stornoRechnung(rechnungId: fin.id, grund: 'Erneut'),
      throwsA(predicate((e) => e.toString().contains('bereits storniert'))),
    );
  });

  test('storno restores stock', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    await db.executor.runCustom("INSERT INTO artikel (bezeichnung, vk_netto, bestand) VALUES ('Widget', 10, 20)");
    final art = await db.executor.runSelect('SELECT id FROM artikel WHERE bezeichnung = ?', ['Widget']);
    final int artikelId = (art.single['id'] as num?)?.toInt() ?? 0;
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: [
        RechnungPositionItem(artikelId: artikelId, bezeichnung: 'Widget', menge: 10, einzelpreis: 10, gesamt: 100),
      ],
    );
    final fin = await uc.finalizeRechnung(rechnungId: draft.id);
    var stock = await db.executor.runSelect('SELECT bestand FROM artikel WHERE id = ?', [artikelId]);
    expect(stock.single['bestand'], 10);
    await uc.stornoRechnung(rechnungId: fin.id, grund: 'Retoure');
    stock = await db.executor.runSelect('SELECT bestand FROM artikel WHERE id = ?', [artikelId]);
    expect(stock.single['bestand'], 20);
  });

  test('storno of draft blocked', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    await expectLater(
      uc.stornoRechnung(rechnungId: draft.id, grund: 'Grund'),
      throwsA(predicate((e) => e.toString().contains('finalisiert'))),
    );
  });
}
