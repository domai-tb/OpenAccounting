import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/assets/asset_repository.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';
import 'package:openaccounting/features/assets/asset_usecases.dart';

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return AssetRepository(db.executor);
});

final assetScheduleServiceProvider = Provider<AssetScheduleService>((ref) {
  return const AssetScheduleService();
});

final assetRegisterUseCasesProvider = Provider<AssetRegisterUseCases>((ref) {
  return AssetRegisterUseCases(
    ref.watch(assetRepositoryProvider),
    scheduleService: ref.watch(assetScheduleServiceProvider),
  );
});
