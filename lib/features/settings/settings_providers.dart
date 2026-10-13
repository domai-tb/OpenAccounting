import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/backup_schedule.dart';
import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/backup_status.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/db/restore_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String settingsRegionPreferenceKey = 'openaccounting.region';

/// Active-profile backup service assembled with the active profile directory,
/// database path, and existing maintenance gates.
final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final ProfileManager manager = ProfileManager();
  final String active = await manager.getActiveProfile();
  final String profileDir = manager.profileDir(active);
  try {
    final AppDatabase db = ref.watch(appDatabaseProvider);
    return BackupService(profileDir: profileDir, executor: db.executor);
  } catch (_) {
    return BackupService(profileDir: profileDir);
  }
});

final restoreCoordinatorProvider = FutureProvider<RestoreCoordinator>((ref) async {
  final ProfileManager manager = ProfileManager();
  final String active = await manager.getActiveProfile();
  return RestoreCoordinator(profileDir: manager.profileDir(active));
});

final backupScheduleProvider = FutureProvider<BackupScheduleState>((ref) async {
  final ProfileManager manager = ProfileManager();
  final String active = await manager.getActiveProfile();
  return BackupScheduleStore(profileDir: manager.profileDir(active)).load();
});

final backupHistoryProvider = FutureProvider<BackupHistoryView>((ref) async {
  final BackupScheduleState state = await ref.watch(backupScheduleProvider.future);
  return backupHistoryView(state, DateTime.now());
});

/// Supported region/formatting preference. Written only after user changes;
/// accounting currency remains EUR.
class SettingsRegionNotifier extends Notifier<String> {
  @override
  String build() {
    Future.microtask(_loadAsync);
    return 'de-DE';
  }

  Future<void> _loadAsync() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(settingsRegionPreferenceKey);
      if (saved == 'de-DE' || saved == 'en-US') state = saved!;
    } catch (_) {}
  }

  Future<bool> setRegion(String region) async {
    if (region != 'de-DE' && region != 'en-US') return false;
    state = region;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setString(settingsRegionPreferenceKey, region);
    } catch (_) {
      return false;
    }
  }
}

final settingsRegionProvider = NotifierProvider<SettingsRegionNotifier, String>(SettingsRegionNotifier.new);

/// SMTP connectivity result labeled narrowly: the current `testSmtp()`
/// performs a TCP/TLS socket connect and closes it. Never implies
/// authentication, certificate pinning, or message delivery.
class SmtpConnectivityResult {
  const SmtpConnectivityResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}
