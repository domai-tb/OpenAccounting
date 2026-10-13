import 'dart:convert';
import 'dart:io';

/// Per-profile backup schedule persisted in `<profile>/backup_state.json`.
///
/// Defaults to manual-only; daily/weekly are opt-in. The last-success
/// timestamp advances only after a complete validated backup.
enum BackupSchedule { manualOnly, daily, weekly }

BackupSchedule parseBackupSchedule(Object? raw) {
  return switch (raw) {
    'daily' => BackupSchedule.daily,
    'weekly' => BackupSchedule.weekly,
    _ => BackupSchedule.manualOnly,
  };
}

String backupScheduleName(BackupSchedule schedule) {
  return switch (schedule) {
    BackupSchedule.manualOnly => 'manual-only',
    BackupSchedule.daily => 'daily',
    BackupSchedule.weekly => 'weekly',
  };
}

class BackupScheduleState {
  const BackupScheduleState({required this.schedule, this.lastBackup, this.lastFailure, this.lastFailureMessage});

  final BackupSchedule schedule;
  final DateTime? lastBackup;
  final DateTime? lastFailure;
  final String? lastFailureMessage;

  Map<String, Object?> toJson() => <String, Object?>{
    'schedule': backupScheduleName(schedule),
    if (lastBackup != null) 'lastBackup': lastBackup!.toUtc().toIso8601String(),
    if (lastFailure != null) 'lastFailure': lastFailure!.toUtc().toIso8601String(),
    if (lastFailureMessage != null) 'lastFailureMessage': lastFailureMessage,
  };
}

class BackupScheduleStore {
  BackupScheduleStore({required this.profileDir});

  final String profileDir;

  String get statePath => '$profileDir/backup_state.json';

  Future<BackupScheduleState> load() async {
    final File file = File(statePath);
    if (!file.existsSync()) {
      return const BackupScheduleState(schedule: BackupSchedule.manualOnly);
    }
    try {
      final Map<String, dynamic> decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return BackupScheduleState(
        schedule: parseBackupSchedule(decoded['schedule']),
        lastBackup: decoded['lastBackup'] is String ? DateTime.tryParse(decoded['lastBackup'] as String) : null,
        lastFailure: decoded['lastFailure'] is String ? DateTime.tryParse(decoded['lastFailure'] as String) : null,
        lastFailureMessage: decoded['lastFailureMessage'] is String ? decoded['lastFailureMessage'] as String : null,
      );
    } catch (_) {
      return const BackupScheduleState(schedule: BackupSchedule.manualOnly);
    }
  }

  Future<void> saveSchedule(BackupSchedule schedule) async {
    final BackupScheduleState current = await load();
    await _write(
      BackupScheduleState(
        schedule: schedule,
        lastBackup: current.lastBackup,
        lastFailure: current.lastFailure,
        lastFailureMessage: current.lastFailureMessage,
      ),
    );
  }

  Future<void> recordSuccess(DateTime when) async {
    final BackupScheduleState current = await load();
    await _write(
      BackupScheduleState(schedule: current.schedule, lastBackup: when.toUtc(), lastFailure: current.lastFailure),
    );
  }

  Future<void> recordFailure(String message) async {
    final BackupScheduleState current = await load();
    await _write(
      BackupScheduleState(
        schedule: current.schedule,
        lastBackup: current.lastBackup,
        lastFailure: DateTime.now().toUtc(),
        lastFailureMessage: message,
      ),
    );
  }

  Future<void> _write(BackupScheduleState state) async {
    final File file = File(statePath);
    await file.parent.create(recursive: true);
    final String staged = '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}';
    await File(staged).writeAsString(jsonEncode(state.toJson()), flush: true);
    await File(staged).rename(file.path);
  }

  /// Whether a scheduled backup is due. Manual-only never runs at startup.
  static bool isDue(BackupScheduleState state, DateTime now) {
    return switch (state.schedule) {
      BackupSchedule.manualOnly => false,
      BackupSchedule.daily =>
        state.lastBackup == null || now.toUtc().difference(state.lastBackup!.toUtc()) >= const Duration(hours: 24),
      BackupSchedule.weekly =>
        state.lastBackup == null || now.toUtc().difference(state.lastBackup!.toUtc()) >= const Duration(days: 7),
    };
  }
}
