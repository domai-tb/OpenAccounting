import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';

import 'pdf_test_helpers.dart';

void main() {
  test('copy shows KOPIE watermark', () async {
    final base = rechnungSnapshot();
    final snapshot = PdfDocumentSnapshot.from(
      documentType: base.documentType,
      template: base.template,
      documentNumber: base.documentNumber,
      documentDate: base.documentDate,
      company: base.company,
      customer: base.customer,
      positions: base.positions,
      totals: base.totals,
      copyState: PdfCopyState.copy,
    );
    final pdfBytes = await const PdfGenerator().generate(snapshot);
    final parsed = parsePdf(pdfBytes);

    expect(parsed.visibleText, contains('KOPIE'));
  });

  test('original shows no KOPIE watermark', () async {
    final base = rechnungSnapshot();
    final snapshot = PdfDocumentSnapshot.from(
      documentType: base.documentType,
      template: base.template,
      documentNumber: base.documentNumber,
      documentDate: base.documentDate,
      company: base.company,
      customer: base.customer,
      positions: base.positions,
      totals: base.totals,
    );
    final pdfBytes = await const PdfGenerator().generate(snapshot);
    final parsed = parsePdf(pdfBytes);

    expect(parsed.visibleText, isNot(contains('KOPIE')));
  });

  test('KOPIE watermark is rendered diagonal', () async {
    final base = rechnungSnapshot();
    final snapshot = PdfDocumentSnapshot.from(
      documentType: base.documentType,
      template: base.template,
      documentNumber: base.documentNumber,
      documentDate: base.documentDate,
      company: base.company,
      customer: base.customer,
      positions: base.positions,
      totals: base.totals,
      copyState: PdfCopyState.copy,
    );
    final pdfBytes = await const PdfGenerator().generate(snapshot);
    final parsed = parsePdf(pdfBytes);
    final source = String.fromCharCodes(pdfBytes);

    expect(parsed.visibleText, contains('KOPIE'));
    // diagonal => rotation matrix via cm or Watermark transform
    expect(source, contains('KOPIE'));
    expect(parsed.pageOperators, contains('cm'));
  });
}
