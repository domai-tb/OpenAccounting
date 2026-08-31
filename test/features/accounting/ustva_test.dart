import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/ustva_entity.dart';
import 'package:openaccounting/features/accounting/ustva_service.dart';

void main() {
  group('UStVA KZ calculations — monthly/quarterly', () {
    late AppDatabase db;
    late UstvaService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await _ensureUstvaColumns(db);
      service = UstvaService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertJournal({
      required String betrag,
      required String datum,
      String? ustSatz,
      String? ustSonderfall,
      String? marge,
      String? ustSatz25a,
      int kategorieId = 1,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?)',
        <Object?>[datum, 'Test $datum', kategorieId, betrag, 'Einnahme', ustSatz, ustSonderfall, marge, ustSatz25a],
      );
    }

    Future<void> insertVorsteuer({required String betrag, required String faelligkeit, String? sonderfall}) async {
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status, ust_sonderfall) VALUES (?, ?, ?, ?)',
        <Object?>[betrag, faelligkeit, 'offen', sonderfall],
      );
    }

    test('KZ1 Gesamtumsatz steuerpflichtig sum', () async {
      await insertJournal(betrag: '1000.00', datum: '2025-03-10', ustSatz: '19');
      await insertJournal(betrag: '500.50', datum: '2025-03-15', ustSatz: '19');
      // different month must not count
      await insertJournal(betrag: '9999.00', datum: '2025-04-01', ustSatz: '19');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 3, rhythmus: 'monatlich');

      expect(r.kz['1'], '1500.50');
      expect(r.kzValue('1'), '1500.50');
      // also String money pure 2 decimals
      expect(r.kz['1'], matches(RegExp(r'^-?\d+\.\d{2}$')));
    });

    test('KZ3 19% USt and KZ4 7% USt', () async {
      // 119 brutto 19% => USt 19.00 ; 107 brutto 7% => USt 7.00
      await insertJournal(betrag: '119.00', datum: '2025-05-05', ustSatz: '19');
      await insertJournal(betrag: '107.00', datum: '2025-05-10', ustSatz: '7');
      await insertJournal(betrag: '119.00', datum: '2025-05-12', ustSatz: '19');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 5, rhythmus: 'monatlich');

      // KZ3 = 19+19=38, KZ4=7
      expect(r.kz['3'], '38.00');
      expect(r.kz['4'], '7.00');
      // KZ1 includes gross sum 119+107+119=345
      expect(r.kz['1'], '345.00');
    });

    test('KZ61 ig Erwerb vs KZ66 allgemein (exclude 61 from 66)', () async {
      await insertVorsteuer(betrag: '190.00', faelligkeit: '2025-06-15', sonderfall: 'ig_erwerb');
      await insertVorsteuer(betrag: '50.00', faelligkeit: '2025-06-16', sonderfall: 'ig_erwerb');
      await insertVorsteuer(betrag: '100.00', faelligkeit: '2025-06-17');
      await insertVorsteuer(betrag: '20.00', faelligkeit: '2025-06-18', sonderfall: 'domestic');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 6, rhythmus: 'monatlich');

      expect(r.kz['61'], '240.00');
      // KZ66 must be 120, not include ig Erwerb (if bug, would be 360)
      expect(r.kz['66'], '120.00');
    });

    test('KZ18 Differenzsteuer §25a via marge_25a_brutto', () async {
      // marge 119 *19/(100+19)=19
      await insertJournal(betrag: '500.00', datum: '2025-07-10', marge: '119.00', ustSatz25a: '19');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 7, rhythmus: 'monatlich');

      expect(r.kz['18'], '19.00');
    });

    test('KZ18 negative margin max(0) yields 0', () async {
      await insertJournal(betrag: '400.00', datum: '2025-07-15', marge: '-50.00', ustSatz25a: '19');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 7, rhythmus: 'monatlich');

      expect(r.kz['18'], '0.00');
      expect(r.kz['81'], '0.00');
      expect(r.kz['83'], '0.00');
    });

    test('KZ81/83 Differenzbetrag: KZ81 sum max(marge,0), KZ83 = KZ81 * satz/(100+satz)', () async {
      await insertJournal(betrag: '300.00', datum: '2025-08-05', marge: '119.00', ustSatz25a: '19');
      await insertJournal(betrag: '300.00', datum: '2025-08-06', marge: '238.00', ustSatz25a: '19');
      // negative ignored
      await insertJournal(betrag: '300.00', datum: '2025-08-07', marge: '-100.00', ustSatz25a: '19');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 8, rhythmus: 'monatlich');

      // KZ81 = 119+238=357, KZ83 = 357*19/119=57
      expect(r.kz['81'], '357.00');
      expect(r.kz['83'], '57.00');
      // KZ18 should equal KZ83 per spec (same base*rate)
      expect(r.kz['18'], '57.00');
    });

    test('KZ89/93 reverse charge separate not domestic', () async {
      await insertJournal(betrag: '500.00', datum: '2025-09-10', ustSatz: '19');
      await insertJournal(betrag: '1000.00', datum: '2025-09-11', ustSatz: '19', ustSonderfall: '13b_abs1');

      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 9, rhythmus: 'monatlich');

      // RC base 1000, tax 1000*19/119=159 (floor 159.66? compute: 100000*19/119=15966=>159.66 floor 159)
      // Let's compute exact: 1000.00 =100000 cents *19/119=15966 =>159.66
      expect(r.kz['89'], '1000.00');
      expect(r.kz['93'], '159.66');
      // KZ1 must be 500 only, not 1500
      expect(r.kz['1'], '500.00');
      // KZ3 should reflect only domestic (500*19/119=79.83 floor 79.83? 50000*19/119=7983=>79.83)
      expect(r.kz['3'], '79.83');
    });

    test('quarterly filing aggregates 3 months', () async {
      await insertJournal(betrag: '100.00', datum: '2025-01-10', ustSatz: '19');
      await insertJournal(betrag: '200.00', datum: '2025-02-15', ustSatz: '19');
      await insertJournal(betrag: '300.00', datum: '2025-03-20', ustSatz: '19');
      await insertJournal(betrag: '999.00', datum: '2025-04-01', ustSatz: '19');

      final UstvaResult q1 = await service.compute(jahr: 2025, monatOrQuartal: 1, rhythmus: 'quartal');

      expect(q1.kz['1'], '600.00');
      // April not included
      final UstvaResult q2 = await service.compute(jahr: 2025, monatOrQuartal: 2, rhythmus: 'quartal');
      expect(q2.kz['1'], '999.00');
    });

    test('quarterly aggregates vorsteuer too', () async {
      await insertVorsteuer(betrag: '19.00', faelligkeit: '2025-01-05');
      await insertVorsteuer(betrag: '19.00', faelligkeit: '2025-02-05');
      await insertVorsteuer(betrag: '19.00', faelligkeit: '2025-03-05');
      await insertVorsteuer(betrag: '99.00', faelligkeit: '2025-04-05');

      final UstvaResult q1 = await service.compute(jahr: 2025, monatOrQuartal: 1, rhythmus: 'quartal');
      expect(q1.kz['66'], '57.00');

      final UstvaResult m2 = await service.compute(jahr: 2025, monatOrQuartal: 2, rhythmus: 'monatlich');
      expect(m2.kz['66'], '19.00');
    });

    test('no transactions all 0', () async {
      final UstvaResult r = await service.compute(jahr: 2025, monatOrQuartal: 12, rhythmus: 'monatlich');

      expect(r.kz['1'], '0.00');
      expect(r.kz['3'], '0.00');
      expect(r.kz['4'], '0.00');
      expect(r.kz['18'], '0.00');
      expect(r.kz['61'], '0.00');
      expect(r.kz['66'], '0.00');
      expect(r.kz['81'], '0.00');
      expect(r.kz['83'], '0.00');
      expect(r.kz['89'], '0.00');
      expect(r.kz['93'], '0.00');
      // String money pure
      for (final String v in r.kz.values) {
        expect(v, matches(RegExp(r'^-?\d+\.\d{2}$')));
      }
    });

    test('rhythmus alias monthly/quarterly accepted', () async {
      await insertJournal(betrag: '100.00', datum: '2025-10-10', ustSatz: '19');
      final UstvaResult a = await service.compute(jahr: 2025, monatOrQuartal: 10, rhythmus: 'monthly');
      expect(a.kz['1'], '100.00');
      final UstvaResult b = await service.compute(jahr: 2025, monatOrQuartal: 4, rhythmus: 'quarterly');
      expect(b.kz['1'], '100.00');
    });
  });
}

Future<void> _ensureUstvaColumns(AppDatabase db) async {
  final List<Map<String, Object?>> jCols = await db.executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
  final Set<String> jNames = jCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!jNames.contains('ust_satz')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ust_satz NUMERIC(12,2)');
  }
  if (!jNames.contains('ust_sonderfall')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ust_sonderfall TEXT');
  }
  if (!jNames.contains('marge_25a_brutto')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN marge_25a_brutto NUMERIC(12,2)');
  }
  if (!jNames.contains('ust_satz_25a')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ust_satz_25a NUMERIC(12,2)');
  }
  if (!jNames.contains('ist_eu_lieferung')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ist_eu_lieferung INTEGER DEFAULT 0');
  }
  if (!jNames.contains('vorsteuer_betrag')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN vorsteuer_betrag NUMERIC(12,2)');
  }
  final List<Map<String, Object?>> vCols = await db.executor.runSelect(
    'PRAGMA table_info(vorsteuer_ansprueche)',
    const <Object?>[],
  );
  final Set<String> vNames = vCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!vNames.contains('ust_sonderfall')) {
    await db.executor.runCustom('ALTER TABLE vorsteuer_ansprueche ADD COLUMN ust_sonderfall TEXT');
  }
}
