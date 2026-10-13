import 'package:openaccounting/core/db/backup_schedule.dart';

/// Four-state backup status for Settings (DESIGN §21).
enum BackupHistoryStatus { never, current, stale, failed }

class BackupHistoryView {
  const BackupHistoryView({required this.status, this.lastSuccess, this.lastFailureMessage});

  final BackupHistoryStatus status;
  final DateTime? lastSuccess;
  final String? lastFailureMessage;
}

/// Derives never/current/stale/failed from actual operation history.
BackupHistoryView backupHistoryView(BackupScheduleState state, DateTime now) {
  if (state.lastFailure != null && (state.lastBackup == null || state.lastFailure!.isAfter(state.lastBackup!))) {
    return BackupHistoryView(
      status: BackupHistoryStatus.failed,
      lastSuccess: state.lastBackup,
      lastFailureMessage: state.lastFailureMessage,
    );
  }
  if (state.lastBackup == null) {
    return const BackupHistoryView(status: BackupHistoryStatus.never);
  }
  final Duration age = now.toUtc().difference(state.lastBackup!.toUtc());
  final Duration staleAfter = switch (state.schedule) {
    BackupSchedule.manualOnly || BackupSchedule.daily => const Duration(hours: 24),
    BackupSchedule.weekly => const Duration(days: 7),
  };
  if (age >= staleAfter) {
    return BackupHistoryView(status: BackupHistoryStatus.stale, lastSuccess: state.lastBackup);
  }
  return BackupHistoryView(status: BackupHistoryStatus.current, lastSuccess: state.lastBackup);
}
