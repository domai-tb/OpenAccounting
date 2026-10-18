// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_offline_xml_validator.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

import 'e_invoice_test_fixtures.dart';

void main() {
  group('Standalone XRechnung export', () {
    late AppDatabase db;
    late Directory profileDir;
    late Directory exportDir;
    late RechnungenUseCases useCases;

    setUp(() async {
      db = await openEInvoiceDatabase();
      profileDir = await Directory.systemTemp.createTemp('e-invoice-export-profile-');
      exportDir = await Directory.systemTemp.createTemp('e-invoice-export-target-');
      useCases = RechnungenUseCases(
        RechnungenRepository(RechnungenDataSource(db.executor, profileDir: profileDir.path)),
      );
    });

    tearDown(() async {
      await db.close();
      if (profileDir.existsSync()) profileDir.deleteSync(recursive: true);
      if (exportDir.existsSync()) exportDir.deleteSync(recursive: true);
    });

    Future<int> finalizePdfInvoice() async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(
        RechnungenDataSource(db.executor, profileDir: profileDir.path),
        kundeId: customerId,
        leistungsdatum: '2026-03-10',
      );
      await useCases.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');
      return invoiceId;
    }

    test('standalone_export_uses_committed_snapshot_without_mutation', () async {
      final int invoiceId = await finalizePdfInvoice();
      final Map<String, Object?> before = await eInvoiceRow(db, invoiceId);
      // Live customer data changes after finalization; the export must still
      // represent the committed snapshot.
      await db.executor.runUpdate(
        'UPDATE kunden SET name = ?, strasse = ? WHERE id = (SELECT kunde_id FROM rechnungen WHERE id = ?)',
        <Object?>['Geänderte GmbH', 'Andere Straße 99', invoiceId],
      );

      final String? destination = await useCases.exportXRechnung(
        rechnungId: invoiceId,
        buyerReference: 'LEITWEG-123',
        service: eInvoiceTestService,
        saveDialog: ({required String extension, required String suggestedName}) async =>
            '${exportDir.path}/$suggestedName',
      );

      expect(destination, isNotNull);
      final String xml = File(destination!).readAsStringSync();
      expect(xml.contains('Kunde GmbH'), isTrue);
      expect(xml.contains('Geänderte GmbH'), isFalse);
      final Map<String, Object?> after = await eInvoiceRow(db, invoiceId);
      expect(after['rechnungsnummer'], before['rechnungsnummer']);
      expect(after['brutto_betrag'].toString(), before['brutto_betrag'].toString());
      expect(after['ist_entwurf'], 0);
      final int journals = (await db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).length;
      expect(journals, 1);
    });

    test('draft_invoice_rejects_export_without_changes', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(
        RechnungenDataSource(db.executor, profileDir: profileDir.path),
        kundeId: customerId,
      );
      var dialogOpened = false;

      await expectLater(
        useCases.exportXRechnung(
          rechnungId: invoiceId,
          buyerReference: 'LEITWEG-123',
          saveDialog: ({required String extension, required String suggestedName}) async {
            dialogOpened = true;
            return '${exportDir.path}/$suggestedName';
          },
        ),
        throwsA(predicate((error) => '$error'.contains('Entwürfe'))),
      );

      expect(dialogOpened, isFalse);
      expect(exportDir.listSync(), isEmpty);
      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['ist_entwurf'], 1);
    });

    test('saves_validated_xrechnung_atomically_without_invoice_mutation', () async {
      final int invoiceId = await finalizePdfInvoice();
      final Map<String, Object?> before = await eInvoiceRow(db, invoiceId);

      final String? destination = await useCases.exportXRechnung(
        rechnungId: invoiceId,
        buyerReference: 'LEITWEG-123',
        service: eInvoiceTestService,
        saveDialog: ({required String extension, required String suggestedName}) async =>
            '${exportDir.path}/$suggestedName',
      );

      expect(destination, endsWith('.xml'));
      final File file = File(destination!);
      expect(file.existsSync(), isTrue);
      final String xml = file.readAsStringSync();
      expect(xml.contains('<cbc:BuyerReference>LEITWEG-123</cbc:BuyerReference>'), isTrue);
      expect(xml.contains('xrechnung_3.0'), isTrue);
      expect(xml.contains('PDF'), isFalse);
      expect(exportDir.listSync().whereType<File>().where((entry) => entry.path.endsWith('.tmp')), isEmpty);
      final Map<String, Object?> after = await eInvoiceRow(db, invoiceId);
      expect(after['ausgabeformat'], before['ausgabeformat']);
      expect(after['original_pdf_pfad'], before['original_pdf_pfad']);
    });

    test('canceling_save_dialog_writes_no_file_and_changes_nothing', () async {
      final int invoiceId = await finalizePdfInvoice();
      final Map<String, Object?> before = await eInvoiceRow(db, invoiceId);

      final String? destination = await useCases.exportXRechnung(
        rechnungId: invoiceId,
        buyerReference: 'LEITWEG-123',
        service: eInvoiceTestService,
        saveDialog: ({required String extension, required String suggestedName}) async => null,
      );

      expect(destination, isNull);
      expect(exportDir.listSync(), isEmpty);
      final Map<String, Object?> after = await eInvoiceRow(db, invoiceId);
      expect(after['brutto_betrag'].toString(), before['brutto_betrag'].toString());
    });

    test('validation_failure_prevents_save_dialog_and_file_write', () async {
      final int invoiceId = await finalizePdfInvoice();
      var dialogOpened = false;

      // No buyer reference: the pinned XRechnung rule fails before any dialog.
      await expectLater(
        useCases.exportXRechnung(
          rechnungId: invoiceId,
          service: eInvoiceTestService,
          saveDialog: ({required String extension, required String suggestedName}) async {
            dialogOpened = true;
            return '${exportDir.path}/$suggestedName';
          },
        ),
        throwsA(isA<EInvoiceExportValidationException>()),
      );

      expect(dialogOpened, isFalse);
      expect(exportDir.listSync(), isEmpty);
    });

    test('offline_schema_failure_prevents_save_dialog_and_file_write', () async {
      final int invoiceId = await finalizePdfInvoice();
      var dialogOpened = false;
      final EInvoiceService service = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: invalidEInvoiceTestOfflineXmlValidation,
      );

      await expectLater(
        useCases.exportXRechnung(
          rechnungId: invoiceId,
          buyerReference: 'LEITWEG-123',
          service: service,
          saveDialog: ({required String extension, required String suggestedName}) async {
            dialogOpened = true;
            return '${exportDir.path}/$suggestedName';
          },
        ),
        throwsA(
          isA<EInvoiceExportValidationException>().having(
            (error) => error.offlineXmlResult?.diagnostics.single.code,
            'offline validator diagnostic',
            'SCHEMA_INVALID',
          ),
        ),
      );

      expect(dialogOpened, isFalse);
      expect(exportDir.listSync(), isEmpty);
    });

    test('offline_validator_unavailability_prevents_save_dialog_and_file_write', () async {
      final int invoiceId = await finalizePdfInvoice();
      var dialogOpened = false;
      final EInvoiceService service = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: unavailableEInvoiceTestOfflineXmlValidation,
      );

      await expectLater(
        useCases.exportXRechnung(
          rechnungId: invoiceId,
          buyerReference: 'LEITWEG-123',
          service: service,
          saveDialog: ({required String extension, required String suggestedName}) async {
            dialogOpened = true;
            return '${exportDir.path}/$suggestedName';
          },
        ),
        throwsA(
          isA<EInvoiceExportValidationException>()
              .having(
                (error) => error.offlineXmlResult?.status,
                'offline validator status',
                EInvoiceOfflineXmlValidationStatus.unavailable,
              )
              .having((error) => service.readiness(error.result), 'service readiness', EInvoiceReadiness.unavailable),
        ),
      );

      expect(dialogOpened, isFalse);
      expect(exportDir.listSync(), isEmpty);
    });
  });
}
