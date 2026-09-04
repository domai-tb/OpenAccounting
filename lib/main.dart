import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/features/desktop/desktop_tray.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      final DesktopTrayService tray = createDesktopTrayService();
      // ponytail: fire-and-forget, never block launch
      unawaited(tray.init().catchError((Object _) => false));
    } catch (_) {
      // unsupported platform — continue without tray
    }
  }
  final profileManager = ProfileManager();
  final activeProfile = await profileManager.getActiveProfile();
  final profileDirectory = profileManager.profileDir(activeProfile);
  await Directory(profileDirectory).create(recursive: true);
  final db = AppDatabase.forProfile(profileDirectory);
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
