import 'dart:io';

import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';
import 'package:openaccounting/pages/stammdaten/customer_data_disclosure_export.dart';

const Set<String> _freshSchemaManagedTables = <String>{
  'forderung_zahlungen',
  'category_mapping_history',
  'feature_table_state',
  'mileage_trips',
  'mileage_trip_corrections',
  'mileage_posting_account_mapping',
  'mileage_posting_period_closures',
  'master_data_import_templates',
  'anlage_afa_jahreswerte',
  'account_opening_balance_sources',
};
const Set<String> _inventoryOnlyTables = <String>{
  'buchungsvorlagen_occurrences',
  'rechnungsvorlagen_occurrences',
  'dokument_email_templates',
  'dokument_email_versuche',
};

Future<Directory> _tempDir(String prefix) async {
  final Directory dir = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });
  return dir;
}

Future<AppDatabase> _seedFresh({String? profileDir}) async {
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir);
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Future<int> _userVersion(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect('PRAGMA user_version', const <Object?>[]);
  final Object? value = rows.single.values.single;
  return value is int ? value : (value! as num).toInt();
}

Future<Set<String>> _tableNames(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    const <Object?>[],
  );
  return <String>{for (final Map<String, Object?> row in rows) row['name'].toString()};
}

Future<List<String>> _columnNames(AppDatabase db, String table) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
  return <String>[for (final Map<String, Object?> row in rows) row['name'].toString()];
}

Future<List<String>> _indexNames(AppDatabase db, String table) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect('PRAGMA index_list($table)', const <Object?>[]);
  return <String>[for (final Map<String, Object?> row in rows) row['name'].toString()];
}

Future<void> _createDocumentEmailTables(AppDatabase db) async {
  await db.executor.runCustom('''
CREATE TABLE dokument_email_templates (
  typ TEXT PRIMARY KEY,
  betreff TEXT NOT NULL,
  text TEXT NOT NULL,
  aktualisiert_am TEXT NOT NULL
)''');
  await db.executor.runCustom('''
CREATE TABLE dokument_email_versuche (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dokument_id INTEGER NOT NULL,
  dokument_typ TEXT NOT NULL,
  empfaenger TEXT NOT NULL,
  ergebnis TEXT NOT NULL DEFAULT 'submitting',
  mahnung_id INTEGER,
  idempotenz_schluessel TEXT NOT NULL UNIQUE,
  artefakt_ids TEXT NOT NULL DEFAULT '[]',
  erstellt_am TEXT NOT NULL,
  abgeschlossen_am TEXT,
  fehler_kategorie TEXT
)''');
}

void main() {
  group('Customer disclosure schema inventory', () {
    test('test_customer_data_disclosure_export_017_new_relationship_is_not_in_the_reviewed_inventor', () async {
      final Directory profileDir = await _tempDir('disclosure_017_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      final int customerId = await db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Kunde AG', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      final Set<String> before = await _tableNames(db);
      // A migrated profile gains a customer-linked column outside the
      // reviewed inventory; a populated value cannot prove its scope.
      await db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN kunde_spitzname TEXT');
      final int invoice = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, kunde_id, datum) VALUES (?, ?, ?, ?)',
        <Object?>['RE-1', 'rechnung', customerId, '2026-01-05'],
      );
      await db.executor.runUpdate('UPDATE rechnungen SET kunde_spitzname = ? WHERE id = ?', <Object?>['Agi', invoice]);

      final CustomerDataDisclosureExportService service = CustomerDataDisclosureExportService(
        executor: db.executor,
        profileDir: profileDir.path,
      );
      final Directory outDir = await _tempDir('disclosure_017_out_');
      final String destination = '${outDir.path}/kunde.zip';
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(manifest['complete'], isFalse);
      final List<Object?> omitted = List<Object?>.from(manifest['omitted_fields']! as List);
      expect(
        omitted.where(
          (Object? e) => (e! as Map)['field'] == 'kunde_spitzname' && (e as Map)['reason'] == 'unclassified_field',
        ),
        hasLength(1),
      );
      expect(await _tableNames(db), before);
    });

    test('test_customer_data_disclosure_export_018_snapshot_cannot_be_acquired_consistently', () async {
      final Directory profileDir = await _tempDir('disclosure_018_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      final int customerId = await db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Kunde AG', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      await db.close();

      final CustomerDataDisclosureExportService service = CustomerDataDisclosureExportService(
        executor: db.executor,
        profileDir: profileDir.path,
      );
      final Directory outDir = await _tempDir('disclosure_018_out_');
      final String destination = '${outDir.path}/kunde.zip';
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.failed);
      expect(result.archivePath, isNull);
      expect(File(destination).existsSync(), isFalse);
    });

    test(
      'test_customer_data_disclosure_export_019_unlisted_customer_linked_table_prevents_a_complete_export',
      () async {
        final Directory profileDir = await _tempDir('disclosure_019_');
        final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
        final int customerId = await db.executor.runInsert(
          "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Kunde AG', 'S', '1', 'B', 'DE')",
          const <Object?>[],
        );
        final Set<String> before = await _tableNames(db);
        await db.executor.runCustom(
          'CREATE TABLE kunden_notizen (id INTEGER PRIMARY KEY, kunde_id INTEGER, notiz TEXT)',
        );
        await db.executor.runInsert('INSERT INTO kunden_notizen (kunde_id, notiz) VALUES (?, ?)', <Object?>[
          customerId,
          'Anruf',
        ]);

        final CustomerDataDisclosureExportService service = CustomerDataDisclosureExportService(
          executor: db.executor,
          profileDir: profileDir.path,
        );
        final Directory outDir = await _tempDir('disclosure_019_out_');
        final String destination = '${outDir.path}/kunde.zip';
        final CustomerDisclosureResult result = await service.exportCustomer(
          customerId: customerId,
          destinationPath: destination,
        );

        // Safely projected records may publish, but never as complete.
        expect(result.status, CustomerDisclosureExportStatus.incomplete);
        expect(File(destination).existsSync(), isTrue);
        final Map<String, Object?> manifest = await service.readManifest(destination);
        final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
        expect(
          exclusions.where(
            (Object? e) => (e! as Map)['record_type'] == 'kunden_notizen' && (e as Map)['reason'] == 'unknown_table',
          ),
          hasLength(1),
        );
        final Map<String, Object?> counts = Map<String, Object?>.from(manifest['record_counts']! as Map);
        expect((counts['kunden']! as num).toInt(), 1);
        final Set<String> expected = <String>{...before, 'kunden_notizen'};
        expect(await _tableNames(db), expected);
      },
    );

    test('test_customer_data_disclosure_export_020_required_or_unknown_customer_table_is_missing_or', () async {
      final Directory profileDir = await _tempDir('disclosure_020_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      final int customerId = await db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Kunde AG', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      await db.executor.runCustom('DROP TABLE kunden_lieferadressen');

      final CustomerDataDisclosureExportService service = CustomerDataDisclosureExportService(
        executor: db.executor,
        profileDir: profileDir.path,
      );
      final Directory outDir = await _tempDir('disclosure_020_out_');
      final String destination = '${outDir.path}/kunde.zip';
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['kunden_lieferadressen'], 'missing');
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? e) =>
              (e! as Map)['record_type'] == 'kunden_lieferadressen' && (e as Map)['reason'] == 'missing_table',
        ),
        hasLength(1),
      );
      expect(await _tableNames(db), isNot(contains('kunden_lieferadressen')));
    });

    test('test_customer_data_disclosure_export_021_all_tables_created_on_fresh_install', () async {
      final Directory profileDir = await _tempDir('disclosure_021_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);

      final Set<String> actual = await _tableNames(db);
      expect(actual, containsAll(AppDatabase.allTableNames));
      expect(actual, contains('feature_table_state'));
      expect(
        actual,
        containsAll(<String>[
          'forderung_zahlungen',
          'mileage_trips',
          'mileage_trip_corrections',
          'category_mapping_history',
        ]),
      );
      expect(actual, isNot(contains('buchungsvorlagen_occurrences')));
      expect(actual, isNot(contains('rechnungsvorlagen_occurrences')));
      expect(actual, <String>{...AppDatabase.allTableNames, ..._freshSchemaManagedTables});
      expect(actual.contains('settlement_groups'), MigrationRunner.currentVersion >= 19);
      expect(await _userVersion(db), MigrationRunner.currentVersion);

      final List<Map<String, Object?>> markers = await db.executor.runSelect(
        'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
        const <Object?>[],
      );
      expect(markers.map((Map<String, Object?> row) => (row['table_name'], row['state'])), <(Object?, Object?)>[
        ('buchungsvorlagen_occurrences', 'never_initialized'),
        ('rechnungsvorlagen_occurrences', 'never_initialized'),
      ]);
      expect(await _userVersion(db), MigrationRunner.currentVersion);

      // The inventory includes the physical schema plus two absent lazy and two optional tables.
      expect(CustomerDisclosureInventory.knownTableNames, <String>{...actual, ..._inventoryOnlyTables});
      expect(
        CustomerDisclosureInventory.knownTableNames,
        containsAll(<String>['dokument_email_templates', 'dokument_email_versuche']),
      );
      expect(actual, isNot(contains('dokument_email_templates')));
      expect(actual, isNot(contains('dokument_email_versuche')));
    });

    test('test_customer_data_disclosure_export_022_pre_v9_profile_is_valid_before_later_feature_mig', () async {
      final Directory profileDir = await _tempDir('disclosure_022_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      await db.executor.runCustom('DROP TABLE feature_table_state');
      await db.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await db.executor.runCustom('DROP TABLE mileage_trips');
      await db.executor.runCustom('DROP TABLE category_mapping_history');
      await db.executor.runCustom('PRAGMA user_version = 8');

      final SchemaHealthReport health = await MigrationRunner(
        executor: db.executor,
        profileDir: profileDir.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();

      expect(health.isHealthy, isTrue);
      expect(health.isCompleteForVersion13Export, isFalse);
      expect(await _userVersion(db), 8);
    });

    test('test_customer_data_disclosure_export_023_missing_v7_payment_table_is_created_by_the_v7_to', () async {
      final Directory profileDir = await _tempDir('disclosure_023_');
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = AppDatabase.forTesting(native, profileDir: profileDir.path);
      await seed.ensureOpen();
      await seed.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Bestand', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await seed.executor.runCustom('PRAGMA user_version = 7');

      final AppDatabase db = AppDatabase.forTesting(native, profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _userVersion(db), MigrationRunner.currentVersion);
      expect(
        await _columnNames(db, 'forderung_zahlungen'),
        containsAll(<String>[
          'id',
          'forderung_id',
          'journal_id',
          'betrag',
          'typ',
          'datum',
          'idempotency_key',
          'requested_betrag_cents',
          'fingerprint_direction',
          'fingerprint_date_policy',
        ]),
      );
      final List<Map<String, Object?>> payments = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM forderung_zahlungen',
        const <Object?>[],
      );
      expect((payments.single['c']! as num).toInt(), 0);
      final List<Map<String, Object?>> keeper = await db.executor.runSelect(
        'SELECT name FROM kunden',
        const <Object?>[],
      );
      expect(keeper.single['name'], 'Bestand');
    });

    test('test_customer_data_disclosure_export_024_missing_payment_table_at_v8_or_later_preserves_t', () async {
      final Directory profileDir = await _tempDir('disclosure_024_');
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = AppDatabase.forTesting(native, profileDir: profileDir.path);
      await seed.ensureOpen();
      await seed.executor.runCustom('DROP TABLE forderung_zahlungen');
      await seed.executor.runCustom('PRAGMA user_version = 8');

      final AppDatabase db = AppDatabase.forTesting(native, profileDir: profileDir.path);
      addTearDown(db.close);
      try {
        await db.ensureOpen();
        fail('expected schemaMigrationFailed');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.schemaMigrationFailed);
      }

      expect(await _userVersion(db), 8);
      expect(await _tableNames(db), isNot(contains('forderung_zahlungen')));
      expect(db.isOpen, isFalse);
      expect(() => db.kundenRepository, throwsA(isA<StateError>()));
    });

    test('test_customer_data_disclosure_export_025_current_payment_table_repair_preserves_existing', () async {
      final Directory profileDir = await _tempDir('disclosure_025_');
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = AppDatabase.forTesting(native, profileDir: profileDir.path);
      await seed.ensureOpen();
      final int customerId = await seed.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Kunde', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      final int forderungId = await seed.executor.runInsert(
        'INSERT INTO forderungen (betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?)',
        <Object?>['10.00', 'rechnung', 'kunde', customerId],
      );
      final int journalId = await seed.executor.runInsert(
        "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-01-05', '10.00', 'Zahlung')",
        const <Object?>[],
      );
      await seed.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum, idempotency_key) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[forderungId, journalId, '10.00', 'zahlung', '2026-01-05', 'repair-1'],
      );
      await seed.executor.runCustom('DROP INDEX forderung_zahlungen_key_unique');

      final AppDatabase db = AppDatabase.forTesting(native, profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _indexNames(db, 'forderung_zahlungen'), contains('forderung_zahlungen_key_unique'));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT forderung_id, journal_id, betrag, typ, datum, idempotency_key FROM forderung_zahlungen',
        const <Object?>[],
      );
      expect(rows, hasLength(1));
      expect(rows.single['forderung_id'], forderungId);
      expect(rows.single['journal_id'], journalId);
      expect(rows.single['idempotency_key'], 'repair-1');
      final SchemaHealthReport health = await MigrationRunner(
        executor: db.executor,
        profileDir: profileDir.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();
      expect(health.malformedTables, isNot(contains('forderung_zahlungen')));
    });

    test(
      'test_customer_data_disclosure_export_026_v12_to_v13_migration_adds_shared_markers_and_mileage_tables',
      () async {
        // The shared markers and mileage tables are introduced by v13.
        final Directory profileDir = await _tempDir('disclosure_026_');
        final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
        addTearDown(native.close);
        final AppDatabase seed = AppDatabase.forTesting(native, profileDir: profileDir.path);
        await seed.ensureOpen();
        await seed.executor.runCustom('DROP TABLE feature_table_state');
        await seed.executor.runCustom('DROP TABLE mileage_trip_corrections');
        await seed.executor.runCustom('DROP TABLE mileage_trips');
        await seed.executor.runCustom('PRAGMA user_version = 12');

        final AppDatabase db = AppDatabase.forTesting(native, profileDir: profileDir.path);
        addTearDown(db.close);
        await db.ensureOpen();

        expect(await _userVersion(db), MigrationRunner.currentVersion);
        final Set<String> actual = await _tableNames(db);
        expect(actual, containsAll(<String>['feature_table_state', 'mileage_trips', 'mileage_trip_corrections']));
        final List<Map<String, Object?>> markers = await db.executor.runSelect(
          'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
          const <Object?>[],
        );
        // Absent lazy tables are classified unknown, never never_initialized.
        expect(markers.map((Map<String, Object?> row) => (row['table_name'], row['state'])), <(Object?, Object?)>[
          ('buchungsvorlagen_occurrences', 'unknown'),
          ('rechnungsvorlagen_occurrences', 'unknown'),
        ]);
      },
    );

    test('test_customer_data_disclosure_export_027_v9_migration_adds_category_history', () async {
      // Category history is introduced by the v9 migration, so begin at v8.
      final Directory profileDir = await _tempDir('disclosure_027_');
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      addTearDown(native.close);
      final AppDatabase seed = AppDatabase.forTesting(native, profileDir: profileDir.path);
      await seed.ensureOpen();
      await seed.executor.runCustom('DROP TABLE category_mapping_history');
      await seed.executor.runCustom('PRAGMA user_version = 8');

      final AppDatabase db = AppDatabase.forTesting(native, profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      expect(await _userVersion(db), MigrationRunner.currentVersion);
      expect(await _tableNames(db), contains('category_mapping_history'));
      expect(
        await _columnNames(db, 'category_mapping_history'),
        containsAll(<String>['id', 'kategorie_id', 'geaendert_am', 'aktion', 'nachher_mapping_json']),
      );
    });

    test('test_customer_data_disclosure_export_028_unknown_lazy_table_state_is_not_repaired_by_init', () async {
      final Directory profileDir = await _tempDir('disclosure_028_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      await db.executor.runUpdate(
        "UPDATE feature_table_state SET state = 'unknown' WHERE table_name = 'rechnungsvorlagen_occurrences'",
        const <Object?>[],
      );

      await expectLater(RechnungsVorlagenRepository(db.executor).ensureSchema(), throwsA(isA<StateError>()));
      expect(await _tableNames(db), isNot(contains('rechnungsvorlagen_occurrences')));
    });

    test('test_customer_data_disclosure_export_029_table_count_verification', () async {
      final Directory profileDir = await _tempDir('disclosure_029_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      final Set<String> before = await _tableNames(db);

      final bool migrated = await MigrationRunner(
        executor: db.executor,
        profileDir: profileDir.path,
        requiredTables: AppDatabase.allTableNames,
      ).run(createSchema: () async {});

      expect(migrated, isFalse);
      expect(await _userVersion(db), MigrationRunner.currentVersion);
      final Set<String> after = await _tableNames(db);
      expect(after, before);
      // Fresh schema leaves both occurrence tables absent.
      expect(after, <String>{...AppDatabase.allTableNames, ..._freshSchemaManagedTables});
      for (final String lazy in <String>['buchungsvorlagen_occurrences', 'rechnungsvorlagen_occurrences']) {
        expect(after, isNot(contains(lazy)));
      }
    });

    test('test_customer_data_disclosure_export_030_unknown_or_malformed_application_tables_fail_sch', () async {
      final Directory unknownProfile = await _tempDir('disclosure_030a_');
      final AppDatabase unknownDb = await _seedFresh(profileDir: unknownProfile.path);
      await unknownDb.executor.runCustom('CREATE TABLE sneaky_tabelle (id INTEGER PRIMARY KEY)');
      final SchemaHealthReport unknownHealth = await MigrationRunner(
        executor: unknownDb.executor,
        profileDir: unknownProfile.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();
      expect(unknownHealth.isHealthy, isFalse);
      expect(unknownHealth.unknownTables, contains('sneaky_tabelle'));

      final Directory malformedProfile = await _tempDir('disclosure_030b_');
      final AppDatabase malformedDb = await _seedFresh(profileDir: malformedProfile.path);
      await malformedDb.executor.runCustom('DROP INDEX forderung_zahlungen_journal_unique');
      final SchemaHealthReport malformedHealth = await MigrationRunner(
        executor: malformedDb.executor,
        profileDir: malformedProfile.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();
      expect(malformedHealth.isHealthy, isFalse);
      expect(malformedHealth.malformedTables, contains('forderung_zahlungen'));
    });

    test('test_customer_data_disclosure_export_031_missing_table_detection', () async {
      final Directory profileDir = await _tempDir('disclosure_031_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      await db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Bestand', 'S', '1', 'B', 'DE')",
        const <Object?>[],
      );
      await db.executor.runCustom('DROP TABLE kunden_lieferadressen');
      final int versionBefore = await _userVersion(db);

      await expectLater(
        MigrationRunner(
          executor: db.executor,
          profileDir: profileDir.path,
          requiredTables: AppDatabase.allTableNames,
        ).run(createSchema: () async {}),
        throwsA(isA<StateError>()),
      );

      expect(await _userVersion(db), versionBefore);
      expect(await _tableNames(db), isNot(contains('kunden_lieferadressen')));
      final List<Map<String, Object?>> keeper = await db.executor.runSelect(
        'SELECT name FROM kunden',
        const <Object?>[],
      );
      expect(keeper.single['name'], 'Bestand');
    });

    test(
      'test_customer_data_disclosure_export_046_present_document_email_tables_match_their_declared_schema',
      () async {
        final Directory validProfile = await _tempDir('disclosure_046a_');
        final AppDatabase validDb = await _seedFresh(profileDir: validProfile.path);
        final Set<String> before = await _tableNames(validDb);
        expect(before, isNot(contains('dokument_email_templates')));
        expect(before, isNot(contains('dokument_email_versuche')));

        await _createDocumentEmailTables(validDb);
        final Map<String, Set<String>> expectedColumns = <String, Set<String>>{
          'dokument_email_templates': <String>{'typ', 'betreff', 'text', 'aktualisiert_am'},
          'dokument_email_versuche': <String>{
            'id',
            'dokument_id',
            'dokument_typ',
            'empfaenger',
            'ergebnis',
            'mahnung_id',
            'idempotenz_schluessel',
            'artefakt_ids',
            'erstellt_am',
            'abgeschlossen_am',
            'fehler_kategorie',
          },
        };
        for (final MapEntry<String, Set<String>> entry in expectedColumns.entries) {
          expect(await _columnNames(validDb, entry.key), unorderedEquals(entry.value));
        }

        final SchemaHealthReport validHealth = await MigrationRunner(
          executor: validDb.executor,
          profileDir: validProfile.path,
          requiredTables: AppDatabase.allTableNames,
        ).inspectSchemaHealth();
        expect(validHealth.isHealthy, isTrue);
        expect(validHealth.unknownTables, isEmpty);
        expect(validHealth.malformedTables, isEmpty);

        final Directory malformedProfile = await _tempDir('disclosure_046b_');
        final AppDatabase malformedDb = await _seedFresh(profileDir: malformedProfile.path);
        final Set<String> malformedBefore = await _tableNames(malformedDb);
        await malformedDb.executor.runCustom('CREATE TABLE dokument_email_versuche (id INTEGER PRIMARY KEY)');
        final Set<String> malformedAfter = <String>{...malformedBefore, 'dokument_email_versuche'};

        final SchemaHealthReport malformedHealth = await MigrationRunner(
          executor: malformedDb.executor,
          profileDir: malformedProfile.path,
          requiredTables: AppDatabase.allTableNames,
        ).inspectSchemaHealth();
        expect(malformedHealth.isHealthy, isFalse);
        expect(malformedHealth.unknownTables, isNot(contains('dokument_email_versuche')));
        expect(malformedHealth.malformedTables, contains('dokument_email_versuche'));
        expect(await _tableNames(malformedDb), malformedAfter);
        expect(malformedAfter, isNot(contains('dokument_email_templates')));
      },
    );

    test('test_customer_data_disclosure_export_047_extra_optional_email_column_fails_schema_health', () async {
      final Directory profileDir = await _tempDir('disclosure_047_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      final Set<String> before = await _tableNames(db);
      await db.executor.runCustom(
        'CREATE TABLE dokument_email_templates (typ TEXT, betreff TEXT, text TEXT, aktualisiert_am TEXT, extra TEXT)',
      );
      final Set<String> after = <String>{...before, 'dokument_email_templates'};

      final SchemaHealthReport health = await MigrationRunner(
        executor: db.executor,
        profileDir: profileDir.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();

      expect(health.isHealthy, isFalse);
      expect(health.malformedTables, contains('dokument_email_templates'));
      expect(await _tableNames(db), after);
    });

    test(
      'test_customer_data_disclosure_export_048_optional_email_declared_type_mismatch_fails_schema_health',
      () async {
        final Directory profileDir = await _tempDir('disclosure_048_');
        final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
        final Set<String> before = await _tableNames(db);
        await db.executor.runCustom(
          'CREATE TABLE dokument_email_templates (typ TEXT, betreff INTEGER, text TEXT, aktualisiert_am TEXT)',
        );
        final Set<String> after = <String>{...before, 'dokument_email_templates'};

        final SchemaHealthReport health = await MigrationRunner(
          executor: db.executor,
          profileDir: profileDir.path,
          requiredTables: AppDatabase.allTableNames,
        ).inspectSchemaHealth();

        expect(health.isHealthy, isFalse);
        expect(health.malformedTables, contains('dokument_email_templates'));
        expect(await _tableNames(db), after);
      },
    );

    test('test_customer_data_disclosure_export_049_malformed_base_rechnungen_fails_schema_health', () async {
      final Directory profileDir = await _tempDir('disclosure_049_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      await db.executor.runCustom('DROP TABLE rechnungen');
      await db.executor.runCustom('CREATE TABLE rechnungen (id INTEGER PRIMARY KEY, rechnungsnummer TEXT)');
      final Set<String> after = await _tableNames(db);

      final SchemaHealthReport health = await MigrationRunner(
        executor: db.executor,
        profileDir: profileDir.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();

      expect(health.isHealthy, isFalse);
      expect(health.malformedTables, contains('rechnungen'));
      expect(await _tableNames(db), after);
      expect(after, contains('rechnungen'));
    });

    test('v29 disclosure inventory requires persisted e-invoice tax evidence', () {
      final Set<String> evidence = <String>{
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
      };
      final Set<String> allowlist = CustomerDisclosureInventory.fieldAllowlists['rechnungspositionen']!;
      expect(allowlist, containsAll(evidence));
      expect(
        CustomerDisclosureInventory.requiredPayloadColumns('rechnungspositionen', schemaVersion: 28),
        isNot(contains('tax_treatment')),
      );
      expect(CustomerDisclosureInventory.requiredPayloadColumns('rechnungspositionen'), containsAll(evidence));
    });

    test('test_customer_data_disclosure_export_050_relationship_key_declared_as_text_fails_schema_health', () async {
      final Directory profileDir = await _tempDir('disclosure_050_');
      final AppDatabase db = await _seedFresh(profileDir: profileDir.path);
      final List<Map<String, Object?>> definitions = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        const <Object?>['kunden_lieferadressen'],
      );
      final String originalSql = definitions.single['sql']! as String;
      final String malformedSql = originalSql.replaceFirst(RegExp(r'\bkunde_id\s+INTEGER\b'), 'kunde_id TEXT');
      expect(malformedSql, isNot(originalSql));
      await db.executor.runCustom('DROP TABLE kunden_lieferadressen');
      await db.executor.runCustom(malformedSql);

      final SchemaHealthReport health = await MigrationRunner(
        executor: db.executor,
        profileDir: profileDir.path,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();

      expect(health.isHealthy, isFalse);
      expect(health.malformedTables, contains('kunden_lieferadressen'));
      expect(await _columnNames(db, 'kunden_lieferadressen'), containsAll(<String>['id', 'kunde_id']));
    });
  });
}
