import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';

import 'pdf_test_helpers.dart';

void main() {
  test('Angebot PDF contains label, document number, validity date, and no Leistungszeitraum line', () async {
    final snapshot = _snapshotFor(
      documentType: PdfDocumentType.angebot,
      documentNumber: 'ANG-2026-001',
      validUntil: DateTime(2026, 9, 15),
      serviceFrom: DateTime(2026, 9),
      serviceTo: DateTime(2026, 9, 30),
    );
    final parsedPdf = parsePdf(await const PdfGenerator().generate(snapshot));

    expect(_containsExactLabel(parsedPdf.visibleText, 'Angebot'), isTrue);
    expect(parsedPdf.visibleText, allOf(contains('ANG-2026-001'), contains('Gültig bis'), contains('15.09.2026')));
    expect(parsedPdf.visibleText, isNot(contains('Leistungszeitraum')));
  });

  test('Angebot PDF omits optional gueltig_bis and Leistungszeitraum lines when absent', () async {
    final snapshot = _snapshotFor(documentType: PdfDocumentType.angebot, documentNumber: 'ANG-2026-002');
    final parsedPdf = parsePdf(await const PdfGenerator().generate(snapshot));

    expect(parsedPdf.visibleText, allOf(isNot(contains('Gültig bis')), isNot(contains('Leistungszeitraum'))));
  });

  const documentLabels = <PdfDocumentType, String>{
    PdfDocumentType.rechnung: 'Rechnung',
    PdfDocumentType.storno: 'Stornorechnung',
    PdfDocumentType.gutschrift: 'Gutschrift',
    PdfDocumentType.angebot: 'Angebot',
    PdfDocumentType.auftrag: 'Auftrag',
    PdfDocumentType.proforma: 'Proforma-Rechnung',
    PdfDocumentType.lieferschein: 'Lieferschein',
  };

  for (final entry in documentLabels.entries) {
    test('${entry.value} PDF renders its exact document label', () async {
      final parsedPdf = parsePdf(
        await const PdfGenerator().generate(
          _snapshotFor(documentType: entry.key, documentNumber: '${entry.key.name}-2026-001'),
        ),
      );

      expect(_containsExactLabel(parsedPdf.visibleText, entry.value), isTrue);
    });
  }

  test('unsupported raw document type is rejected at the existing enum boundary', () {
    expect(() => PdfDocumentType.values.byName('Gutschein'), throwsArgumentError);
    expect(() => PdfDocumentType.fromRaw('Gutschein'), throwsArgumentError);
  });

  test('unknown raw template falls back to Standard', () {
    expect(PdfTemplate.fromRaw('neon'), PdfTemplate.standard);
  });

  test('Standard PDF retains USt columns', () async {
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotFor(documentType: PdfDocumentType.rechnung)),
    );

    expect(parsedPdf.visibleText, allOf(contains('19,00 %'), contains('190,00 €')));
    expect(_containsExactLabel(parsedPdf.visibleText, 'USt-Satz'), isTrue);
    expect(_containsExactLabel(parsedPdf.visibleText, 'USt'), isTrue);
  });

  test('Grün PDF omits USt columns and shows the Kleinunternehmer notice', () async {
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(
        _snapshotFor(documentType: PdfDocumentType.rechnung, template: PdfTemplate.gruen),
      ),
    );

    expect(parsedPdf.visibleText, contains('Gemäß §19 UStG wird keine Umsatzsteuer berechnet'));
    expect(_containsExactLabel(parsedPdf.visibleText, 'USt-Satz'), isFalse);
    expect(_containsExactLabel(parsedPdf.visibleText, 'USt'), isFalse);
  });

  test('Auftrag PDF contains its status metadata', () async {
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(
        _snapshotFor(documentType: PdfDocumentType.auftrag, orderStatus: 'in_bearbeitung'),
      ),
    );

    expect(parsedPdf.visibleText, allOf(contains('Auftragsstatus'), contains('in_bearbeitung')));
  });

  test('Lieferschein PDF renders description and quantity columns only', () async {
    final parsedPdf = parsePdf(
      await const PdfGenerator().generate(_snapshotFor(documentType: PdfDocumentType.lieferschein)),
    );

    expect(parsedPdf.visibleText, allOf(contains('Pos.'), contains('Beschreibung'), contains('Menge')));
    expect(
      parsedPdf.visibleText,
      allOf(
        isNot(contains('Einzelpreis')),
        isNot(contains('Rabatt')),
        isNot(contains('Netto')),
        isNot(contains('USt-Satz')),
      ),
    );
    expect(
      parsedPdf.visibleText,
      allOf(
        isNot(contains('USt')),
        isNot(contains('Brutto')),
        isNot(contains('Gesamtbetrag')),
        isNot(contains('1.000,00 €')),
      ),
    );
  });
}

PdfDocumentSnapshot _snapshotFor({
  required PdfDocumentType documentType,
  PdfTemplate template = PdfTemplate.standard,
  String documentNumber = 'DOC-2026-001',
  DateTime? validUntil,
  DateTime? serviceFrom,
  DateTime? serviceTo,
  String? orderStatus,
}) {
  final base = rechnungSnapshot();
  return PdfDocumentSnapshot.from(
    documentType: documentType,
    template: template,
    documentNumber: documentNumber,
    documentDate: base.documentDate,
    company: base.company,
    customer: base.customer,
    positions: base.positions,
    totals: base.totals,
    serviceFrom: serviceFrom,
    serviceTo: serviceTo,
    validUntil: validUntil,
    orderStatus: orderStatus,
  );
}

bool _containsExactLabel(String visibleText, String label) =>
    RegExp(r'(?:^|\s)' + RegExp.escape(label) + r'(?:\s|$)').hasMatch(visibleText);
