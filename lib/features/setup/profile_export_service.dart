import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Status of a profile export attempt.
enum ProfileExportStatus {
  /// Archive was verified and published.
  complete,

  /// Archive was published but is not a complete export.
  incomplete,

  /// No archive was published; the attempt is retryable.
  failed,

  /// The user cancelled; no archive was published.
  cancelled,
}

/// A referenced artifact or secret field excluded from the archive.
///
/// Only stable identifiers are stored: never source paths or secret values.
class ProfileExportExclusion {
  const ProfileExportExclusion({
    required this.recordType,
    required this.recordId,
    required this.field,
    required this.reason,
  });

  final String recordType;
  final String recordId;
  final String field;

  /// One of `missing`, `unreadable`, `outside_profile`, `omitted_secret`.
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'record_type': recordType,
    'record_id': recordId,
    'field': field,
    'reason': reason,
  };
}

/// Outcome of one export attempt.
class ProfileExportResult {
  const ProfileExportResult({
    required this.status,
    this.archivePath,
    this.message,
    this.exclusions = const <ProfileExportExclusion>[],
    this.recordCounts = const <String, int>{},
    this.complete = false,
  });

  final ProfileExportStatus status;

  /// Final archive location; only set for complete/incomplete results.
  final String? archivePath;

  /// Localized (German-first) human-readable outcome.
  final String? message;

  /// Artifact exclusions with reasons `missing`, `unreadable`, `outside_profile`.
  final List<ProfileExportExclusion> exclusions;
  final Map<String, int> recordCounts;
  final bool complete;
}

/// Eligibility of the active profile for a complete structured export.
enum ProfileExportEligibility {
  /// All version-required tables and markers are present.
  ready,

  /// The profile is readable but the inventory is not complete.
  incomplete,

  /// The profile directory is missing or cannot be examined.
  unavailable,
}

/// Outcome of the read-only export preflight check.
///
/// Never creates, repairs, or deletes tables and never exposes file system
/// paths: [table] and [state] carry only inventory names and fixed state
/// codes (`missing`, `undeclared`, `malformed`, `unknown`,
/// `version_pending`, `unsupported_version`).
class ProfileExportReadiness {
  const ProfileExportReadiness({
    required this.eligibility,
    required this.message,
    required this.schemaVersion,
    this.table,
    this.state,
  });

  final ProfileExportEligibility eligibility;

  /// German-first human-readable outcome; never contains a file system path.
  final String message;
  final int schemaVersion;
  final String? table;
  final String? state;

  bool get isReady => eligibility == ProfileExportEligibility.ready;
}

/// Exports the active profile as a versioned ZIP archive.
///
/// Layout: UTF-8 `manifest.json`, UTF-8 JSON Lines at `records/<table>.jsonl`,
/// referenced evidence under `evidence/`. Reads from a WAL-safe snapshot taken
/// through `VACUUM INTO` (the backup lifecycle pattern), writes through a
/// sibling temporary file, publishes only after structural verification, and
/// never modifies source data. Secrets are excluded via a positive omission
/// list and are never read from the secret store.
class ProfileExportService {
  ProfileExportService({
    required this._executor,
    required String profileDir,
    String? profileLabel,
    DateTime Function()? clock,
  }) : profileDir = p.normalize(p.absolute(profileDir)),
       profileLabel = _resolveLabel(profileLabel, profileDir),
       _clock = clock ?? DateTime.now;

  final QueryExecutor _executor;

  /// Canonical active profile root; artifact copies must resolve inside it.
  final String profileDir;
  final String profileLabel;
  final DateTime Function() _clock;

  /// Version of the archive container and manifest schema.
  static const int archiveVersion = 1;

  /// Version of the per-table record serialization.
  static const int recordVersion = 1;

  static const String reasonMissing = 'missing';
  static const String reasonUnreadable = 'unreadable';
  static const String reasonOutsideProfile = 'outside_profile';
  static const String reasonOmittedSecret = 'omitted_secret';

  static const String _messageCancelled = 'Export abgebrochen. Es wurde kein Archiv erstellt.';
  static const String _messageComplete = 'Export abgeschlossen und geprüft.';
  static const String _messageIncomplete = 'Export unvollständig gespeichert. Bitte Hinweise prüfen.';
  static const String _messageRetry = 'Bitte Ziel prüfen und erneut versuchen.';

  /// Feature-owned tables beyond [AppDatabase.allTableNames].
  static const List<String> _featureTables = <String>[
    'forderung_zahlungen',
    'category_mapping_history',
    'feature_table_state',
    'buchungsvorlagen_occurrences',
    'rechnungsvorlagen_occurrences',
    'mileage_trips',
    'mileage_trip_corrections',
  ];

  /// Columns that are never serialized. Values are reported only as
  /// `omitted_secret` exclusions identified by record ID and field.
  static const Map<String, Set<String>> _omittedColumns = <String, Set<String>>{
    'unternehmen': <String>{'backup_extern_pfad', 'backup_extern_pfad_lokal_ok', 'smtp_passwort'},
    'datev_export_log': <String>{'datei_pfad'},
  };

  /// Persisted file references resolved against the profile root.
  static const List<(String, String)> _artifactColumns = <(String, String)>[
    ('unternehmen', 'logo_pfad'),
    ('belege', 'dateipfad'),
    ('rechnungen', 'original_pdf_pfad'),
  ];

  /// Runs a complete export to [destinationPath].
  ///
  /// When [allowOverwrite] is false an existing destination fails instead of
  /// being replaced. [isCancelled] is polled between stages; [onStaged] is a
  /// diagnostic hook invoked after the temporary archive is written but
  /// before verification and publication.
  Future<ProfileExportResult> exportProfile({
    required String destinationPath,
    bool allowOverwrite = false,
    bool Function()? isCancelled,
    void Function(String stagedPath)? onStaged,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    if (destinationPath.trim().isEmpty || cancelled()) {
      return const ProfileExportResult(status: ProfileExportStatus.cancelled, message: _messageCancelled);
    }
    final String destination = p.normalize(p.absolute(destinationPath));
    final String? destinationError = _validateDestination(destination, allowOverwrite: allowOverwrite);
    if (destinationError != null) {
      return ProfileExportResult(status: ProfileExportStatus.failed, message: destinationError);
    }
    if (!Directory(profileDir).existsSync()) {
      return const ProfileExportResult(
        status: ProfileExportStatus.failed,
        message: 'Profilverzeichnis wurde nicht gefunden. $_messageRetry',
      );
    }
    // Read-point gate (BackupService convention): refuse while a transaction
    // holds the database so the snapshot below is consistent.
    try {
      await _executor.runCustom('BEGIN IMMEDIATE');
      await _executor.runCustom('ROLLBACK');
    } catch (_) {
      return const ProfileExportResult(
        status: ProfileExportStatus.failed,
        message: 'Export erfordert ein Wartungsfenster ohne aktive Transaktion. $_messageRetry',
      );
    }
    if (cancelled()) {
      return const ProfileExportResult(status: ProfileExportStatus.cancelled, message: _messageCancelled);
    }
    final Map<String, _ExportTable> tables = await _readTables();
    if (cancelled()) {
      return const ProfileExportResult(status: ProfileExportStatus.cancelled, message: _messageCancelled);
    }
    final SchemaHealthReport health = await MigrationRunner(
      executor: _executor,
      profileDir: profileDir,
      requiredTables: AppDatabase.allTableNames,
    ).inspectSchemaHealth();
    final String resolvedRoot;
    try {
      resolvedRoot = Directory(profileDir).resolveSymbolicLinksSync();
    } catch (_) {
      return const ProfileExportResult(
        status: ProfileExportStatus.failed,
        message: 'Profilverzeichnis konnte nicht aufgelöst werden. $_messageRetry',
      );
    }

    final List<ProfileExportExclusion> exclusions = <ProfileExportExclusion>[];
    final List<Map<String, Object?>> omittedFields = <Map<String, Object?>>[];
    final List<_EvidenceFile> evidence = <_EvidenceFile>[];
    final Map<String, int> counts = <String, int>{};
    final Map<String, String> recordPayloads = <String, String>{};
    for (final String table in <String>[...AppDatabase.allTableNames, ..._featureTables]) {
      final _ExportTable snapshot = tables[table]!;
      counts[table] = snapshot.rows.length;
      if (!snapshot.present) {
        continue;
      }
      final StringBuffer buffer = StringBuffer();
      for (final Map<String, Object?> row in snapshot.rows) {
        final Map<String, Object?> exported = Map<String, Object?>.from(row);
        final Set<String>? omitted = _omittedColumns[table];
        if (omitted != null) {
          for (final String column in omitted) {
            if (_isOmittedValue(exported[column])) {
              omittedFields.add(<String, Object?>{
                'record_type': table,
                'record_id': _recordId(table, exported),
                'field': column,
                'reason': reasonOmittedSecret,
              });
            }
            exported.remove(column);
          }
        }
        for (final (String, String) artifact in _artifactColumns) {
          if (artifact.$1 != table || !exported.containsKey(artifact.$2)) {
            continue;
          }
          final String recordId = _recordId(table, exported);
          final Object? raw = exported[artifact.$2];
          if (!_hasValue(raw)) {
            exported[artifact.$2] = null;
            continue;
          }
          final _ArtifactResolution resolution = _resolveArtifact(
            table: table,
            recordId: recordId,
            field: artifact.$2,
            raw: raw.toString(),
            resolvedRoot: resolvedRoot,
          );
          if (resolution.exclusion != null) {
            exclusions.add(resolution.exclusion!);
            exported[artifact.$2] = null;
          } else {
            evidence.add(resolution.evidence!);
            exported[artifact.$2] = resolution.evidence!.archivePath;
          }
        }
        buffer.writeln(jsonEncode(exported));
      }
      recordPayloads['records/$table.jsonl'] = buffer.toString();
    }
    _noteSecretStore(omittedFields, tables);

    final bool complete = health.isCompleteForVersion13Export && exclusions.isEmpty;
    final Map<String, Object?> manifest = <String, Object?>{
      'archive_version': archiveVersion,
      'record_version': recordVersion,
      'schema_version': MigrationRunner.currentVersion,
      'profile_label': profileLabel,
      'created_at': _clock().toUtc().toIso8601String(),
      'complete': complete,
      'record_counts': counts,
      'table_presence': <String, Object?>{
        for (final String table in <String>[...AppDatabase.allTableNames, ..._featureTables])
          table: <String, Object?>{
            'present': tables[table]!.present,
            if (_markerState(tables, table) != null) 'state': _markerState(tables, table),
          },
      },
      'evidence': <Map<String, Object?>>[
        for (final _EvidenceFile item in evidence)
          <String, Object?>{'archive_path': item.archivePath, 'sha256': item.sha256},
      ],
      'exclusions': <Map<String, Object?>>[for (final ProfileExportExclusion item in exclusions) item.toJson()],
      'omitted_fields': omittedFields,
      'credentials_omitted': true,
    };

    final List<_ZipEntry> zipEntries = <_ZipEntry>[
      _ZipEntry(name: 'manifest.json', data: utf8.encode(jsonEncode(manifest))),
      for (final MapEntry<String, String> payload in recordPayloads.entries)
        _ZipEntry(name: payload.key, data: utf8.encode(payload.value)),
      for (final _EvidenceFile item in evidence) _ZipEntry(name: item.archivePath, data: item.bytes),
    ];
    final Uint8List archiveBytes = _encodeZip(zipEntries);

    final String staged = '$destination.export-${_stamp()}.tmp';
    if (cancelled()) {
      return const ProfileExportResult(status: ProfileExportStatus.cancelled, message: _messageCancelled);
    }
    try {
      final FileSystemEntityType stagedType = FileSystemEntity.typeSync(staged, followLinks: false);
      if (stagedType == FileSystemEntityType.link) {
        throw StateError('Temporäre Export-Datei darf kein Link sein');
      }
      if (stagedType != FileSystemEntityType.notFound) {
        File(staged).deleteSync();
      }
      File(staged).writeAsBytesSync(archiveBytes, flush: true);
    } catch (_) {
      await _deleteQuietly(staged);
      return const ProfileExportResult(
        status: ProfileExportStatus.failed,
        message: 'Export konnte nicht geschrieben werden. $_messageRetry',
      );
    }
    onStaged?.call(staged);
    if (cancelled()) {
      await _deleteQuietly(staged);
      return const ProfileExportResult(status: ProfileExportStatus.cancelled, message: _messageCancelled);
    }
    try {
      _verifyStaged(
        File(staged).readAsBytesSync(),
        requiredEntries: <String>['manifest.json', ...recordPayloads.keys],
        counts: counts,
        evidence: evidence,
      );
    } catch (_) {
      await _deleteQuietly(staged);
      return const ProfileExportResult(
        status: ProfileExportStatus.failed,
        message: 'Export-Prüfung fehlgeschlagen. $_messageRetry',
      );
    }
    if (!allowOverwrite && File(destination).existsSync()) {
      await _deleteQuietly(staged);
      return const ProfileExportResult(
        status: ProfileExportStatus.failed,
        message: 'Zieldatei existiert bereits. Bitte anderen Namen wählen oder Ersetzen bestätigen.',
      );
    }
    try {
      File(staged).renameSync(destination);
    } on FileSystemException {
      // Windows cannot rename over an existing file: move it aside first.
      if (!allowOverwrite) {
        await _deleteQuietly(staged);
        return const ProfileExportResult(
          status: ProfileExportStatus.failed,
          message: 'Zieldatei existiert bereits. Bitte anderen Namen wählen oder Ersetzen bestätigen.',
        );
      }
      final String previous = '$destination.export-previous-${_stamp()}.tmp';
      try {
        File(destination).renameSync(previous);
        try {
          File(staged).renameSync(destination);
          File(previous).deleteSync();
        } catch (_) {
          if (!File(destination).existsSync() && File(previous).existsSync()) {
            File(previous).renameSync(destination);
          }
          rethrow;
        }
      } catch (_) {
        await _deleteQuietly(staged);
        return const ProfileExportResult(
          status: ProfileExportStatus.failed,
          message: 'Export konnte nicht veröffentlicht werden. $_messageRetry',
        );
      }
    }
    if (complete) {
      return ProfileExportResult(
        status: ProfileExportStatus.complete,
        archivePath: destination,
        message: _messageComplete,
        exclusions: exclusions,
        recordCounts: counts,
        complete: true,
      );
    }
    return ProfileExportResult(
      status: ProfileExportStatus.incomplete,
      archivePath: destination,
      message: _messageIncomplete,
      exclusions: exclusions,
      recordCounts: counts,
    );
  }

  /// Read-only preflight gate for Settings and tests.
  ///
  /// Reports whether a complete export is possible without touching the
  /// database contents: only `PRAGMA user_version` and `SELECT` reads run.
  /// Never creates, repairs, or deletes a table, and never includes file
  /// system paths in the result.
  Future<ProfileExportReadiness> checkExportReadiness() async {
    if (!Directory(profileDir).existsSync()) {
      return const ProfileExportReadiness(
        eligibility: ProfileExportEligibility.unavailable,
        message: 'Export ist nicht verfügbar. Das aktive Profil kann nicht gelesen werden.',
        schemaVersion: -1,
      );
    }
    final SchemaHealthReport health;
    try {
      health = await MigrationRunner(
        executor: _executor,
        profileDir: profileDir,
        requiredTables: AppDatabase.allTableNames,
      ).inspectSchemaHealth();
    } catch (_) {
      return const ProfileExportReadiness(
        eligibility: ProfileExportEligibility.unavailable,
        message: 'Export ist nicht verfügbar. Das Profil konnte nicht geprüft werden.',
        schemaVersion: -1,
      );
    }
    ProfileExportReadiness incomplete(String? table, String state, String message) {
      return ProfileExportReadiness(
        eligibility: ProfileExportEligibility.incomplete,
        message: message,
        schemaVersion: health.schemaVersion,
        table: table,
        state: state,
      );
    }

    if (health.unknownTables.isNotEmpty) {
      final String table = health.unknownTables.first;
      return incomplete(
        table,
        'undeclared',
        'Export ist unvollständig: Tabelle „$table“ ist nicht im Export-Inventar enthalten.',
      );
    }
    if (health.missingTables.isNotEmpty) {
      final String table = health.missingTables.first;
      return incomplete(table, 'missing', 'Export ist unvollständig: Tabelle „$table“ fehlt.');
    }
    if (health.malformedTables.isNotEmpty) {
      final String table = health.malformedTables.first;
      return incomplete(table, 'malformed', 'Export ist unvollständig: Tabelle „$table“ ist ungültig.');
    }
    if (!health.isHealthy) {
      if (health.schemaVersion > MigrationRunner.currentVersion) {
        return incomplete(
          null,
          'unsupported_version',
          'Export ist unvollständig: Schema v${health.schemaVersion} wird nicht unterstützt.',
        );
      }
      final MapEntry<String, String>? marker = await _mismatchedMarker();
      if (marker == null) {
        return incomplete(null, 'unknown', 'Export ist unvollständig: Der Bestand weicht vom erwarteten Zustand ab.');
      }
      return incomplete(
        marker.key,
        marker.value,
        'Export ist unvollständig: „${marker.key}“ weicht ab (Status: ${marker.value}).',
      );
    }
    if (!health.isCompleteForVersion13Export) {
      if (health.schemaVersion < MigrationRunner.currentVersion) {
        return incomplete(
          null,
          'version_pending',
          'Das Profil ist gültig (Schema v${health.schemaVersion}), aber erst nach der Migration '
              'auf v${MigrationRunner.currentVersion} vollständig exportierbar.',
        );
      }
      final MapEntry<String, String>? marker = await _unknownMarker();
      if (marker == null) {
        return incomplete(
          null,
          'unknown',
          'Export ist unvollständig: Eine optionale Tabelle ist noch nicht zugeordnet.',
        );
      }
      return incomplete(marker.key, 'unknown', 'Export ist unvollständig: „${marker.key}“ ist noch nicht zugeordnet.');
    }
    return ProfileExportReadiness(
      eligibility: ProfileExportEligibility.ready,
      message: 'Export ist bereit.',
      schemaVersion: health.schemaVersion,
    );
  }

  /// First lazy marker whose state disagrees with its table presence.
  Future<MapEntry<String, String>?> _mismatchedMarker() async {
    try {
      final List<Map<String, Object?>> rows = await _executor.runSelect(
        'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
        const <Object?>[],
      );
      final List<Map<String, Object?>> names = await _executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
        const <Object?>[],
      );
      final Set<String> actual = <String>{for (final Map<String, Object?> row in names) row['name'].toString()};
      for (final Map<String, Object?> row in rows) {
        final String table = row['table_name'].toString();
        final String state = row['state'].toString();
        final bool exists = actual.contains(table);
        final bool matches =
            (state == 'never_initialized' && !exists) ||
            (state == 'initialized' && exists) ||
            (state == 'unknown' && !exists);
        if (!matches) {
          return MapEntry<String, String>(table, state);
        }
      }
    } catch (_) {}
    return null;
  }

  /// First lazy table still marked `unknown`, if any.
  Future<MapEntry<String, String>?> _unknownMarker() async {
    try {
      final List<Map<String, Object?>> rows = await _executor.runSelect(
        "SELECT table_name FROM feature_table_state WHERE state = 'unknown' ORDER BY table_name",
        const <Object?>[],
      );
      if (rows.isNotEmpty) {
        return MapEntry<String, String>(rows.first['table_name'].toString(), 'unknown');
      }
    } catch (_) {}
    return null;
  }

  /// Reads the manifest of a previously written archive.
  Future<Map<String, Object?>> readManifest(String archivePath) async {
    final List<_ZipEntry> entries = _decodeZip(File(archivePath).readAsBytesSync());
    for (final _ZipEntry entry in entries) {
      if (entry.name == 'manifest.json') {
        return Map<String, Object?>.from(jsonDecode(utf8.decode(entry.data))! as Map);
      }
    }
    throw StateError('manifest.json fehlt im Archiv');
  }

  /// Lists entry names of a previously written archive.
  Future<List<String>> listEntries(String archivePath) async {
    return <String>[for (final _ZipEntry entry in _decodeZip(File(archivePath).readAsBytesSync())) entry.name];
  }

  /// Reads one entry of a previously written archive.
  Future<Uint8List> readEntry(String archivePath, String entryName) async {
    final List<_ZipEntry> entries = _decodeZip(File(archivePath).readAsBytesSync());
    for (final _ZipEntry entry in entries) {
      if (entry.name == entryName) {
        return Uint8List.fromList(entry.data);
      }
    }
    throw StateError('Eintrag $entryName fehlt im Archiv');
  }

  String? _validateDestination(String destination, {required bool allowOverwrite}) {
    final FileSystemEntityType type = FileSystemEntity.typeSync(destination, followLinks: false);
    if (type == FileSystemEntityType.link) {
      return 'Export-Ziel darf kein Link sein. $_messageRetry';
    }
    if (type == FileSystemEntityType.directory) {
      return 'Export-Ziel ist ein Verzeichnis. Bitte eine Datei wählen und erneut versuchen.';
    }
    if (type == FileSystemEntityType.file && !allowOverwrite) {
      return 'Zieldatei existiert bereits. Bitte anderen Namen wählen oder Ersetzen bestätigen.';
    }
    final String parent = p.dirname(destination);
    if (FileSystemEntity.typeSync(parent, followLinks: false) == FileSystemEntityType.link) {
      return 'Zielverzeichnis darf kein Link sein. $_messageRetry';
    }
    try {
      Directory(parent).createSync(recursive: true);
    } catch (_) {
      return 'Export-Ziel ist nicht schreibbar. $_messageRetry';
    }
    return null;
  }

  /// Consistent read point: WAL-safe snapshot via `VACUUM INTO`, falling back
  /// to direct executor reads when no file snapshot can be taken.
  Future<Map<String, _ExportTable>> _readTables() async {
    final String staging = p.join(Directory.systemTemp.path, 'profile-export-snapshot-${_stamp()}.db');
    sqlite.Database? snapshot;
    try {
      await _executor.runCustom('VACUUM INTO ?', <Object?>[staging]);
      snapshot = sqlite.sqlite3.open(staging, mode: sqlite.OpenMode.readOnly);
      final Map<String, _ExportTable> tables = _readFromSnapshot(snapshot);
      snapshot.close();
      await _deleteQuietly(staging);
      return tables;
    } catch (_) {
      try {
        snapshot?.close();
      } catch (_) {}
      await _deleteQuietly(staging);
      return _readFromExecutor();
    }
  }

  Map<String, _ExportTable> _readFromSnapshot(sqlite.Database snapshot) {
    final sqlite.ResultSet names = snapshot.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    final Set<String> actual = <String>{for (final sqlite.Row row in names) row['name'].toString()};
    final Map<String, _ExportTable> tables = <String, _ExportTable>{};
    for (final String table in <String>[...AppDatabase.allTableNames, ..._featureTables]) {
      if (!actual.contains(table)) {
        tables[table] = const _ExportTable(columns: <String>[], rows: <Map<String, Object?>>[], present: false);
        continue;
      }
      final sqlite.ResultSet result = snapshot.select('SELECT * FROM "$table"');
      final List<String> columns = <String>[...result.columnNames];
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[
        for (final sqlite.Row row in result)
          <String, Object?>{for (final String column in columns) column: _jsonSafe(row[column])},
      ];
      tables[table] = _ExportTable(columns: columns, rows: rows, present: true);
    }
    return tables;
  }

  Future<Map<String, _ExportTable>> _readFromExecutor() async {
    final List<Map<String, Object?>> names = await _executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      const <Object?>[],
    );
    final Set<String> actual = <String>{for (final Map<String, Object?> row in names) row['name'].toString()};
    final Map<String, _ExportTable> tables = <String, _ExportTable>{};
    for (final String table in <String>[...AppDatabase.allTableNames, ..._featureTables]) {
      if (!actual.contains(table)) {
        tables[table] = const _ExportTable(columns: <String>[], rows: <Map<String, Object?>>[], present: false);
        continue;
      }
      final List<Map<String, Object?>> rows = await _executor.runSelect('SELECT * FROM "$table"', const <Object?>[]);
      final List<String> columns = rows.isEmpty ? await _pragmaColumns(table) : <String>[...rows.first.keys];
      tables[table] = _ExportTable(
        columns: columns,
        rows: <Map<String, Object?>>[
          for (final Map<String, Object?> row in rows)
            <String, Object?>{for (final String column in columns) column: _jsonSafe(row[column])},
        ],
        present: true,
      );
    }
    return tables;
  }

  Future<List<String>> _pragmaColumns(String table) async {
    final List<Map<String, Object?>> info = await _executor.runSelect('PRAGMA table_info("$table")', const <Object?>[]);
    return <String>[for (final Map<String, Object?> row in info) row['name'].toString()];
  }

  /// Canonical-resolve plus inside-root check; copies nothing, only reads.
  _ArtifactResolution _resolveArtifact({
    required String table,
    required String recordId,
    required String field,
    required String raw,
    required String resolvedRoot,
  }) {
    ProfileExportExclusion exclusion(String reason) =>
        ProfileExportExclusion(recordType: table, recordId: recordId, field: field, reason: reason);
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return _ArtifactResolution.empty();
    }
    final String candidate = p.isAbsolute(trimmed) ? p.normalize(trimmed) : p.normalize(p.join(profileDir, trimmed));
    if (FileSystemEntity.typeSync(candidate, followLinks: false) == FileSystemEntityType.notFound) {
      return _ArtifactResolution.excluded(exclusion(reasonMissing));
    }
    final String canonical;
    try {
      canonical = File(candidate).resolveSymbolicLinksSync();
    } catch (_) {
      return _ArtifactResolution.excluded(exclusion(reasonUnreadable));
    }
    if (canonical != resolvedRoot && !p.isWithin(resolvedRoot, canonical)) {
      return _ArtifactResolution.excluded(exclusion(reasonOutsideProfile));
    }
    if (FileSystemEntity.typeSync(canonical, followLinks: false) != FileSystemEntityType.file) {
      return _ArtifactResolution.excluded(exclusion(reasonUnreadable));
    }
    final Uint8List bytes;
    try {
      bytes = File(canonical).readAsBytesSync();
    } catch (_) {
      return _ArtifactResolution.excluded(exclusion(reasonUnreadable));
    }
    final String digest = sha256.convert(bytes).toString();
    final String safeId = recordId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    final String archivePath =
        'evidence/${table}_${safeId}_${field}_${digest.substring(0, 12)}${_safeExtension(candidate)}';
    return _ArtifactResolution.included(_EvidenceFile(archivePath: archivePath, sha256: digest, bytes: bytes));
  }

  /// Notes the file-backed SMTP secret without ever reading its value.
  void _noteSecretStore(List<Map<String, Object?>> omittedFields, Map<String, _ExportTable> tables) {
    final File secret = File(p.join(profileDir, '.smtp_secret'));
    if (!secret.existsSync()) {
      return;
    }
    final _ExportTable? companies = tables['unternehmen'];
    String recordId = '1';
    if (companies != null && companies.present && companies.rows.isNotEmpty) {
      recordId = _recordId('unternehmen', companies.rows.first);
    }
    omittedFields.add(<String, Object?>{
      'record_type': 'unternehmen',
      'record_id': recordId,
      'field': 'smtp_passwort',
      'reason': reasonOmittedSecret,
    });
  }

  String _stamp() {
    final DateTime now = _clock().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}_'
        '${now.microsecondsSinceEpoch}';
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static String _resolveLabel(String? label, String directory) {
    if (label != null && label.trim().isNotEmpty) {
      return label.trim();
    }
    final String base = p.basename(p.normalize(p.absolute(directory)));
    return base.isEmpty ? 'Profil' : base;
  }

  static String _recordId(String table, Map<String, Object?> row) {
    if (table == 'feature_table_state') {
      return row['table_name']?.toString() ?? '';
    }
    return row['id']?.toString() ?? '';
  }

  static bool _hasValue(Object? value) => value != null && (value is! String || value.trim().isNotEmpty);

  /// Only stored values are reported as omissions; defaults stay silent.
  static bool _isOmittedValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is bool) {
      return value;
    }
    return true;
  }

  static Object? _jsonSafe(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Uint8List) {
      return base64Encode(value);
    }
    if (value is List<int>) {
      return base64Encode(value);
    }
    return value.toString();
  }

  static String? _markerState(Map<String, _ExportTable> tables, String table) {
    final _ExportTable? markers = tables['feature_table_state'];
    if (markers == null || !markers.present) {
      return null;
    }
    for (final Map<String, Object?> row in markers.rows) {
      if (row['table_name']?.toString() == table) {
        return row['state']?.toString();
      }
    }
    return null;
  }

  static String _safeExtension(String sourcePath) {
    final String extension = p.extension(sourcePath).toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)) {
      return extension;
    }
    return '.bin';
  }

  static void _verifyStaged(
    List<int> bytes, {
    required List<String> requiredEntries,
    required Map<String, int> counts,
    required List<_EvidenceFile> evidence,
  }) {
    final List<_ZipEntry> entries = _decodeZip(bytes);
    final Map<String, _ZipEntry> byName = <String, _ZipEntry>{for (final _ZipEntry entry in entries) entry.name: entry};
    for (final String required in requiredEntries) {
      if (!byName.containsKey(required)) {
        throw StateError('Export-Prüfung fehlgeschlagen: $required fehlt');
      }
    }
    final _ZipEntry manifestEntry = byName['manifest.json']!;
    final Map<String, Object?> manifest = Map<String, Object?>.from(
      jsonDecode(utf8.decode(manifestEntry.data))! as Map,
    );
    if (manifest['archive_version'] != archiveVersion || manifest['record_version'] != recordVersion) {
      throw StateError('Export-Prüfung fehlgeschlagen: unbekannte Archivversion');
    }
    final Map<String, Object?> manifestCounts = Map<String, Object?>.from(manifest['record_counts']! as Map);
    for (final MapEntry<String, int> count in counts.entries) {
      final Object? stored = manifestCounts[count.key];
      if (stored is! num || stored.toInt() != count.value) {
        throw StateError('Export-Prüfung fehlgeschlagen: Zähler ${count.key} weicht ab');
      }
    }
    for (final _EvidenceFile item in evidence) {
      final _ZipEntry? file = byName[item.archivePath];
      if (file == null) {
        throw StateError('Export-Prüfung fehlgeschlagen: Nachweis fehlt');
      }
      if (sha256.convert(file.data).toString() != item.sha256) {
        throw StateError('Export-Prüfung fehlgeschlagen: Integrität verletzt');
      }
    }
  }
}

class _ExportTable {
  const _ExportTable({required this.columns, required this.rows, required this.present});
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final bool present;
}

class _EvidenceFile {
  const _EvidenceFile({required this.archivePath, required this.sha256, required this.bytes});
  final String archivePath;
  final String sha256;
  final Uint8List bytes;
}

class _ArtifactResolution {
  const _ArtifactResolution._({this.exclusion, this.evidence});
  factory _ArtifactResolution.empty() => const _ArtifactResolution._();
  factory _ArtifactResolution.excluded(ProfileExportExclusion exclusion) => _ArtifactResolution._(exclusion: exclusion);
  factory _ArtifactResolution.included(_EvidenceFile evidence) => _ArtifactResolution._(evidence: evidence);

  final ProfileExportExclusion? exclusion;
  final _EvidenceFile? evidence;
}

class _ZipEntry {
  const _ZipEntry({required this.name, required this.data});
  final String name;
  final List<int> data;
}

final List<int> _crcTable = List<int>.generate(256, (int index) {
  var value = index;
  for (var round = 0; round < 8; round++) {
    value = (value & 1) != 0 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  return value;
});

int _crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final int byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xff] ^ ((crc >>> 8) & 0xffffff);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void _writeU16(BytesBuilder out, int value) {
  out.add(<int>[value & 0xff, (value >> 8) & 0xff]);
}

void _writeU32(BytesBuilder out, int value) {
  out.add(<int>[value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff]);
}

(int, int) _dosTime(DateTime time) {
  final int date = ((time.year - 1980) << 9) | (time.month << 5) | time.day;
  final int clock = (time.hour << 11) | (time.minute << 5) | (time.second ~/ 2);
  return (clock, date);
}

/// Minimal stored (uncompressed) ZIP writer; avoids a new dependency.
Uint8List _encodeZip(List<_ZipEntry> entries) {
  final BytesBuilder out = BytesBuilder();
  final BytesBuilder central = BytesBuilder();
  final DateTime now = DateTime.now();
  final (int, int) stamp = _dosTime(now);
  var offset = 0;
  for (final _ZipEntry entry in entries) {
    final List<int> name = utf8.encode(entry.name);
    final int crc = _crc32(entry.data);
    final int size = entry.data.length;
    _writeU32(out, 0x04034b50);
    _writeU16(out, 20);
    _writeU16(out, 0x0800);
    _writeU16(out, 0);
    _writeU16(out, stamp.$1);
    _writeU16(out, stamp.$2);
    _writeU32(out, crc);
    _writeU32(out, size);
    _writeU32(out, size);
    _writeU16(out, name.length);
    _writeU16(out, 0);
    out.add(name);
    out.add(entry.data);
    _writeU32(central, 0x02014b50);
    _writeU16(central, 20);
    _writeU16(central, 20);
    _writeU16(central, 0x0800);
    _writeU16(central, 0);
    _writeU16(central, stamp.$1);
    _writeU16(central, stamp.$2);
    _writeU32(central, crc);
    _writeU32(central, size);
    _writeU32(central, size);
    _writeU16(central, name.length);
    _writeU16(central, 0);
    _writeU16(central, 0);
    _writeU16(central, 0);
    _writeU16(central, 0);
    _writeU32(central, 0);
    _writeU32(central, offset);
    central.add(name);
    offset += 30 + name.length + size;
  }
  final Uint8List centralBytes = central.takeBytes();
  final int centralOffset = offset;
  out.add(centralBytes);
  _writeU32(out, 0x06054b50);
  _writeU16(out, 0);
  _writeU16(out, 0);
  _writeU16(out, entries.length);
  _writeU16(out, entries.length);
  _writeU32(out, centralBytes.length);
  _writeU32(out, centralOffset);
  _writeU16(out, 0);
  return out.takeBytes();
}

/// Stored-ZIP reader with CRC verification; throws on any structural flaw.
List<_ZipEntry> _decodeZip(List<int> bytes) {
  final Uint8List raw = Uint8List.fromList(bytes);
  if (raw.length < 22) {
    throw StateError('Ungültiges Export-Archiv');
  }
  final ByteData view = ByteData.sublistView(raw);
  var endOfCentral = -1;
  final int scanStart = raw.length - 22;
  for (var i = scanStart; i >= 0 && i >= raw.length - 65557; i--) {
    if (view.getUint32(i, Endian.little) == 0x06054b50) {
      endOfCentral = i;
      break;
    }
  }
  if (endOfCentral < 0) {
    throw StateError('Ungültiges Export-Archiv');
  }
  final int count = view.getUint16(endOfCentral + 10, Endian.little);
  final int centralSize = view.getUint32(endOfCentral + 12, Endian.little);
  final int centralOffset = view.getUint32(endOfCentral + 16, Endian.little);
  if (centralOffset + centralSize > raw.length) {
    throw StateError('Ungültiges Export-Archiv');
  }
  final List<_ZipEntry> entries = <_ZipEntry>[];
  var offset = centralOffset;
  for (var index = 0; index < count; index++) {
    if (view.getUint32(offset, Endian.little) != 0x02014b50) {
      throw StateError('Ungültiges Export-Archiv');
    }
    final int method = view.getUint16(offset + 10, Endian.little);
    if (method != 0) {
      throw StateError('Komprimierte Einträge werden nicht unterstützt');
    }
    final int crc = view.getUint32(offset + 16, Endian.little);
    final int compressedSize = view.getUint32(offset + 20, Endian.little);
    final int size = view.getUint32(offset + 24, Endian.little);
    if (compressedSize != size) {
      throw StateError('Ungültiges Export-Archiv');
    }
    final int nameLength = view.getUint16(offset + 28, Endian.little);
    final int extraLength = view.getUint16(offset + 30, Endian.little);
    final int commentLength = view.getUint16(offset + 32, Endian.little);
    final int localOffset = view.getUint32(offset + 42, Endian.little);
    final String name = utf8.decode(raw.sublist(offset + 46, offset + 46 + nameLength));
    if (view.getUint32(localOffset, Endian.little) != 0x04034b50) {
      throw StateError('Ungültiges Export-Archiv');
    }
    final int localNameLength = view.getUint16(localOffset + 26, Endian.little);
    final int localExtraLength = view.getUint16(localOffset + 28, Endian.little);
    final int dataStart = localOffset + 30 + localNameLength + localExtraLength;
    final List<int> data = raw.sublist(dataStart, dataStart + size);
    if (_crc32(data) != crc) {
      throw StateError('Integritätsprüfung fehlgeschlagen');
    }
    entries.add(_ZipEntry(name: name, data: data));
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}
