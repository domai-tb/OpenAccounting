import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/feature_modules/feature_module_repository.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';

/// Riverpod wiring for the module catalog. No BLoC, no new GetIt wiring.
final featureModuleRepositoryProvider = Provider<FeatureModuleRepository>((ref) {
  return FeatureModuleRepository(ref.watch(appDatabaseProvider).executor);
});

final featureModuleServiceProvider = Provider<FeatureModuleService>((ref) {
  return FeatureModuleService(repository: ref.watch(featureModuleRepositoryProvider));
});

final featureModuleStateProvider = FutureProvider<FeatureModuleState>((ref) {
  return ref.watch(featureModuleServiceProvider).currentState();
});

final featureModuleEffectiveProvider = FutureProvider.family<bool, String>((ref, id) {
  return ref.watch(featureModuleServiceProvider).isEffectivelyEnabled(id);
});
