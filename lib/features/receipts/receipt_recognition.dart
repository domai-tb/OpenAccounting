import 'dart:typed_data';

/// Advisory receipt recognition: suggestions linked to the original source.
///
/// Recognized fields are suggestions with provenance; explicit user review is
/// required before values enter an assignment or posting flow. Recognition
/// never modifies the original source bytes. Failures leave the original
/// available and offer manual review. Provider choice, confidence policy, and
/// data-processing rules remain open decisions.
class ReceiptRecognition {
  const ReceiptRecognition();

  /// Applies accepted suggestions to a review form map. The source artifact
  /// is never modified; only the form copy receives values.
  static Map<String, Object?> applyAccepted({
    required Map<String, Object?> form,
    required Map<String, Object?> suggestions,
    required Set<String> acceptedFields,
    required Uint8List sourceBytesBefore,
    required Uint8List sourceBytesAfter,
  }) {
    if (!_identicalBytes(sourceBytesBefore, sourceBytesAfter)) {
      throw StateError('Quelldatei wurde verändert — Übernahme abgebrochen');
    }
    final Map<String, Object?> next = Map<String, Object?>.from(form);
    for (final String field in acceptedFields) {
      if (suggestions.containsKey(field)) next[field] = suggestions[field];
    }
    return next;
  }

  /// Manual-review fallback when recognition is unavailable or fails.
  static Map<String, Object?> manualFallback({required String reason}) {
    return <String, Object?>{'modus': 'manuell', 'hinweis': reason, 'vorschlaege': <String, Object?>{}};
  }

  static bool _identicalBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Provenance of one recognized suggestion.
class RecognitionSuggestion {
  const RecognitionSuggestion({required this.field, required this.value, required this.source, this.confidence});

  final String field;
  final Object? value;

  /// Where the value came from (e.g. `ocr`, `xrechnung`, `manuell`).
  final String source;
  final double? confidence;

  Map<String, Object?> toJson() => <String, Object?>{'field': field, 'value': value, 'source': source};
}
