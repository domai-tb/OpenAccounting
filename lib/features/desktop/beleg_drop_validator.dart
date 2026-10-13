import 'dart:typed_data';

import 'package:openaccounting/features/documents/beleg_source_validator.dart';

/// Destination-specific drag-and-drop validation for Belege.
///
/// Generic import types (PDF, CSV, JPG, PNG, TIFF) remain supported when a
/// destination explicitly accepts them. The Belege drop zone accepts only
/// verified PDF, PNG, JPEG, and supported XRechnung / ZUGFeRD-Factur-X XML
/// sources up to 50 MiB, and rejects CSV and TIFF even though another
/// destination may accept those types.
class BelegDropValidator {
  const BelegDropValidator({this.validator = const BelegSourceValidator()});

  final BelegSourceValidator validator;

  /// Validates a dropped file for the Belege zone. Returns null when the
  /// file may be stored, otherwise a German rejection message.
  String? validateForBelege({required Uint8List bytes, required String filename}) {
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.csv') || lower.endsWith('.tiff') || lower.endsWith('.tif')) {
      return 'Dateityp nicht unterstützt';
    }
    try {
      validator.validate(bytes, filename: filename);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  /// Generic drop-zone check: supported generic types are PDF, CSV, JPG,
  /// PNG, TIFF. Returns null when acceptable.
  static String? validateGeneric({required String filename}) {
    final String lower = filename.toLowerCase();
    const List<String> supported = <String>['.pdf', '.csv', '.jpg', '.jpeg', '.png', '.tiff', '.tif'];
    if (supported.any(lower.endsWith)) return null;
    return 'Nicht unterstütztes Dateiformat';
  }
}
