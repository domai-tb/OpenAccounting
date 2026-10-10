import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_guards.dart';
import 'package:openaccounting/features/feature_modules/feature_module_repository.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';
import 'package:openaccounting/features/feature_modules/feature_module_settings_section.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';

/// Optional feature module controls (optional-feature-module-controls).
/// TDD: each scenario starts red, implementation follows, refactor keeps green.
void main() {
  group('Optional feature module controls', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
    });

    tearDown(() async {
      await db.close();
    });

    FeatureModuleService serviceWith(Set<String> providers) {
      return FeatureModuleService(repository: FeatureModuleRepository(db.executor), availableProviders: providers);
    }

    test('test_available_module_state_is_restored', () async {
      final repo = FeatureModuleRepository(db.executor);
      await repo.save(
        const FeatureModuleState(
          enabled: <String, bool>{
            FeatureModuleCatalog.profileManager: false,
            FeatureModuleCatalog.inventory: true,
            FeatureModuleCatalog.guv: false,
          },
        ),
      );
      final String? rawBefore = await repo.loadRaw();

      // Application restart: a fresh service instance loads the same state.
      final service = serviceWith(FeatureModuleProviders.all);
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isTrue);
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.profileManager), isFalse);
      expect(await repo.loadRaw(), rawBefore);
    });

    test('test_unknown_or_unavailable_module_cannot_be_enabled', () async {
      final repo = FeatureModuleRepository(db.executor);
      final String? rawBefore = await repo.loadRaw();
      final service = serviceWith(const <String>{FeatureModuleProviders.profileWorkspace});

      // Unknown IDs resolve to disabled even when the saved preference claims true.
      expect(await service.isEffectivelyEnabled('unknown_modul'), isFalse);
      expect(await service.canMutate('unknown_modul'), isFalse);
      final unknown = await service.setEnabled('unknown_modul', value: true);
      expect(unknown.success, isFalse);

      // Known but unavailable (missing article/invoice providers) stays disabled.
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isFalse);
      expect(await service.canMutate(FeatureModuleCatalog.inventory), isFalse);
      final blocked = await service.setEnabled(FeatureModuleCatalog.inventory, value: true);
      expect(blocked.success, isFalse);

      // No refused write may touch the canonical value.
      expect(await repo.loadRaw(), rawBefore);
    });

    test('test_module_is_disabled_while_it_has_existing_records', () async {
      await db.executor.runCustom('''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''');
      final artikel = await db.artikelRepository.create(
        bezeichnung: 'Lagerartikel',
        vkBrutto: 11.9,
        lagerAktiv: true,
        bestandAktuell: 3,
        mindestbestand: 10,
      );
      await db.executor.runInsert(
        'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund) VALUES (?, ?, ?, ?)',
        <Object?>[artikel.id, '2026-01-05', 3, 'Wareneingang'],
      );
      Future<String> snapshot() async {
        final artikeln = await db.executor.runSelect('SELECT * FROM artikel ORDER BY id', const <Object?>[]);
        final bewegungen = await db.executor.runSelect(
          'SELECT * FROM inventarbewegungen ORDER BY id',
          const <Object?>[],
        );
        return '$artikeln|$bewegungen';
      }

      final service = serviceWith(FeatureModuleProviders.all);
      expect((await service.setEnabled(FeatureModuleCatalog.inventory, value: true)).success, isTrue);
      final String before = await snapshot();

      final disabled = await service.setEnabled(FeatureModuleCatalog.inventory, value: false);
      expect(disabled.success, isTrue);
      expect(disabled.state.isEnabled(FeatureModuleCatalog.inventory), isFalse);

      // Entry points hide, records stay byte-for-byte unchanged.
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isFalse);
      expect(await service.isEntryVisible(FeatureModuleCatalog.inventory), isFalse);
      expect(await service.isDashboardWidgetVisible('lagerwarnung'), isFalse);
      expect(await service.isDashboardWidgetVisible('lagerbestand'), isFalse);
      expect(await service.canMutate(FeatureModuleCatalog.inventory), isFalse);
      expect(await snapshot(), before);

      // A fresh resolver sees the updated state without restarting the app.
      final reloaded = serviceWith(FeatureModuleProviders.all);
      expect(await reloaded.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isFalse);
    });

    testWidgets('test_direct_navigation_reaches_a_safe_unavailable_state', (tester) async {
      final repo = FeatureModuleRepository(db.executor);
      await repo.save(FeatureModuleState.defaults());
      final String? rawBefore = await repo.loadRaw();
      final int artikelBefore =
          ((await db.executor.runSelect('SELECT COUNT(*) AS c FROM artikel', const <Object?>[])).single['c']! as num)
              .toInt();
      final service = serviceWith(FeatureModuleProviders.all);
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureModuleGuard(
              service: service,
              moduleId: FeatureModuleCatalog.inventory,
              child: const Text('Geheimes Lager'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Geheimes Lager'), findsNothing);
      expect(find.text('Modul nicht verfügbar'), findsOneWidget);
      // The guard performs no database write.
      expect(await repo.loadRaw(), rawBefore);
      final int artikelAfter =
          ((await db.executor.runSelect('SELECT COUNT(*) AS c FROM artikel', const <Object?>[])).single['c']! as num)
              .toInt();
      expect(artikelAfter, artikelBefore);
    });

    testWidgets('test_user_changes_a_supported_module', (tester) async {
      final repo = FeatureModuleRepository(db.executor);
      await repo.save(FeatureModuleState.defaults());
      final service = serviceWith(FeatureModuleProviders.all);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeatureModuleSettingsSection(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('feature_module_toggle_inventory')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('feature_module_toggle_inventory')));
      await tester.pumpAndSettle();

      // The persisted setting changes and the entry points update at once.
      expect((await repo.loadOrDefaults()).isEnabled(FeatureModuleCatalog.inventory), isTrue);
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isTrue);
      expect(await service.isEntryVisible(FeatureModuleCatalog.inventory), isTrue);
      // An accessible localized status confirms the result.
      expect(find.text('Aktiviert'), findsWidgets);
    });

    testWidgets('test_module_setting_cannot_be_saved', (tester) async {
      const before = FeatureModuleState(
        enabled: <String, bool>{
          FeatureModuleCatalog.profileManager: false,
          FeatureModuleCatalog.inventory: true,
          FeatureModuleCatalog.guv: false,
        },
      );
      final service = FeatureModuleService(
        repository: _FailingFeatureModuleRepository(db.executor, before),
        availableProviders: FeatureModuleProviders.all,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FeatureModuleSettingsSection(service: service)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('feature_module_toggle_inventory')));
      await tester.pumpAndSettle();

      // The previous enabled state remains in effect with a retryable error.
      expect(await service.isEffectivelyEnabled(FeatureModuleCatalog.inventory), isTrue);
      expect(find.text('Speichern fehlgeschlagen. Erneut versuchen.'), findsOneWidget);
    });
  });
}

/// Repository that reads a fixed state and fails every write, simulating
/// a persistence failure while the user changes a module.
class _FailingFeatureModuleRepository extends FeatureModuleRepository {
  _FailingFeatureModuleRepository(super.executor, this.fixed);

  final FeatureModuleState fixed;

  @override
  Future<FeatureModuleState> loadOrDefaults() async => fixed;

  @override
  Future<FeatureModuleState> save(FeatureModuleState state) async {
    throw const FeatureModuleException('Defekt');
  }
}
