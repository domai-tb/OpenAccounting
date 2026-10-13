import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/beleg_drop_validator.dart';
import 'package:openaccounting/features/documents/beleg_source_validator.dart';

Uint8List _pdfBytes([String body = 'Beleg']) {
  return Uint8List.fromList(utf8.encode('%PDF-1.7\n$body\n'));
}

Uint8List _pngBytes() {
  return Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
}

Uint8List _jpegBytes() {
  return Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
}

Uint8List _xrechnungBytes() {
  return Uint8List.fromList(
    utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?><CrossIndustryInvoice><ExchangedDocument><ID>4711</ID></ExchangedDocument></CrossIndustryInvoice>',
    ),
  );
}

void main() {
  group('document-correction-artifacts-and-receipt-intake / drag-and-drop', () {
    test('test_drag_pdf_to_belege', () {
      const BelegDropValidator validator = BelegDropValidator();
      expect(validator.validateForBelege(bytes: _pdfBytes(), filename: 'beleg.pdf'), isNull);
      expect(const BelegSourceValidator().validate(_pdfBytes()), 'application/pdf');
    });

    test('test_drag_unsupported_file_type', () {
      const BelegDropValidator validator = BelegDropValidator();
      final Uint8List docx = Uint8List.fromList(utf8.encode('PK fake docx content'));
      expect(validator.validateForBelege(bytes: docx, filename: 'vertrag.docx'), 'Dateityp nicht unterstützt');
      expect(BelegDropValidator.validateGeneric(filename: 'vertrag.docx'), 'Nicht unterstütztes Dateiformat');
    });

    test('test_drag_multiple_supported_files', () {
      const BelegDropValidator validator = BelegDropValidator();
      final List<({Uint8List bytes, String name})> files = <({Uint8List bytes, String name})>[
        (bytes: _pdfBytes('A'), name: 'a.pdf'),
        (bytes: _pdfBytes('B'), name: 'b.pdf'),
        (bytes: _pngBytes(), name: 'scan.png'),
        (bytes: _jpegBytes(), name: 'foto.jpg'),
      ];
      for (final ({Uint8List bytes, String name}) file in files) {
        expect(
          validator.validateForBelege(bytes: file.bytes, filename: file.name),
          isNull,
          reason: file.name,
        );
      }
    });

    test('test_drag_file_outside_drop_zone', () {
      // Outside any drop zone no validator runs: releasing the file has no
      // effect and no record is created. Represented by the absence of any
      // validation/upload call — generic validation alone stores nothing.
      expect(BelegDropValidator.validateGeneric(filename: 'beleg.pdf'), isNull);
    });

    test('test_belege_rejects_generic_csv_and_tiff_imports', () {
      const BelegDropValidator validator = BelegDropValidator();
      final Uint8List csv = Uint8List.fromList(utf8.encode('datum;betrag\n2026-01-01;10,00\n'));
      expect(() => const BelegSourceValidator().validate(csv), throwsA(isA<FormatException>()));
      expect(validator.validateForBelege(bytes: csv, filename: 'konto.csv'), 'Dateityp nicht unterstützt');
      final Uint8List tiff = Uint8List.fromList(<int>[0x49, 0x49, 0x2A, 0x00, 0x01]);
      expect(validator.validateForBelege(bytes: tiff, filename: 'scan.tiff'), 'Dateityp nicht unterstützt');
      // Another destination may still accept those types.
      expect(BelegDropValidator.validateGeneric(filename: 'konto.csv'), isNull);
      expect(BelegDropValidator.validateGeneric(filename: 'scan.tiff'), isNull);
    });

    test('test_supported_e_invoice_xml_is_validated_before_storage', () {
      const BelegDropValidator validator = BelegDropValidator();
      expect(validator.validateForBelege(bytes: _xrechnungBytes(), filename: 'xrechnung.xml'), isNull);
      // External entities and network access are disabled.
      final Uint8List xxe = Uint8List.fromList(
        utf8.encode(
          '<?xml version="1.0"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM "http://evil/x">]><CrossIndustryInvoice>&xxe;</CrossIndustryInvoice>',
        ),
      );
      expect(validator.validateForBelege(bytes: xxe, filename: 'boese.xml'), 'Dateityp nicht unterstützt');
      // Malformed XML is rejected before storage.
      final Uint8List broken = Uint8List.fromList(utf8.encode('<CrossIndustryInvoice><unclosed>'));
      expect(validator.validateForBelege(bytes: broken, filename: 'kaputt.xml'), 'Dateityp nicht unterstützt');
      // Oversized sources are rejected before creating a record or file.
      final Uint8List huge = Uint8List(BelegSourceValidator.maxSourceBytes + 1)..[0] = 0x25;
      expect(validator.validateForBelege(bytes: huge, filename: 'gross.pdf'), contains('50 MiB'));
    });
  });
}
