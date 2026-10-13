import 'dart:io';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:path/path.dart' as p;

// Artifact references, never filesystem paths: callers nominate typed IDs,
// the resolver verifies document ownership and canonical profile-root
// containment. Cross-document IDs and escaping symlinks are rejected without
// reading any bytes.

class DocumentArtifactRef {
  const DocumentArtifactRef({required this.dokumentId, this.bezugDokumentId});

  /// Main generated artifact of [dokumentId], or a related existing artifact
  /// when [bezugDokumentId] is set.
  final int dokumentId;
  final int? bezugDokumentId;

  bool get istHaupt => bezugDokumentId == null;
}

class ResolvedArtifact {
  const ResolvedArtifact({required this.ref, required this.pfad, required this.dateiname});

  final DocumentArtifactRef ref;
  final String pfad;
  final String dateiname;
}

class DocumentArtifactResolver {
  DocumentArtifactResolver(this.executor, {this.profileDir});

  final QueryExecutor executor;
  final String? profileDir;

  /// Related documents share the conversion/correction family of the source
  /// document; only those may contribute explicitly selected attachments.
  Future<Set<int>> relatedDocumentIds(int dokumentId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, konvertiert_von, konvertiert_zu, gutschrift_von, storno_von, ersatz_fuer, ersatzrechnung_id '
      'FROM rechnungen',
      const <Object?>[],
    );
    final Map<int, Map<String, Object?>> byId = <int, Map<String, Object?>>{
      for (final Map<String, Object?> row in rows) (row['id']! as num).toInt(): row,
    };
    if (!byId.containsKey(dokumentId)) {
      throw const DocumentDeliveryException('Dokument nicht gefunden', code: 'dokument_fehlt');
    }
    final Set<int> family = <int>{dokumentId};
    bool grown = true;
    while (grown) {
      grown = false;
      for (final MapEntry<int, Map<String, Object?>> entry in byId.entries) {
        if (family.contains(entry.key)) continue;
        final Iterable<int> links = <String>[
          'konvertiert_von',
          'konvertiert_zu',
          'gutschrift_von',
          'storno_von',
          'ersatz_fuer',
          'ersatzrechnung_id',
        ].map((String column) => _asInt(entry.value[column])).whereType<int>();
        if (links.any(family.contains)) {
          family.add(entry.key);
          grown = true;
        }
        final Map<String, Object?> self = byId[dokumentId]!;
        final Iterable<int> selfLinks = <String>[
          'konvertiert_von',
          'konvertiert_zu',
          'gutschrift_von',
          'storno_von',
          'ersatz_fuer',
          'ersatzrechnung_id',
        ].map((String column) => _asInt(self[column])).whereType<int>();
        if (selfLinks.contains(entry.key)) {
          family.add(entry.key);
          grown = true;
        }
      }
    }
    return family;
  }

  Future<ResolvedArtifact> resolve(DocumentArtifactRef ref) async {
    final int targetId = ref.bezugDokumentId ?? ref.dokumentId;
    if (ref.bezugDokumentId != null) {
      final Set<int> family = await relatedDocumentIds(ref.dokumentId);
      if (!family.contains(targetId)) {
        throw const DocumentDeliveryException('Anhang gehört zu einem anderen Dokument', code: 'artefakt_fremd');
      }
    }
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT original_pdf_pfad FROM rechnungen WHERE id = ?',
      <Object?>[targetId],
    );
    if (rows.isEmpty) {
      throw const DocumentDeliveryException('Dokument nicht gefunden', code: 'dokument_fehlt');
    }
    final String? relative = rows.single['original_pdf_pfad'] as String?;
    if (relative == null || relative.trim().isEmpty) {
      throw const DocumentDeliveryException('Kein erzeugtes PDF für dieses Dokument', code: 'artefakt_fehlt');
    }
    return _contain(relative, ref);
  }

  /// Only the selected document's generated artifact plus explicitly listed
  /// related refs are allowed; arbitrary paths cannot be expressed.
  Future<List<ResolvedArtifact>> resolveAll(int dokumentId, List<DocumentArtifactRef> refs) async {
    final List<ResolvedArtifact> resolved = <ResolvedArtifact>[];
    for (final DocumentArtifactRef ref in refs) {
      if (ref.dokumentId != dokumentId) {
        throw const DocumentDeliveryException('Anhang gehört zu einem anderen Dokument', code: 'artefakt_fremd');
      }
      resolved.add(await resolve(ref));
    }
    return resolved;
  }

  Future<ResolvedArtifact> _contain(String relative, DocumentArtifactRef ref) async {
    final String? root = profileDir;
    if (root == null || root.trim().isEmpty) {
      throw const DocumentDeliveryException('Profilspeicher nicht konfiguriert', code: 'profil_fehlt');
    }
    final String basePath = p.normalize(p.absolute(root));
    final String candidate = p.normalize(p.join(basePath, relative));
    if (!p.isWithin(basePath, candidate) && candidate != basePath) {
      throw const DocumentDeliveryException('Anhang außerhalb des Profils', code: 'artefakt_ausserhalb');
    }
    final File file = File(candidate);
    final FileSystemEntityType kind = FileSystemEntity.typeSync(candidate, followLinks: false);
    if (kind == FileSystemEntityType.link) {
      throw const DocumentDeliveryException('Anhang ist ein Verweis außerhalb der Prüfung', code: 'artefakt_symlink');
    }
    if (kind != FileSystemEntityType.file) {
      throw const DocumentDeliveryException('Anhang nicht gefunden', code: 'artefakt_fehlt');
    }
    try {
      final String resolved = await file.resolveSymbolicLinks();
      if (!p.isWithin(basePath, p.normalize(p.absolute(resolved)))) {
        throw const DocumentDeliveryException('Anhang verweist außerhalb des Profils', code: 'artefakt_symlink');
      }
    } catch (error) {
      if (error is DocumentDeliveryException) rethrow;
      throw const DocumentDeliveryException('Anhang nicht prüfbar', code: 'artefakt_fehlt');
    }
    final List<int> bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const DocumentDeliveryException('Anhang ist leer', code: 'artefakt_fehlt');
    }
    return ResolvedArtifact(ref: ref, pfad: candidate, dateiname: p.basename(candidate));
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}
