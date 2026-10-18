// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/documents/artifact_transaction.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';

import 'e_invoice_test_fixtures.dart';

int _indexOfBytes(List<int> bytes, List<int> needle) {
  for (int start = 0; start <= bytes.length - needle.length; start++) {
    bool matches = true;
    for (int offset = 0; offset < needle.length; offset++) {
      if (bytes[start + offset] != needle[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return start;
  }
  return -1;
}

Uint8List _extractCiiPayload(Uint8List pdfBytes, String ciiXml) {
  final List<int> expected = utf8.encode(ciiXml);
  final int start = _indexOfBytes(pdfBytes, expected);
  if (start < 0) throw StateError('Embedded CII payload was not found');
  return Uint8List.fromList(pdfBytes.sublist(start, start + expected.length));
}

int _declaredCiiSize(Uint8List pdfBytes, String ciiXml) {
  final List<int> expected = utf8.encode(ciiXml);
  final int start = _indexOfBytes(pdfBytes, expected);
  if (start < 0) throw StateError('Embedded CII payload was not found');
  final String prefix = latin1.decode(pdfBytes.sublist(0, start));
  final int paramsStart = prefix.lastIndexOf('/Params');
  if (paramsStart < 0) throw StateError('Embedded CII size dictionary was not found');
  final RegExpMatch? match = RegExp(r'/Params\s*<<\s*/Size\s+(\d+)').firstMatch(prefix.substring(paramsStart));
  if (match == null) throw StateError('Embedded CII size value was not found');
  return int.parse(match.group(1)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

    test('zugferd_pdf_generator_embeds_cii_as_facturx_attachment_with_pdfa_metadata', () async {
      const PdfDocumentSnapshot snapshot = PdfDocumentSnapshot(
        documentType: PdfDocumentType.rechnung,
        template: PdfTemplate.standard,
        documentNumber: 'RE-2026-001',
        company: PdfCompanySnapshot(name: 'Muster GmbH'),
        customer: PdfCustomerSnapshot(name: 'Kunde GmbH'),
        positions: <PdfPositionSnapshot>[
          PdfPositionSnapshot(
            description: 'Beratung',
            quantity: 1,
            unitPrice: 100,
            netAmount: 100,
            taxRate: 19,
            taxAmount: 19,
            grossAmount: 119,
          ),
        ],
        totals: PdfTotalsSnapshot(netAmount: 100, taxAmount: 19, grossAmount: 119),
      );
      const String ciiXml =
          '<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" '
          'xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100">'
          '<ram:Name>Berliner Straße ß</ram:Name></rsm:CrossIndustryInvoice>';

      final pdfBytes = await const PdfGenerator().generate(snapshot, locale: 'de_DE', zugferdCiiXml: ciiXml);
      final String pdfStructure = String.fromCharCodes(pdfBytes);
      final List<int> expectedCiiBytes = utf8.encode(ciiXml);

      expect(pdfStructure, contains('/EmbeddedFiles'));
      expect(pdfStructure, contains('/AFRelationship/Alternative'));
      expect(pdfStructure, contains('factur-x.xml'));
      expect(_extractCiiPayload(pdfBytes, ciiXml), expectedCiiBytes);
      expect(_declaredCiiSize(pdfBytes, ciiXml), expectedCiiBytes.length);
      expect(pdfStructure, contains('<fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>'));
      expect(pdfStructure, contains('<fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>'));
      expect(pdfStructure, contains('<pdfaid:part>3</pdfaid:part>'));
      expect(pdfStructure, contains('<pdfaid:conformance>B</pdfaid:conformance>'));
      expect(pdfStructure, contains('/DestOutputProfile'));
    });

    test('crash_recovery_removes_draft_and_orphan_zugferd_sidecars_but_keeps_finalized', () async {
      final int draftCustomerId = await addEInvoiceCustomer(db);
      final int draftInvoiceId = await createEInvoiceDraft(ds, kundeId: draftCustomerId);
      final int finalizedCustomerId = await addEInvoiceCustomer(db);
      final int finalizedInvoiceId = await createEInvoiceDraft(ds, kundeId: finalizedCustomerId);
      await ds.finalizeRechnung(rechnungId: finalizedInvoiceId, locale: 'de_DE', profileDir: profileDir);
      final Map<String, Object?> finalizedRow = await eInvoiceRow(db, finalizedInvoiceId);
      final File finalizedPdf = File(finalizedRow['original_pdf_pfad']! as String);

      const int missingInvoiceId = 999999;
      expect(
        await db.executor.runSelect('SELECT id FROM rechnungen WHERE id = ?', <Object?>[missingInvoiceId]),
        isEmpty,
      );

      final Directory documentsDir = Directory('${profileDir.path}/pdfs/documents')..createSync(recursive: true);
      final File draftSidecar = File('${documentsDir.path}/$draftInvoiceId.zugferd.xml')
        ..writeAsStringSync('<invoice>draft-crash</invoice>');
      final File draftSidecarTemp = File('${documentsDir.path}/$draftInvoiceId.zugferd.xml.tmp')
        ..writeAsStringSync('<invoice>partial</invoice>');
      final File orphanSidecar = File('${documentsDir.path}/$missingInvoiceId.zugferd.xml')
        ..writeAsStringSync('<invoice>no-row-crash</invoice>');
      final File orphanSidecarTemp = File('${documentsDir.path}/$missingInvoiceId.zugferd.xml.tmp')
        ..writeAsStringSync('<invoice>no-row-partial</invoice>');
      final File finalizedSidecar = File('${documentsDir.path}/$finalizedInvoiceId.zugferd.xml')
        ..writeAsStringSync('<invoice>finalized</invoice>');
      final File finalizedSidecarTemp = File('${documentsDir.path}/$finalizedInvoiceId.zugferd.xml.tmp')
        ..writeAsStringSync('<invoice>finalized-temp</invoice>');
      final File unrelated = File('${documentsDir.path}/notizen.txt')..writeAsStringSync('keep');

      final ({int removed, List<String> broken}) recovery = await ArtifactRecovery.reconcileAtStartup(
        db.executor,
        profileDir.path,
      );
      expect(recovery.removed, 4);
      expect(recovery.broken, isEmpty);
      expect(finalizedPdf.existsSync(), isTrue);
      expect(draftSidecar.existsSync(), isFalse);
      expect(draftSidecarTemp.existsSync(), isFalse);
      expect(orphanSidecar.existsSync(), isFalse);
      expect(orphanSidecarTemp.existsSync(), isFalse);
      expect(finalizedSidecar.existsSync(), isTrue);
      expect(finalizedSidecarTemp.existsSync(), isTrue);
      expect(unrelated.existsSync(), isTrue);

      const String ciiXml = '<invoice>retry</invoice>';
      final File retriedSidecar = await const ArtifactTransaction().writeArtifact(
        directory: documentsDir,
        baseName: '$draftInvoiceId.zugferd.xml',
        stagingName: '$draftInvoiceId.zugferd.xml.tmp',
        bytes: utf8.encode(ciiXml),
      );

      expect(retriedSidecar.path, draftSidecar.path);
      expect(draftSidecar.readAsStringSync(), ciiXml);
      expect(draftSidecarTemp.existsSync(), isFalse);
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

    test('zugferd_validator_unavailable_prevents_any_finalization_side_effects', () async {
      final int articleId = (await db.artikelRepository.create(
        bezeichnung: 'Lagerartikel',
        vkBrutto: 119,
        lagerAktiv: true,
        bestandAktuell: 10,
      )).id;
      final int customerId = await addEInvoiceCustomer(db, zugferdAktiv: true);
      final int invoiceId = await createEInvoiceDraft(ds, kundeId: customerId);
      await db.executor.runUpdate('UPDATE rechnungspositionen SET artikel_id = ? WHERE rechnung_id = ?', <Object?>[
        articleId,
        invoiceId,
      ]);

      final Map<String, Object?> invoiceBefore = await eInvoiceRow(db, invoiceId);
      final int sequenceBefore = await eInvoiceSequence(db);
      final List<Map<String, Object?>> stockBefore = await db.executor.runSelect(
        'SELECT bestand, bestand_aktuell, lager_aktiv FROM artikel WHERE id = ?',
        <Object?>[articleId],
      );
      Future<int> rowCount(String tableName) async {
        final List<Map<String, Object?>> rows = await db.executor.runSelect(
          'SELECT COUNT(*) AS row_count FROM $tableName',
          const <Object?>[],
        );
        return (rows.single['row_count']! as num).toInt();
      }

      const List<String> tables = <String>['journal', 'forderungen', 'vorsteuer_ansprueche', 'inventarbewegungen'];
      final Map<String, int> countsBefore = <String, int>{};
      for (final String table in tables) {
        countsBefore[table] = await rowCount(table);
      }

      final EInvoiceService unavailableService = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: unavailableEInvoiceTestOfflineXmlValidation,
      );
      final RechnungenDataSource unavailableDataSource = RechnungenDataSource(
        db.executor,
        eInvoiceService: unavailableService,
      );
      final Directory documentsDir = Directory('${profileDir.path}/pdfs/documents');
      expect(documentsDir.existsSync(), isFalse);

      await expectLater(
        unavailableDataSource.finalizeRechnung(
          rechnungId: invoiceId,
          locale: 'de_DE',
          profileDir: profileDir,
          ausgabeformat: 'zugferd',
        ),
        throwsA(
          isA<EInvoiceExportValidationException>().having(
            (error) => error.result.status,
            'validation status',
            EInvoiceValidationStatus.unavailable,
          ),
        ),
      );

      expect(await eInvoiceRow(db, invoiceId), invoiceBefore);
      expect(await eInvoiceSequence(db), sequenceBefore);
      expect(
        await db.executor.runSelect('SELECT bestand, bestand_aktuell, lager_aktiv FROM artikel WHERE id = ?', <Object?>[
          articleId,
        ]),
        stockBefore,
      );
      for (final String table in tables) {
        expect(await rowCount(table), countsBefore[table], reason: '$table must remain unchanged');
      }
      expect(documentsDir.existsSync(), isFalse);
      expect(await eInvoiceArtifacts(profileDir, invoiceId), isEmpty);
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
