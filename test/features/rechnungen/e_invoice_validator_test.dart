// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_artifacts.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Version-pinned formats and business-rule validation', () {
    test('rejects seller email without contact point and telephone using pinned rules', () async {
      expect(EInvoicePinnedVersions.xrechnungVersion, '3.0');
      expect(EInvoicePinnedVersions.xrechnungSyntax, 'UBL 2.1');
      expect(EInvoicePinnedVersions.xrechnungBundleVersion, '3.0.2');
      expect(EInvoicePinnedVersions.kositValidatorVersion, '1.6.3');
      expect(EInvoicePinnedVersions.xrechnungConfigVersion, 'v2026-08-31');
      expect(EInvoicePinnedVersions.cenSchematronVersion, '1.3.16');
      expect(EInvoicePinnedVersions.xrechnungSchematronVersion, '2.6.0');
      expect(PinnedArtifactBundle.packaged.available, isTrue);

      final Map<String, Object?> company = validCompany()..['email'] = 'seller@example.de';
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
        deliveryDate: '2026-03-10',
      );
      final String xml = const EInvoiceXmlSerializer().xrechnungUbl(snapshot);

      expect(xml.contains('3.0.2'), isFalse);
      expect(xml.contains('xrechnung_3.0'), isTrue);
      expect(xml, contains('<cac:Contact>'));
      expect(xml, contains('<cbc:ElectronicMail>seller@example.de</cbc:ElectronicMail>'));

      const EInvoiceService service = EInvoiceService();
      await expectLater(
        service.xrechnungXml(snapshot),
        throwsA(
          isA<EInvoiceExportValidationException>()
              .having(
                (error) => error.offlineXmlResult?.engineVersion,
                'engineVersion',
                'KoSIT Validator ${EInvoicePinnedVersions.kositValidatorVersion}',
              )
              .having(
                (error) => error.offlineXmlResult?.diagnostics.map((finding) => finding.code),
                'diagnostic codes',
                allOf(contains('BR-DE-5'), contains('BR-DE-6'), contains('BR-DE-27')),
              )
              .having(
                (error) => error.offlineXmlResult?.diagnostics.map((finding) => finding.message).join(' '),
                'missing seller contact fields',
                allOf(contains('BT-41'), contains('BT-42')),
              ),
        ),
      );
    });

    test('rejects missing seller contact with the official BR-DE-2 diagnostic', () async {
      const EInvoiceService service = EInvoiceService();
      final FinalizationSnapshot snapshot = validSnapshot(
        buyerReference: 'LEITWEG-123',
        format: EInvoiceOutputFormat.xrechnung,
      );

      await expectLater(
        service.xrechnungXml(snapshot),
        throwsA(
          isA<EInvoiceExportValidationException>()
              .having(
                (error) => error.offlineXmlResult?.engineVersion,
                'engineVersion',
                'KoSIT Validator ${EInvoicePinnedVersions.kositValidatorVersion}',
              )
              .having(
                (error) => error.offlineXmlResult?.diagnostics.map((finding) => finding.code),
                'diagnostic codes',
                contains('BR-DE-2'),
              )
              .having(
                (error) => error.offlineXmlResult?.diagnostics.map((finding) => finding.message).join(' '),
                'diagnostic message',
                contains('BG-6'),
              ),
        ),
      );
    });

    test('unavailable_or_corrupt_bundle_rejects_output_without_compliance_claim', () async {
      const EInvoiceService service = EInvoiceService(bundle: PinnedArtifactBundle());
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123');

      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.xrechnung);

      expect(result.valid, isFalse);
      expect(result.diagnostics.single.ruleId, 'bundleUnavailable');
      expect(service.readiness(result), EInvoiceReadiness.unavailable);
      // No compliance is claimed and no output is produced.
      await expectLater(service.xrechnungXml(snapshot), throwsA(isA<EInvoiceExportValidationException>()));
      await expectLater(
        service.hybridFromPdf(snapshot: snapshot, pdfBytes: fakePdfBytes),
        throwsA(isA<EInvoiceExportValidationException>()),
      );
    });

    test('valid_snapshot_is_accepted_and_reported_ready', () {
      const EInvoiceService service = eInvoiceTestService;
      final FinalizationSnapshot snapshot = validSnapshot(buyerReference: 'LEITWEG-123');

      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.xrechnung);
      expect(result.valid, isTrue);
      expect(result.diagnostics, isEmpty);
      expect(service.readiness(result), EInvoiceReadiness.valid);
      expect(service.readiness(null), EInvoiceReadiness.notValidated);
      expect(
        const EInvoiceXmlSerializer()
            .xrechnungUbl(snapshot)
            .contains('<cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>'),
        isTrue,
      );
    });

    test('missing_source_field_reports_localized_diagnostic_without_output', () {
      const EInvoiceService service = eInvoiceTestService;
      final Map<String, Object?> company = validCompany()
        ..remove('steuernummer')
        ..remove('ust_idnr');
      final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
        documentNumber: 'RE-2026-0001',
        outputFormat: EInvoiceOutputFormat.zugferd,
        issueDate: '2026-03-15',
        companyRow: company,
        customerRow: validCustomer(),
        posRows: standardPositions(),
        preview: standardTotals(),
        eingabemodus: 'netto',
      );

      final EInvoiceValidationResult result = service.validate(snapshot, EInvoiceOutputFormat.zugferd);

      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('seller.taxIdentifier'));
      final EInvoiceDiagnostic diagnostic = result.diagnostics.firstWhere(
        (entry) => entry.ruleId == 'seller.taxIdentifier',
      );
      expect(diagnostic.messageFor('de_DE'), contains('Steuernummer'));
      expect(diagnostic.messageFor('en'), contains('VAT ID'));
      expect(service.readiness(result), EInvoiceReadiness.invalid);
    });

    test('pinned_business_rule_rejects_output_without_mutating_invoice', () {
      const EInvoiceService service = eInvoiceTestService;
      // Hand-built inconsistent snapshot: line sums diverge from totals.
      const FinalizationSnapshot broken = FinalizationSnapshot(
        documentNumber: 'RE-2026-0001',
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
            quantityText: '2',
            unitPriceText: '100.0000',
            netUnitPriceText: '100.0000',
            unitPriceIsGross: false,
            netCents: 20000,
            taxCents: 3800,
            grossCents: 23800,
            taxRateHundredths: 1900,
            classification: EInvoiceLineClassification(
              treatment: EInvoiceTaxTreatment.standard19,
              legalBasis: EInvoiceTaxLegalBasis.ustg12_1,
              category: EInvoiceTaxCategory.standard,
            ),
          ),
        ],
        taxBreakdowns: <EInvoiceTaxBreakdownSnapshot>[
          EInvoiceTaxBreakdownSnapshot(
            taxRateHundredths: 1900,
            classification: EInvoiceLineClassification(
              treatment: EInvoiceTaxTreatment.standard19,
              legalBasis: EInvoiceTaxLegalBasis.ustg12_1,
              category: EInvoiceTaxCategory.standard,
            ),
            netCents: 20000,
            taxCents: 3800,
          ),
        ],
        netCents: 20000,
        taxCents: 9999,
        grossCents: 23800,
        buyerReference: 'LEITWEG-123',
      );

      final EInvoiceValidationResult result = service.validate(broken, EInvoiceOutputFormat.xrechnung);

      expect(result.valid, isFalse);
      expect(result.diagnostics.map((diagnostic) => diagnostic.ruleId), contains('BR-SUM-01'));
      // The source snapshot is unchanged by validation.
      expect(broken.taxCents, 9999);
      expect(broken.lines.single.taxCents, 3800);
    });
  });
}
