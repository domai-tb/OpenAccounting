import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';

/// Customer/supplier archive-state migration (db delta, group 1).
void main() {
  group('Contact archive migration', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_archive_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    test('test_fresh_profile_includes_contact_archive_columns', () async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);

      for (final String table in <String>['kunden', 'lieferanten']) {
        final List<Map<String, Object?>> columns = await db.executor.runSelect(
          'PRAGMA table_info($table)',
          const <Object?>[],
        );
        final List<Map<String, Object?>> archived = columns
            .where((Map<String, Object?> column) => column['name'] == 'archived_at')
            .toList(growable: false);
        expect(archived, hasLength(1), reason: '$table misses archived_at');
        expect(archived.single['type'], 'TEXT');
        expect(archived.single['notnull'], 0, reason: '$table.archived_at must be nullable');
      }

      final KundenRepository kunden = KundenRepository(db.executor);
      final LieferantenRepository lieferanten = LieferantenRepository(db.executor);
      final Kunde customer = await kunden.create(
        name: 'Neu GmbH',
        strasse: 'Hauptstrasse 1',
        plz: '10115',
        ort: 'Berlin',
      );
      final Lieferant supplier = await lieferanten.create(
        name: 'Neu AG',
        strasse: 'Hafenstrasse 2',
        plz: '20354',
        ort: 'Hamburg',
      );
      expect(customer.archivedAt, isNull);
      expect(supplier.archivedAt, isNull);

      final List<Map<String, Object?>> customerRows = await db.executor.runSelect(
        'SELECT archived_at FROM kunden WHERE id = ?',
        <Object?>[customer.id],
      );
      final List<Map<String, Object?>> supplierRows = await db.executor.runSelect(
        'SELECT archived_at FROM lieferanten WHERE id = ?',
        <Object?>[supplier.id],
      );
      expect(customerRows.single['archived_at'], isNull);
      expect(supplierRows.single['archived_at'], isNull);
    });

    test('test_existing_profile_migrates_without_changing_records', () async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);

      final KundenRepository kunden = KundenRepository(db.executor);
      final LieferantenRepository lieferanten = LieferantenRepository(db.executor);
      final Kunde customer = await kunden.create(
        name: 'Müller GmbH',
        strasse: 'Alte Strasse 4',
        plz: '80331',
        ort: 'München',
      );
      final Lieferant supplier = await lieferanten.create(
        name: 'Bürobedarf AG',
        strasse: 'Lagerweg 7',
        plz: '50667',
        ort: 'Köln',
      );
      final List<Map<String, Object?>> customersBefore = await db.executor.runSelect(
        'SELECT * FROM kunden ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> suppliersBefore = await db.executor.runSelect(
        'SELECT * FROM lieferanten ORDER BY id',
        const <Object?>[],
      );

      // Simulate a legacy profile without archive columns.
      await db.executor.runCustom('ALTER TABLE kunden DROP COLUMN archived_at');
      await db.executor.runCustom('ALTER TABLE lieferanten DROP COLUMN archived_at');
      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: profileDirectory.path);
      await runner.setUserVersion(MigrationRunner.currentVersion - 1);

      await runner.run(createSchema: () async {});

      expect(await runner.getUserVersion(), MigrationRunner.currentVersion);
      final List<Map<String, Object?>> customerColumns = await db.executor.runSelect(
        'PRAGMA table_info(kunden)',
        const <Object?>[],
      );
      final List<Map<String, Object?>> supplierColumns = await db.executor.runSelect(
        'PRAGMA table_info(lieferanten)',
        const <Object?>[],
      );
      expect(customerColumns.any((Map<String, Object?> column) => column['name'] == 'archived_at'), isTrue);
      expect(supplierColumns.any((Map<String, Object?> column) => column['name'] == 'archived_at'), isTrue);

      final List<Map<String, Object?>> customersAfter = await db.executor.runSelect(
        'SELECT * FROM kunden ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> suppliersAfter = await db.executor.runSelect(
        'SELECT * FROM lieferanten ORDER BY id',
        const <Object?>[],
      );
      expect(customersAfter.length, customersBefore.length);
      expect(suppliersAfter.length, suppliersBefore.length);
      for (final Map<String, Object?> row in customersAfter) {
        expect(row['archived_at'], isNull);
      }
      for (final Map<String, Object?> row in suppliersAfter) {
        expect(row['archived_at'], isNull);
      }
      for (final String key in customersBefore.single.keys) {
        expect(customersAfter.single[key], customersBefore.single[key], reason: 'kunden.$key changed');
      }
      for (final String key in suppliersBefore.single.keys) {
        expect(suppliersAfter.single[key], suppliersBefore.single[key], reason: 'lieferanten.$key changed');
      }
      expect(customersAfter.single['id'], customer.id);
      expect(suppliersAfter.single['id'], supplier.id);
    });

    test('test_archive_and_restore_preserve_customer_identity', () async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);

      final KundenRepository kunden = KundenRepository(db.executor);
      final Kunde customer = await kunden.create(
        name: 'Müller GmbH',
        strasse: 'Alte Strasse 4',
        plz: '80331',
        ort: 'München',
      );
      await db.executor.runInsert(
        'INSERT INTO rechnungen (typ, status, ist_entwurf, eingabemodus, kunde_id, datum) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['rechnung', 'final', 0, 'netto', customer.id, '2026-03-01'],
      );

      final Kunde archived = await kunden.archive(customer.id);
      expect(archived.id, customer.id);
      expect(archived.archivedAt, isNotNull);
      expect(DateTime.tryParse(archived.archivedAt!), isNotNull);

      final Kunde? resolved = await kunden.findById(customer.id);
      expect(resolved, isNotNull);
      expect(resolved!.id, customer.id);
      expect(resolved.debitorNr, customer.debitorNr);
      final List<Map<String, Object?>> invoices = await db.executor.runSelect(
        'SELECT kunde_id FROM rechnungen WHERE kunde_id = ?',
        <Object?>[customer.id],
      );
      expect(invoices, hasLength(1));

      final Kunde restored = await kunden.restore(customer.id);
      expect(restored.id, customer.id);
      expect(restored.archivedAt, isNull);
      final Kunde? reread = await kunden.findById(customer.id);
      expect(reread, isNotNull);
      expect(reread!.id, customer.id);
      expect(reread.debitorNr, customer.debitorNr);
    });
  });
}
