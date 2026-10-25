// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_offline_xml_validator.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_tax_classification.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_xml.dart';

import 'e_invoice_test_fixtures.dart'
    show
        InvalidSchemaEInvoiceXmlSerializer,
        eInvoiceTestService,
        invalidEInvoiceTestOfflineXmlValidation,
        unavailableEInvoiceTestOfflineXmlValidation,
        fakePdfBytes,
        fakePdfBytesWithCii,
        standardPositions,
        standardTotals,
        validCompany,
        construction13b2PositionWithoutResolvedCertificate,
        validCustomer,
        euService13b1PositionWithoutResolvedAssessment,
        validSnapshot;

void _expectSection6aRejected({required String expectedField, String? destinationCountry, String? evidenceSourceRef}) {
  final Map<String, Object?> customer = validCustomer()
    ..['land'] = 'FR'
    ..['ust_idnr'] = 'FR12345678901';
  final Map<String, Object?> position = <String, Object?>{
    'bezeichnung': 'Lieferung nach Frankreich',
    'menge': 1,
    'einzelpreis': 100,
    'ust_satz': 0,
    'tax_treatment': 'intra_community_supply_6a',
    'tax_legal_basis': 'ustg_4_1b_6a',
    'e_invoice_tax_category_code': 'K',
    'e_invoice_exemption_reason_code': 'VATEX-EU-IC',
    'e_invoice_exemption_reason_text': 'Steuerfreie innergemeinschaftliche Lieferung',
    'e_invoice_intra_community_destination_country_iso': destinationCountry,
    'e_invoice_intra_community_supply_evidence_source_ref': evidenceSourceRef,
    'position': 0,
  };
  expect(
    () => const EInvoiceSnapshotBuilder().buildFinalization(
      documentNumber: 'RE-2026-0001',
      outputFormat: EInvoiceOutputFormat.xrechnung,
      issueDate: '2026-03-15',
      companyRow: validCompany(),
      customerRow: customer,
      posRows: <Map<String, Object?>>[position],
      preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
      eingabemodus: 'netto',
      deliveryDate: '2026-03-10',
    ),
    throwsA(
      predicate(
        (Object? error) =>
            error is EInvoiceSourceException &&
            error.code == 'incompleteCrossBorderTaxEvidence' &&
            error.fields.contains(expectedField),
      ),
    ),
  );
}

void _expectSection6Rejected({required String expectedField, String? destinationCountry, String? evidenceSourceRef}) {
  final Map<String, Object?> customer = validCustomer()..['land'] = 'US';
  final Map<String, Object?> position = <String, Object?>{
    'bezeichnung': 'Ausfuhrlieferung',
    'menge': 1,
    'einzelpreis': 100,
    'ust_satz': 0,
    'tax_treatment': 'export_supply_6',
    'tax_legal_basis': 'ustg_4_1a_6',
    'e_invoice_tax_category_code': 'G',
    'e_invoice_exemption_reason_code': 'VATEX-EU-G',
    'e_invoice_exemption_reason_text': null,
    'e_invoice_export_destination_country_iso': destinationCountry,
    'e_invoice_export_evidence_source_ref': evidenceSourceRef,
    'position': 0,
  };
  expect(
    () => const EInvoiceSnapshotBuilder().buildFinalization(
      documentNumber: 'RE-2026-0001',
      outputFormat: EInvoiceOutputFormat.xrechnung,
      issueDate: '2026-03-15',
      companyRow: validCompany(),
      customerRow: customer,
      posRows: <Map<String, Object?>>[position],
      preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
      eingabemodus: 'netto',
      deliveryDate: '2026-03-10',
    ),
    throwsA(
      predicate(
        (Object? error) =>
            error is EInvoiceSourceException &&
            error.code == 'incompleteCrossBorderTaxEvidence' &&
            error.fields.contains(expectedField),
      ),
    ),
  );
}

FinalizationSnapshot _grossInputSnapshot() => const EInvoiceSnapshotBuilder().buildFinalization(
  documentNumber: 'RE-2026-0001',
  outputFormat: EInvoiceOutputFormat.xrechnung,
  issueDate: '2026-03-15',
  companyRow: validCompany(),
  customerRow: validCustomer(),
  posRows: <Map<String, Object?>>[
    <String, Object?>{
      'bezeichnung': 'Beratung',
      'menge': 1,
      'einzelpreis': 119,
      'ust_satz': 19,
      'tax_treatment': 'standard_19',
      'tax_legal_basis': 'ustg_12_1',
      'e_invoice_tax_category_code': 'S',
      'position': 0,
    },
  ],
  preview: const EInvoiceCanonicalTotals(
    netCents: 10000,
    taxCents: 1900,
    grossCents: 11900,
    positionTotals: <EInvoiceCanonicalPositionAmounts>[
      EInvoiceCanonicalPositionAmounts(position: 0, netCents: 10000, taxCents: 1900, grossCents: 11900),
    ],
    disclosureTotals: EInvoiceDisclosureTotals(netCents: 10000, taxCents: 1900, grossCents: 11900),
  ),
  eingabemodus: 'brutto',
);

void main() {
  group('ZUGFeRD and XRechnung e-invoicing', () {
    test('offline_validator_accepts_serialized_ubl_and_cii_before_return', () async {
      final List<EInvoiceOutputFormat> validatedFormats = <EInvoiceOutputFormat>[];
      final EInvoiceService service = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: ({required EInvoiceOutputFormat format, required String xml}) async {
          validatedFormats.add(format);
          if (format == EInvoiceOutputFormat.xrechnung) {
            expect(xml, contains('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"'));
          } else {
            expect(xml, contains('<rsm:CrossIndustryInvoice'));
          }
          return const EInvoiceOfflineXmlValidationResult(
            status: EInvoiceOfflineXmlValidationStatus.valid,
            message: 'The pinned profile accepted this XML.',
          );
        },
      );
      final FinalizationSnapshot zugferdSnapshot = validSnapshot(format: EInvoiceOutputFormat.zugferd);
      final String ubl = await service.xrechnungXml(
        validSnapshot(buyerReference: 'LEITWEG-123', format: EInvoiceOutputFormat.xrechnung),
      );
      final ZugferdHybridArtifact hybrid = await service.hybridFromPdf(
        snapshot: zugferdSnapshot,
        pdfBytes: fakePdfBytesWithCii(const EInvoiceXmlSerializer().zugferdCii(zugferdSnapshot)),
      );

      expect(ubl, contains('<Invoice'));
      expect(hybrid.ciiXml, contains('<rsm:CrossIndustryInvoice'));
      expect(validatedFormats, <EInvoiceOutputFormat>[EInvoiceOutputFormat.xrechnung, EInvoiceOutputFormat.zugferd]);
    });

    test('offline_validator_rejects_schema_invalid_xrechnung_xml', () async {
      final EInvoiceService service = EInvoiceService(
        serializer: const InvalidSchemaEInvoiceXmlSerializer(),
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: invalidEInvoiceTestOfflineXmlValidation,
      );
      final FinalizationSnapshot snapshot = validSnapshot(
        buyerReference: 'LEITWEG-123',
        format: EInvoiceOutputFormat.xrechnung,
      );

      await expectLater(
        Future<String>.sync(() => service.xrechnungXml(snapshot)),
        throwsA(isA<EInvoiceExportValidationException>()),
      );
    });

    test('offline_validator_rejects_schema_invalid_cii_before_hybrid_return', () async {
      final EInvoiceService service = EInvoiceService(
        serializer: const InvalidSchemaEInvoiceXmlSerializer(),
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: invalidEInvoiceTestOfflineXmlValidation,
      );
      final FinalizationSnapshot snapshot = validSnapshot(format: EInvoiceOutputFormat.zugferd);

      await expectLater(
        Future<ZugferdHybridArtifact>.sync(() => service.hybridFromPdf(snapshot: snapshot, pdfBytes: fakePdfBytes)),
        throwsA(isA<EInvoiceExportValidationException>()),
      );
    });

    test('offline_validator_unavailability_blocks_ubl_and_cii_output', () async {
      final EInvoiceService service = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: unavailableEInvoiceTestOfflineXmlValidation,
      );
      EInvoiceExportValidationException? ublError;
      EInvoiceExportValidationException? ciiError;

      try {
        await service.xrechnungXml(
          validSnapshot(buyerReference: 'LEITWEG-123', format: EInvoiceOutputFormat.xrechnung),
        );
      } on EInvoiceExportValidationException catch (error) {
        ublError = error;
      }
      try {
        await service.hybridFromPdf(
          snapshot: validSnapshot(format: EInvoiceOutputFormat.zugferd),
          pdfBytes: fakePdfBytes,
        );
      } on EInvoiceExportValidationException catch (error) {
        ciiError = error;
      }

      void expectUnavailable(EInvoiceExportValidationException? error) {
        expect(error, isNotNull);
        final EInvoiceExportValidationException failure = error!;
        expect(failure.offlineXmlResult?.status, EInvoiceOfflineXmlValidationStatus.unavailable);
        expect(failure.result.status, EInvoiceValidationStatus.unavailable);
        expect(failure.offlineXmlResult?.message, 'The Java runtime is not available.');
        expect(service.readiness(failure.result), EInvoiceReadiness.unavailable);
        final EInvoiceDiagnostic diagnostic = failure.result.diagnostics.single;
        expect(diagnostic.ruleId, 'offlineValidator.unavailable');
        expect(
          diagnostic.messageFor('de'),
          'Die Offline-Prüfung ist nicht verfügbar. Es wurde kein E-Rechnungsartefakt ausgegeben.',
        );
        expect(
          diagnostic.messageFor('en_US'),
          'Offline validation is unavailable. No e-invoice artifact was produced.',
        );
      }

      expectUnavailable(ublError);
      expectUnavailable(ciiError);
    });

    test('offline_validator_invalid_diagnostics_are_localized_and_engine_details_are_retained', () async {
      final EInvoiceService service = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: invalidEInvoiceTestOfflineXmlValidation,
      );
      EInvoiceExportValidationException? failure;

      try {
        await service.xrechnungXml(validSnapshot(buyerReference: 'LEITWEG-123'));
      } on EInvoiceExportValidationException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      final EInvoiceExportValidationException result = failure!;
      expect(result.result.status, EInvoiceValidationStatus.invalid);
      expect(service.readiness(result.result), EInvoiceReadiness.invalid);
      expect(result.offlineXmlResult?.diagnostics.single.message, 'Die XML-Datei verletzt die Schemastruktur.');
      final EInvoiceDiagnostic diagnostic = result.result.diagnostics.single;
      expect(diagnostic.ruleId, 'SCHEMA_INVALID');
      expect(diagnostic.messageFor('de'), 'Die Offline-Prüfung hat das E-Rechnungs-XML abgelehnt.');
      expect(diagnostic.messageFor('en_US'), 'Offline validation rejected the e-invoice XML.');
      expect(diagnostic.messageFor('en_US'), isNot(contains('Die XML-Datei verletzt die Schemastruktur.')));
    });

    test('generates_hybrid_pdf_with_validated_zugferd_metadata', () async {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(format: EInvoiceOutputFormat.zugferd);
      final List<int> pdfBytes = fakePdfBytesWithCii(const EInvoiceXmlSerializer().zugferdCii(snapshot));

      final EInvoiceValidationResult validation = service.validate(snapshot, EInvoiceOutputFormat.zugferd);
      expect(validation.valid, isTrue);
      final ZugferdHybridArtifact hybrid = await service.hybridFromPdf(snapshot: snapshot, pdfBytes: pdfBytes);

      expect(hybrid.pdfBytes, pdfBytes);
      expect(hybrid.documentNumber, 'RE-2026-0001');
      expect(hybrid.ciiXml.contains('CrossIndustryInvoice'), isTrue);
      expect(hybrid.ciiXml.contains('urn:cen.eu:en16931:2017'), isTrue);
      expect(hybrid.ciiXml.contains('<ram:GrandTotalAmount>238.00</ram:GrandTotalAmount>'), isTrue);
      expect(service.readiness(validation), EInvoiceReadiness.valid);
    });

    test('generates_standalone_xrechnung_ubl_without_mutating_invoice', () async {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(
        buyerReference: 'LEITWEG-123',
        format: EInvoiceOutputFormat.xrechnung,
      );
      final int netBefore = snapshot.netCents;

      final String xml = await service.xrechnungXml(snapshot);

      expect(xml.contains('<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"'), isTrue);
      expect(xml.contains('xrechnung_3.0'), isTrue);
      expect(xml.contains('PDF'), isFalse);
      expect(xml.contains('<cbc:BuyerReference>LEITWEG-123</cbc:BuyerReference>'), isTrue);
      expect(xml.contains('<cbc:PayableAmount currencyID="EUR">238.00</cbc:PayableAmount>'), isTrue);
      // Serialization never mutates the snapshot.
      expect(snapshot.netCents, netBefore);
      expect(snapshot.lines.single.netCents, 20000);
    });

    test('rejects_invalid_invoice_with_localized_rule_diagnostic_and_no_output', () async {
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
      await expectLater(service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
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
      final FinalizationSnapshot exempt = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0002',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: validCompany(),
        customerRow: validCustomer(),
        posRows: <Map<String, Object?>>[
          <String, Object?>{
            'bezeichnung': 'Beratung',
            'menge': 1,
            'einzelpreis': 100,
            'ust_satz': 0,
            'tax_treatment': 'kleinunternehmer_19',
            'tax_legal_basis': 'ustg_19',
            'e_invoice_tax_category_code': 'E',
            'e_invoice_exemption_reason_code': null,
            'e_invoice_exemption_reason_text': ApprovedTaxClassification.kleinunternehmerReason,
            'position': 0,
          },
        ],
        preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
        eingabemodus: 'netto',
        buyerReference: 'LEITWEG-123',
      );

      final String cii = serializer.zugferdCii(exempt);
      expect(cii.contains('<ram:CategoryCode>E</ram:CategoryCode>'), isTrue);
      expect(
        cii.contains('<ram:ExemptionReason>${ApprovedTaxClassification.kleinunternehmerReason}</ram:ExemptionReason>'),
        isTrue,
      );
      expect(cii.contains('<ram:ExemptionReasonCode>'), isFalse);

      final String ubl = serializer.xrechnungUbl(exempt);
      expect(ubl.contains('<cbc:ID>E</cbc:ID>'), isTrue);
      expect(
        ubl.contains(
          '<cbc:TaxExemptionReason>${ApprovedTaxClassification.kleinunternehmerReason}</cbc:TaxExemptionReason>',
        ),
        isTrue,
      );
      expect(ubl.contains('<cbc:TaxExemptionReasonCode>'), isFalse);
      expect(
        ubl,
        contains('<cbc:CompanyLegalForm>${ApprovedTaxClassification.kleinunternehmerReason}</cbc:CompanyLegalForm>'),
      );
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

    test('missing_payment_data_fails_closed', () async {
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
      await expectLater(service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
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
        taxBreakdowns: base.taxBreakdowns,
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

    test('missing_delivery_date_fails_closed', () async {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123', deliveryDate: null);

      expect(snapshot.deliveryDate, isNull);
      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.xrechnung);
      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('invoice.deliveryDate'));
      await expectLater(service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
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

    test('standard_rate_without_typed_treatment_fails_with_tax_field_diagnostic', () {
      for (final num rate in <num>[19, 7]) {
        final Map<String, Object?> position = <String, Object?>{
          'bezeichnung': 'Leistung',
          'menge': 1,
          'einzelpreis': 100,
          'ust_satz': rate,
          'position': 0,
        };

        expect(
          () => const EInvoiceSnapshotBuilder().buildFinalization(
            documentNumber: 'RE-2026-0001',
            outputFormat: EInvoiceOutputFormat.xrechnung,
            issueDate: '2026-03-15',
            companyRow: validCompany(),
            customerRow: validCustomer(),
            posRows: <Map<String, Object?>>[position],
            preview: EInvoiceCanonicalTotals(
              netCents: 10000,
              taxCents: rate == 19 ? 1900 : 700,
              grossCents: rate == 19 ? 11900 : 10700,
            ),
            eingabemodus: 'netto',
          ),
          throwsA(
            predicate(
              (Object? error) =>
                  error is EInvoiceSourceException &&
                  error.code == 'unresolvedTaxClassification' &&
                  error.fields.contains('position[0].tax_treatment'),
            ),
          ),
          reason: 'the tax percentage alone cannot select an EN 16931 category',
        );
      }
    });

    test('maps_explicit_standard_and_reduced_rates_to_s', () {
      for (final ({String treatment, String basis, num rate, int taxCents}) value
          in <({String treatment, String basis, num rate, int taxCents})>[
            (treatment: 'standard_19', basis: 'ustg_12_1', rate: 19, taxCents: 1900),
            (treatment: 'reduced_7', basis: 'ustg_12_2', rate: 7, taxCents: 700),
          ]) {
        final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Leistung',
              'menge': 1,
              'einzelpreis': 100,
              'ust_satz': value.rate,
              'tax_treatment': value.treatment,
              'tax_legal_basis': value.basis,
              'e_invoice_tax_category_code': 'S',
              'e_invoice_exemption_reason_code': null,
              'e_invoice_exemption_reason_text': null,
              'position': 0,
            },
          ],
          preview: EInvoiceCanonicalTotals(
            netCents: 10000,
            taxCents: value.taxCents,
            grossCents: 10000 + value.taxCents,
          ),
          eingabemodus: 'netto',
        );

        expect(snapshot.lines.single.classification.category, EInvoiceTaxCategory.standard);
        expect(snapshot.taxBreakdowns.single.taxCents, value.taxCents);
      }
    });

    test('maps_taxable_zero_to_z_only_with_explicit_basis_and_seller_registration', () {
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: validCompany(),
        customerRow: validCustomer(),
        posRows: <Map<String, Object?>>[
          <String, Object?>{
            'bezeichnung': 'Leistung',
            'menge': 1,
            'einzelpreis': 100,
            'ust_satz': 0,
            'tax_treatment': 'taxable_zero_12_3',
            'tax_legal_basis': 'ustg_12_3',
            'e_invoice_tax_category_code': 'Z',
            'e_invoice_exemption_reason_code': null,
            'e_invoice_exemption_reason_text': null,
            'position': 0,
          },
        ],
        preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
        eingabemodus: 'netto',
      );

      expect(snapshot.lines.single.classification.category, EInvoiceTaxCategory.zeroRated);
      expect(snapshot.lines.single.classification.exemptionReason, isNull);
      expect(const EInvoiceXmlSerializer().xrechnungUbl(snapshot), contains('<cbc:ID>Z</cbc:ID>'));
    });

    test('tax_evidence_tuple_mismatch_fails_with_position_field_diagnostic', () {
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Leistung',
              'menge': 1,
              'einzelpreis': 100,
              'ust_satz': 19,
              'tax_treatment': 'standard_19',
              'tax_legal_basis': 'ustg_12_2',
              'e_invoice_tax_category_code': 'S',
              'e_invoice_exemption_reason_code': null,
              'e_invoice_exemption_reason_text': null,
              'position': 0,
            },
          ],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 1900, grossCents: 11900),
          eingabemodus: 'netto',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'unresolvedTaxClassification' &&
                error.fields.contains('position[0].tax_legal_basis'),
          ),
        ),
      );
    });

    test('eu_service_13b1_complete_facts_without_resolved_assessment_fail_closed', () {
      final Map<String, Object?> company = validCompany()
        ..['land'] = 'AT'
        ..['ust_idnr'] = 'ATU12345678';
      final Map<String, Object?> customer = validCustomer()..['ust_idnr'] = 'DE987654321';
      final Map<String, Object?> position = euService13b1PositionWithoutResolvedAssessment();
      expect(position['e_invoice_reverse_charge_evidence_source_ref'], 'dangling-assessment-13b1-not-found');
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: company,
          customerRow: customer,
          posRows: <Map<String, Object?>>[position],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'unresolvedTaxClassification' &&
                error.fields.contains('position[0].e_invoice_reverse_charge_evidence_source_ref'),
          ),
        ),
      );
    });

    test('construction_13b2_unresolved_references_fail_closed_without_seller_country_assumption', () {
      final Map<String, Object?> company = validCompany()
        ..['land'] = 'AT'
        ..['ust_idnr'] = 'ATU12345678';
      final Map<String, Object?> customer = validCustomer()..['ust_idnr'] = 'DE987654321';
      final Map<String, Object?> position = construction13b2PositionWithoutResolvedCertificate();
      expect(position['e_invoice_reverse_charge_evidence_source_ref'], 'dangling-assessment-13b2-not-found');
      expect(position['e_invoice_reverse_charge_ust1tg_certificate_ref'], 'dangling-ust1tg-certificate-not-found');
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: company,
          customerRow: customer,
          posRows: <Map<String, Object?>>[position],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
          deliveryDate: '2026-03-10',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'unresolvedTaxClassification' &&
                error.fields.contains('position[0].e_invoice_reverse_charge_evidence_source_ref') &&
                error.fields.contains('position[0].e_invoice_reverse_charge_ust1tg_certificate_ref') &&
                !error.fields.contains('unternehmen.land'),
          ),
        ),
      );
    });

    test('construction_13b2_missing_or_invalid_ust1tg_fails_with_position_diagnostic', () {
      final Map<String, Object?> position = construction13b2PositionWithoutResolvedCertificate()
        ..['e_invoice_reverse_charge_ust1tg_scope'] = 'building_cleaning_13b_2_8'
        ..['e_invoice_reverse_charge_ust1tg_recipient_vat_id'] = 'DE000000000';
      final Map<String, Object?> customer = validCustomer()..['ust_idnr'] = 'DE987654321';

      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: customer,
          posRows: <Map<String, Object?>>[position],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
          deliveryDate: '2026-03-10',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'unresolvedTaxClassification' &&
                error.fields.contains('position[0].e_invoice_reverse_charge_ust1tg_scope') &&
                error.fields.contains('position[0].e_invoice_reverse_charge_ust1tg_recipient_vat_id'),
          ),
        ),
      );
    });

    test('eu_service_13b1_missing_eligibility_evidence_fails_with_position_diagnostic', () {
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Leistung',
              'menge': 1,
              'einzelpreis': 100,
              'ust_satz': 0,
              'tax_treatment': 'reverse_charge_eu_service_13b_1',
              'tax_legal_basis': 'ustg_3a_2_13b_1',
              'e_invoice_tax_category_code': 'AE',
              'e_invoice_exemption_reason_code': 'VATEX-EU-AE',
              'e_invoice_exemption_reason_text': 'Steuerschuldnerschaft des Leistungsempfängers',
              'position': 0,
            },
          ],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'unresolvedTaxClassification' &&
                error.fields.contains('position[0].e_invoice_reverse_charge_evidence_source_ref'),
          ),
        ),
      );
    });

    test('section_6a_missing_or_unknown_supply_destination_fails_closed', () {
      for (final String? destinationCountry in <String?>[null, 'ZZ']) {
        _expectSection6aRejected(
          expectedField: 'position[0].e_invoice_intra_community_destination_country_iso',
          destinationCountry: destinationCountry,
        );
      }
    });

    test('section_6a_german_supply_destination_fails_closed', () {
      _expectSection6aRejected(
        expectedField: 'position[0].e_invoice_intra_community_destination_country_iso',
        destinationCountry: 'DE',
      );
    });

    test('section_6a_non_eu_supply_destination_fails_closed', () {
      _expectSection6aRejected(
        expectedField: 'position[0].e_invoice_intra_community_destination_country_iso',
        destinationCountry: 'US',
      );
    });

    test('section_6a_other_eu_destination_without_resolved_transport_evidence_fails_closed', () {
      _expectSection6aRejected(
        expectedField: 'position[0].e_invoice_intra_community_supply_evidence_source_ref',
        destinationCountry: 'FR',
        evidenceSourceRef: 'dangling-supply-evidence',
      );
    });

    test('section_6a_requires_party_vat_ids_and_delivery_date', () {
      final Map<String, Object?> customer = validCustomer()..['land'] = 'FR';
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: customer,
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Lieferung nach Frankreich',
              'menge': 1,
              'einzelpreis': 100,
              'ust_satz': 0,
              'tax_treatment': 'intra_community_supply_6a',
              'tax_legal_basis': 'ustg_4_1b_6a',
              'e_invoice_tax_category_code': 'K',
              'e_invoice_exemption_reason_code': 'VATEX-EU-IC',
              'e_invoice_exemption_reason_text': 'Steuerfreie innergemeinschaftliche Lieferung',
              'position': 0,
            },
          ],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'incompleteCrossBorderTaxEvidence' &&
                error.fields.contains('kunden.ust_idnr') &&
                error.fields.contains('leistungsdatum'),
          ),
        ),
      );
    });

    test('section_6_export_customer_billing_country_alone_does_not_establish_destination_fails_closed', () {
      _expectSection6Rejected(expectedField: 'position[0].e_invoice_export_destination_country_iso');
    });

    test('section_6_export_missing_or_unknown_destination_fails_closed', () {
      _expectSection6Rejected(
        expectedField: 'position[0].e_invoice_export_destination_country_iso',
        destinationCountry: 'ZZ',
      );
    });

    test('section_6_export_german_destination_fails_closed', () {
      _expectSection6Rejected(
        expectedField: 'position[0].e_invoice_export_destination_country_iso',
        destinationCountry: 'DE',
      );
    });

    test('section_6_export_eu_destination_fails_closed', () {
      _expectSection6Rejected(
        expectedField: 'position[0].e_invoice_export_destination_country_iso',
        destinationCountry: 'FR',
      );
    });

    test('section_6_export_without_resolved_line_bound_movement_evidence_fails_closed', () {
      _expectSection6Rejected(
        expectedField: 'position[0].e_invoice_export_evidence_source_ref',
        destinationCountry: 'US',
        evidenceSourceRef: 'dangling-export-evidence',
      );
    });

    for (final (String testName, String treatment, String code, String note) in <(String, String, String, String)>[
      (
        'section_25a_second_hand_preserves_disclosed_payable_amount_107_60',
        'margin_scheme_25a_second_hand',
        'VATEX-EU-F',
        'Gebrauchtgegenstände/Sonderregelung',
      ),
      (
        'section_25a_art_preserves_disclosed_payable_amount_107_60',
        'margin_scheme_25a_art',
        'VATEX-EU-I',
        'Kunstgegenstände/Sonderregelung',
      ),
      (
        'section_25a_collectors_antiquities_preserves_disclosed_payable_amount_107_60',
        'margin_scheme_25a_collectors_antiquities',
        'VATEX-EU-J',
        'Sammlungsstücke und Antiquitäten/Sonderregelung',
      ),
    ]) {
      test(testName, () {
        final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Differenzbesteuerter Artikel',
              'menge': 1,
              'einzelpreis': 107.60,
              'ust_satz': 0,
              'tax_treatment': treatment,
              'tax_legal_basis': 'ustg_25a',
              'e_invoice_tax_category_code': 'E',
              'e_invoice_exemption_reason_code': code,
              'e_invoice_exemption_reason_text': note,
              'position': 8,
            },
          ],
          preview: const EInvoiceCanonicalTotals(
            netCents: 10000,
            taxCents: 760,
            grossCents: 10760,
            positionTotals: <EInvoiceCanonicalPositionAmounts>[
              EInvoiceCanonicalPositionAmounts(position: 8, netCents: 10000, taxCents: 760, grossCents: 10760),
            ],
            disclosureTotals: EInvoiceDisclosureTotals(netCents: 10760, taxCents: 0, grossCents: 10760),
          ),
          eingabemodus: 'netto',
        );

        expect(snapshot.lines.single.netCents, 10760);
        expect(snapshot.lines.single.taxCents, 0);
        expect(snapshot.lines.single.grossCents, 10760);
        expect(snapshot.netCents, 10760);
        expect(snapshot.taxCents, 0);
        expect(snapshot.grossCents, 10760);
        expect(snapshot.accountingNetCents, 10000);
        expect(snapshot.accountingTaxCents, 760);
        expect(snapshot.accountingGrossCents, 10760);
        expect(snapshot.invoiceNotes, contains(note));
        expect(snapshot.taxBreakdowns.single.classification.category, EInvoiceTaxCategory.exempt);
        expect(snapshot.taxBreakdowns.single.netCents, 10760);
        expect(snapshot.taxBreakdowns.single.taxCents, 0);
        final String ubl = const EInvoiceXmlSerializer().xrechnungUbl(snapshot);
        final String cii = const EInvoiceXmlSerializer().zugferdCii(snapshot);
        expect(ubl, contains('<cbc:BaseQuantity unitCode="H87">1</cbc:BaseQuantity>'));
        expect(cii, contains('<ram:BasisQuantity unitCode="H87">1</ram:BasisQuantity>'));
        expect(ubl, contains('<cbc:LineExtensionAmount currencyID="EUR">107.60</cbc:LineExtensionAmount>'));
        expect(ubl, contains('<cbc:TaxableAmount currencyID="EUR">107.60</cbc:TaxableAmount>'));
        expect(ubl, contains('<cbc:TaxExclusiveAmount currencyID="EUR">107.60</cbc:TaxExclusiveAmount>'));
        expect(ubl, contains('<cbc:TaxInclusiveAmount currencyID="EUR">107.60</cbc:TaxInclusiveAmount>'));
        expect(ubl, contains('<cbc:PayableAmount currencyID="EUR">107.60</cbc:PayableAmount>'));
        expect(cii, contains('<ram:LineTotalAmount>107.60</ram:LineTotalAmount>'));
        expect(cii, contains('<ram:TaxBasisTotalAmount>107.60</ram:TaxBasisTotalAmount>'));
        expect(ubl, contains('<cbc:Note>$note</cbc:Note>'));
        expect(ubl, contains('<cbc:TaxExemptionReasonCode>$code</cbc:TaxExemptionReasonCode>'));
        expect(cii, contains('<ram:DuePayableAmount>107.60</ram:DuePayableAmount>'));
        expect(cii, contains('<ram:IncludedNote><ram:Content>$note</ram:Content></ram:IncludedNote>'));
        expect(cii, contains('<ram:ExemptionReasonCode>$code</ram:ExemptionReasonCode>'));
      });
    }

    test('gross_input_emits_canonical_net_price_basis_in_ubl_and_cii', () {
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: validCompany(),
        customerRow: validCustomer(),
        posRows: <Map<String, Object?>>[
          <String, Object?>{
            'bezeichnung': 'Beratung',
            'menge': 1,
            'einzelpreis': 119,
            'ust_satz': 19,
            'tax_treatment': 'standard_19',
            'tax_legal_basis': 'ustg_12_1',
            'e_invoice_tax_category_code': 'S',
            'position': 0,
          },
        ],
        preview: const EInvoiceCanonicalTotals(
          netCents: 10000,
          taxCents: 1900,
          grossCents: 11900,
          positionTotals: <EInvoiceCanonicalPositionAmounts>[
            EInvoiceCanonicalPositionAmounts(position: 0, netCents: 10000, taxCents: 1900, grossCents: 11900),
          ],
          disclosureTotals: EInvoiceDisclosureTotals(netCents: 10000, taxCents: 1900, grossCents: 11900),
        ),
        eingabemodus: 'brutto',
      );
      final String ubl = const EInvoiceXmlSerializer().xrechnungUbl(snapshot);
      final String cii = const EInvoiceXmlSerializer().zugferdCii(snapshot);

      expect(snapshot.lines.single.netCents, 10000);
      expect(ubl, contains('<cbc:PriceAmount currencyID="EUR">100.0000</cbc:PriceAmount>'));
      expect(ubl, contains('<cbc:LineExtensionAmount currencyID="EUR">100.00</cbc:LineExtensionAmount>'));
      expect(
        cii,
        contains(
          '<ram:NetPriceProductTradePrice><ram:ChargeAmount>100.0000</ram:ChargeAmount><ram:BasisQuantity unitCode="H87">1</ram:BasisQuantity></ram:NetPriceProductTradePrice>',
        ),
      );
      expect(
        cii,
        contains(
          '<ram:GrossPriceProductTradePrice><ram:ChargeAmount>119.0000</ram:ChargeAmount><ram:BasisQuantity unitCode="H87">1</ram:BasisQuantity></ram:GrossPriceProductTradePrice>',
        ),
      );
      expect(cii, contains('<ram:LineTotalAmount>100.00</ram:LineTotalAmount>'));
    });

    test('gross_input_cii_emits_canonical_net_and_source_gross_prices', () {
      final FinalizationSnapshot snapshot = _grossInputSnapshot();
      final String cii = const EInvoiceXmlSerializer().zugferdCii(snapshot);

      expect(
        cii,
        contains(
          '<ram:NetPriceProductTradePrice><ram:ChargeAmount>100.0000</ram:ChargeAmount><ram:BasisQuantity unitCode="H87">1</ram:BasisQuantity></ram:NetPriceProductTradePrice>',
        ),
      );
      expect(
        cii,
        contains(
          '<ram:GrossPriceProductTradePrice><ram:ChargeAmount>119.0000</ram:ChargeAmount><ram:BasisQuantity unitCode="H87">1</ram:BasisQuantity></ram:GrossPriceProductTradePrice>',
        ),
      );
      expect(cii, contains('<ram:LineTotalAmount>100.00</ram:LineTotalAmount>'));
    });

    test('gross_input_without_position_totals_fails_closed_for_missing_net_price_basis', () {
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Beratung',
              'menge': 1,
              'einzelpreis': 119,
              'ust_satz': 19,
              'tax_treatment': 'standard_19',
              'tax_legal_basis': 'ustg_12_1',
              'e_invoice_tax_category_code': 'S',
              'position': 0,
            },
          ],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 1900, grossCents: 11900),
          eingabemodus: 'brutto',
        ),
        throwsA(
          isA<EInvoiceSourceException>().having(
            (EInvoiceSourceException error) => error.code,
            'code',
            'missingNetPriceBasis',
          ),
        ),
      );
    });

    test('section_25a_canonical_line_total_reconciles_to_source_price_and_quantity', () {
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Differenzbesteuerter Artikel',
              'menge': 1,
              'einzelpreis': 107.60,
              'ust_satz': 0,
              'tax_treatment': 'margin_scheme_25a_second_hand',
              'tax_legal_basis': 'ustg_25a',
              'e_invoice_tax_category_code': 'E',
              'e_invoice_exemption_reason_code': 'VATEX-EU-F',
              'e_invoice_exemption_reason_text': 'Gebrauchtgegenstände/Sonderregelung',
              'position': 8,
            },
          ],
          preview: const EInvoiceCanonicalTotals(
            netCents: 10761,
            taxCents: 0,
            grossCents: 10761,
            positionTotals: <EInvoiceCanonicalPositionAmounts>[
              EInvoiceCanonicalPositionAmounts(position: 8, netCents: 10761, taxCents: 0, grossCents: 10761),
            ],
            disclosureTotals: EInvoiceDisclosureTotals(netCents: 10761, taxCents: 0, grossCents: 10761),
          ),
          eingabemodus: 'netto',
        ),
        throwsA(
          isA<EInvoiceSourceException>().having(
            (EInvoiceSourceException error) => error.code,
            'code',
            'unreconciledPriceBasis',
          ),
        ),
      );
    });

    test('section_25a_line_and_document_discounts_fail_closed_without_emitted_basis', () {
      for (final (String source, num? lineDiscount, num? documentDiscount) in <(String, num?, num?)>[
        ('line', 10, null),
        ('document', null, 10),
      ]) {
        const EInvoiceCanonicalTotals discountedTotals = EInvoiceCanonicalTotals(
          netCents: 9684,
          taxCents: 0,
          grossCents: 9684,
          positionTotals: <EInvoiceCanonicalPositionAmounts>[
            EInvoiceCanonicalPositionAmounts(position: 8, netCents: 9684, taxCents: 0, grossCents: 9684),
          ],
          disclosureTotals: EInvoiceDisclosureTotals(netCents: 9684, taxCents: 0, grossCents: 9684),
        );
        expect(
          () => const EInvoiceSnapshotBuilder().buildFinalization(
            documentNumber: 'RE-2026-0001',
            outputFormat: EInvoiceOutputFormat.xrechnung,
            issueDate: '2026-03-15',
            companyRow: validCompany(),
            customerRow: validCustomer(),
            posRows: <Map<String, Object?>>[
              <String, Object?>{
                'bezeichnung': 'Differenzbesteuerter Artikel',
                'menge': 1,
                'einzelpreis': 107.60,
                'ust_satz': 0,
                'tax_treatment': 'margin_scheme_25a_second_hand',
                'tax_legal_basis': 'ustg_25a',
                'e_invoice_tax_category_code': 'E',
                'e_invoice_exemption_reason_code': 'VATEX-EU-F',
                'e_invoice_exemption_reason_text': 'Gebrauchtgegenstände/Sonderregelung',
                'position': 8,
                'rabatt_prozent': ?lineDiscount,
              },
            ],
            preview: discountedTotals,
            eingabemodus: 'netto',
            documentDiscountPercent: documentDiscount,
          ),
          throwsA(
            isA<EInvoiceSourceException>().having(
              (EInvoiceSourceException error) => error.code,
              'code',
              'missingPriceAdjustmentBasis',
            ),
          ),
          reason: '$source discount has no emitted adjustment basis',
        );
      }
    });

    test('section_25a_mixed_with_standard_tax_preserves_standard_bt110', () {
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.xrechnung,
        issueDate: '2026-03-15',
        companyRow: validCompany(),
        customerRow: validCustomer(),
        posRows: <Map<String, Object?>>[
          <String, Object?>{
            'bezeichnung': 'Differenzbesteuerter Artikel',
            'menge': 1,
            'einzelpreis': 107.60,
            'ust_satz': 0,
            'tax_treatment': 'margin_scheme_25a_second_hand',
            'tax_legal_basis': 'ustg_25a',
            'e_invoice_tax_category_code': 'E',
            'e_invoice_exemption_reason_code': 'VATEX-EU-F',
            'e_invoice_exemption_reason_text': 'Gebrauchtgegenstände/Sonderregelung',
            'position': 8,
          },
          <String, Object?>{
            'bezeichnung': 'Beratung',
            'menge': 1,
            'einzelpreis': 50,
            'ust_satz': 19,
            'tax_treatment': 'standard_19',
            'tax_legal_basis': 'ustg_12_1',
            'e_invoice_tax_category_code': 'S',
            'position': 2,
          },
        ],
        preview: const EInvoiceCanonicalTotals(
          netCents: 15000,
          taxCents: 1710,
          grossCents: 16710,
          positionTotals: <EInvoiceCanonicalPositionAmounts>[
            EInvoiceCanonicalPositionAmounts(position: 2, netCents: 5000, taxCents: 950, grossCents: 5950),
            EInvoiceCanonicalPositionAmounts(position: 8, netCents: 10000, taxCents: 760, grossCents: 10760),
          ],
          disclosureTotals: EInvoiceDisclosureTotals(netCents: 15760, taxCents: 950, grossCents: 16710),
        ),
        eingabemodus: 'netto',
      );

      expect(snapshot.netCents, 15760);
      expect(snapshot.taxCents, 950);
      expect(snapshot.grossCents, 16710);
      expect(snapshot.accountingNetCents, 15000);
      expect(snapshot.accountingTaxCents, 1710);
      expect(snapshot.accountingGrossCents, 16710);
      expect(
        snapshot.taxBreakdowns.map((EInvoiceTaxBreakdownSnapshot row) => row.taxCents),
        containsAll(<int>[0, 950]),
      );
      expect(
        snapshot.taxBreakdowns.fold<int>(0, (int sum, EInvoiceTaxBreakdownSnapshot row) => sum + row.taxCents),
        950,
      );
      final EInvoiceTaxBreakdownSnapshot section25aBreakdown = snapshot.taxBreakdowns.firstWhere(
        (EInvoiceTaxBreakdownSnapshot row) => row.classification.category == EInvoiceTaxCategory.exempt,
      );
      expect(section25aBreakdown.netCents, 10760);
      expect(section25aBreakdown.taxCents, 0);
      final String ubl = const EInvoiceXmlSerializer().xrechnungUbl(snapshot);
      expect(ubl, contains('<cbc:TaxAmount currencyID="EUR">9.50</cbc:TaxAmount>'));
      expect(ubl, contains('<cbc:TaxableAmount currencyID="EUR">107.60</cbc:TaxableAmount>'));
      expect(ubl, contains('<cbc:TaxableAmount currencyID="EUR">50.00</cbc:TaxableAmount>'));
      expect(ubl, contains('<cbc:LineExtensionAmount currencyID="EUR">157.60</cbc:LineExtensionAmount>'));
      expect(ubl, contains('<cbc:TaxExclusiveAmount currencyID="EUR">157.60</cbc:TaxExclusiveAmount>'));
      expect(ubl, contains('<cbc:TaxInclusiveAmount currencyID="EUR">167.10</cbc:TaxInclusiveAmount>'));
      expect(ubl, contains('<cbc:PayableAmount currencyID="EUR">167.10</cbc:PayableAmount>'));
    });

    test('section_25a_without_supported_reason_code_fails_with_position_diagnostic', () {
      expect(
        () => const EInvoiceSnapshotBuilder().buildFinalization(
          documentNumber: 'RE-2026-0001',
          outputFormat: EInvoiceOutputFormat.xrechnung,
          issueDate: '2026-03-15',
          companyRow: validCompany(),
          customerRow: validCustomer(),
          posRows: <Map<String, Object?>>[
            <String, Object?>{
              'bezeichnung': 'Differenzbesteuerter Artikel',
              'menge': 1,
              'einzelpreis': 100,
              'ust_satz': 0,
              'tax_treatment': 'margin_scheme_25a_second_hand',
              'tax_legal_basis': 'ustg_25a',
              'e_invoice_tax_category_code': 'E',
              'e_invoice_exemption_reason_code': null,
              'e_invoice_exemption_reason_text': null,
              'position': 0,
            },
          ],
          preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 0, grossCents: 10000),
          eingabemodus: 'netto',
        ),
        throwsA(
          predicate(
            (Object? error) =>
                error is EInvoiceSourceException &&
                error.code == 'unresolvedTaxClassification' &&
                error.fields.contains('position[0].e_invoice_exemption_reason_code'),
          ),
        ),
      );
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
