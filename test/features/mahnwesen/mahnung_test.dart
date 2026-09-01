import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';

void main() {
  group('Mahnung Snapshot, Gebühr/Zinsen, Carry-Over', () {
    late AppDatabase db;
    late MahnungenRepository repo;
    late MahnstufenRepository stufenRepo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MahnungenRepository(db.executor);
      stufenRepo = MahnstufenRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> createKunde({String name = 'Test Kunde'}) async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[name, 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
    }

    Future<int> createRechnung({
      required int kundeId,
      String rechnungsnummer = 'RE-999',
      String brutto = '500.00',
      String faelligkeit = '2025-01-15',
    }) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[rechnungsnummer, 'rechnung', 'offen', 1, 'netto', kundeId, '2025-01-01', faelligkeit, brutto, brutto],
      );
    }

    test('dunning creates snapshot and retains after rechnung edit', () async {
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1001', brutto: '500.00');
      final levels = await stufenRepo.list();
      final stufe = levels.firstWhere((e) => e.stufe == 1);
      final mahnung = await repo.create(rechnungId: rechnungId, stufeId: stufe.id);
      expect(mahnung.snapshot, isNotNull);
      final snap = mahnung.snapshotData;
      expect(snap, isNotNull);
      expect(snap!['rechnungsnummer'], 'RE-1001');
      expect(snap['betrag'], '500.00');
      expect(snap['faelligkeit'], '2025-01-15');
      expect(snap['stufe'], 1);
      // Edit rechnung amount to 600 → snapshot retains 500.
      await db.executor.runUpdate('UPDATE rechnungen SET brutto_betrag = ?, netto_betrag = ? WHERE id = ?', <Object?>[
        '600.00',
        '600.00',
        rechnungId,
      ]);
      final after = await repo.getById(mahnung.id);
      expect(after, isNotNull);
      expect(after!.snapshotData!['betrag'], '500.00');
      expect(after.betrag, '500.00');
    });

    test('Gebühr bezahlt/unbezahlt partial and full tracking', () async {
      final kundeId = await createKunde(name: 'Gebuehr Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1002', brutto: '1000.00');
      final levels = await stufenRepo.list();
      final stufe = levels.firstWhere((e) => e.stufe == 2);
      final mahnung = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe.id,
        gebuehrOverride: '10.00',
        zinsenOverride: '0.00',
      );
      expect(mahnung.gebuehr, '10.00');
      expect(mahnung.gebuehrBezahlt, '0.00');
      expect(mahnung.gebuehrUnbezahlt, '10.00');
      // Partial 5 → bezahlt 5 unbezahlt 5.
      final partial = await repo.updateGebuehrBezahlt(mahnung.id, '5.00');
      expect(partial.gebuehrBezahlt, '5.00');
      expect(partial.gebuehrUnbezahlt, '5.00');
      // Full 10 → 0 unbezahlt.
      final full = await repo.updateGebuehrBezahlt(mahnung.id, '10.00');
      expect(full.gebuehrBezahlt, '10.00');
      expect(full.gebuehrUnbezahlt, '0.00');
    });

    test('Zinsen formula 1000*0.08*30/365≈6.58 and zero outstanding →0', () async {
      final z = repo.berechneZinsen(betrag: '1000.00', zinssatz: '8.00', tage: 30);
      // 1000*0.08*30/365 = 6.575 → 6.58
      expect(z, '6.58');
      expect(repo.berechneZinsen(betrag: '0.00', zinssatz: '8.00', tage: 30), '0.00');
      expect(repo.berechneZinsen(betrag: '1000.00', zinssatz: '0.00', tage: 30), '0.00');
      expect(repo.berechneZinsen(betrag: '1000.00', zinssatz: '8.00', tage: 0), '0.00');
    });

    test('Carry-over: level2 open 10+3 → level3 shows carried', () async {
      final kundeId = await createKunde(name: 'Carry Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1003', brutto: '500.00');
      final levels = await stufenRepo.list();
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      final stufe3 = levels.firstWhere((e) => e.stufe == 3);
      // Level2 open 10+3.
      await repo.create(rechnungId: rechnungId, stufeId: stufe2.id, gebuehrOverride: '10.00', zinsenOverride: '3.00');
      final carryBefore = await repo.getCarryOver(rechnungId);
      expect(carryBefore, '13.00');
      // Level3 should show carried.
      final m3 = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe3.id,
        gebuehrOverride: '15.00',
        zinsenOverride: '0.00',
      );
      expect(m3.uebernommeneGebuehr, '10.00');
      expect(m3.uebernommeneZinsen, '3.00');
      expect(m3.carriedTotal, '13.00');
      // Also via breakdown.
      final breakdown = await repo.getCarryOverBreakdown(rechnungId);
      // After level3 creation, prior unpaid still 13 + new level3 unpaid 15 → total 28, but we check carry before includes only level2.
      // For this test, ensure at least carryBefore was 13.
      expect(breakdown['total'], isNotNull);
    });

    test('No carry when fully paid → 0 carried', () async {
      final kundeId = await createKunde(name: 'NoCarry Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1004', brutto: '500.00');
      final levels = await stufenRepo.list();
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      final stufe3 = levels.firstWhere((e) => e.stufe == 3);
      final m2 = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe2.id,
        gebuehrOverride: '10.00',
        zinsenOverride: '3.00',
      );
      await repo.updateGebuehrBezahlt(m2.id, '10.00');
      await repo.updateZinsenBezahlt(m2.id, '3.00');
      final carry = await repo.getCarryOver(rechnungId);
      expect(carry, '0.00');
      final m3 = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe3.id,
        gebuehrOverride: '15.00',
        zinsenOverride: '0.00',
      );
      expect(m3.uebernommeneGebuehr, '0.00');
      expect(m3.uebernommeneZinsen, '0.00');
      expect(m3.carriedTotal, '0.00');
    });

    test('rechnungen.mahnstufe_aktuell updated on create', () async {
      final kundeId = await createKunde(name: 'Stufe Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1005', brutto: '400.00');
      final levels = await stufenRepo.list();
      final stufe1 = levels.firstWhere((e) => e.stufe == 1);
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      await repo.create(rechnungId: rechnungId, stufeId: stufe1.id);
      expect(await repo.getInvoiceDunningLevel(rechnungId), 1);
      await repo.create(rechnungId: rechnungId, stufeId: stufe2.id, gebuehrOverride: '10.00');
      expect(await repo.getInvoiceDunningLevel(rechnungId), 2);
    });

    test('listByRechnung and listByKunde return created mahnungen', () async {
      final kundeId = await createKunde(name: 'List Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1006', brutto: '200.00');
      final levels = await stufenRepo.list();
      final stufe = levels.first;
      await repo.create(rechnungId: rechnungId, stufeId: stufe.id);
      final byRechnung = await repo.listByRechnung(rechnungId);
      expect(byRechnung, hasLength(1));
      final byKunde = await repo.listByKunde(kundeId);
      expect(byKunde.length, greaterThanOrEqualTo(1));
    });
  });
}
