// ponytail: Riverpod is primary DI per DESIGN.md D1.
// AGENTS.md describes GetIt via AppScope — keep shim for compat, but new code
// uses Riverpod ProviderScope. AppScope wrapper stays in Batch 2 if needed.
import 'package:get_it/get_it.dart';
import 'package:openaccounting/core/database.dart';

/// Legacy GetIt accessor — prefer Riverpod [appDatabaseProvider] for new code.
/// Kept to satisfy AGENTS.md DI contract without forking architecture.
final GetIt getIt = GetIt.instance;

/// Register core singletons. Called once from main() before runApp().
/// ponytail: no abstraction for single use — just the DB today.
Future<void> configureDependencies() async {
  if (!getIt.isRegistered<AppDatabase>()) {
    final db = AppDatabase();
    await db.ensureOpen();
    getIt.registerSingleton<AppDatabase>(db);
  }
}
