// ignore_for_file: file_names

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';

void main() {
  group('Runtime composition and database lifecycle', () {
    test('test_runtime_composition_and_database_lifecycle_1_1_normal_startup_shares_one_ready_database', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();

      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // All consumers resolve the same opened database instance
      final db1 = container.read(appDatabaseProvider);
      final db2 = container.read(appDatabaseProvider);
      expect(identical(db1, db2), isTrue);
      expect(db1, equals(db));

      // Database is actually opened (not LazyDatabase)
      final result = await db1.executor.runSelect('SELECT 1 AS ok', const <Object?>[]);
      expect(result.single['ok'], 1);
    });

    test(
      'test_runtime_composition_and_database_lifecycle_1_2_dependency_resolution_cannot_use_an_unopened_default',
      () async {
        // Default appDatabaseProvider throws — consumer cannot issue SQL
        // against an unopened or nonexistent database.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(() => container.read(appDatabaseProvider), throwsA(anything));
      },
    );

    test('test_runtime_composition_and_database_lifecycle_2_1_a_page_calls_its_use_case', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();

      final services = AppServices(db);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db), appServicesProvider.overrideWithValue(services)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Page resolves use-case from scope, not repository directly
      final resolved = container.read(appServicesProvider);
      expect(resolved, isA<AppServices>());
      expect(resolved.rechnungen, isNotNull);
      expect(resolved.forderungen, isNotNull);
    });

    test(
      'test_runtime_composition_and_database_lifecycle_2_2_a_missing_service_is_diagnosed_at_composition_time',
      () async {
        // When appServicesProvider is not overridden and appDatabaseProvider
        // has no override, resolution cascades the StateError.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(() => container.read(appServicesProvider), throwsA(anything));
      },
    );
  });
}
