import 'package:openaccounting/core/db/backup_schedule.dart';
import 'package:openaccounting/core/db/backup_service.dart';

/// Runs the opt-in schedule check once after the active database is ready.
/// Manual-only never backs up; daily/weekly create one validated local backup
/// when due. Last-success advances only after validation; failures stay due
/// and are recorded for Settings.
class BackupStartupCheck {
  const BackupStartupCheck._();

  static bool _ranForSession = false;

  static void resetForTests() => _ranForSession = false;

  static Future<bool> runOnceAfterReady({
    required String profileDir,
    required BackupService backup,
    DateTime Function()? now,
  }) async {
    if (_ranForSession) return false;
    _ranForSession = true;
    final BackupScheduleStore store = BackupScheduleStore(profileDir: profileDir);
    final BackupScheduleState state = await store.load();
    if (!BackupScheduleStore.isDue(state, (now ?? DateTime.now)())) {
      return false;
    }
    try {
      await backup.createLocalBackup();
      await store.recordSuccess((now ?? DateTime.now)());
      return true;
    } catch (error) {
      await store.recordFailure('$error');
      return false;
    }
  }
}
