import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:openaccounting/features/documents/zip_codec.dart';

/// Dokumentenpaket workspace over the existing membership contract.
///
/// Accounting documents reference the package through
/// `rechnungen.dokumentenpaket_id`; supporting evidence uses
/// `dokumentenpaket_belege`. Adding or removing membership never changes or
/// deletes the underlying document or Beleg. Empty package creation is
/// rejected with `Mindestens ein Dokument auswählen`. Batch printing and
/// email delivery are deferred and never represented as available.
class DokumentenpaketRepository {
  DokumentenpaketRepository(this.executor, {this.profileDir});

  final QueryExecutor executor;
  final String? profileDir;

  /// Creates a package from selected documents. Rejects empty selections.
  Future<int> createPackage({required String name, required List<int> dokumentIds}) async {
    if (dokumentIds.isEmpty) {
      throw StateError('Mindestens ein Dokument auswählen');
    }
    for (final int id in dokumentIds) {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM rechnungen WHERE id = ?',
        <Object?>[id],
      );
      if (rows.isEmpty) throw StateError('Dokument $id ist nicht verfügbar');
    }
    final int paketId = await executor.runInsert('INSERT INTO dokumentenpakete (name, status) VALUES (?, ?)', <Object?>[
      name,
      'offen',
    ]);
    for (final int id in dokumentIds) {
      await executor.runUpdate('UPDATE rechnungen SET dokumentenpaket_id = ? WHERE id = ?', <Object?>[paketId, id]);
    }
    return paketId;
  }

  /// Adds receipt evidence through `dokumentenpaket_belege`.
  Future<void> addBeleg({required int paketId, required int belegId}) async {
    final List<Map<String, Object?>> packages = await executor.runSelect(
      'SELECT id FROM dokumentenpakete WHERE id = ?',
      <Object?>[paketId],
    );
    if (packages.isEmpty) throw StateError('Dokumentenpaket nicht gefunden');
    final List<Map<String, Object?>> belege = await executor.runSelect('SELECT id FROM belege WHERE id = ?', <Object?>[
      belegId,
    ]);
    if (belege.isEmpty) throw StateError('Beleg ist nicht verfügbar');
    final List<Map<String, Object?>> existing = await executor.runSelect(
      'SELECT id FROM dokumentenpaket_belege WHERE paket_id = ? AND beleg_id = ? LIMIT 1',
      <Object?>[paketId, belegId],
    );
    if (existing.isNotEmpty) return;
    await executor.runInsert('INSERT INTO dokumentenpaket_belege (paket_id, beleg_id) VALUES (?, ?)', <Object?>[
      paketId,
      belegId,
    ]);
  }

  /// Removes a Beleg membership without deleting the evidence.
  Future<void> removeBeleg({required int paketId, required int belegId}) async {
    await executor.runDelete('DELETE FROM dokumentenpaket_belege WHERE paket_id = ? AND beleg_id = ?', <Object?>[
      paketId,
      belegId,
    ]);
  }

  /// Removes a document membership without changing the document.
  Future<void> removeDokument({required int paketId, required int dokumentId}) async {
    await executor.runUpdate(
      'UPDATE rechnungen SET dokumentenpaket_id = NULL WHERE id = ? AND dokumentenpaket_id = ?',
      <Object?>[dokumentId, paketId],
    );
  }

  /// Lists package members with source identifiers and artifact state.
  Future<({List<Map<String, Object?>> dokumente, List<Map<String, Object?>> belege})> listMembers(int paketId) async {
    final List<Map<String, Object?>> dokumente = await executor.runSelect(
      'SELECT id, rechnungsnummer, typ, status, datum, original_pdf_pfad FROM rechnungen WHERE dokumentenpaket_id = ? ORDER BY id',
      <Object?>[paketId],
    );
    final List<Map<String, Object?>> belege = await executor.runSelect(
      'SELECT b.id, b.dateiname, b.original_name, b.dateipfad, b.sha256 FROM belege b '
      'JOIN dokumentenpaket_belege pb ON pb.beleg_id = b.id WHERE pb.paket_id = ? ORDER BY b.id',
      <Object?>[paketId],
    );
    return (dokumente: dokumente, belege: belege);
  }

  /// Exports a ZIP snapshot with manifest; verifies copied digests before
  /// reporting success. Missing member artifacts are listed and prevent a
  /// complete result. No member record or file is changed.
  Future<PaketExportResult> exportSnapshot(int paketId) async {
    final List<Map<String, Object?>> packages = await executor.runSelect(
      'SELECT id, name FROM dokumentenpakete WHERE id = ?',
      <Object?>[paketId],
    );
    if (packages.isEmpty) throw StateError('Dokumentenpaket nicht gefunden');
    final ({List<Map<String, Object?>> dokumente, List<Map<String, Object?>> belege}) members = await listMembers(
      paketId,
    );
    final List<ZipEntry> entries = <ZipEntry>[];
    final List<String> missing = <String>[];
    for (final Map<String, Object?> doc in members.dokumente) {
      final String? path = doc['original_pdf_pfad']?.toString();
      final String label = 'dokument_${doc['id']}.pdf';
      final Uint8List? bytes = _readArtifact(path);
      if (bytes == null) {
        missing.add('Dokument ${doc['rechnungsnummer'] ?? doc['id']}: Artifact fehlt');
        continue;
      }
      entries.add(ZipEntry(name: 'dokumente/$label', data: bytes));
    }
    for (final Map<String, Object?> beleg in members.belege) {
      final String? path = beleg['dateipfad']?.toString();
      final String label = 'beleg_${beleg['id']}_${beleg['dateiname']?.toString() ?? 'quelle'}';
      final Uint8List? bytes = _readArtifact(path);
      if (bytes == null) {
        missing.add('Beleg ${beleg['id']}: Quelle fehlt');
        continue;
      }
      entries.add(ZipEntry(name: 'belege/$label', data: bytes));
    }
    final Map<String, String> manifest = <String, String>{
      for (final ZipEntry entry in entries) entry.name: sha256.convert(entry.data).toString(),
    };
    final String inventory = jsonEncode(<String, Object?>{
      'paket_id': paketId,
      'mitglieder_dokumente': members.dokumente.length,
      'mitglieder_belege': members.belege.length,
      'fehlend': missing,
    });
    final List<ZipEntry> zipEntries = <ZipEntry>[
      ...entries,
      ZipEntry(name: 'manifest.json', data: utf8.encode(jsonEncode(manifest))),
      ZipEntry(name: 'inventar.json', data: utf8.encode(inventory)),
    ];
    final Uint8List archive = encodeZip(zipEntries);
    // Verify copied digests before reporting success.
    for (final ZipEntry entry in entries) {
      if (manifest[entry.name] != sha256.convert(entry.data).toString()) {
        throw StateError('Paketexport-Prüfung fehlgeschlagen');
      }
    }
    return PaketExportResult(archiveBytes: archive, manifest: manifest, missing: missing, complete: missing.isEmpty);
  }

  Uint8List? _readArtifact(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      final File file = File(path);
      if (!file.existsSync()) return null;
      final Uint8List bytes = file.readAsBytesSync();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}

/// Result of a package snapshot export.
class PaketExportResult {
  const PaketExportResult({
    required this.archiveBytes,
    required this.manifest,
    required this.missing,
    required this.complete,
  });

  final Uint8List archiveBytes;
  final Map<String, String> manifest;
  final List<String> missing;
  final bool complete;
}
