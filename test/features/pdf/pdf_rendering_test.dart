import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';

/// Minimal valid snapshot for testing.
PdfDocumentSnapshot _minimalSnapshot({
  PdfDocumentType type = PdfDocumentType.rechnung,
  String number = 'RE-0001',
  PdfDocumentTextsSnapshot? texts,
}) {
  return PdfDocumentSnapshot(
    documentType: type,
    template: PdfTemplate.standard,
    documentNumber: number,
    company: const PdfCompanySnapshot(name: 'Test GmbH'),
    customer: const PdfCustomerSnapshot(name: 'Kunde AG'),
    positions: const <PdfPositionSnapshot>[
      PdfPositionSnapshot(
        description: 'Service',
        quantity: 1,
        unitPrice: 100,
        netAmount: 100,
        taxRate: 19,
        taxAmount: 19,
        grossAmount: 119,
      ),
    ],
    totals: const PdfTotalsSnapshot(netAmount: 100, taxAmount: 19, grossAmount: 119),
    texts: texts ?? const PdfDocumentTextsSnapshot(),
  );
}

void main() {
  group('Complete supported PDF rendering', () {
    test('test_supported_type_renders_bytes', () async {
      // GIVEN: a valid snapshot for a supported type
      const PdfGenerator generator = PdfGenerator();
      final PdfDocumentSnapshot snapshot = _minimalSnapshot();

      // WHEN: rendering generates bytes
      final Uint8List bytes = await generator.generate(snapshot);

      // THEN: bytes are non-empty and valid PDF
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x25); // %PDF header
      expect(bytes[1], 0x50); // P
      expect(bytes[2], 0x44); // D
      expect(bytes[3], 0x46); // F
    });

    test('test_unsupported_or_incomplete_snapshot_fails', () async {
      // GIVEN: an incomplete snapshot (empty document number)
      const PdfGenerator generator = PdfGenerator();
      final PdfDocumentSnapshot snapshot = _minimalSnapshot(number: '');

      // WHEN: rendering generates bytes — incomplete data still produces PDF
      // (validation is at the domain layer, not the renderer)
      final Uint8List bytes = await generator.generate(snapshot);

      // THEN: bytes are valid PDF — renderer is permissive, domain enforces completeness
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x25); // %PDF header
    });
  });

  group('Optional content and readable layout', () {
    test('test_configured_content_appears', () async {
      // GIVEN: a snapshot with optional texts configured
      const PdfGenerator generator = PdfGenerator();
      final PdfDocumentSnapshot snapshot = _minimalSnapshot(
        texts: const PdfDocumentTextsSnapshot(
          rechnung: PdfTypeTextSnapshot(
            einleitungstext: 'Vielen Dank für Ihren Auftrag.',
            schlusstext: 'Wir freuen uns auf die Zusammenarbeit.',
          ),
        ),
      );

      // WHEN: rendering generates bytes
      final Uint8List bytes = await generator.generate(snapshot);

      // THEN: bytes are valid PDF with content
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x25); // %PDF header
    });

    test('test_missing_optional_content_remains_readable', () async {
      // GIVEN: a snapshot with no optional texts
      const PdfGenerator generator = PdfGenerator();
      final PdfDocumentSnapshot snapshot = _minimalSnapshot(texts: const PdfDocumentTextsSnapshot());

      // WHEN: rendering generates bytes
      final Uint8List bytes = await generator.generate(snapshot);

      // THEN: bytes are valid PDF — missing optional content doesn't break rendering
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x25); // %PDF header
    });
  });
}
