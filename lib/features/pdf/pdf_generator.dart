import 'dart:typed_data';

import 'package:openaccounting/features/pdf/pdf_models.dart';

final class PdfGenerator {
  const PdfGenerator();

  Future<Uint8List> generate(PdfDocumentSnapshot _) {
    return Future<Uint8List>.error(UnimplementedError('PDF rendering is not implemented in task 10.1'));
  }
}
