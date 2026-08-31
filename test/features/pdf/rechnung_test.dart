import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';

import 'pdf_test_helpers.dart';

void main() {
  test('Rechnung PDF contains PDF signature', () async {
    final pdfBytes = await const PdfGenerator().generate(rechnungSnapshot());

    expect(latin1.decode(pdfBytes.sublist(0, 5)), '%PDF-');
  });

  test('Rechnung PDF contains company header', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(
      parsedPdf.visibleText,
      allOf(contains('Muster Studio'), contains('Musterstraße 1'), contains('10115 Berlin')),
    );
  });

  test('Rechnung PDF contains Rechnung label and number', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(parsedPdf.visibleText, allOf(contains('Rechnung'), contains('RE-2026-001')));
  });

  test('Rechnung PDF contains position content', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(parsedPdf.visibleText, allOf(contains('Website-Design'), contains('2,00')));
  });

  test('Rechnung PDF contains German-formatted total', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(parsedPdf.visibleText, contains('1.190,00 €'));
  });
}
