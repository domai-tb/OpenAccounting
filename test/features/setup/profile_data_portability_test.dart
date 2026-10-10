import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/setup/profile_data_section.dart';
import 'package:openaccounting/features/setup/profile_export_service.dart';
import 'package:path/path.dart' as p;

Future<AppDatabase> _openProfile(String prefix) async {
  final Directory dir = await Directory.systemTemp.createTemp(prefix);
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: dir.path);
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Future<Set<String>> _exportTableNames(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    const <Object?>[],
  );
  return <String>{for (final Map<String, Object?> row in rows) row['name'].toString()};
}

Future<void> _pumpSection(WidgetTester tester, ProfileDataSection section) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: section)),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 60),
  );
}

void main() {
  group('Profile data portability export', () {
    test('test_profile_data_portability_012_export_a_populated_profile', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('profile_export_012_');
      addTearDown(() async {
        if (profileDir.existsSync()) {
          await profileDir.delete(recursive: true);
        }
      });
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Muster GmbH']);
      await db.executor.runInsert(
        "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('Kunde AG', 'Str 1', '10115', 'Berlin')",
        const <Object?>[],
      );
      final File logo = File(p.join(profileDir.path, 'logo.png'));
      await logo.writeAsBytes(<int>[1, 2, 3, 4, 5], flush: true);
      await db.executor.runUpdate('UPDATE unternehmen SET logo_pfad = ? WHERE id = 1', <Object?>[logo.path]);
      final File receipt = File(p.join(profileDir.path, 'beleg.pdf'));
      await receipt.writeAsBytes(<int>[9, 8, 7, 6], flush: true);
      final int belegId = await db.executor.runInsert(
        'INSERT INTO belege (datum, betrag, dateipfad) VALUES (?, ?, ?)',
        <Object?>['2026-01-15', '12.34', receipt.path],
      );

      final List<Map<String, Object?>> beforeKunden = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM kunden',
        const <Object?>[],
      );
      final List<Map<String, Object?>> beforeBelege = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM belege',
        const <Object?>[],
      );

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_012_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final String destination = p.join(outDir.path, 'profil_export.zip');
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: profileDir.path,
        profileLabel: 'Muster GmbH',
      );
      final ProfileExportResult result = await service.exportProfile(destinationPath: destination);

      expect(result.status, ProfileExportStatus.complete);
      expect(result.archivePath, destination);
      expect(File(destination).existsSync(), isTrue);

      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(manifest['archive_version'], 1);
      expect(manifest['record_version'], 1);
      expect(manifest['schema_version'], MigrationRunner.currentVersion);
      expect(manifest['profile_label'], 'Muster GmbH');
      expect(DateTime.tryParse(manifest['created_at'].toString()), isNotNull);
      expect(manifest['complete'], isTrue);
      final Map<String, Object?> counts = Map<String, Object?>.from(manifest['record_counts']! as Map);
      expect((counts['unternehmen']! as num).toInt(), greaterThanOrEqualTo(1));
      expect((counts['kunden']! as num).toInt(), greaterThanOrEqualTo(1));
      expect((counts['belege']! as num).toInt(), greaterThanOrEqualTo(1));
      final List<Object?> evidence = List<Object?>.from(manifest['evidence']! as List);
      expect(evidence, hasLength(2));
      for (final Object? entry in evidence) {
        final Map<String, Object?> item = Map<String, Object?>.from(entry! as Map);
        expect(item['sha256'].toString(), hasLength(64));
      }
      expect(manifest['exclusions']! as List, isEmpty);

      final List<String> entries = await service.listEntries(destination);
      expect(entries, contains('manifest.json'));
      expect(entries, contains('records/unternehmen.jsonl'));
      expect(entries, contains('records/belege.jsonl'));
      final String unternehmenJsonl = utf8.decode(await service.readEntry(destination, 'records/unternehmen.jsonl'));
      expect(unternehmenJsonl, contains('Muster GmbH'));
      expect(unternehmenJsonl, isNot(contains('backup_extern_pfad')));

      // Referenced files are stored under relative archive paths with matching bytes.
      for (final Object? entry in evidence) {
        final Map<String, Object?> item = Map<String, Object?>.from(entry! as Map);
        final String archivePath = item['archive_path'].toString();
        expect(p.isAbsolute(archivePath), isFalse);
        final List<int> bytes = await service.readEntry(destination, archivePath);
        expect(bytes, isNotEmpty);
      }
      final String belegJsonl = utf8.decode(await service.readEntry(destination, 'records/belege.jsonl'));
      expect(belegJsonl, isNot(contains(receipt.path)));
      expect(belegJsonl, contains('evidence/'));

      // No temporary sibling output is left behind.
      final List<String> leftovers = outDir
          .listSync()
          .map((FileSystemEntity entity) => p.basename(entity.path))
          .where((String name) => name != 'profil_export.zip')
          .toList();
      expect(leftovers, isEmpty);

      // Source profile remains unchanged.
      final List<Map<String, Object?>> afterKunden = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM kunden',
        const <Object?>[],
      );
      final List<Map<String, Object?>> afterBelege = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM belege',
        const <Object?>[],
      );
      expect(afterKunden.single['c'], beforeKunden.single['c']);
      expect(afterBelege.single['c'], beforeBelege.single['c']);
      expect(belegId, greaterThan(0));
    });

    test('test_profile_data_portability_013_export_excludes_secrets', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('profile_export_013_');
      addTearDown(() async {
        if (profileDir.existsSync()) {
          await profileDir.delete(recursive: true);
        }
      });
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      final List<Map<String, Object?>> companyColumns = await db.executor.runSelect(
        'PRAGMA table_info(unternehmen)',
        const <Object?>[],
      );
      if (!companyColumns.any((Map<String, Object?> row) => row['name'] == 'smtp_passwort')) {
        await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN smtp_passwort TEXT');
      }
      await db.executor.runInsert(
        'INSERT INTO unternehmen (name, backup_extern_pfad, backup_extern_pfad_lokal_ok, smtp_passwort) '
        'VALUES (?, ?, ?, ?)',
        const <Object?>['SENTINEL_COMPANY', 'SECRET_SENTINEL_EXTERN_PFAD_XYZ', 1, 'SECRET_SENTINEL_SMTP_PW_XYZ'],
      );
      await db.executor.runInsert(
        'INSERT INTO datev_export_log (anzahl_buchungen, datei_pfad, status) VALUES (?, ?, ?)',
        const <Object?>[3, 'SECRET_SENTINEL_DATEI_PFAD_XYZ', 'ok'],
      );
      await File(p.join(profileDir.path, '.smtp_secret')).writeAsString('SECRET_SENTINEL_KEYCHAIN_XYZ', flush: true);

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_013_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final String destination = p.join(outDir.path, 'profil_export.zip');
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: profileDir.path,
        profileLabel: 'Testprofil',
      );
      final ProfileExportResult result = await service.exportProfile(destinationPath: destination);

      expect(result.status, ProfileExportStatus.complete);
      expect(File(destination).existsSync(), isTrue);

      // No sentinel value may appear anywhere in the raw archive bytes.
      final String raw = latin1.decode(File(destination).readAsBytesSync());
      for (final String sentinel in <String>[
        'SECRET_SENTINEL_EXTERN_PFAD_XYZ',
        'SECRET_SENTINEL_SMTP_PW_XYZ',
        'SECRET_SENTINEL_DATEI_PFAD_XYZ',
        'SECRET_SENTINEL_KEYCHAIN_XYZ',
      ]) {
        expect(raw, isNot(contains(sentinel)));
      }

      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(manifest['credentials_omitted'], isTrue);
      final List<Object?> omitted = List<Object?>.from(manifest['omitted_fields']! as List);
      final Set<String> omittedFields = <String>{
        for (final Object? item in omitted) (item! as Map)['field'].toString(),
      };
      expect(omittedFields, containsAll(<String>{'backup_extern_pfad', 'datei_pfad'}));
      for (final Object? item in omitted) {
        final Map<String, Object?> map = Map<String, Object?>.from(item! as Map);
        expect(map.keys.toSet(), <String>{'record_type', 'record_id', 'field', 'reason'});
        expect(map['reason'], 'omitted_secret');
      }

      final String unternehmenJsonl = utf8.decode(await service.readEntry(destination, 'records/unternehmen.jsonl'));
      expect(unternehmenJsonl, isNot(contains('SECRET_SENTINEL')));
      expect(unternehmenJsonl, isNot(contains('backup_extern_pfad')));
      expect(unternehmenJsonl, isNot(contains('smtp_passwort')));
      final String datevJsonl = utf8.decode(await service.readEntry(destination, 'records/datev_export_log.jsonl'));
      expect(datevJsonl, contains('"anzahl_buchungen":3'));
      expect(datevJsonl, isNot(contains('datei_pfad')));
    });

    test('test_profile_data_portability_014_referenced_source_file_is_unavailable', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('profile_export_014_');
      addTearDown(() async {
        if (profileDir.existsSync()) {
          await profileDir.delete(recursive: true);
        }
      });
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Muster GmbH']);
      final String missingPath = p.join(profileDir.path, 'fehlt.pdf');
      final int belegId = await db.executor.runInsert(
        'INSERT INTO belege (datum, betrag, dateipfad) VALUES (?, ?, ?)',
        <Object?>['2026-02-01', '7.50', missingPath],
      );

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_014_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final String destination = p.join(outDir.path, 'profil_export.zip');
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: profileDir.path,
        profileLabel: 'Muster GmbH',
      );
      final ProfileExportResult result = await service.exportProfile(destinationPath: destination);

      expect(result.status, ProfileExportStatus.incomplete);
      expect(result.complete, isFalse);
      expect(File(destination).existsSync(), isTrue);

      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(manifest['complete'], isFalse);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(exclusions, hasLength(1));
      final Map<String, Object?> exclusion = Map<String, Object?>.from(exclusions.single! as Map);
      expect(exclusion, <String, Object?>{
        'record_type': 'belege',
        'record_id': '$belegId',
        'field': 'dateipfad',
        'reason': 'missing',
      });

      // The manifest and records must not leak the source path or basename.
      final String manifestRaw = jsonEncode(manifest);
      expect(manifestRaw, isNot(contains('fehlt.pdf')));
      expect(manifestRaw, isNot(contains(profileDir.path)));
      final String belegJsonl = utf8.decode(await service.readEntry(destination, 'records/belege.jsonl'));
      expect(belegJsonl, isNot(contains('fehlt.pdf')));
      expect(belegJsonl, contains('"dateipfad":null'));

      // Source record still references the missing file; nothing was repaired.
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(rows.single['dateipfad'], missingPath);
    });

    test('test_profile_data_portability_015_successful_export_is_verified_before_publication', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('profile_export_015_');
      addTearDown(() async {
        if (profileDir.existsSync()) {
          await profileDir.delete(recursive: true);
        }
      });
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Muster GmbH']);
      await db.executor.runInsert(
        "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('Kunde AG', 'Str 1', '10115', 'Berlin')",
        const <Object?>[],
      );

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_015_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final String destination = p.join(outDir.path, 'profil_export.zip');
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: profileDir.path,
        profileLabel: 'Muster GmbH',
      );
      String? observedStaged;
      bool finalExistedAtStage = true;
      final ProfileExportResult result = await service.exportProfile(
        destinationPath: destination,
        onStaged: (String stagedPath) {
          observedStaged = stagedPath;
          finalExistedAtStage = File(destination).existsSync();
        },
      );

      expect(result.status, ProfileExportStatus.complete);
      expect(result.archivePath, destination);
      // Verification ran on the sibling temp file before the final path existed.
      expect(observedStaged, isNotNull);
      expect(observedStaged, isNot(destination));
      expect(finalExistedAtStage, isFalse);
      expect(File(observedStaged!).existsSync(), isFalse);
      expect(File(destination).existsSync(), isTrue);

      final Map<String, Object?> manifest = await service.readManifest(destination);
      final Map<String, Object?> counts = Map<String, Object?>.from(manifest['record_counts']! as Map);
      final List<Map<String, Object?>> kunden = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM kunden',
        const <Object?>[],
      );
      expect((counts['kunden']! as num).toInt(), kunden.single['c']);
      expect(result.recordCounts['kunden'], kunden.single['c']);
    });

    test('test_profile_data_portability_016_destination_or_validation_failure', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('profile_export_016_');
      addTearDown(() async {
        if (profileDir.existsSync()) {
          await profileDir.delete(recursive: true);
        }
      });
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Muster GmbH']);
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM unternehmen',
        const <Object?>[],
      );

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_016_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: profileDir.path,
        profileLabel: 'Muster GmbH',
      );

      // Occupied destination without confirmation fails and keeps the original.
      final File occupied = File(p.join(outDir.path, 'profil_export.zip'));
      await occupied.writeAsBytes(<int>[1, 2, 3], flush: true);
      final ProfileExportResult occupiedResult = await service.exportProfile(destinationPath: occupied.path);
      expect(occupiedResult.status, ProfileExportStatus.failed);
      expect(occupiedResult.archivePath, isNull);
      expect(occupiedResult.message, contains('Ersetzen'));
      expect(occupied.readAsBytesSync(), <int>[1, 2, 3]);

      // Unwritable destination fails with a localized retryable message.
      final File blocker = File(p.join(outDir.path, 'blocker'));
      await blocker.writeAsString('x', flush: true);
      final ProfileExportResult unwritableResult = await service.exportProfile(
        destinationPath: p.join(blocker.path, 'profil_export.zip'),
      );
      expect(unwritableResult.status, ProfileExportStatus.failed);
      expect(unwritableResult.archivePath, isNull);
      expect(unwritableResult.message, contains('erneut versuchen'));

      // A directory as destination fails as well.
      final ProfileExportResult directoryResult = await service.exportProfile(destinationPath: outDir.path);
      expect(directoryResult.status, ProfileExportStatus.failed);

      // No temporary sibling output is left behind and source data is unchanged.
      final List<String> leftovers = outDir
          .listSync()
          .map((FileSystemEntity entity) => p.basename(entity.path))
          .where((String name) => name.contains('.export-'))
          .toList();
      expect(leftovers, isEmpty);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM unternehmen',
        const <Object?>[],
      );
      expect(after.single['c'], before.single['c']);
    });

    test('test_profile_data_portability_017_user_cancels_export', () async {
      final Directory profileDir = await Directory.systemTemp.createTemp('profile_export_017_');
      addTearDown(() async {
        if (profileDir.existsSync()) {
          await profileDir.delete(recursive: true);
        }
      });
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
      addTearDown(db.close);
      await db.ensureOpen();

      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Muster GmbH']);
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM unternehmen',
        const <Object?>[],
      );

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_017_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: profileDir.path,
        profileLabel: 'Muster GmbH',
      );

      final ProfileExportResult noDestination = await service.exportProfile(destinationPath: '   ');
      expect(noDestination.status, ProfileExportStatus.cancelled);
      expect(noDestination.archivePath, isNull);

      final String destination = p.join(outDir.path, 'profil_export.zip');
      final ProfileExportResult cancelled = await service.exportProfile(
        destinationPath: destination,
        isCancelled: () => true,
      );
      expect(cancelled.status, ProfileExportStatus.cancelled);
      expect(cancelled.archivePath, isNull);
      expect(File(destination).existsSync(), isFalse);

      final List<String> leftovers = outDir
          .listSync()
          .map((FileSystemEntity entity) => p.basename(entity.path))
          .toList();
      expect(leftovers, isEmpty);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM unternehmen',
        const <Object?>[],
      );
      expect(after.single['c'], before.single['c']);
    });

    testWidgets('test_profile_data_portability_018_user_distinguishes_export_types', (WidgetTester tester) async {
      final AppDatabase db = (await tester.runAsync(() => _openProfile('profile_export_018_')))!;
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: db.profileDir!,
        profileLabel: 'Muster GmbH',
      );
      await _pumpSection(
        tester,
        ProfileDataSection(
          exportService: service,
          additionalActions: <ProfileDataExportAction>[
            ProfileDataExportAction(
              id: 'test_bericht',
              scopeTitle: 'Gefilterter Testbericht',
              scopeDescription: 'Nur eine gefilterte Liste, kein vollständiges Archiv.',
              onRun: (String destination) async => ProfileExportResult(
                status: ProfileExportStatus.complete,
                archivePath: destination,
                message: 'Testbericht gespeichert.',
                complete: true,
              ),
            ),
            const ProfileDataExportAction(
              id: 'datev',
              scopeTitle: 'DATEV-Buchungsstapel',
              scopeDescription: 'EXTF-CSV für den Steuerberater.',
            ),
          ],
        ),
      );

      expect(find.text('Daten & Datenschutz'), findsOneWidget);
      expect(find.text('Vollständiges strukturiertes Profilarchiv'), findsOneWidget);
      expect(find.text('Gefilterter Testbericht'), findsOneWidget);
      expect(find.text('DATEV-Buchungsstapel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Profil exportieren'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Starten'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Nicht verfügbar'), findsOneWidget);
      expect(find.text('Dies ist kein DATEV-, GoBD-, Backup-, Berichts- oder Dokumentenpaket-Export.'), findsOneWidget);
      for (final String workflow in <String>['DATEV', 'GoBD', 'Backup']) {
        expect(find.widgetWithText(FilledButton, workflow), findsNothing);
        expect(find.widgetWithText(OutlinedButton, workflow), findsNothing);
      }
      expect(find.text('Export ist bereit.'), findsOneWidget);
    });

    testWidgets('test_profile_data_portability_019_export_action_is_unavailable', (WidgetTester tester) async {
      await _pumpSection(tester, const ProfileDataSection(exportService: null));
      expect(find.text('Export ist nicht verfügbar.'), findsOneWidget);
      expect(find.textContaining('keine Daten exportiert'), findsOneWidget);
      expect(find.text('Profil exportieren'), findsNothing);
      final AppDatabase db = (await tester.runAsync(() => _openProfile('profile_export_019_')))!;
      final ProfileExportService unreadable = ProfileExportService(
        executor: db.executor,
        profileDir: p.join(db.profileDir!, 'fehlt'),
        profileLabel: 'Muster GmbH',
      );
      await _pumpSection(tester, ProfileDataSection(exportService: unreadable));
      expect(find.text('Export ist nicht verfügbar.'), findsOneWidget);
      expect(find.textContaining('keine Daten exportiert'), findsOneWidget);
      expect(find.text('Profil exportieren'), findsNothing);
    });

    testWidgets('test_profile_data_portability_020_erasure_policy_is_unresolved', (WidgetTester tester) async {
      final AppDatabase db = (await tester.runAsync(() => _openProfile('profile_export_020_')))!;
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: db.profileDir!,
        profileLabel: 'Muster GmbH',
      );
      await _pumpSection(tester, ProfileDataSection(exportService: service));

      for (final String forbidden in <String>[
        'Lösch',
        'lösch',
        'Anonym',
        'anonym',
        'Aufbewahr',
        'aufbewahr',
        'Retention',
        'retention',
        'Erasure',
        'erasure',
      ]) {
        expect(find.textContaining(forbidden), findsNothing, reason: 'kein $forbidden-Steuerelement');
      }
      final String sectionSource = File('lib/features/setup/profile_data_section.dart').readAsStringSync();
      expect(sectionSource.toLowerCase(), isNot(contains('lösch')));
      expect(sectionSource.toLowerCase(), isNot(contains('anonym')));
      expect(sectionSource.toLowerCase(), isNot(contains('aufbewahr')));
      expect(sectionSource, isNot(contains('etention')));
      expect(sectionSource.toLowerCase(), isNot(contains('erasure')));
    });

    test('test_profile_data_portability_021_table_inventory_or_durable_marker_is_incomplete', () async {
      final AppDatabase db = await _openProfile('profile_export_021_');
      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: db.profileDir!,
        profileLabel: 'Muster GmbH',
      );
      final MigrationRunner runner = MigrationRunner(
        executor: db.executor,
        profileDir: db.profileDir!,
        requiredTables: AppDatabase.allTableNames,
      );
      final int versionBefore = await runner.getUserVersion();

      // Undeclared table: incomplete, identified, nothing created or repaired.
      await db.executor.runCustom('CREATE TABLE rogue_export_tabelle (id INTEGER PRIMARY KEY)');
      final ProfileExportReadiness rogue = await service.checkExportReadiness();
      expect(rogue.eligibility, ProfileExportEligibility.incomplete);
      expect(rogue.table, 'rogue_export_tabelle');
      expect(rogue.state, 'undeclared');
      expect(rogue.message, contains('rogue_export_tabelle'));
      expect(rogue.message, isNot(contains(db.profileDir)));

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_021_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final ProfileExportResult rogueResult = await service.exportProfile(
        destinationPath: p.join(outDir.path, 'profil_export.zip'),
      );
      expect(rogueResult.status, ProfileExportStatus.incomplete);
      expect(rogueResult.complete, isFalse);
      expect(rogueResult.archivePath, isNotNull);
      final Map<String, Object?> rogueManifest = await service.readManifest(rogueResult.archivePath!);
      expect(jsonEncode(rogueManifest), isNot(contains(db.profileDir)));
      expect(await _exportTableNames(db), contains('rogue_export_tabelle'));
      expect(await runner.getUserVersion(), versionBefore);

      // Unknown lazy marker: incomplete, identified, absent table is not created.
      await db.executor.runCustom('DROP TABLE rogue_export_tabelle');
      await db.executor.runCustom(
        "UPDATE feature_table_state SET state = 'unknown' WHERE table_name = 'buchungsvorlagen_occurrences'",
        const <Object?>[],
      );
      final ProfileExportReadiness unknown = await service.checkExportReadiness();
      expect(unknown.eligibility, ProfileExportEligibility.incomplete);
      expect(unknown.table, 'buchungsvorlagen_occurrences');
      expect(unknown.state, 'unknown');
      expect(unknown.message, isNot(contains(db.profileDir)));

      final ProfileExportResult unknownResult = await service.exportProfile(
        destinationPath: p.join(outDir.path, 'profil_export_unbekannt.zip'),
      );
      expect(unknownResult.status, ProfileExportStatus.incomplete);
      expect(unknownResult.complete, isFalse);
      expect(await _exportTableNames(db), isNot(contains('buchungsvorlagen_occurrences')));
      expect(await runner.getUserVersion(), versionBefore);
    });

    test('test_profile_data_portability_022_version_12_profile_remains_valid_before_v13_migration', () async {
      final AppDatabase db = await _openProfile('profile_export_022_');
      await db.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await db.executor.runCustom('DROP TABLE mileage_trips');
      await db.executor.runCustom('DROP TABLE feature_table_state');
      await db.executor.runCustom('PRAGMA user_version = 12');

      final MigrationRunner runner = MigrationRunner(
        executor: db.executor,
        profileDir: db.profileDir!,
        requiredTables: AppDatabase.allTableNames,
      );
      final SchemaHealthReport health = await runner.inspectSchemaHealth();
      expect(health.isHealthy, isTrue);
      expect(health.isCompleteForVersion13Export, isFalse);

      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: db.profileDir!,
        profileLabel: 'Muster GmbH',
      );
      final ProfileExportReadiness readiness = await service.checkExportReadiness();
      expect(readiness.eligibility, ProfileExportEligibility.incomplete);
      expect(readiness.schemaVersion, 12);
      expect(readiness.state, 'version_pending');
      expect(readiness.message, contains('gültig'));
      expect(readiness.message, isNot(contains(db.profileDir)));

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_022_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final ProfileExportResult result = await service.exportProfile(
        destinationPath: p.join(outDir.path, 'profil_export.zip'),
      );
      expect(result.status, ProfileExportStatus.incomplete);
      expect(result.complete, isFalse);
      expect(await _exportTableNames(db), isNot(contains('feature_table_state')));
      expect(await runner.getUserVersion(), 12);
    });

    test('test_profile_data_portability_023_missing_payment_table_is_detected_before_startup', () async {
      final AppDatabase db = await _openProfile('profile_export_023_');
      await db.executor.runCustom('DROP TABLE forderung_zahlungen');

      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: db.profileDir!,
        profileLabel: 'Muster GmbH',
      );
      final ProfileExportReadiness readiness = await service.checkExportReadiness();
      expect(readiness.eligibility, ProfileExportEligibility.incomplete);
      expect(readiness.table, 'forderung_zahlungen');
      expect(readiness.state, 'missing');
      expect(readiness.message, contains('forderung_zahlungen'));
      expect(readiness.message, isNot(contains(db.profileDir)));

      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_023_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final ProfileExportResult result = await service.exportProfile(
        destinationPath: p.join(outDir.path, 'profil_export.zip'),
      );
      expect(result.status, ProfileExportStatus.incomplete);
      expect(result.complete, isFalse);
      final List<Map<String, Object?>> paymentTable = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
        const <Object?>[],
      );
      expect(paymentTable, isEmpty);
    });

    test('test_profile_data_portability_024_mileage_and_category_tables_follow_their_migrati', () async {
      // Before v13: marker and mileage tables are not yet required.
      final AppDatabase preV13 = await _openProfile('profile_export_024_v12_');
      await preV13.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await preV13.executor.runCustom('DROP TABLE mileage_trips');
      await preV13.executor.runCustom('DROP TABLE feature_table_state');
      await preV13.executor.runCustom('PRAGMA user_version = 12');
      final MigrationRunner preV13Runner = MigrationRunner(
        executor: preV13.executor,
        profileDir: preV13.profileDir!,
        requiredTables: AppDatabase.allTableNames,
      );
      expect((await preV13Runner.inspectSchemaHealth()).isHealthy, isTrue);
      final ProfileExportReadiness preV13Readiness = await ProfileExportService(
        executor: preV13.executor,
        profileDir: preV13.profileDir!,
      ).checkExportReadiness();
      expect(preV13Readiness.eligibility, ProfileExportEligibility.incomplete);
      expect(preV13Readiness.state, 'version_pending');

      // Before v9: category history is not yet required.
      final AppDatabase preV9 = await _openProfile('profile_export_024_v8_');
      await preV9.executor.runCustom('DROP TABLE category_mapping_history');
      await preV9.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await preV9.executor.runCustom('DROP TABLE mileage_trips');
      await preV9.executor.runCustom('DROP TABLE feature_table_state');
      await preV9.executor.runCustom('PRAGMA user_version = 8');
      final MigrationRunner preV9Runner = MigrationRunner(
        executor: preV9.executor,
        profileDir: preV9.profileDir!,
        requiredTables: AppDatabase.allTableNames,
      );
      expect((await preV9Runner.inspectSchemaHealth()).isHealthy, isTrue);
      final ProfileExportReadiness preV9Readiness = await ProfileExportService(
        executor: preV9.executor,
        profileDir: preV9.profileDir!,
      ).checkExportReadiness();
      expect(preV9Readiness.eligibility, ProfileExportEligibility.incomplete);
      expect(preV9Readiness.state, 'version_pending');

      // At the current version: an absent mileage table prevents complete export.
      final AppDatabase current = await _openProfile('profile_export_024_v14_');
      await current.executor.runCustom('DROP TABLE mileage_trips');
      final ProfileExportReadiness mileage = await ProfileExportService(
        executor: current.executor,
        profileDir: current.profileDir!,
      ).checkExportReadiness();
      expect(mileage.eligibility, ProfileExportEligibility.incomplete);
      expect(mileage.table, 'mileage_trips');
      expect(mileage.state, 'missing');

      // At the current version: absent category history prevents complete export.
      await current.executor.runCustom('DROP TABLE category_mapping_history');
      final ProfileExportReadiness category = await ProfileExportService(
        executor: current.executor,
        profileDir: current.profileDir!,
      ).checkExportReadiness();
      expect(category.eligibility, ProfileExportEligibility.incomplete);
      expect(category.table, 'category_mapping_history');
      expect(category.state, 'missing');
    });

    test('test_profile_data_portability_025_excluded_file_reference_contains_no_host_path', () async {
      final AppDatabase db = await _openProfile('profile_export_025_');
      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Muster GmbH']);
      final int belegId = await db.executor.runInsert(
        'INSERT INTO belege (datum, betrag, dateipfad) VALUES (?, ?, ?)',
        <Object?>['2026-03-01', '5.00', p.join(db.profileDir!, 'nicht_vorhanden.pdf')],
      );

      final ProfileExportService service = ProfileExportService(
        executor: db.executor,
        profileDir: db.profileDir!,
        profileLabel: 'Muster GmbH',
      );
      final Directory outDir = await Directory.systemTemp.createTemp('profile_export_025_out_');
      addTearDown(() async {
        if (outDir.existsSync()) {
          await outDir.delete(recursive: true);
        }
      });
      final String destination = p.join(outDir.path, 'profil_export.zip');
      final ProfileExportResult result = await service.exportProfile(destinationPath: destination);
      expect(result.status, ProfileExportStatus.incomplete);

      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(exclusions, hasLength(1));
      for (final Object? entry in exclusions) {
        final Map<String, Object?> item = Map<String, Object?>.from(entry! as Map);
        expect(item.keys.toSet(), <String>{'record_type', 'record_id', 'field', 'reason'});
      }
      final Map<String, Object?> belegExclusion = Map<String, Object?>.from(exclusions.single! as Map);
      expect(belegExclusion['record_type'], 'belege');
      expect(belegExclusion['record_id'], '$belegId');
      expect(belegExclusion['field'], 'dateipfad');
      expect(belegExclusion['reason'], 'missing');

      final String manifestRaw = jsonEncode(manifest);
      expect(manifestRaw, isNot(contains('nicht_vorhanden')));
      expect(manifestRaw, isNot(contains(db.profileDir)));
      final String belegJsonl = utf8.decode(await service.readEntry(destination, 'records/belege.jsonl'));
      expect(belegJsonl, isNot(contains('nicht_vorhanden')));
      expect(belegJsonl, contains('"dateipfad":null'));
    });
  });
}
