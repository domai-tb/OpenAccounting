import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

void main() {
  test('Angebot -> Auftrag propagates positions preserves eingabemodus', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'AN-YY####', naechste_nummer = 1 WHERE typ = 'angebot'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'AU-YY####', naechste_nummer = 1 WHERE typ = 'auftrag'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final angebot = await uc.createDokument(
      typ: 'angebot',
      datum: '2026-08-30',
      eingabemodus: 'brutto',
      positionen: const [
        RechnungPositionItem(bezeichnung: 'Design', menge: 10, einzelpreis: 150, gesamt: 1500),
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 200, ustSatz: 7),
      ],
    );
    final finAngebot = await uc.finalizeRechnung(rechnungId: angebot.id);
    final auftrag = await uc.konvertiereDokument(quelleId: finAngebot.id, zielTyp: 'auftrag');
    expect(auftrag.typ, 'auftrag');
    expect(auftrag.eingabemodus, 'brutto');
    expect(auftrag.positionen, hasLength(2));
    expect(auftrag.positionen.first.bezeichnung, 'Design');
    expect(auftrag.positionen.first.menge, 10);
    expect(auftrag.positionen.first.einzelpreis, 150);
    expect(auftrag.positionen.first.ustSatz, 19);
    // IDs regenerated
    expect(auftrag.positionen.first.id, isNot(angebot.positionen.first.id));
    final srcRows = await db.executor.runSelect('SELECT konvertiert_zu FROM rechnungen WHERE id = ?', [finAngebot.id]);
    final tgtRows = await db.executor.runSelect('SELECT konvertiert_von FROM rechnungen WHERE id = ?', [auftrag.id]);
    expect(srcRows.single['konvertiert_zu'], auftrag.id);
    expect(tgtRows.single['konvertiert_von'], finAngebot.id);
  });

  test('Lieferschein -> Rechnung propagates lieferadresse', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('Muster', 'Str 1', '10115', 'Berlin')",
    );
    final kunden = await db.executor.runSelect('SELECT id FROM kunden LIMIT 1', const <Object?>[]);
    final int kundenId = (kunden.single['id'] as num?)?.toInt() ?? 0;
    await db.executor.runCustom(
      'INSERT INTO kunden_lieferadressen (kunde_id, bezeichnung, strasse, plz, ort) VALUES (?, ?, ?, ?, ?)',
      [kundenId, 'Werkstatt Hamburg', 'Hafen 1', '20095', 'Hamburg'],
    );
    final adr = await db.executor.runSelect('SELECT id FROM kunden_lieferadressen LIMIT 1', const <Object?>[]);
    final int adrId = (adr.single['id'] as num?)?.toInt() ?? 0;
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'LS-YY####', naechste_nummer = 1 WHERE typ = 'lieferschein'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final ls = await uc.createDokument(
      typ: 'lieferschein',
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Ware A', menge: 2, einzelpreis: 50, gesamt: 100)],
      lieferadresseId: adrId,
    );
    expect(ls.typ, 'lieferschein');
    expect(ls.istEntwurf, isFalse);
    final rechnung = await uc.konvertiereDokument(quelleId: ls.id, zielTyp: 'rechnung');
    expect(rechnung.typ, 'rechnung');
    final rows = await db.executor.runSelect('SELECT lieferadresse_id FROM rechnungen WHERE id = ?', [rechnung.id]);
    expect(rows.single['lieferadresse_id'], adrId);
  });

  test('Auftrag -> LS -> Rechnung chain', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    for (final t in ['angebot', 'auftrag', 'lieferschein', 'rechnung_ausgang']) {
      final fmt = t == 'rechnung_ausgang' ? 'RE-YY####' : '${t.substring(0, 2).toUpperCase()}-YY####';
      await db.executor.runCustom('UPDATE nummernkreise SET format = ?, naechste_nummer = 1 WHERE typ = ?', [fmt, t]);
    }
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final ang = await uc.createDokument(
      typ: 'angebot',
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'X', menge: 1, einzelpreis: 100, gesamt: 100)],
    );
    final finAng = await uc.finalizeRechnung(rechnungId: ang.id);
    final auftrag = await uc.konvertiereDokument(quelleId: finAng.id, zielTyp: 'auftrag');
    final auftragFin = await uc.finalizeRechnung(rechnungId: auftrag.id);
    final ls = await uc.konvertiereDokument(quelleId: auftragFin.id, zielTyp: 'lieferschein');
    final re = await uc.konvertiereDokument(quelleId: ls.id, zielTyp: 'rechnung');
    expect(re.positionen.single.bezeichnung, 'X');
    expect(re.positionen.single.gesamt, 100);
  });

  test('unsupported conversion blocked', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'LS-YY####', naechste_nummer = 1 WHERE typ = 'lieferschein'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final ls = await uc.createDokument(
      typ: 'lieferschein',
      datum: '2026-08-30',
      positionen: const [RechnungPositionItem(bezeichnung: 'Ware', menge: 1, einzelpreis: 10, gesamt: 10)],
    );
    await expectLater(
      uc.konvertiereDokument(quelleId: ls.id, zielTyp: 'angebot'),
      throwsA(predicate((e) => e.toString().contains('kann nicht'))),
    );
  });

  test('position fields preserved including rabatt and ust', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'AN-YY####', naechste_nummer = 1 WHERE typ = 'angebot'",
    );
    final uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final ang = await uc.createDokument(
      typ: 'angebot',
      datum: '2026-08-30',
      positionen: const [
        RechnungPositionItem(bezeichnung: 'Website-Design', menge: 10, einzelpreis: 150, gesamt: 1500),
      ],
    );
    final fin = await uc.finalizeRechnung(rechnungId: ang.id);
    final auftrag = await uc.konvertiereDokument(quelleId: fin.id, zielTyp: 'auftrag');
    final pos = auftrag.positionen.single;
    expect(pos.bezeichnung, 'Website-Design');
    expect(pos.menge, 10);
    expect(pos.einzelpreis, 150);
    expect(pos.ustSatz, 19);
  });
}
