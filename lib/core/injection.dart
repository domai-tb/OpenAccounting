import 'package:get_it/get_it.dart';

// ponytail: Riverpod is primary DI per DESIGN.md D1.
// AGENTS.md describes GetIt via AppScope — keep shim for compat, new code
// uses Riverpod ProviderScope. AppScope wrapper stays in Batch 2 if needed.
// ponytail: no abstraction for single use — just the DB today (Batch 3 adds tables).

/// Legacy GetIt accessor — prefer Riverpod appDatabaseProvider for new code.
/// Kept to satisfy AGENTS.md DI contract without forking architecture.
final GetIt getIt = GetIt.instance;

/// Register core singletons. Called once from main() before runApp().
/// Batch 1: no-op shim — DB lifecycle owned by Riverpod appDatabaseProvider.
/// Kept for call-site compat; main.dart now creates DB via ProviderScope override.
Future<void> configureDependencies() async {
  // ponytail: intentionally empty — single ownership via Riverpod avoids
  // dual close hazard (GetIt+Riverpod sharing same instance).
}
