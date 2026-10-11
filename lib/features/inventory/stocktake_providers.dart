import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_providers.dart';
import 'package:openaccounting/features/inventory/stocktake_entity.dart';
import 'package:openaccounting/features/inventory/stocktake_repository.dart';
import 'package:openaccounting/features/inventory/stocktake_usecases.dart';

/// Riverpod wiring for the stocktake workspace. No BLoC, no new GetIt wiring.
final stocktakeRepositoryProvider = Provider<StocktakeRepository>((ref) {
  return StocktakeRepository(ref.watch(appDatabaseProvider).executor);
});

final stocktakeUseCasesProvider = Provider<StocktakeUseCases>((ref) {
  return StocktakeUseCases(ref.watch(stocktakeRepositoryProvider), ref.watch(featureModuleServiceProvider));
});

final stocktakeEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(featureModuleEffectiveProvider(FeatureModuleCatalog.inventory).future);
});

final stocktakeHistoryProvider = FutureProvider<List<Stocktake>>((ref) {
  return ref.watch(stocktakeUseCasesProvider).history();
});

final stocktakeDraftsProvider = FutureProvider<List<Stocktake>>((ref) {
  return ref.watch(stocktakeUseCasesProvider).drafts();
});
