import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:openaccounting/features/documents/beleg_source_validator.dart';

/// Outcome of a Beleg deletion-guard check.
class BelegDeletionGuard {
  const BelegDeletionGuard({required this.canDelete, this.blocker = ''});

  final bool canDelete;

  /// German explanation naming the blocking relationship.
  final String blocker;
}

/// Beleg persistence behind the use-case boundary.
///
/// Stores originals below the active profile root, preserves source bytes,
/// and enforces the deletion rule: explicit deletion only when the Beleg has
/// no invoice, journal, template, package, customer, or supplier
/// relationship. Customer links use the canonical `kunden_belege` join table
/// (a Beleg has no `kunde_id` column); deletion checks query it. Removing a
/// package or contact membership never deletes the underlying evidence.
/// `loeschdatum` is informational until a retention policy is accepted and
/// never triggers automatic purging.
class BelegRepository {
  BelegRepository(this.executor, {this.profileDir, this.validator = const BelegSourceValidator()});

  final QueryExecutor executor;
  final String? profileDir;
  final BelegSourceValidator validator;

  /// Adds Beleg metadata columns idempotently (additive, no version bump).
  /// Migrations.currentVersion (16) is the baseline; this uses the same
  /// `_addColumnIfMissing` pattern as AppDatabase.ensureOpen.
  Future<void> ensureSchema() async {
    const Map<String, String> columns = <String, String>{
      'dateiname': 'TEXT',
      'original_name': 'TEXT',
      'mime_type': 'TEXT',
      'dateigroesse': 'INTEGER DEFAULT 0',
      'sha256': 'TEXT',
      'hochgeladen_am': 'TEXT',
      'beleg_pdfa_pfad': 'TEXT',
      'loeschdatum': 'TEXT',
    };
    for (final MapEntry<String, String> entry in columns.entries) {
      final List<Map<String, Object?>> existing = await executor.runSelect(
        'PRAGMA table_info(belege)',
        const <Object?>[],
      );
      if (existing.any((Map<String, Object?> row) => row['name'] == entry.key)) continue;
      await executor.runCustom('ALTER TABLE belege ADD COLUMN ${entry.key} ${entry.value}');
    }
    // Package membership on documents (additive; preserves existing links).
    for (final MapEntry<String, String> entry in <String, String>{
      'dokumentenpaket_id': 'INTEGER REFERENCES dokumentenpakete(id)',
      'beleg_id': 'INTEGER REFERENCES belege(id)',
    }.entries) {
      final List<Map<String, Object?>> existing = await executor.runSelect(
        'PRAGMA table_info(rechnungen)',
        const <Object?>[],
      );
      if (existing.any((Map<String, Object?> row) => row['name'] == entry.key)) continue;
      await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN ${entry.key} ${entry.value}');
    }
  }

  /// Imports a source file: validates content, stores bytes atomically, then
  /// commits the Beleg row referencing the final path. Failures leave no
  /// partial record or file behind.
  Future<int> importSource({
    required Uint8List bytes,
    required String filename,
    String? datum,
    String? beschreibung,
  }) async {
    await ensureSchema();
    final String mimeType = validator.validate(bytes, filename: filename);
    final String digest = sha256.convert(bytes).toString();
    final Directory dir = _sourceDir();
    dir.createSync(recursive: true);
    final String safeName = filename.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final String finalName = '${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final File staging = File('${dir.path}/$finalName.tmp');
    final File target = File('${dir.path}/$finalName');
    try {
      staging.writeAsBytesSync(bytes, flush: true);
      if (staging.readAsBytesSync().isEmpty && bytes.isNotEmpty) {
        throw FileSystemException('Quelle ist nicht lesbar', staging.path);
      }
      staging.renameSync(target.path);
      final String now = DateTime.now().toIso8601String();
      final int id = await executor.runInsert(
        'INSERT INTO belege (datum, betrag, status, beschreibung, dateipfad, dateiname, original_name, mime_type, dateigroesse, sha256, hochgeladen_am) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          datum ?? now.substring(0, 10),
          '0',
          'neu',
          beschreibung ?? filename,
          target.path,
          finalName,
          filename,
          mimeType,
          bytes.length,
          digest,
          now,
        ],
      );
      return id;
    } catch (_) {
      try {
        if (staging.existsSync()) staging.deleteSync();
      } catch (_) {}
      // Crash-after-rename-but-before-commit leaves an unreferenced
      // importer-owned file; recovery removes it (see reconcileImports).
      rethrow;
    }
  }

  /// Removes importer-owned files without a committed Beleg row. Unrelated
  /// files are preserved.
  Future<int> reconcileImports() async {
    final Directory dir = _sourceDir();
    if (!dir.existsSync()) return 0;
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT dateipfad FROM belege WHERE dateipfad IS NOT NULL',
      const <Object?>[],
    );
    final Set<String> referenced = <String>{for (final Map<String, Object?> row in rows) row['dateipfad'].toString()};
    var removed = 0;
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) continue;
      final String name = entity.path.split(Platform.pathSeparator).last;
      if (name.endsWith('.tmp') || !referenced.contains(entity.path)) {
        // Only remove importer-owned names (timestamped) — never unknown files.
        if (RegExp(r'^\d+_').hasMatch(name) || name.endsWith('.tmp')) {
          try {
            await entity.delete();
            removed++;
          } catch (_) {}
        }
      }
    }
    return removed;
  }

  /// Attaches an existing Beleg to an invoice via `rechnungen.beleg_id`.
  Future<void> attachToInvoice({required int belegId, required int rechnungId}) async {
    await ensureSchema();
    final List<Map<String, Object?>> belege = await executor.runSelect('SELECT id FROM belege WHERE id = ?', <Object?>[
      belegId,
    ]);
    if (belege.isEmpty) throw StateError('Beleg nicht gefunden');
    final List<Map<String, Object?>> invoices = await executor.runSelect(
      'SELECT id FROM rechnungen WHERE id = ?',
      <Object?>[rechnungId],
    );
    if (invoices.isEmpty) throw StateError('Rechnung nicht gefunden');
    await executor.runUpdate('UPDATE rechnungen SET beleg_id = ? WHERE id = ?', <Object?>[belegId, rechnungId]);
  }

  /// Checks whether a Beleg may be deleted. Queries the canonical
  /// `kunden_belege` join table plus invoice, journal, template, package,
  /// and supplier relationships.
  Future<BelegDeletionGuard> deletionGuard(int belegId) async {
    final List<({String sql, String label})> checks = <({String sql, String label})>[
      (sql: 'SELECT id FROM rechnungen WHERE beleg_id = ? LIMIT 1', label: 'Rechnung'),
      (sql: 'SELECT id FROM journal WHERE beleg_id = ? LIMIT 1', label: 'Journalbuchung'),
      (sql: 'SELECT id FROM rechnungsvorlagen WHERE beleg_id = ? LIMIT 1', label: 'Vorlage'),
      (sql: 'SELECT id FROM dokumentenpaket_belege WHERE beleg_id = ? LIMIT 1', label: 'Dokumentenpaket'),
      (sql: 'SELECT id FROM kunden_belege WHERE beleg_id = ? LIMIT 1', label: 'Kunde'),
    ];
    for (final ({String sql, String label}) check in checks) {
      List<Map<String, Object?>> rows;
      try {
        rows = await executor.runSelect(check.sql, <Object?>[belegId]);
      } catch (_) {
        continue; // Column/table absent on legacy schema — treated as no link.
      }
      if (rows.isNotEmpty) {
        return BelegDeletionGuard(
          canDelete: false,
          blocker: 'Beleg ist mit ${check.label} verknüpft — bitte zuerst entknüpfen',
        );
      }
    }
    // Supplier links live on belege.lieferant_id.
    try {
      final List<Map<String, Object?>> suppliers = await executor.runSelect(
        'SELECT id FROM belege WHERE id = ? AND lieferant_id IS NOT NULL',
        <Object?>[belegId],
      );
      if (suppliers.isNotEmpty) {
        return const BelegDeletionGuard(
          canDelete: false,
          blocker: 'Beleg ist mit Lieferant verknüpft — bitte zuerst entknüpfen',
        );
      }
    } catch (_) {}
    return const BelegDeletionGuard(canDelete: true);
  }

  /// Deletes a Beleg only after every relationship was explicitly unlinked.
  /// Removes metadata and stored source bytes.
  Future<void> deleteBeleg(int belegId) async {
    final BelegDeletionGuard guard = await deletionGuard(belegId);
    if (!guard.canDelete) throw StateError(guard.blocker);
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT dateipfad FROM belege WHERE id = ?',
      <Object?>[belegId],
    );
    final String? path = rows.isEmpty ? null : rows.single['dateipfad']?.toString();
    await executor.runDelete('DELETE FROM belege WHERE id = ?', <Object?>[belegId]);
    if (path != null && path.isNotEmpty) {
      try {
        final File file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
  }

  /// `loeschdatum` status: informational only, never auto-purges.
  /// Returns 'overdue' (red), 'due_soon' (yellow, ≤ 30 days), or 'none'.
  static String loeschdatumStatus(String? loeschdatum, {DateTime? today}) {
    if (loeschdatum == null || loeschdatum.isEmpty) return 'none';
    final DateTime? due = DateTime.tryParse(loeschdatum);
    if (due == null) return 'none';
    final DateTime now = today ?? DateTime.now();
    final DateTime dueDay = DateTime(due.year, due.month, due.day);
    final DateTime todayDay = DateTime(now.year, now.month, now.day);
    if (todayDay.isAfter(dueDay)) return 'overdue';
    if (dueDay.difference(todayDay).inDays <= 30) return 'due_soon';
    return 'none';
  }

  Directory _sourceDir() {
    final String base = profileDir ?? Directory.systemTemp.path;
    return Directory('$base/uploads/belege');
  }
}
