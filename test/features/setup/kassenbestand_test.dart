import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.createTestDatabase();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kassenbestand Initialisierung', () {
    test('Default Kassenbestand 0.00 wenn leer', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);

      await repo.ensureKassenKonto(betrag: '0.00');

      final konten = await db.executor.runSelect('SELECT * FROM konten WHERE kontoart = ?', const ['Kasse']);
      expect(konten.length, 1);
      expect(konten.single['name'], contains('Kasse'));

      final journal = await db.executor.runSelect('SELECT betrag FROM journal WHERE konto_id = ?', <Object?>[
        konten.single['id'],
      ]);
      expect(journal.length, 1);
      expect(money.formatBetrag(journal.single['betrag'].toString()), '0.00');

      await db.close();
    });

    test('Custom Kassenbestand 150.00', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);

      await repo.ensureKassenKonto(betrag: '150.00');

      final konten = await db.executor.runSelect('SELECT * FROM konten WHERE kontoart = ?', const ['Kasse']);
      expect(konten.length, 1);

      final journal = await db.executor.runSelect('SELECT betrag FROM journal WHERE konto_id = ?', <Object?>[
        konten.single['id'],
      ]);
      expect(money.formatBetrag(journal.single['betrag'].toString()), '150.00');

      await db.close();
    });

    test('Negativer Kassenbestand wird abgelehnt', () async {
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);

      expect(() => repo.ensureKassenKonto(betrag: '-10.00'), throwsA(isA<Exception>()));
      expect(() => repo.ensureKassenKonto(betrag: '-0.01'), throwsA(isA<Exception>()));

      await db.close();
    });

    test('WizardService validiert negativen Kassenbestand', () {
      final svc = WizardService();
      expect(svc.validateKassenbestand('-5'), isNotNull);
      expect(svc.validateKassenbestand('0'), isNull);
      expect(svc.validateKassenbestand(''), isNull);
    });

    test('Kassen-Konto wird in konten-Tabelle mit kontoart=Kasse angelegt', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);

      await repo.ensureKassenKonto(betrag: '42.50');

      final rows = await db.executor.runSelect("SELECT kontoart FROM konten WHERE kontoart = 'Kasse'", const []);
      expect(rows.length, 1);
      expect(rows.single['kontoart'], 'Kasse');

      await db.close();
    });

    test('Eröffnungsbuchung über Standard-Journal, kein separates kassenbestand-Table', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);

      await repo.ensureKassenKonto(betrag: '10.00');

      // kein separates Table
      final tables = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='kassenbestand'",
        const [],
      );
      expect(tables, isEmpty);

      // journal enthält Eröffnungsbetrag
      final journals = await db.executor.runSelect('SELECT * FROM journal', const []);
      expect(journals.length, 1);
      expect(money.formatBetrag(journals.single['betrag'].toString()), '10.00');

      await db.close();
    });

    test('Wizard completeWizard mit Kassenbestand persistiert Journal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);
      final svc = WizardService(repository: repo);

      await svc.completeWizard(
        companyName: 'Test GmbH',
        accounts: <BankAccount>[const BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: '')],
        kassenbestand: '150.00',
        kategorieIds: <int>[1],
      );

      final konten = await db.executor.runSelect('SELECT id FROM konten WHERE kontoart = ?', const ['Kasse']);
      final journal = await db.executor.runSelect('SELECT betrag FROM journal WHERE konto_id = ?', <Object?>[
        konten.single['id'],
      ]);
      expect(money.formatBetrag(journal.single['betrag'].toString()), '150.00');

      await db.close();
    });

    test('Idempotenz: zweiter Aufruf ändert Kassenbestand nicht doppelt', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);

      await repo.ensureKassenKonto(betrag: '20.00');
      await repo.ensureKassenKonto(betrag: '20.00');

      final konten = await db.executor.runSelect('SELECT COUNT(*) as c FROM konten WHERE kontoart = ?', const [
        'Kasse',
      ]);
      // ponytail: idempotent — nur ein Kasse-Konto
      expect(contenSingle(conten: konten), 1);

      await db.close();
    });
  });
}

int contenSingle({required List<Map<String, Object?>> conten}) {
  final v = conten.single['c'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.parse(v.toString());
}
