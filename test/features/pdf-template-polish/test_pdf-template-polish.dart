// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';

import '../pdf/pdf_test_helpers.dart';

void main() {
  group('Payment block', () {
    test('test_happy: Rechnung PDF contains payment information', () async {
      final snapshot = PdfDocumentSnapshot.from(
        documentType: PdfDocumentType.rechnung,
        template: PdfTemplate.standard,
        documentNumber: 'RE-2026-002',
        documentDate: DateTime(2026, 9),
        company: const PdfCompanySnapshot(
          name: 'Muster Studio',
          street: 'Musterstraße 1',
          postalCode: '10115',
          city: 'Berlin',
          iban: 'DE89 3704 0044 0532 0130 00',
          bic: 'COBADEFFXXX',
        ),
        customer: const PdfCustomerSnapshot(
          name: 'Beispiel GmbH',
          street: 'Kundenweg 2',
          postalCode: '20095',
          city: 'Hamburg',
        ),
        positions: const <PdfPositionSnapshot>[
          PdfPositionSnapshot(
            description: 'Website-Design',
            quantity: 2,
            unitPrice: 500,
            netAmount: 1000,
            taxRate: 19,
            taxAmount: 190,
            grossAmount: 1190,
          ),
        ],
        totals: const PdfTotalsSnapshot(netAmount: 1000, taxAmount: 190, grossAmount: 1190),
        paymentBlock: const PdfPaymentBlockSnapshot(
          iban: 'DE89 3704 0044 0532 0130 00',
          bic: 'COBADEFFXXX',
          bankName: 'Commerzbank',
          paymentTerms: 'Zahlbar innerhalb von 14 Tagen ohne Abzug.',
        ),
      );

      final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(snapshot));

      expect(parsedPdf.visibleText, contains('Zahlungsdaten'));
      expect(parsedPdf.visibleText, contains('DE89 3704 0044 0532 0130 00'));
      expect(parsedPdf.visibleText, contains('COBADEFFXXX'));
      expect(parsedPdf.visibleText, contains('Commerzbank'));
      expect(parsedPdf.visibleText, contains('Zahlbar innerhalb von 14 Tagen ohne Abzug.'));
    });

    test('test_failure: Rechnung PDF without payment block omits payment section', () async {
      final snapshot = rechnungSnapshot();

      final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(snapshot));

      expect(parsedPdf.visibleText, isNot(contains('Zahlungsdaten')));
      expect(parsedPdf.visibleText, isNot(contains('IBAN')));
    });
  });

  group('Mahnung document type', () {
    test('test_happy: Mahnung PDF renders correct title and fields', () async {
      final snapshot = PdfDocumentSnapshot.from(
        documentType: PdfDocumentType.mahnung,
        template: PdfTemplate.standard,
        documentNumber: 'MA-2026-001',
        documentDate: DateTime(2026, 9, 5),
        company: const PdfCompanySnapshot(
          name: 'Muster Studio',
          street: 'Musterstraße 1',
          postalCode: '10115',
          city: 'Berlin',
        ),
        customer: const PdfCustomerSnapshot(
          name: 'Beispiel GmbH',
          street: 'Kundenweg 2',
          postalCode: '20095',
          city: 'Hamburg',
        ),
        positions: const <PdfPositionSnapshot>[
          PdfPositionSnapshot(
            description: 'Website-Design',
            quantity: 1,
            unitPrice: 1190,
            netAmount: 1000,
            taxRate: 19,
            taxAmount: 190,
            grossAmount: 1190,
          ),
        ],
        totals: const PdfTotalsSnapshot(netAmount: 1000, taxAmount: 190, grossAmount: 1190),
        mahnung: PdfMahnungSnapshot(
          originalInvoiceNumber: 'RE-2026-001',
          originalInvoiceDate: DateTime(2026, 8),
          dueDate: DateTime(2026, 8, 15),
          dunningLevel: 1,
        ),
      );

      final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(snapshot));

      expect(parsedPdf.visibleText, contains('Mahnung'));
      expect(parsedPdf.visibleText, contains('MA-2026-001'));
      expect(parsedPdf.visibleText, contains('RE-2026-001'));
      expect(parsedPdf.visibleText, contains('1. Mahnung'));
    });

    test('test_failure: Mahnung PDF without required fields shows validation error', () {
      expect(
        () => PdfDocumentSnapshot.from(
          documentType: PdfDocumentType.mahnung,
          template: PdfTemplate.standard,
          documentNumber: 'MA-2026-002',
          company: const PdfCompanySnapshot(name: 'Studio'),
          customer: const PdfCustomerSnapshot(name: 'Customer'),
          positions: const <PdfPositionSnapshot>[],
          totals: const PdfTotalsSnapshot(netAmount: 0, taxAmount: 0, grossAmount: 0),
        ),
        throwsArgumentError,
      );
    });
  });
}
