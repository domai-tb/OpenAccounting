// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_offline_xml_validator.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
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
      await _ensureTaxEvidenceColumns(db);
      await _setTaxEvidence(db, invoiceId, treatment: 'standard_19', legalBasis: 'ustg_12_1', category: 'S');
      await useCases.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');
      return invoiceId;
    }

    Future<int> finalizeSection25aPdfInvoice({required bool includeTaxEvidence}) async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(
        RechnungenDataSource(db.executor, profileDir: profileDir.path),
        kundeId: customerId,
        leistungsdatum: '2026-03-10',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Differenzbesteuerte Ware',
            menge: 1,
            einzelpreis: 107.60,
            gesamt: 107.60,
            ustSatz: 0,
            position: 8,
          ),
        ],
      );
      if (includeTaxEvidence) {
        await _ensureTaxEvidenceColumns(db);
        await _setTaxEvidence(
          db,
          invoiceId,
          treatment: 'margin_scheme_25a_second_hand',
          legalBasis: 'ustg_25a',
          category: 'E',
          reasonCode: 'VATEX-EU-F',
          reasonText: 'Gebrauchtgegenstände/Sonderregelung',
        );
      }
      await useCases.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');
      return invoiceId;
    }

    Future<int> finalizeCrossBorderPdfInvoice({
      required String buyerCountry,
      String? buyerVatId,
      required RechnungPositionTaxEvidence taxEvidence,
    }) async {
      final int customerId = await addEInvoiceCustomer(db, country: buyerCountry);
      if (buyerVatId != null) {
        await db.executor.runUpdate('UPDATE kunden SET ust_idnr = ? WHERE id = ?', <Object?>[buyerVatId, customerId]);
      }
      final int invoiceId = await createEInvoiceDraft(
        RechnungenDataSource(db.executor, profileDir: profileDir.path),
        kundeId: customerId,
        leistungsdatum: '2026-03-10',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Exportware',
            menge: 1,
            einzelpreis: 100,
            gesamt: 100,
            ustSatz: 0,
            position: 13,
            taxEvidence: taxEvidence,
          ),
        ],
      );
      final List<Map<String, Object?>> savedTaxEvidence = await db.executor.runSelect(
        'SELECT tax_treatment, tax_legal_basis, e_invoice_tax_category_code, '
        'e_invoice_exemption_reason_code, e_invoice_exemption_reason_text '
        'FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      );
      expect(savedTaxEvidence, hasLength(1));
      expect(savedTaxEvidence.single['tax_treatment'], taxEvidence.taxTreatment);
      expect(savedTaxEvidence.single['tax_legal_basis'], taxEvidence.taxLegalBasis);
      expect(savedTaxEvidence.single['e_invoice_tax_category_code'], taxEvidence.eInvoiceTaxCategoryCode);
      expect(savedTaxEvidence.single['e_invoice_exemption_reason_code'], taxEvidence.eInvoiceExemptionReasonCode);
      expect(savedTaxEvidence.single['e_invoice_exemption_reason_text'], taxEvidence.eInvoiceExemptionReasonText);
      await useCases.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');
      final List<Map<String, Object?>> finalizedTaxEvidence = await db.executor.runSelect(
        'SELECT tax_treatment, tax_legal_basis, e_invoice_tax_category_code, '
        'e_invoice_exemption_reason_code, e_invoice_exemption_reason_text '
        'FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      );
      expect(finalizedTaxEvidence, savedTaxEvidence);
      return invoiceId;
    }

    Future<int> finalizeDiscountedPdfInvoice() async {
      final int customerId = await addEInvoiceCustomer(db);
      final int invoiceId = await createEInvoiceDraft(
        RechnungenDataSource(db.executor, profileDir: profileDir.path),
        kundeId: customerId,
        leistungsdatum: '2026-03-10',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Beratung',
            menge: 1,
            einzelpreis: 100,
            gesamt: 90,
            position: 4,
            rabattProzent: 10,
          ),
        ],
      );
      await _ensureTaxEvidenceColumns(db);
      await _setTaxEvidence(db, invoiceId, treatment: 'standard_19', legalBasis: 'ustg_12_1', category: 'S');
      await useCases.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');
      return invoiceId;
    }

    Future<FinalizationSnapshot> readCommittedSnapshot(int invoiceId) {
      return RechnungenDataSource(db.executor, profileDir: profileDir.path).readCommittedEInvoiceSnapshot(invoiceId);
    }

    Future<void> seedCopyTaxEvidence(int invoiceId) async {
      const List<String> columns = RechnungPositionTaxEvidence.databaseColumns;
      final List<Object?> values = List<Object?>.generate(
        columns.length,
        (int index) => columns[index] == 'e_invoice_intra_community_acquisition_tax_treatment'
            ? 'subject_to_destination_member_state_acquisition_vat_rules'
            : index.isEven
            ? '${columns[index]}-value'
            : null,
      );
      final String assignments = columns.map((String column) => '$column = ?').join(', ');
      await db.executor.runUpdate('UPDATE rechnungspositionen SET $assignments WHERE rechnung_id = ?', <Object?>[
        ...values,
        invoiceId,
      ]);
    }

    Future<Map<String, Object?>> readCopyTaxEvidence(int invoiceId) async {
      final String columns = RechnungPositionTaxEvidence.databaseColumns.join(', ');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT $columns FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      );
      expect(rows, hasLength(1));
      return rows.single;
    }

    test('replacement_invoice_copies_all_nullable_e_invoice_tax_evidence', () async {
      final RechnungenDataSource dataSource = RechnungenDataSource(db.executor, profileDir: profileDir.path);
      final int sourceId = await createEInvoiceDraft(dataSource, kundeId: await addEInvoiceCustomer(db));
      await seedCopyTaxEvidence(sourceId);
      await db.executor.runUpdate('UPDATE rechnungen SET status = ?, storno_datum = ? WHERE id = ?', <Object?>[
        'storniert',
        '2026-03-15',
        sourceId,
      ]);

      final int replacementId = await dataSource.createErsatzRechnung(vonRechnungId: sourceId);

      expect(await readCopyTaxEvidence(replacementId), await readCopyTaxEvidence(sourceId));
    });

    test('invoice_conversion_copies_all_nullable_e_invoice_tax_evidence', () async {
      final RechnungenDataSource dataSource = RechnungenDataSource(db.executor, profileDir: profileDir.path);
      final int sourceId = await createEInvoiceDraft(dataSource, kundeId: await addEInvoiceCustomer(db));
      await seedCopyTaxEvidence(sourceId);
      await db.executor.runUpdate('UPDATE rechnungen SET typ = ? WHERE id = ?', <Object?>['angebot', sourceId]);

      final int convertedId = await dataSource.konvertiereDokument(quelleId: sourceId, zielTyp: 'rechnung');

      expect(await readCopyTaxEvidence(convertedId), await readCopyTaxEvidence(sourceId));
    });

    test('draft_position_roundtrips_nullable_e_invoice_tax_evidence', () async {
      final int customerId = await addEInvoiceCustomer(db);
      const RechnungPositionTaxEvidence initialEvidence = RechnungPositionTaxEvidence(
        taxTreatment: 'standard_19',
        taxLegalBasis: 'ustg_12_1',
        eInvoiceTaxCategoryCode: 'S',
        eInvoiceReverseChargeServiceKind: 'not_applicable',
      );
      final int invoiceId = await createEInvoiceDraft(
        RechnungenDataSource(db.executor, profileDir: profileDir.path),
        kundeId: customerId,
        positionen: <RechnungPositionItem>[
          const RechnungPositionItem(
            bezeichnung: 'Beratung',
            menge: 1,
            einzelpreis: 100,
            gesamt: 100,
            taxEvidence: initialEvidence,
          ),
        ],
      );

      final RechnungItem? loaded = await useCases.findById(invoiceId);
      expect(loaded?.positionen.single.taxEvidence?.taxTreatment, 'standard_19');
      expect(loaded?.positionen.single.taxEvidence?.eInvoiceTaxCategoryCode, 'S');
      expect(loaded?.positionen.single.taxEvidence?.eInvoiceReverseChargeServiceKind, 'not_applicable');
      expect(loaded?.positionen.single.taxEvidence?.eInvoiceExportMovementActor, isNull);

      final RechnungItem updated = await useCases.updateDraftRechnung(
        rechnungId: invoiceId,
        datum: '2026-03-15',
        positionen: <RechnungPositionItem>[
          const RechnungPositionItem(
            bezeichnung: 'Beratung',
            menge: 1,
            einzelpreis: 100,
            gesamt: 100,
            taxEvidence: RechnungPositionTaxEvidence(
              taxTreatment: 'standard_19',
              taxLegalBasis: 'ustg_12_1',
              eInvoiceTaxCategoryCode: 'S',
              eInvoiceExemptionReasonText: 'captured-on-draft',
            ),
          ),
        ],
      );

      expect(updated.positionen.single.taxEvidence?.eInvoiceExemptionReasonText, 'captured-on-draft');
      expect(updated.positionen.single.taxEvidence?.eInvoiceReverseChargeServiceKind, isNull);
    });

    test('committed_reader_preserves_persisted_line_allowance_basis', () async {
      final int invoiceId = await finalizeDiscountedPdfInvoice();

      final FinalizationSnapshot snapshot = await readCommittedSnapshot(invoiceId);
      final EInvoiceLineSnapshot line = snapshot.lines.single;

      expect(line.position, 4);
      expect(line.netCents, 9000);
      expect(line.taxCents, 1710);
      expect(line.grossCents, 10710);
      expect(line.netUnitPriceText, '100.0000');
      expect(line.lineAllowance?.amountCents, 1000);
      expect(line.lineAllowance?.baseAmountCents, 10000);
      expect(line.lineAllowance?.percentHundredths, 1000);
      expect(snapshot.netCents, 9000);
      expect(snapshot.taxCents, 1710);
      expect(snapshot.grossCents, 10710);
    });

    test('committed_reader_preserves_persisted_25a_payable_amount', () async {
      final int invoiceId = await finalizeSection25aPdfInvoice(includeTaxEvidence: true);

      final FinalizationSnapshot snapshot = await readCommittedSnapshot(invoiceId);

      expect(snapshot.lines.single.position, 8);
      expect(snapshot.lines.single.netCents, 10760);
      expect(snapshot.lines.single.taxCents, 0);
      expect(snapshot.lines.single.grossCents, 10760);
      expect(snapshot.netCents, 10760);
      expect(snapshot.taxCents, 0);
      expect(snapshot.grossCents, 10760);
      expect(snapshot.taxBreakdowns.single.netCents, 10760);
      expect(snapshot.taxBreakdowns.single.taxCents, 0);
    });

    test('committed_reader_fails_closed_when_tax_evidence_is_absent', () async {
      final int invoiceId = await finalizeSection25aPdfInvoice(includeTaxEvidence: false);

      await expectLater(
        readCommittedSnapshot(invoiceId),
        throwsA(
          isA<EInvoiceSourceException>()
              .having((error) => error.code, 'error code', 'unresolvedTaxClassification')
              .having((error) => error.fields, 'missing evidence fields', contains('position[0].tax_treatment')),
        ),
      );
    });

    test('committed_reader_fails_closed_for_missing_or_unverified_6a_acquisition_tax_treatment', () async {
      for (final String? acquisitionTreatment in <String?>[
        null,
        'unknown',
        'not_subject_to_destination_member_state_acquisition_vat_rules',
      ]) {
        final int invoiceId = await finalizeCrossBorderPdfInvoice(
          buyerCountry: 'FR',
          buyerVatId: 'FR12345678901',
          taxEvidence: RechnungPositionTaxEvidence(
            taxTreatment: 'intra_community_supply_6a',
            taxLegalBasis: 'ustg_4_1b_6a',
            eInvoiceTaxCategoryCode: 'K',
            eInvoiceExemptionReasonCode: 'VATEX-EU-IC',
            eInvoiceExemptionReasonText: 'Steuerfreie innergemeinschaftliche Lieferung',
            eInvoiceIntraCommunityDestinationCountryIso: 'FR',
            eInvoiceIntraCommunityAcquisitionTaxTreatment: acquisitionTreatment,
            eInvoiceIntraCommunitySupplyEvidenceSourceRef: 'assessment-1',
          ),
        );

        await expectLater(
          readCommittedSnapshot(invoiceId),
          throwsA(
            isA<EInvoiceSourceException>()
                .having((error) => error.code, 'error code', 'incompleteCrossBorderTaxEvidence')
                .having(
                  (error) => error.fields,
                  'position diagnostics',
                  contains('position[13].e_invoice_intra_community_acquisition_tax_treatment'),
                ),
          ),
        );
      }
    });

    test('committed_reader_projects_valid_6a_fields_but_keeps_resolver_fail_closed', () async {
      final int invoiceId = await finalizeCrossBorderPdfInvoice(
        buyerCountry: 'FR',
        buyerVatId: 'FR12345678901',
        taxEvidence: const RechnungPositionTaxEvidence(
          taxTreatment: 'intra_community_supply_6a',
          taxLegalBasis: 'ustg_4_1b_6a',
          eInvoiceTaxCategoryCode: 'K',
          eInvoiceExemptionReasonCode: 'VATEX-EU-IC',
          eInvoiceExemptionReasonText: 'Steuerfreie innergemeinschaftliche Lieferung',
          eInvoiceIntraCommunityDestinationCountryIso: 'FR',
          eInvoiceIntraCommunityAcquisitionTaxTreatment: 'subject_to_destination_member_state_acquisition_vat_rules',
          eInvoiceIntraCommunitySupplyEvidenceSourceRef: 'assessment-1',
        ),
      );
      final List<Map<String, Object?>> acquisitionStatusRows = await db.executor.runSelect(
        'SELECT e_invoice_intra_community_acquisition_tax_treatment FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      );
      expect(acquisitionStatusRows, hasLength(1));
      expect(
        acquisitionStatusRows.single['e_invoice_intra_community_acquisition_tax_treatment'],
        'subject_to_destination_member_state_acquisition_vat_rules',
      );

      await expectLater(
        readCommittedSnapshot(invoiceId),
        throwsA(
          isA<EInvoiceSourceException>()
              .having((error) => error.code, 'error code', 'incompleteCrossBorderTaxEvidence')
              .having(
                (error) => error.fields,
                'line-bound resolver diagnostic',
                allOf(
                  contains('position[13].e_invoice_intra_community_supply_evidence_source_ref'),
                  contains('position[13].e_invoice_intra_community_acquisition_tax_treatment'),
                  isNot(contains('position[13].e_invoice_intra_community_destination_country_iso')),
                ),
              ),
        ),
      );
    });

    test('committed_reader_fails_closed_for_unknown_6_export_movement_actor', () async {
      final int invoiceId = await finalizeCrossBorderPdfInvoice(
        buyerCountry: 'CH',
        taxEvidence: const RechnungPositionTaxEvidence(
          taxTreatment: 'export_supply_6',
          taxLegalBasis: 'ustg_4_1a_6',
          eInvoiceTaxCategoryCode: 'G',
          eInvoiceExemptionReasonCode: 'VATEX-EU-G',
          eInvoiceExportDestinationCountryIso: 'CH',
          eInvoiceExportMovementActor: 'unknown',
          eInvoiceExportEvidenceSourceRef: 'export-proof-1',
        ),
      );

      await expectLater(
        readCommittedSnapshot(invoiceId),
        throwsA(
          isA<EInvoiceSourceException>()
              .having((error) => error.code, 'error code', 'incompleteCrossBorderTaxEvidence')
              .having(
                (error) => error.fields,
                'position diagnostics',
                contains('position[13].e_invoice_export_movement_actor'),
              ),
        ),
      );
    });

    test('committed_reader_projects_valid_6_export_fields_but_keeps_resolver_fail_closed', () async {
      final int invoiceId = await finalizeCrossBorderPdfInvoice(
        buyerCountry: 'CH',
        taxEvidence: const RechnungPositionTaxEvidence(
          taxTreatment: 'export_supply_6',
          taxLegalBasis: 'ustg_4_1a_6',
          eInvoiceTaxCategoryCode: 'G',
          eInvoiceExemptionReasonCode: 'VATEX-EU-G',
          eInvoiceExportDestinationCountryIso: 'CH',
          eInvoiceExportMovementActor: 'supplier_or_supplier_agent',
          eInvoiceExportEvidenceSourceRef: 'export-proof-1',
        ),
      );

      await expectLater(
        readCommittedSnapshot(invoiceId),
        throwsA(
          isA<EInvoiceSourceException>()
              .having((error) => error.code, 'error code', 'incompleteCrossBorderTaxEvidence')
              .having(
                (error) => error.fields,
                'line-bound resolver diagnostic',
                allOf(
                  contains('position[13].e_invoice_export_evidence_source_ref'),
                  isNot(contains('position[13].e_invoice_export_destination_country_iso')),
                  isNot(contains('position[13].e_invoice_export_movement_actor')),
                ),
              ),
        ),
      );
    });

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

Future<void> _ensureTaxEvidenceColumns(AppDatabase db) async {
  const List<String> columns = <String>[
    'tax_treatment',
    'tax_legal_basis',
    'e_invoice_tax_category_code',
    'e_invoice_exemption_reason_code',
    'e_invoice_exemption_reason_text',
  ];
  final List<Map<String, Object?>> schema = await db.executor.runSelect(
    'PRAGMA table_info(rechnungspositionen)',
    const <Object?>[],
  );
  final Set<String> existing = <String>{
    for (final Map<String, Object?> column in schema) column['name']?.toString() ?? '',
  };
  for (final String column in columns) {
    if (existing.contains(column)) continue;
    await db.executor.runCustom('ALTER TABLE rechnungspositionen ADD COLUMN $column TEXT');
  }
}

Future<void> _setTaxEvidence(
  AppDatabase db,
  int invoiceId, {
  required String treatment,
  required String legalBasis,
  required String category,
  String? reasonCode,
  String? reasonText,
}) async {
  final int updated = await db.executor.runUpdate(
    'UPDATE rechnungspositionen SET tax_treatment = ?, tax_legal_basis = ?, e_invoice_tax_category_code = ?, '
    'e_invoice_exemption_reason_code = ?, e_invoice_exemption_reason_text = ? WHERE rechnung_id = ?',
    <Object?>[treatment, legalBasis, category, reasonCode, reasonText, invoiceId],
  );
  if (updated != 1) throw StateError('Expected to update one synthetic tax-evidence row, updated $updated');
}
