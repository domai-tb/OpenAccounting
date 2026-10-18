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
  group('Version-pinned formats and business-rule validation', () {
    test('validates_supported_xml_against_exact_local_pinned_artifacts', () {
      expect(EInvoicePinnedVersions.zugferdVersion, '2.5.2');
      expect(EInvoicePinnedVersions.zugferdProfile, 'EN16931');
      expect(EInvoicePinnedVersions.xrechnungVersion, '3.0');
      expect(EInvoicePinnedVersions.xrechnungSyntax, 'UBL 2.1');
      expect(EInvoicePinnedVersions.xrechnungBundleVersion, '3.0.2');
      expect(EInvoicePinnedVersions.kositValidatorVersion, '1.6.3');
      expect(EInvoicePinnedVersions.xrechnungConfigVersion, 'v2026-08-31');
      expect(EInvoicePinnedVersions.cenSchematronVersion, '1.3.16');
      expect(EInvoicePinnedVersions.xrechnungSchematronVersion, '2.6.0');

      const EInvoiceXmlSerializer serializer = EInvoiceXmlSerializer();
      final FinalizationSnapshot snapshot = validSnapshot(
        buyerReference: 'LEITWEG-123',
        format: EInvoiceOutputFormat.xrechnung,
      );
      // Bundle identity is release metadata; the XML carries only the
      // normative format version, never the bundle version.
      expect(serializer.xrechnungUbl(snapshot).contains('3.0.2'), isFalse);
      expect(serializer.xrechnungUbl(snapshot).contains('xrechnung_3.0'), isTrue);
      expect(
        PinnedArtifactBundle.packaged.releaseIdentity(EInvoiceOutputFormat.xrechnung),
        contains('Bundle 3.0.2 Summer 2026'),
      );
      const EInvoiceService service = eInvoiceTestService;
      expect(service.validate(snapshot, EInvoiceOutputFormat.xrechnung).valid, isTrue);
    });

    test('unavailable_or_corrupt_bundle_rejects_output_without_compliance_claim', () async {
      const EInvoiceService service = EInvoiceService();
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
            unitPriceIsGross: false,
            netCents: 20000,
            taxCents: 3800,
            grossCents: 23800,
            taxRateHundredths: 1900,
            classification: EInvoiceLineClassification(category: EInvoiceTaxCategory.standard),
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
