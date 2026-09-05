import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

void main() {
  test('netto mode position totals', () {
    final preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 3, einzelpreis: 100, gesamt: 300)],
    );
    expect(preview.nettoBetrag, 300.00);
    expect(preview.ustBetrag, 57.00);
    expect(preview.bruttoBetrag, 357.00);
  });

  test('brutto mode derives netto correctly', () {
    final preview = VorschauService.calculate(
      eingabemodus: 'brutto',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 3, einzelpreis: 119, gesamt: 357)],
    );
    expect(preview.bruttoBetrag, 357.00);
    expect(preview.nettoBetrag, 300.00);
    expect(preview.ustBetrag, 57.00);
  });

  test('position-level rounding', () {
    final preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 3, einzelpreis: 33.333, gesamt: 100)],
    );
    // einzelpreis 33.333 *3 = 99.999 -> rounded 100.00, ust 19.00
    expect(preview.nettoBetrag, closeTo(100.00, 0.01));
  });

  test('document-level rabatt conflict rejected', () {
    expect(
      () => VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 1000, gesamt: 1000)],
        rabattProzent: 10,
        rabattBetrag: 50,
      ),
      throwsA(predicate((e) => e.toString().contains('Nur ein Rabatt'))),
    );
  });

  test('position rabatt 10% reduces total', () {
    final preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const [
        RechnungPositionItem(bezeichnung: 'A', menge: 2, einzelpreis: 200, gesamt: 360, rabattProzent: 10),
      ],
    );
    expect(preview.nettoBetrag, 360.00);
  });

  test('document rabatt fixed amount', () {
    final preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 1000, gesamt: 1000)],
      rabattBetrag: 50,
    );
    expect(preview.nettoBetrag, 950.00);
  });

  test('preview is single source for finalize totals', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 2, einzelpreis: 100, gesamt: 200)],
    );
    final fin = await uc.finalizeRechnung(rechnungId: draft.id);
    final rows = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      [fin.id],
    );
    expect(rows.single['netto_betrag'], 200);
    expect(rows.single['ust_betrag'], 38);
    expect(rows.single['brutto_betrag'], 238);
    // preview must match stored
    final preview = VorschauService.calculate(eingabemodus: 'netto', positionen: fin.positionen);
    expect(preview.nettoBetrag, 200);
    expect(preview.ustBetrag, 38);
  });

  test('brutto mode preview matches stored on finalize', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await uc.createDraftRechnung(
      datum: '2026-08-30',
      eingabemodus: 'brutto',
      positionen: const [RechnungPositionItem(bezeichnung: 'A', menge: 3, einzelpreis: 119, gesamt: 357)],
    );
    final fin = await uc.finalizeRechnung(rechnungId: draft.id);
    final rows = await db.executor.runSelect('SELECT netto_betrag, brutto_betrag FROM rechnungen WHERE id = ?', [
      fin.id,
    ]);
    expect(rows.single['brutto_betrag'], 357);
    expect(rows.single['netto_betrag'], 300);
  });
}
