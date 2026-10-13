import 'dart:io';
import 'dart:typed_data';

import 'package:openaccounting/features/documents/artifact_transaction.dart';

/// Finalized document artifact writer.
///
/// Every operation that transitions a document to finalized SHALL persist a
/// readable profile-local artifact rendered from its own finalized snapshot. This
/// includes invoices, document-only types, corrections, replacements, and conversions.
/// A draft result remains editable and never claims a finalized artifact
/// path. Bytes come from the caller (rendered via the existing PDF service
/// from an immutable snapshot); this writer owns temp → verify → rename and
/// reports failures without leaving false finalizations.
class CorrectionArtifactWriter {
  const CorrectionArtifactWriter({this.transaction = const ArtifactTransaction()});

  final ArtifactTransaction transaction;

  /// Commits [pdfBytes] for [documentId] below [documentsDir].
  ///
  /// Returns the final file. Throws when bytes are empty or the write fails;
  /// callers must roll back numbering, relationships, and side effects.
  Future<File> commitFinalizedArtifact({
    required Directory documentsDir,
    required int documentId,
    required Uint8List pdfBytes,
  }) async {
    if (pdfBytes.isEmpty) {
      throw StateError('Korrektur-PDF konnte nicht erzeugt werden');
    }
    return transaction.writeArtifact(directory: documentsDir, baseName: '$documentId.pdf', bytes: pdfBytes);
  }
}
