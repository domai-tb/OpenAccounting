import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';

void main() {
  group('Schema — 38 tables', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('all 38 tables exist after creation', () async {
      final rows = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
        const [],
      );
      final names = rows.map((r) => r['name']?.toString() ?? '').toList()..sort();
      expect(names.length, 38, reason: 'Expected 38 tables, got ${names.length}: $names');
      for (final t in AppDatabase.allTableNames) {
        expect(names, contains(t), reason: 'Missing table $t');
      }
    });

    test('table count remains 38 after second open', () async {
      await db.close();
      final db2 = AppDatabase.createTestDatabase();
      await db2.ensureOpen();
      final rows = await db2.executor.runSelect(
        "SELECT count(*) as c FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        const [],
      );
      expect(rows.first['c'], 38);
      await db2.close();
    });

    test('NUMERIC(12,2) for money columns, NUMERIC(12,4) for vk_netto', () async {
      final rows = await db.executor.runSelect("SELECT sql FROM sqlite_master WHERE type='table'", const []);
      final allSql = rows.map((r) => (r['sql'] as String?) ?? '').join('\n');
      expect(allSql.contains('NUMERIC(12,2)'), isTrue, reason: 'NUMERIC(12,2) missing');
      expect(allSql.contains('NUMERIC(12,4)'), isTrue, reason: 'NUMERIC(12,4) missing for vk_netto');

      final artikelRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='artikel'",
        const [],
      );
      expect(artikelRows.first['sql']?.toString() ?? '', contains('vk_netto NUMERIC(12,4)'));

      final rechnungRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='rechnungen'",
        const [],
      );
      expect(rechnungRows.first['sql']?.toString() ?? '', contains('NUMERIC(12,2)'));

      final journalRows = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='journal'",
        const [],
      );
      expect(journalRows.first['sql']?.toString() ?? '', contains('NUMERIC(12,2)'));
    });

    test('FKs correct — rechnungspositionen, journal, bank_transaktionen', () async {
      Future<List<Map<String, Object?>>> fk(String table) async {
        return db.executor.runSelect('PRAGMA foreign_key_list($table)', const []);
      }

      final rpFk = await fk('rechnungspositionen');
      expect(rpFk.any((r) => r['table'] == 'rechnungen'), isTrue);
      expect(rpFk.any((r) => r['table'] == 'artikel'), isTrue);

      final journalFk = await fk('journal');
      expect(journalFk.any((r) => r['table'] == 'kategorien'), isTrue);
      expect(journalFk.any((r) => r['table'] == 'konten'), isTrue);

      final btFk = await fk('bank_transaktionen');
      expect(btFk.any((r) => r['table'] == 'konten'), isTrue);
      expect(btFk.any((r) => r['table'] == 'bank_imports'), isTrue);
    });

    test('WAL mode and FK enforcement active', () async {
      final jm = await db.executor.runSelect('PRAGMA journal_mode', const []);
      final String journalMode = jm.first.values.first.toString().toLowerCase();
      expect(journalMode, anyOf(['wal', 'memory']), reason: 'Journal mode should be wal or memory');
      final fk = await db.executor.runSelect('PRAGMA foreign_keys', const []);
      final val = fk.first.values.first;
      expect(val == 1 || val == true || val == '1', isTrue);
    });

    test('partial unique indexes exist', () async {
      final rows = await db.executor.runSelect(
        "SELECT name, sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL",
        const [],
      );
      final sqls = rows.map((r) => r['sql']?.toString() ?? '').join('\n');
      expect(sqls, contains('idx_kunden_kundennummer_unique'));
      expect(sqls, contains('idx_lieferanten_lieferantennummer_unique'));
      expect(sqls, contains('idx_bank_transaktionen_dedupe'));
      expect(sqls, contains('WHERE kundennummer IS NOT NULL'));
      expect(sqls, contains('WHERE dedupe_hash IS NOT NULL'));
    });

    test('FK enforcement rejects invalid reference', () async {
      await db.executor.runCustom("INSERT INTO konten (id, name) VALUES (1, 'Testkonto')");
      await db.executor.runCustom("INSERT INTO bank_imports (id, konto_id, dateiname) VALUES (1, 1, 'test.csv')");
      bool failed = false;
      try {
        await db.executor.runCustom(
          "INSERT INTO bank_transaktionen (konto_id, import_id, datum, betrag) VALUES (9999, 1, '2026-01-01', 100)",
        );
      } catch (_) {
        failed = true;
      }
      expect(failed, isTrue, reason: 'FK should reject invalid konto_id');
    });

    test('money precision — 123456789.12 stored exactly', () async {
      await db.executor.runCustom("INSERT INTO konten (id, name, saldo) VALUES (2, 'MoneyTest', 123456789.12)");
      final rows = await db.executor.runSelect('SELECT saldo FROM konten WHERE id=2', const []);
      final v = rows.first['saldo'];
      expect((num.tryParse(v?.toString() ?? '') ?? 0).toStringAsFixed(2), '123456789.12');
    });

    test('vk_netto precision 2.9412 *100 =294.12', () async {
      await db.executor.runCustom("INSERT INTO artikel (id, bezeichnung, vk_netto) VALUES (1, 'Test', 2.9412)");
      final rows = await db.executor.runSelect('SELECT vk_netto FROM artikel WHERE id=1', const []);
      final double v = (num.tryParse(rows.first['vk_netto']?.toString() ?? '') ?? 0).toDouble();
      expect((v * 100).toStringAsFixed(2), '294.12');
      await db.executor.runCustom("INSERT INTO artikel (id, bezeichnung, vk_netto) VALUES (2, 'Zero', 0.0000)");
      final rows2 = await db.executor.runSelect('SELECT vk_netto FROM artikel WHERE id=2', const []);
      expect((num.tryParse(rows2.first['vk_netto']?.toString() ?? '') ?? 0).toDouble(), 0.0);
    });
  });
}
