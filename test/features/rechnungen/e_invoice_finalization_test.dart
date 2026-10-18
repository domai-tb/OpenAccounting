// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';

import 'e_invoice_test_fixtures.dart';

void main() {
  group('Document lifecycle finalization with output format', () {
    late AppDatabase db;
    late RechnungenDataSource ds;
    late Directory profileDir;

    setUp(() async {
      db = await openEInvoiceDatabase();
      profileDir = await Directory.systemTemp.createTemp('e-invoice-finalization-');
      ds = RechnungenDataSource(db.executor, eInvoiceService: eInvoiceTestService);
    });

    tearDown(() async {
      await db.close();
      if (profileDir.existsSync()) profileDir.deleteSync(recursive: true);
    });

    test('finalization_assigns_number_locks_fields_persists_format_and_stores_pdf', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir);

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['rechnungsnummer'], isNotNull);
      expect(row['ist_entwurf'], 0);
      expect(row['ausgabeformat'], 'pdf');
      final String pdfPath = row['original_pdf_pfad']! as String;
      expect(File(pdfPath).existsSync(), isTrue);
      // Locked fields reject direct edits after finalization.
      await expectLater(
        db.executor.runUpdate('UPDATE rechnungen SET datum = ? WHERE id = ?', <Object?>['2026-04-01', invoiceId]),
        throwsA(predicate((error) => '$error'.contains('finalisiert'))),
      );
    });

    test('finalized_pdf_uses_captured_company_snapshot', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir);

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect((row['absender_snapshot']! as String).contains('Musterstraße 1'), isTrue);
      await db.executor.runUpdate('UPDATE unternehmen SET strasse = ?', const <Object?>['Neue Straße 9']);
      final Map<String, Object?> after = await eInvoiceRow(db, invoiceId);
      expect((after['absender_snapshot']! as String).contains('Musterstraße 1'), isTrue);
      final String pdfText = String.fromCharCodes(File(row['original_pdf_pfad']! as String).readAsBytesSync());
      expect(pdfText.contains('Musterstra'), isTrue);
    });

    test('rejects_finalization_of_already_finalized_invoice', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);
      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir);

      await expectLater(
        ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir),
        throwsA(predicate((error) => '$error'.contains('Dokument ist bereits finalisiert'))),
      );
    });

    test('legacy_finalized_invoice_resolves_missing_format_to_pdf', () async {
      final int legacyId = await db.executor.runInsert(
        "INSERT INTO rechnungen (typ, status, datum, ist_entwurf) VALUES ('rechnung', 'offen', '2026-02-01', 0)",
        const <Object?>[],
      );

      final Map<String, Object?> row = await eInvoiceRow(db, legacyId);
      expect(row['ausgabeformat'], isNull);
      final invoice = await ds.findRechnungById(legacyId);
      expect(invoice, isNotNull);
      expect(parseEInvoiceOutputFormat(invoice!['ausgabeformat']), EInvoiceOutputFormat.pdf);
    });

    test('zugferd_finalization_stores_validated_hybrid_and_readiness', () async {
      final int customerId = await addEInvoiceCustomer(db, zugferdAktiv: true);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);

      await ds.finalizeRechnung(
        rechnungId: invoiceId,
        locale: 'de_DE',
        profileDir: profileDir,
        ausgabeformat: 'zugferd',
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['ausgabeformat'], 'zugferd');
      expect(File(row['original_pdf_pfad']! as String).existsSync(), isTrue);
      final File xml = File('${profileDir.path}/pdfs/documents/$invoiceId.zugferd.xml');
      expect(xml.existsSync(), isTrue);
      final String content = xml.readAsStringSync();
      expect(content.contains('CrossIndustryInvoice'), isTrue);
      expect(content.contains('urn:cen.eu:en16931:2017'), isTrue);
      expect(content.contains(row['rechnungsnummer']! as String), isTrue);
    });

    test('pdf_selection_does_not_embed_zugferd_xml', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir);

      expect(File('${profileDir.path}/pdfs/documents/$invoiceId.zugferd.xml').existsSync(), isFalse);
      expect(File('${profileDir.path}/pdfs/documents/$invoiceId.pdf').existsSync(), isTrue);
    });

    test('invalid_zugferd_data_blocks_finalization_without_side_effects', () async {
      // Buyer with a blank street address violates the pinned profile.
      final int customerId = await addEInvoiceCustomer(db, street: '');
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);
      final int sequenceBefore = await eInvoiceSequence(db);

      await expectLater(
        ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir, ausgabeformat: 'zugferd'),
        throwsA(anything),
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['ist_entwurf'], 1);
      expect(row['rechnungsnummer'], isNull);
      expect(await eInvoiceSequence(db), sequenceBefore);
      expect(await eInvoiceArtifacts(profileDir, invoiceId), isEmpty);
    });

    test('pdf_and_cii_match_the_snapshot_and_committed_invoice', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);
      await ds.finalizeRechnung(
        rechnungId: invoiceId,
        locale: 'de_DE',
        profileDir: profileDir,
        ausgabeformat: 'zugferd',
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect((row['netto_betrag']! as num).toDouble(), 200.0);
      expect((row['ust_betrag']! as num).toDouble(), 38.0);
      expect((row['brutto_betrag']! as num).toDouble(), 238.0);
      final String xml = File('${profileDir.path}/pdfs/documents/$invoiceId.zugferd.xml').readAsStringSync();
      expect(xml.contains('<ram:LineTotalAmount>200.00</ram:LineTotalAmount>'), isTrue);
      expect(xml.contains('<ram:GrandTotalAmount>238.00</ram:GrandTotalAmount>'), isTrue);
      final String pdfText = String.fromCharCodes(File(row['original_pdf_pfad']! as String).readAsBytesSync());
      expect(pdfText.contains('Beratung'), isTrue);
    });

    test('output_failure_rolls_back_number_status_stock_and_artifacts', () async {
      final int articleId = (await db.artikelRepository.create(
        bezeichnung: 'Lagerartikel',
        vkBrutto: 119,
        lagerAktiv: true,
        bestandAktuell: 10,
      )).id;
      final int customerId = await addEInvoiceCustomer(db, street: null);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);
      await db.executor.runUpdate('UPDATE rechnungspositionen SET artikel_id = ? WHERE rechnung_id = ?', <Object?>[
        articleId,
        invoiceId,
      ]);
      final int sequenceBefore = await eInvoiceSequence(db);

      await expectLater(
        ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir, ausgabeformat: 'zugferd'),
        throwsA(anything),
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['ist_entwurf'], 1);
      expect(row['rechnungsnummer'], isNull);
      expect(await eInvoiceSequence(db), sequenceBefore);
      final List<Map<String, Object?>> stock = await db.executor.runSelect(
        'SELECT bestand_aktuell FROM artikel WHERE id = ?',
        <Object?>[articleId],
      );
      expect((stock.single['bestand_aktuell']! as num).toDouble(), 10.0);
      expect(await eInvoiceArtifacts(profileDir, invoiceId), isEmpty);
    });

    test('stores_validated_hybrid_pdf_and_references_artifact', () async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);
      await ds.finalizeRechnung(
        rechnungId: invoiceId,
        locale: 'de_DE',
        profileDir: profileDir,
        ausgabeformat: 'zugferd',
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      final String pdfPath = row['original_pdf_pfad']! as String;
      expect(pdfPath.endsWith('$invoiceId.pdf'), isTrue);
      expect(File(pdfPath).existsSync(), isTrue);
      final String xml = File('${profileDir.path}/pdfs/documents/$invoiceId.zugferd.xml').readAsStringSync();
      expect(xml.contains('<ram:TaxTotalAmount currencyID="EUR">38.00</ram:TaxTotalAmount>'), isTrue);
    });

    test('explicit_non_zugferd_choice_generates_non_hybrid_pdf', () async {
      final int customerId = await addEInvoiceCustomer(db, zugferdAktiv: true);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);

      // Customer default prefers ZUGFeRD; the explicit PDF choice wins.
      await ds.finalizeRechnung(
        rechnungId: invoiceId,
        locale: 'de_DE',
        profileDir: profileDir,
        ausgabeformat: 'pdf', // ignore: avoid_redundant_argument_values
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['ausgabeformat'], 'pdf');
      expect(File('${profileDir.path}/pdfs/documents/$invoiceId.zugferd.xml').existsSync(), isFalse);
    });

    test('zugferd_validation_failure_rolls_back_finalization_and_temp_files', () async {
      final int customerId = await addEInvoiceCustomer(db, street: null);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);

      await expectLater(
        ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir, ausgabeformat: 'zugferd'),
        throwsA(anything),
      );

      final Map<String, Object?> row = await eInvoiceRow(db, invoiceId);
      expect(row['ist_entwurf'], 1);
      expect(await eInvoiceArtifacts(profileDir, invoiceId), isEmpty);
      final Directory documents = Directory('${profileDir.path}/pdfs/documents');
      final List<File> leftovers = documents.existsSync()
          ? documents.listSync().whereType<File>().where((file) => file.path.endsWith('.tmp')).toList()
          : <File>[];
      expect(leftovers, isEmpty);
    });
  });
}
