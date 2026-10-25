import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';

const List<String> _eInvoiceTaxEvidenceColumns = <String>[
  'tax_treatment',
  'tax_legal_basis',
  'e_invoice_tax_category_code',
  'e_invoice_exemption_reason_code',
  'e_invoice_exemption_reason_text',
  'e_invoice_intra_community_destination_country_iso',
  'e_invoice_intra_community_acquisition_tax_treatment',
  'e_invoice_intra_community_supply_evidence_source_ref',
  'e_invoice_export_destination_country_iso',
  'e_invoice_export_movement_actor',
  'e_invoice_export_evidence_source_ref',
  'e_invoice_reverse_charge_supplier_establishment_country_iso',
  'e_invoice_reverse_charge_supplier_establishment_basis',
  'e_invoice_reverse_charge_supplier_german_fixed_establishment_status',
  'e_invoice_reverse_charge_recipient_status',
  'e_invoice_reverse_charge_recipient_establishment_country_iso',
  'e_invoice_reverse_charge_service_kind',
  'e_invoice_reverse_charge_place_of_supply_basis',
  'e_invoice_reverse_charge_place_of_supply_country_iso',
  'e_invoice_reverse_charge_taxability',
  'e_invoice_reverse_charge_evidence_source_ref',
  'e_invoice_reverse_charge_recipient_13b5_basis',
  'e_invoice_reverse_charge_ust1tg_certificate_ref',
  'e_invoice_reverse_charge_ust1tg_scope',
  'e_invoice_reverse_charge_ust1tg_recipient_vat_id',
  'e_invoice_reverse_charge_ust1tg_issued_on',
  'e_invoice_reverse_charge_ust1tg_valid_through',
];

Future<void> _removeV29TaxEvidenceColumns(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'PRAGMA table_info(rechnungspositionen)',
    const <Object?>[],
  );
  final Set<String> existing = <String>{for (final row in rows) row['name'].toString()};
  for (final String column in _eInvoiceTaxEvidenceColumns.reversed) {
    if (existing.contains(column)) {
      await db.executor.runCustom('ALTER TABLE rechnungspositionen DROP COLUMN $column');
    }
  }
}

void main() {
  group('MigrationRunner', () {
    late AppDatabase db;
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_migration_test_');
      db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
      await profileDirectory.delete(recursive: true);
    });

    test('fresh schema installs nullable v29 e-invoice tax evidence', () async {
      final MigrationRunner runner = MigrationRunner(
        executor: db.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );
      expect(await runner.getUserVersion(), 29);

      final List<Map<String, Object?>> columns = await db.executor.runSelect(
        'PRAGMA table_info(rechnungspositionen)',
        const <Object?>[],
      );
      for (final String name in _eInvoiceTaxEvidenceColumns) {
        final Map<String, Object?> column = columns.singleWhere((row) => row['name'] == name);
        expect(column['type'].toString().toUpperCase(), 'TEXT', reason: name);
        expect(column['notnull'], 0, reason: name);
        expect(column['dflt_value'], equals(null), reason: name);
      }
      expect((await runner.inspectSchemaHealth()).isHealthy, isTrue);
    });

    test('v28 migration adds nullable evidence without inferring legacy values', () async {
      final int invoiceId = await db.executor.runInsert(
        'INSERT INTO rechnungen (typ, datum) VALUES (?, ?)',
        const <Object?>['rechnung', '2026-10-25'],
      );
      final int positionId = await db.executor.runInsert(
        'INSERT INTO rechnungspositionen (rechnung_id, bezeichnung, einzelpreis, gesamt, ust_satz) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>[invoiceId, 'Legacy standard line', 100.0, 100.0, 19.0],
      );
      await _removeV29TaxEvidenceColumns(db);
      await db.executor.runCustom('PRAGMA user_version = 28');

      final MigrationRunner runner = MigrationRunner(
        executor: db.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );
      expect(await runner.run(createSchema: () async {}), isTrue);
      expect(await runner.getUserVersion(), 29);

      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT id, bezeichnung, ${_eInvoiceTaxEvidenceColumns.join(', ')} '
        'FROM rechnungspositionen WHERE id = ?',
        <Object?>[positionId],
      );
      expect(rows.single['bezeichnung'], 'Legacy standard line');
      for (final String column in _eInvoiceTaxEvidenceColumns) {
        expect(rows.single[column], equals(null), reason: column);
      }
      expect((await runner.inspectSchemaHealth()).isHealthy, isTrue);
    });

    test('v29 migration rolls back when an existing tax column is unverifiable', () async {
      await _removeV29TaxEvidenceColumns(db);
      await db.executor.runCustom('ALTER TABLE rechnungspositionen ADD COLUMN tax_treatment INTEGER');
      await db.executor.runCustom('PRAGMA user_version = 28');

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await expectLater(
        runner.run(createSchema: () async {}),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('tax_treatment'))),
      );

      expect(await runner.getUserVersion(), 28);
      final List<Map<String, Object?>> columns = await db.executor.runSelect(
        'PRAGMA table_info(rechnungspositionen)',
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final row in columns) row['name'].toString()};
      expect(names, contains('tax_treatment'));
      expect(names, isNot(contains('tax_legal_basis')));
    });

    test('runs the v29 migration from the previous schema version', () async {
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);

      final migrated = await runner.run(createSchema: () async {});

      expect(migrated, isTrue);
      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
    });

    test('rejects a current-version database with a missing required table', () async {
      await db.executor.runCustom('DROP TABLE inventarbewegungen');
      final runner = MigrationRunner(
        executor: db.executor,
        profileDir: profileDirectory.path,
        requiredTables: AppDatabase.allTableNames,
      );

      await expectLater(
        runner.run(createSchema: () async {}),
        throwsA(isA<StateError>().having((error) => error.message, 'message', contains('inventarbewegungen'))),
      );
    });

    test('rolls back schema changes when the post-DDL callback fails', () async {
      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);

      await expectLater(
        runner.run(
          createSchema: () async {},
          afterFeatureSchemaDdl: (QueryExecutor executor) async {
            await executor.runCustom('CREATE TABLE migration_partial (id INTEGER PRIMARY KEY)');
            throw StateError('migration failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(await runner.getUserVersion(), MigrationRunner.currentVersion - 1);
      final rows = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_partial'",
        const [],
      );
      expect(rows, isEmpty);
    });

    test('rolls back fresh schema creation when creation fails', () async {
      final executor = drift_native.NativeDatabase.memory();
      addTearDown(executor.close);
      await executor.ensureOpen(_NoopMigrationUser());
      final runner = MigrationRunner(executor: executor, profileDir: profileDirectory.path);

      await expectLater(
        runner.run(
          createSchema: () async {
            await executor.runCustom('CREATE TABLE fresh_partial (id INTEGER PRIMARY KEY)');
            throw StateError('fresh schema failed');
          },
        ),
        throwsA(isA<StateError>()),
      );

      final rows = await executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='fresh_partial'",
        const [],
      );
      expect(rows, isEmpty);
      expect(await runner.getUserVersion(), 0);
    });

    test('preserves legacy non-draft status during v2 rebuild', () async {
      await db.executor.runCustom('PRAGMA foreign_keys = OFF');
      await db.executor.runCustom('DROP TABLE rechnungen');
      await db.executor.runCustom('''
CREATE TABLE rechnungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rechnungsnummer TEXT NOT NULL,
  typ TEXT NOT NULL,
  status TEXT DEFAULT 'entwurf',
  kunde_id INTEGER,
  lieferant_id INTEGER,
  datum TEXT NOT NULL,
  faelligkeit TEXT,
  netto_betrag NUMERIC(12,2) DEFAULT 0,
  brutto_betrag NUMERIC(12,2) DEFAULT 0,
  ust_betrag NUMERIC(12,2) DEFAULT 0,
  skonto_prozent NUMERIC(12,2) DEFAULT 0,
  skonto_faelligkeit TEXT,
  notiz TEXT,
  unternehmen_id INTEGER,
  nummernkreis_id INTEGER,
  storno_von INTEGER,
  absender_snapshot TEXT,
  ausgegeben_am TEXT,
  mahnstufe_aktuell INTEGER DEFAULT 0
)''');
      await db.executor.runCustom('''
INSERT INTO rechnungen (rechnungsnummer, typ, status, datum)
VALUES ('RE-260001', 'rechnung', 'ausgestellt', '2026-08-30')''');
      await db.executor.runCustom('PRAGMA foreign_keys = ON');

      final runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(1);
      final migrated = await runner.run(createSchema: () async {});

      expect(migrated, isTrue);
      final rows = await db.executor.runSelect(
        'SELECT status, ist_entwurf FROM rechnungen WHERE rechnungsnummer = ?',
        <Object?>['RE-260001'],
      );
      expect(rows.single['status'], 'ausgestellt');
      expect(rows.single['ist_entwurf'], 0);

      final positionFks = await db.executor.runSelect('PRAGMA foreign_key_list(rechnungspositionen)', const []);
      expect(positionFks.any((row) => row['table'] == 'rechnungen'), isTrue);
      final foreignKeys = await db.executor.runSelect('PRAGMA foreign_keys', const []);
      expect(foreignKeys.single.values.first, 1);
    });
  });
}

class _NoopMigrationUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
