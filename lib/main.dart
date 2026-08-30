import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  await db.ensureOpen();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(() {
            unawaited(db.close());
          });
          return db;
        }),
      ],
      child: const OpenAccountingApp(),
    ),
  );
}
