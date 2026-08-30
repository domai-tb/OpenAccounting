import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Open DB before first frame — satisfies 1.1 startup connection.
  // Riverpod provider also watches DB; GetIt kept for AGENTS.md compat.
  await configureDependencies();
  final db = getIt<AppDatabase>();
  runApp(ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const OpenAccountingApp()));
}
