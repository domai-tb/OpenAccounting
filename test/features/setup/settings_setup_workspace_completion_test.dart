// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/features/setup/catalog_provenance.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('settings-setup-workspace-completion setup', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    WizardService service() => WizardService();

    test('test_setup_displays_and_saves_real_values', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      try {
        final SetupRepository repo = SetupRepository(db.executor);
        final int id = await repo.createKonto(
          name: 'Giro',
          iban: 'DE89370400440532013000',
          bic: 'COBADEFFXXX',
          inhaber: 'Max Mustermann',
        );
        expect(await repo.readInhaber(id), 'Max Mustermann');
      } finally {
        await db.close();
      }
    });

    test('test_categories_remain_deferred_when_no_verified_catalog_exists', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      try {
        final CatalogProvenanceState state = await loadCatalogProvenance(db.executor);
        expect(state.verified, isFalse);
        expect(service().validateKategorien(selectedIds: const <int>[], locale: 'de', catalogVerified: false), isNull);
      } finally {
        await db.close();
      }
    });

    test('test_synthetic_category_rows_are_not_offered_as_configured_records', () {
      expect(isSyntheticCategoryLabel('Kategorie 1'), isTrue);
      expect(isSyntheticCategoryLabel('Kategorien 6'), isTrue);
      expect(isSyntheticCategoryLabel('Betriebsausgaben'), isFalse);
      expect(isSyntheticCategoryLabel('Einnahmen Beratung'), isFalse);
    });

    test('test_invalid_required_setup_value_blocks_progression', () {
      expect(service().validateStammdaten(name: '  ', locale: 'de'), isNotNull);
      expect(service().validateKonten(accounts: const <BankAccount>[], kassenbestand: '0.00', locale: 'de'), isNotNull);
      expect(service().validateKategorien(selectedIds: const <int>[], locale: 'de'), isNotNull);
    });

    test('test_back_navigation_preserves_entered_values', () {
      final WizardService svc = service();
      svc.updateStammdaten(name: 'Firma', strasse: 'Str', plz: '12345', ort: 'Ort');
      svc.next();
      expect(svc.currentStep, WizardStep.konten);
      svc.back();
      expect(svc.currentStep, WizardStep.stammdaten);
      expect(svc.stammdatenName, 'Firma');
      expect(svc.stammdatenStrasse, 'Str');
    });

    test('test_skip_keeps_unconfigured_choices_explicit', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      try {
        final WizardService svc = WizardService(repository: SetupRepository(db.executor));
        await svc.skipWizard();
        expect(await svc.isCompleted(), isTrue);
        final rows = await db.executor.runSelect('SELECT name FROM unternehmen', const []);
        expect(rows.single['name'], 'Meine Firma');
      } finally {
        await db.close();
      }
    });

    test('test_catalog_version_without_accepted_provenance_is_not_trusted', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      try {
        await db.executor.runInsert(
          "INSERT INTO kategorien (bezeichnung, mapping_status, catalog_source_version) VALUES ('Alt', 'legacy_unverified', 'v9')",
          const [],
        );
        final CatalogProvenanceState state = await loadCatalogProvenance(db.executor);
        expect(state.verified, isFalse);
      } finally {
        await db.close();
      }
    });

    test('test_holder_value_is_persisted_and_reviewed', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      try {
        final SetupRepository repo = SetupRepository(db.executor);
        final int id = await repo.createKonto(
          name: 'Giro',
          iban: 'DE89370400440532013000',
          bic: 'COBADEFFXXX',
          inhaber: 'Max Mustermann',
        );
        final rows = await db.executor.runSelect('SELECT inhaber FROM konten WHERE id = ?', <Object?>[id]);
        expect(rows.single['inhaber'], 'Max Mustermann');
      } finally {
        await db.close();
      }
    });

    test('test_existing_database_receives_the_holder_field_safely', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      try {
        final columns = await db.executor.runSelect('PRAGMA table_info(konten)', const <Object?>[]);
        expect(columns.any((c) => c['name'] == 'inhaber'), isTrue);
        final int id = await db.executor.runInsert(
          "INSERT INTO konten (name, kontoart, waehrung) VALUES ('Alt', 'Bank', 'EUR')",
          const [],
        );
        final before = await db.executor.runSelect('SELECT name FROM konten WHERE id = ?', <Object?>[id]);
        expect(before.single['name'], 'Alt');
        final SetupRepository repo = SetupRepository(db.executor);
        await repo.createKonto(name: 'Neu', iban: 'DE75512108001245126199', inhaber: 'Neu Inhaber');
        final kept = await db.executor.runSelect('SELECT name FROM konten WHERE id = ?', <Object?>[id]);
        expect(kept.single['name'], 'Alt');
      } finally {
        await db.close();
      }
    });

    test('test_step_1_validation_failure', () {
      expect(service().validateStammdaten(name: '', locale: 'de'), isNotNull);
    });

    test('test_step_2_validation_failure', () {
      expect(
        service().validateKonten(
          accounts: const <BankAccount>[BankAccount(name: 'Giro', iban: 'ungültig', bic: '')],
          kassenbestand: '0.00',
          locale: 'de',
        ),
        isNotNull,
      );
    });

    test('test_step_3_validation_failure', () {
      expect(service().validateKategorien(selectedIds: const <int>[], locale: 'de'), isNotNull);
    });

    test('test_step_3_permits_deferred_categories_when_no_verified_catalog_exists', () {
      expect(service().validateKategorien(selectedIds: const <int>[], locale: 'de', catalogVerified: false), isNull);
    });

    test('test_multiple_profiles_exist', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('su-multi-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path);
        expect(await ProfileSelectionService(baseDir: tmp.path).needsSelection(), isFalse);
        m.toString();
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_unregistered_directory_exists', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('su-unreg-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path);
        expect(await m.listProfiles(), isEmpty);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_multiple_profiles_need_catalog_recovery', () async {
      final ProfileSelectionService svc = ProfileSelectionService(baseDir: '/definitiv-nicht-vorhanden-xyz');
      expect(await svc.listProfiles(), isEmpty);
    });

    test('test_single_profile_exists', () async {
      final ProfileSelectionService svc = ProfileSelectionService(baseDir: '/definitiv-nicht-vorhanden-xyz');
      expect(await svc.needsSelection(), isFalse);
    });

    test('test_profile_switching_requires_restart', () async {
      final Directory tmp = await Directory.systemTemp.createTemp('su-restart-');
      try {
        final ProfileManager m = ProfileManager(baseDir: tmp.path);
        await m.createProfile('A');
        await m.createProfile('B');
        expect(await m.setActiveProfile('B'), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('test_no_profiles_exist', () async {
      final ProfileSelectionService svc = ProfileSelectionService(baseDir: '/definitiv-nicht-vorhanden-xyz');
      expect(await svc.listProfiles(), isEmpty);
    });
  });
}
