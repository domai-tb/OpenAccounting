// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_tax_classification.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_xml.dart';

import 'e_invoice_test_fixtures.dart'
    show
        eInvoiceTestService,
        fakePdfBytes,
        standardPositions,
        standardTotals,
        validCompany,
        validCustomer,
        validSnapshot;

void main() {
  group('ZUGFeRD and XRechnung e-invoicing', () {
    test('generates_hybrid_pdf_with_validated_zugferd_metadata', () {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(format: EInvoiceOutputFormat.zugferd);

      final EInvoiceValidationResult validation = service.validate(snapshot, EInvoiceOutputFormat.zugferd);
      expect(validation.valid, isTrue);
      final ZugferdHybridArtifact hybrid = service.hybridFromPdf(snapshot: snapshot, pdfBytes: fakePdfBytes);

      expect(hybrid.pdfBytes, fakePdfBytes);
      expect(hybrid.documentNumber, 'RE-2026-0001');
      expect(hybrid.ciiXml.contains('CrossIndustryInvoice'), isTrue);
      expect(hybrid.ciiXml.contains('urn:cen.eu:en16931:2017'), isTrue);
      expect(hybrid.ciiXml.contains('<ram:GrandTotalAmount>238.00</ram:GrandTotalAmount>'), isTrue);
      expect(service.readiness(validation), EInvoiceReadiness.valid);
    });

    test('generates_standalone_xrechnung_ubl_without_mutating_invoice', () {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(
        buyerReference: 'LEITWEG-123',
        format: EInvoiceOutputFormat.xrechnung,
      );
      final int netBefore = snapshot.netCents;

      final String xml = service.xrechnungXml(snapshot);

      expect(xml.contains('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"'), isTrue);
      expect(xml.contains('xrechnung_3.0'), isTrue);
      expect(xml.contains('PDF'), isFalse);
      expect(xml.contains('<cbc:BuyerReference>LEITWEG-123</cbc:BuyerReference>'), isTrue);
      expect(xml.contains('<cbc:PayableAmount currencyID="EUR">238.00</cbc:PayableAmount>'), isTrue);
      // Serialization never mutates the snapshot.
      expect(snapshot.netCents, netBefore);
      expect(snapshot.lines.single.netCents, 20000);
    });

    test('rejects_invalid_invoice_with_localized_rule_diagnostic_and_no_output', () {
      const EInvoiceService service = eInvoiceTestService;
      final Map<String, Object?> customer = validCustomer()..remove('strasse');
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.zugferd,
        issueDate: '2026-03-15',
        companyRow: validCompany(),
        customerRow: customer,
        posRows: standardPositions(),
        preview: standardTotals(),
        eingabemodus: 'netto',
      );

      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.zugferd);

      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('buyer.street'));
      final EInvoiceDiagnostic diagnostic = result.diagnostics.firstWhere((entry) => entry.ruleId == 'buyer.street');
      expect(diagnostic.messageFor('de'), contains('buyer.street'));
      expect(diagnostic.messageFor('en_US'), isNotEmpty);
      expect(diagnostic.route, 'rechnungen');
      expect(() => service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
    });

    test('serializes_approved_typed_tax_category_and_exemption_reason', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123');

      expect(snapshot.lines.single.classification.category.code, 'S');

      final String cii = serializer.zugferdCii(snapshot);
      expect(cii.contains('<ram:CategoryCode>S</ram:CategoryCode>'), isTrue);
      expect(cii.contains('<ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>'), isTrue);
      final String ubl = serializer.xrechnungUbl(snapshot);
      expect(ubl.contains('<cbc:ID>S</cbc:ID>'), isTrue);
      expect(ubl.contains('<cbc:Percent>19.00</cbc:Percent>'), isTrue);
    });

    test('serializes_exempt_tax_category_with_statutory_reason', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      const FinalizationSnapshot exempt = FinalizationSnapshot(
        documentNumber: 'RE-2026-0002',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        currency: 'EUR',
        seller: EInvoicePartySnapshot(
          name: 'Muster GmbH',
          street: 'Musterstraße 1',
          postalCode: '10115',
          city: 'Berlin',
          country: 'DE',
          taxNumber: '13/123/12345',
        ),
        buyer: EInvoicePartySnapshot(
          name: 'Kunde GmbH',
          street: 'Kundenweg 5',
          postalCode: '20095',
          city: 'Hamburg',
          country: 'DE',
        ),
        lines: <EInvoiceLineSnapshot>[
          EInvoiceLineSnapshot(
            position: 0,
            description: 'Beratung',
            quantityText: '1',
            unitPriceText: '100.0000',
            unitPriceIsGross: false,
            netCents: 10000,
            taxCents: 0,
            grossCents: 10000,
            taxRateHundredths: 0,
            classification: EInvoiceLineClassification(
              category: EInvoiceTaxCategory.exempt,
              exemptionReason: 'Steuerfrei nach § 19 UStG',
            ),
          ),
        ],
        netCents: 10000,
        taxCents: 0,
        grossCents: 10000,
        buyerReference: 'LEITWEG-123',
      );

      final String cii = serializer.zugferdCii(exempt);
      expect(cii.contains('<ram:CategoryCode>E</ram:CategoryCode>'), isTrue);
      expect(cii.contains('<ram:ExemptionReason>Steuerfrei nach § 19 UStG</ram:ExemptionReason>'), isTrue);
      final String ubl = serializer.xrechnungUbl(exempt);
      expect(ubl.contains('<cbc:ID>E</cbc:ID>'), isTrue);
      expect(ubl.contains('<cbc:TaxExemptionReason>Steuerfrei nach § 19 UStG</cbc:TaxExemptionReason>'), isTrue);
    });

    test('seller_endpoint_uses_vat_id_with_9930', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123');

      expect(snapshot.seller.endpointId, 'DE123456789');
      expect(snapshot.seller.endpointScheme, '9930');
      final String ubl = serializer.xrechnungUbl(snapshot);
      expect(ubl.contains('<cbc:EndpointID schemeID="9930">DE123456789</cbc:EndpointID>'), isTrue);
    });

    test('endpoint_fallback_without_invention', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final Map<String, Object?> customer = validCustomer()..['email'] = 'kunde@example.de';
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: validCompany(),
        customerRow: customer,
        posRows: standardPositions(),
        preview: standardTotals(),
        eingabemodus: 'netto',
        buyerReference: 'LEITWEG-123',
      );

      expect(snapshot.buyer.endpointId, 'kunde@example.de');
      expect(snapshot.buyer.endpointScheme, 'EM');
      expect(
        serializer.xrechnungUbl(snapshot).contains('<cbc:EndpointID schemeID="EM">kunde@example.de</cbc:EndpointID>'),
        isTrue,
      );

      const EInvoiceService service = eInvoiceTestService;
      final Map<String, Object?> noIdCompany = validCompany()..remove('ust_idnr');
      final FinalizationSnapshot noSellerEndpoint = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: noIdCompany,
        customerRow: validCustomer(),
        posRows: standardPositions(),
        preview: standardTotals(),
        eingabemodus: 'netto',
        buyerReference: 'LEITWEG-123',
      );
      final EInvoiceValidationResult result = service.validate(noSellerEndpoint, EInvoiceOutputFormat.xrechnung);
      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('seller.endpoint'));
    });

    test('missing_payment_data_fails_closed', () {
      const EInvoiceService service = eInvoiceTestService;
      final Map<String, Object?> company = validCompany()..remove('iban');
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: company,
        customerRow: validCustomer(),
        posRows: standardPositions(),
        preview: standardTotals(),
        eingabemodus: 'netto',
        buyerReference: 'LEITWEG-123',
      );

      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.xrechnung);
      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('seller.payment'));
      expect(() => service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
    });

    test('emits_payment_means_with_company_iban', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123');

      final String ubl = serializer.xrechnungUbl(snapshot);
      expect(ubl.contains('<cbc:PaymentMeansCode>58</cbc:PaymentMeansCode>'), isTrue);
      expect(ubl.contains('<cbc:ID>DE89370400440532013000</cbc:ID>'), isTrue);
    });

    test('delivery_date_emitted_verbatim', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final FinalizationSnapshot base = validSnapshot(buyerReference: 'LEITWEG-123');

      final FinalizationSnapshot snapshot = FinalizationSnapshot(
        documentNumber: base.documentNumber,
        outputFormat: base.outputFormat,
        issueDate: base.issueDate,
        currency: base.currency,
        seller: base.seller,
        buyer: base.buyer,
        lines: base.lines,
        netCents: base.netCents,
        taxCents: base.taxCents,
        grossCents: base.grossCents,
        buyerReference: base.buyerReference,
        deliveryDate: '2026-03-10',
      );

      expect(
        serializer.xrechnungUbl(snapshot).contains('<cbc:ActualDeliveryDate>2026-03-10</cbc:ActualDeliveryDate>'),
        isTrue,
      );
    });

    test('missing_delivery_date_fails_closed', () {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123', deliveryDate: null);

      expect(snapshot.deliveryDate, isNull);
      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.xrechnung);
      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('invoice.deliveryDate'));
      expect(() => service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
    });

    test('xrechnung_delivery_date_follows_ubl_21_sequence', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final FinalizationSnapshot snapshot = validSnapshot(
        buyerReference: 'LEITWEG-123',
        format: EInvoiceOutputFormat.xrechnung,
      );

      final String xml = serializer.xrechnungUbl(snapshot);
      final int supplierIndex = xml.indexOf('<cac:AccountingSupplierParty>');
      final int customerIndex = xml.indexOf('<cac:AccountingCustomerParty>');
      final int deliveryIndex = xml.indexOf('<cac:Delivery>');
      final int deliveryDateIndex = xml.indexOf('<cbc:ActualDeliveryDate>2026-03-10</cbc:ActualDeliveryDate>');
      final int deliveryEndIndex = xml.indexOf('</cac:Delivery>');
      final int paymentIndex = xml.indexOf('<cac:PaymentMeans>');

      expect(customerIndex, greaterThan(supplierIndex));
      expect(deliveryIndex, greaterThan(customerIndex));
      expect(deliveryDateIndex, greaterThan(deliveryIndex));
      expect(deliveryEndIndex, greaterThan(deliveryDateIndex));
      expect(paymentIndex, greaterThan(deliveryEndIndex));
    });

    test('zugferd_cii_type_code_precedes_issue_date', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final String xml = serializer.zugferdCii(validSnapshot(format: EInvoiceOutputFormat.zugferd));
      final int documentStart = xml.indexOf('<rsm:ExchangedDocument>');
      final int documentEnd = xml.indexOf('</rsm:ExchangedDocument>');
      final String document = xml.substring(documentStart, documentEnd);
      final int idIndex = document.indexOf('<ram:ID>');
      final int typeCodeIndex = document.indexOf('<ram:TypeCode>380</ram:TypeCode>');
      final int issueDateIndex = document.indexOf('<ram:IssueDateTime>');

      expect(idIndex, greaterThanOrEqualTo(0));
      expect(typeCodeIndex, greaterThan(idIndex));
      expect(issueDateIndex, greaterThan(typeCodeIndex));
    });

    test('zugferd_cii_address_precedes_tax_registration', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final String xml = serializer.zugferdCii(validSnapshot(format: EInvoiceOutputFormat.zugferd));
      final int sellerStart = xml.indexOf('<ram:SellerTradeParty>');
      final int sellerEnd = xml.indexOf('</ram:SellerTradeParty>');
      final String seller = xml.substring(sellerStart, sellerEnd);

      final int addressIndex = seller.indexOf('<ram:PostalTradeAddress>');
      final int registrationIndex = seller.indexOf('<ram:SpecifiedTaxRegistration>');

      expect(addressIndex, greaterThanOrEqualTo(0));
      expect(registrationIndex, greaterThan(addressIndex));
    });

    test('zugferd_cii_calculated_amount_precedes_tax_details', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final String xml = serializer.zugferdCii(validSnapshot(format: EInvoiceOutputFormat.zugferd));
      final int settlementStart = xml.indexOf('<ram:ApplicableHeaderTradeSettlement>');
      final int settlementEnd = xml.indexOf('</ram:ApplicableHeaderTradeSettlement>');
      final String settlement = xml.substring(settlementStart, settlementEnd);
      final int taxStart = settlement.indexOf('<ram:ApplicableTradeTax>');
      final int taxEnd = settlement.indexOf('</ram:ApplicableTradeTax>');
      final String tax = settlement.substring(taxStart, taxEnd);

      final int calculatedAmountIndex = tax.indexOf('<ram:CalculatedAmount>');
      final int taxTypeIndex = tax.indexOf('<ram:TypeCode>VAT</ram:TypeCode>');

      expect(calculatedAmountIndex, greaterThanOrEqualTo(0));
      expect(taxTypeIndex, greaterThan(calculatedAmountIndex));
    });

    test('zugferd_cii_uses_en16931_profile_id', () {
      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final String xml = serializer.zugferdCii(validSnapshot(format: EInvoiceOutputFormat.zugferd));

      expect(xml, contains('<ram:ID>urn:cen.eu:en16931:2017</ram:ID>'));
    });

    test('unresolved_tax_mapping_fails_without_inference_or_output', () {
      final List<Map<String, Object?>> positions = <Map<String, Object?>>[
        <String, Object?>{
          'bezeichnung': 'Auslandsleistung',
          'menge': 1,
          'einzelpreis': 100,
          'gesamt': 100,
          'ust_satz': 0,
          'rabatt_prozent': 0,
          'position': 0,
        },
      ];

      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.zugferd,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: positions,
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
        ),
        throwsA(predicate((error) => error is EInvoiceSourceException && error.code == 'unresolvedTaxClassification')),
      );
    });
  });
}
