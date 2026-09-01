import 'dart:convert';

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
    final baseline = parsePdf(
      await const PdfGenerator().generate(
        _snapshotWithTexts(
          documentType: PdfDocumentType.rechnung,
          texts: const PdfDocumentTextsSnapshot(rechnung: PdfTypeTextSnapshot(schlusstext: 'RECHNUNG CLOSING')),
        ),
      ),
    );
    const texts = PdfDocumentTextsSnapshot(angebot: PdfTypeTextSnapshot(schlusstext: 'ANGEBOT FALLBACK CLOSING'));
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(baseline.visibleText, contains('RECHNUNG CLOSING'));
    expect(
      parsedPdf.visibleText,
      allOf(isNot(contains('RECHNUNG CLOSING')), isNot(contains('ANGEBOT FALLBACK CLOSING'))),
    );
  });

  test('empty Rechnung Schlusstext is omitted without falling back to Angebot', () async {
    final baseline = parsePdf(
      await const PdfGenerator().generate(
        _snapshotWithTexts(
          documentType: PdfDocumentType.rechnung,
          texts: const PdfDocumentTextsSnapshot(rechnung: PdfTypeTextSnapshot(schlusstext: 'RECHNUNG CLOSING')),
        ),
      ),
    );
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(schlusstext: ''),
      angebot: PdfTypeTextSnapshot(schlusstext: 'ANGEBOT FALLBACK CLOSING'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(baseline.visibleText, contains('RECHNUNG CLOSING'));
    expect(
      parsedPdf.visibleText,
      allOf(isNot(contains('RECHNUNG CLOSING')), isNot(contains('ANGEBOT FALLBACK CLOSING'))),
    );
  });

  test('whitespace-only Rechnung Schlusstext is omitted without falling back to Angebot', () async {
    final baseline = parsePdf(
      await const PdfGenerator().generate(
        _snapshotWithTexts(
          documentType: PdfDocumentType.rechnung,
          texts: const PdfDocumentTextsSnapshot(rechnung: PdfTypeTextSnapshot(schlusstext: 'RECHNUNG CLOSING')),
        ),
      ),
    );
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(schlusstext: ' \n\t '),
      angebot: PdfTypeTextSnapshot(schlusstext: 'ANGEBOT FALLBACK CLOSING'),
    );
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts)),
    );

    expect(baseline.visibleText, contains('RECHNUNG CLOSING'));
    expect(
      parsedPdf.visibleText,
      allOf(isNot(contains('RECHNUNG CLOSING')), isNot(contains('ANGEBOT FALLBACK CLOSING'))),
    );
  });

  test('PDF renders bold and italic text without Markdown delimiters or losing styles', () async {
    const texts = PdfDocumentTextsSnapshot(
      rechnung: PdfTypeTextSnapshot(einleitungstext: '**BOLD_STYLE** and *ITALIC_STYLE*'),
    );
    final pdfBytes = await const PdfGenerator().generate(
      _snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts),
    );
    final parsedPdf = parsePdf(pdfBytes);
    final pdfSource = latin1.decode(pdfBytes);
    final boldFontName = _fontUsedForText(pdfSource, 'BOLD_STYLE');
    final italicFontName = _fontUsedForText(pdfSource, 'ITALIC_STYLE');

    expect(
      parsedPdf.visibleText,
      allOf(contains('BOLD_STYLE'), contains('ITALIC_STYLE'), isNot(contains('**')), isNot(contains('*'))),
    );
    expect(boldFontName, isNotNull);
    expect(italicFontName, isNotNull);
    expect(pdfSource, matches(RegExp('/BaseFont/Helvetica-Bold[^\n]*/Name/$boldFontName/')));
    expect(pdfSource, matches(RegExp('/BaseFont/Helvetica-Oblique[^\n]*/Name/$italicFontName/')));
  });

  test('malformed, escaped, nested, and unsupported Markdown stays visible and preserves snapshot', () async {
    const intro =
        r'**outer *inner* outer** | *unmatched | \*escaped italic\* | \**escaped bold** | __unsupported__ | ~~strike~~';
    const texts = PdfDocumentTextsSnapshot(rechnung: PdfTypeTextSnapshot(einleitungstext: intro));
    final snapshot = _snapshotWithTexts(documentType: PdfDocumentType.rechnung, texts: texts);
    final parsedPdf = parsePdf(await const PdfGenerator().generate(snapshot));

    expect(
      parsedPdf.visibleText,
      allOf(
        contains(r'**outer *inner* outer**'),
        contains('*unmatched'),
        contains(r'\*escaped italic\*'),
        contains(r'\**escaped bold**'),
        contains('__unsupported__'),
        contains('~~strike~~'),
      ),
    );
    expect(snapshot.texts, same(texts));
    expect(snapshot.texts.rechnung.einleitungstext, intro);
  });

  test('Einleitungstext follows address and metadata before positions', () async {
    const texts = PdfDocumentTextsSnapshot(angebot: PdfTypeTextSnapshot(einleitungstext: 'ORDERED INTRO'));
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(
        _snapshotWithTexts(documentType: PdfDocumentType.angebot, texts: texts, validUntil: DateTime(2026, 9, 15)),
      ),
    );
    final visibleText = parsedPdf.visibleText;
    final addressIndex = visibleText.indexOf('20095 Hamburg');
    final metadataIndex = visibleText.indexOf('Gültig bis');
    final introIndex = visibleText.indexOf('ORDERED INTRO');
    final positionIndex = visibleText.indexOf('Website-Design');

    expect(addressIndex, greaterThanOrEqualTo(0));
    expect(metadataIndex, greaterThanOrEqualTo(0));
    expect(introIndex, greaterThanOrEqualTo(0));
    expect(positionIndex, greaterThanOrEqualTo(0));
    expect(addressIndex, lessThan(introIndex));
    expect(metadataIndex, lessThan(introIndex));
    expect(introIndex, lessThan(positionIndex));
  });

  test('Lieferschein Schlusstext follows positions when totals are absent', () async {
    const texts = PdfDocumentTextsSnapshot(lieferschein: PdfTypeTextSnapshot(schlusstext: 'DELIVERY CLOSING'));
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotWithTexts(documentType: PdfDocumentType.lieferschein, texts: texts)),
    );
    final visibleText = parsedPdf.visibleText;
    final positionIndex = visibleText.indexOf('Website-Design');
    final closingIndex = visibleText.indexOf('DELIVERY CLOSING');

    expect(positionIndex, greaterThanOrEqualTo(0));
    expect(closingIndex, greaterThan(positionIndex));
    expect(visibleText, isNot(contains('Gesamtbetrag')));
  });
}

PdfDocumentSnapshot _snapshotWithTexts({
  required PdfDocumentType documentType,
  required PdfDocumentTextsSnapshot texts,
  DateTime? validUntil,
  String? orderStatus,
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
    validUntil: validUntil,
    orderStatus: orderStatus,
  );
}

String? _fontUsedForText(String pdfSource, String text) {
  final textOperand = '[($text)]TJ';
  for (final operation in pdfSource.split('BT ')) {
    if (operation.contains(textOperand)) {
      return RegExp(r'/(F\d+) 12 Tf').firstMatch(operation)?.group(1);
    }
  }
  return null;
}
