import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

void main() {
  test('gutschrift from invoice creates negative amounts with GS nummer and link', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 500, gesamt: 500)],
    );
    final fin = await uc.finalizeRechnung(rechnungId: draft.id);
    final gs = await uc.createGutschrift(vonRechnungId: fin.id, grund: 'Mangel');
    expect(gs.typ, 'gutschrift');
    expect(gs.rechnungsnummer, 'GS-260001');
    expect(gs.positionen.single.gesamt, -500);
    final rows = await db.executor.runSelect('SELECT gutschrift_von FROM rechnungen WHERE id = ?', [gs.id]);
    expect(rows.single['gutschrift_von'], fin.id);
  });

  test('standalone gutschrift without reference', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final gs = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Gutschrift', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    expect(gs.typ, 'gutschrift');
    expect(gs.rechnungsnummer, 'GS-260001');
    expect(gs.positionen.single.gesamt, -100);
    final rows = await db.executor.runSelect('SELECT gutschrift_von FROM rechnungen WHERE id = ?', [gs.id]);
    expect(rows.single['gutschrift_von'], isNull);
  });

  test('ersatzrechnung bidirectional link only from storniert', () async {
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
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final gs = await uc.createGutschrift(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'G', menge: 1, einzelpreis: 200, gesamt: 200)],
    );
    final storno = await uc.stornoRechnung(rechnungId: gs.id, grund: 'Storno Gutschrift');
    expect(storno.typ, 'storno');
    expect(storno.positionen.single.gesamt, 200);
  });
}
