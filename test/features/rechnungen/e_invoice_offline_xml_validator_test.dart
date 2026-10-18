import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_offline_xml_validator.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EInvoiceOfflineXmlValidator validator;

  setUpAll(() {
    validator = EInvoiceOfflineXmlValidator();
  });

  tearDownAll(() async {
    await validator.dispose();
  });

  group('packaged offline XML validator', () {
    test('accepts official XRechnung UBL and ZUGFeRD CII EN16931 fixtures', () async {
      final String xrechnung = await _fixture('xrechnung_valid_01_01a.xml');
      final EInvoiceOfflineXmlValidationResult ublResult = await validator.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml: xrechnung,
      );
      expect(ublResult.status, EInvoiceOfflineXmlValidationStatus.valid, reason: ublResult.message);
      expect(ublResult.engineVersion, 'KoSIT Validator 1.6.3');
      expect(ublResult.steps.map((EInvoiceOfflineXmlValidationStep step) => step.id), contains('val-xsd'));
      expect(ublResult.steps.map((EInvoiceOfflineXmlValidationStep step) => step.id), contains('val-sch.1'));
      expect(ublResult.steps.map((EInvoiceOfflineXmlValidationStep step) => step.id), contains('val-sch.2'));

      final String zugferd = await _fixture('zugferd_valid_en16931_cii.xml');
      final EInvoiceOfflineXmlValidationResult ciiResult = await validator.validateXml(
        format: EInvoiceOutputFormat.zugferd,
        xml: zugferd,
      );
      expect(ciiResult.status, EInvoiceOfflineXmlValidationStatus.valid, reason: ciiResult.message);
      expect(ciiResult.engineVersion, 'KoSIT Validator 1.6.3');
      expect(ciiResult.steps.map((EInvoiceOfflineXmlValidationStep step) => step.id), contains('val-xsd'));
      expect(ciiResult.steps.map((EInvoiceOfflineXmlValidationStep step) => step.id), contains('val-sch.1'));
    });

    test('does not accept a valid document from the wrong requested profile', () async {
      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml: await _fixture('zugferd_valid_en16931_cii.xml'),
      );

      expect(result.status, EInvoiceOfflineXmlValidationStatus.invalid);
      expect(
        result.diagnostics.map((EInvoiceOfflineXmlDiagnostic finding) => finding.code),
        contains('PROFILE_MISMATCH'),
      );
    });

    test('rejects a missing XRechnung seller endpoint with the official rule', () async {
      final String validXml = await _fixture('xrechnung_valid_01_01a.xml');
      final String invalidXml = validXml.replaceFirst(
        '<cbc:EndpointID schemeID="EM">seller@email.de</cbc:EndpointID>',
        '',
      );
      expect(invalidXml, isNot(validXml));

      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml: invalidXml,
      );
      expect(result.status, EInvoiceOfflineXmlValidationStatus.invalid, reason: result.message);
      expect(
        result.diagnostics.map((EInvoiceOfflineXmlDiagnostic finding) => finding.code),
        contains('PEPPOL-EN16931-R020'),
      );
    });

    test('rejects a missing CII seller name with the official rule', () async {
      final String validXml = await _fixture('zugferd_valid_en16931_cii.xml');
      final String invalidXml = validXml.replaceFirst('<ram:Name>LE VENDEUR</ram:Name>', '<ram:Name></ram:Name>');
      expect(invalidXml, isNot(validXml));

      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.zugferd,
        xml: invalidXml,
      );
      expect(result.status, EInvoiceOfflineXmlValidationStatus.invalid, reason: result.message);
      expect(result.diagnostics.map((EInvoiceOfflineXmlDiagnostic finding) => finding.code), contains('BR-06'));
    });

    test('rejects DTD input before invoking the validator', () async {
      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml: '<!DOCTYPE invoice SYSTEM "file:///etc/passwd"><Invoice/>',
      );

      expect(result.status, EInvoiceOfflineXmlValidationStatus.invalid, reason: result.message);
      expect(result.diagnostics.single.code, 'DTD_NOT_ALLOWED');
    });

    test('rejects XML schema hints instead of allowing external resolution', () async {
      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml:
            '<Invoice xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:schemaLocation="urn:test https://example.invalid/invoice.xsd"/>',
      );

      expect(result.status, EInvoiceOfflineXmlValidationStatus.invalid);
      expect(result.diagnostics.single.code, 'EXTERNAL_SCHEMA_REFERENCE');
    });

    test('rejects malformed XML before invoking the validator', () async {
      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml: '<Invoice>',
      );

      expect(result.status, EInvoiceOfflineXmlValidationStatus.invalid);
      expect(result.diagnostics.single.code, 'MALFORMED_XML');
    });

    test('returns unavailable for PDF because no XML profile is packaged', () async {
      final EInvoiceOfflineXmlValidationResult result = await validator.validateXml(
        format: EInvoiceOutputFormat.pdf,
        xml: '<not-an-invoice/>',
      );

      expect(result.status, EInvoiceOfflineXmlValidationStatus.unavailable);
    });

    test('fails closed when Java is missing', () async {
      final EInvoiceOfflineXmlValidator missingJava = EInvoiceOfflineXmlValidator(
        javaExecutable: 'openaccounting-test-java-that-does-not-exist',
      );
      addTearDown(missingJava.dispose);

      final EInvoiceOfflineXmlValidationResult result = await missingJava.validateXml(
        format: EInvoiceOutputFormat.xrechnung,
        xml: await _fixture('xrechnung_valid_01_01a.xml'),
      );

      expect(result.status, EInvoiceOfflineXmlValidationStatus.unavailable);
      expect(result.valid, isFalse);
    });
  });
}

Future<String> _fixture(String fileName) {
  final String path = p.join('test', 'fixtures', 'e_invoice', 'offline_validator', fileName);
  return File(path).readAsString();
}
