import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';

import 'pdf_test_helpers.dart';

void main() {
  test('selected document type renders only its own Einleitungstext and Schlusstext', () async {
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(einleitungstext: 'RECHNUNG INTRO', schlusstext: 'RECHNUNG CLOSING'),
      angebot: PdfTypeTextSnapshot(einleitungstext: 'ANGEBOT INTRO', schlusstext: 'ANGEBOT CLOSING'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(parsedPdf.visibleText, allOf(contains('RECHNUNG INTRO'), contains('RECHNUNG CLOSING')));
    expect(parsedPdf.visibleText, allOf(isNot(contains('ANGEBOT INTRO')), isNot(contains('ANGEBOT CLOSING'))));
  });

  test('null Rechnung Schlusstext is omitted without falling back to Angebot', () async {
    const texts = PdfDocumentTextsSnapshot(angebot: PdfTypeTextSnapshot(schlusstext: 'ANGEBOT FALLBACK CLOSING'));
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(
      parsedPdf.visibleText,
      allOf(isNot(contains('RECHNUNG CLOSING')), isNot(contains('ANGEBOT FALLBACK CLOSING'))),
    );
  });

  test('empty Rechnung Schlusstext is omitted without falling back to Angebot', () async {
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(schlusstext: ''),
      angebot: PdfTypeTextSnapshot(schlusstext: 'ANGEBOT FALLBACK CLOSING'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(
      parsedPdf.visibleText,
      allOf(isNot(contains('RECHNUNG CLOSING')), isNot(contains('ANGEBOT FALLBACK CLOSING'))),
    );
  });

  test('whitespace-only Rechnung Schlusstext is omitted without falling back to Angebot', () async {
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(schlusstext: ' \n\t '),
      angebot: PdfTypeTextSnapshot(schlusstext: 'ANGEBOT FALLBACK CLOSING'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(
      parsedPdf.visibleText,
      allOf(isNot(contains('RECHNUNG CLOSING')), isNot(contains('ANGEBOT FALLBACK CLOSING'))),
    );
  });

  test('PDF renders bold and italic text without Markdown delimiters', () async {
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(einleitungstext: '**bold text** and *italic text*'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(
      parsedPdf.visibleText,
      allOf(contains('bold text'), contains('italic text'), isNot(contains('**')), isNot(contains('*'))),
    );
  });

  test('PDF renders Einleitungstext before positions and Schlusstext after totals', () async {
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(einleitungstext: 'ORDERED INTRO', schlusstext: 'ORDERED CLOSING'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );
    final visibleText = parsedPdf.visibleText;
    final introIndex = visibleText.indexOf('ORDERED INTRO');
    final positionIndex = visibleText.indexOf('Website-Design');
    final closingIndex = visibleText.indexOf('ORDERED CLOSING');
    final totalsIndex = visibleText.indexOf('Gesamtbetrag');

    expect(introIndex, greaterThanOrEqualTo(0));
    expect(positionIndex, greaterThanOrEqualTo(0));
    expect(closingIndex, greaterThanOrEqualTo(0));
    expect(totalsIndex, greaterThanOrEqualTo(0));
    expect(introIndex, lessThan(positionIndex));
    expect(closingIndex, greaterThan(totalsIndex));
  });
}

PdfDocumentSnapshot _snapshotWithTexts({
  required PdfDocumentType documentType,
  required PdfDocumentTextsSnapshot texts,
}) {
  final base = rechnungSnapshot();
  return PdfDocumentSnapshot.from(
    documentType: documentType,
    template: base.template,
    documentNumber: base.documentNumber,
    documentDate: base.documentDate,
    company: base.company,
    customer: base.customer,
    positions: base.positions,
    totals: base.totals,
    texts: texts,
  );
}
