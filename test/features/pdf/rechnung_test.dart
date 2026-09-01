import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';

import 'pdf_test_helpers.dart';

void main() {
  test('PdfCompanySnapshot supports public const construction', () {
    const company = PdfCompanySnapshot(name: 'Const Studio');

    expect(company.name, 'Const Studio');
  });

  test('PdfDocumentSnapshot supports public const construction', () {
    const document = PdfDocumentSnapshot(
      documentType: PdfDocumentType.rechnung,
      template: PdfTemplate.standard,
      documentNumber: 'CONST-001',
      company: PdfCompanySnapshot(name: 'Const Studio'),
      customer: PdfCustomerSnapshot(name: 'Const Customer'),
      positions: <PdfPositionSnapshot>[
        PdfPositionSnapshot(
          description: 'Const position',
          quantity: 1,
          unitPrice: 1,
          netAmount: 1,
          taxRate: 19,
          taxAmount: 0.19,
          grossAmount: 1.19,
        ),
      ],
      totals: PdfTotalsSnapshot(netAmount: 1, taxAmount: 0.19, grossAmount: 1.19),
    );

    expect(document.documentNumber, 'CONST-001');
  });

  test('collection-bearing snapshot construction defensively copies inputs', () {
    const position = PdfPositionSnapshot(
      description: 'Copied position',
      quantity: 1,
      unitPrice: 1,
      netAmount: 1,
      taxRate: 19,
      taxAmount: 0.19,
      grossAmount: 1.19,
    );
    final positions = <PdfPositionSnapshot>[position];
    final document = PdfDocumentSnapshot.from(
      documentType: PdfDocumentType.rechnung,
      template: PdfTemplate.standard,
      documentNumber: 'COPY-001',
      company: const PdfCompanySnapshot(name: 'Copy Studio'),
      customer: const PdfCustomerSnapshot(name: 'Copy Customer'),
      positions: positions,
      totals: const PdfTotalsSnapshot(netAmount: 1, taxAmount: 0.19, grossAmount: 1.19),
    );
    positions.clear();

    final logoBytes = <int>[1];
    final company = PdfCompanySnapshot.from(name: 'Bytes Studio', logoBytes: logoBytes);
    logoBytes[0] = 2;

    expect(document.positions, hasLength(1));
    expect(() => document.positions.add(position), throwsUnsupportedError);
    expect(company.logoBytes, [1]);
    expect(() => company.logoBytes!.add(2), throwsUnsupportedError);
  });

  test('PDF parser handles names before page operators', () {
    final parsedPdf = parseUncompressedPdf(uncompressedPdf(latin1.encode('BT /F1 12 Tf (Hallo) Tj ET')));

    expect(parsedPdf.visibleText, contains('Hallo'));
    expect(parsedPdf.containsOperator('Tf'), isTrue);
  });

  test('PDF parser maps the WinAnsi Euro byte', () {
    final stream = <int>[...latin1.encode('BT /F1 12 Tf (1.190,00 '), 0x80, ...latin1.encode(') Tj ET')];
    final parsedPdf = parseUncompressedPdf(uncompressedPdf(stream));

    expect(parsedPdf.visibleText, contains('1.190,00 €'));
  });

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

  test('Rechnung PDF contains customer address and German date', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(
      parsedPdf.visibleText,
      allOf(contains('Beispiel GmbH'), contains('Kundenweg 2'), contains('20095 Hamburg'), contains('30.08.2026')),
    );
  });

  test('Rechnung PDF contains full Standard monetary columns', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(
      parsedPdf.visibleText,
      allOf(
        contains('Pos.'),
        contains('Beschreibung'),
        contains('Menge'),
        contains('Einzelpreis'),
        contains('Rabatt'),
        contains('Netto'),
      ),
    );
    expect(
      parsedPdf.visibleText,
      allOf(
        contains('USt-Satz'),
        contains('USt'),
        contains('Brutto'),
        contains('1.000,00 €'),
        contains('19,00 %'),
        contains('190,00 €'),
      ),
    );
  });

  test('Rechnung generation leaves snapshot values unchanged', () async {
    final snapshot = rechnungSnapshot();
    final positions = snapshot.positions;

    await const PdfGenerator().generate(snapshot);

    expect(snapshot.positions, same(positions));
    expect(snapshot.documentNumber, 'RE-2026-001');
    expect(snapshot.totals.grossAmount, 1190);
  });

  test('Rechnung PDF contains German-formatted total', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot()));

    expect(parsedPdf.visibleText, allOf(contains('Gesamtbetrag'), contains('1.190,00 €')));
  });
}
