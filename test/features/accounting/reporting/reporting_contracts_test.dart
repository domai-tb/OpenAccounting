import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/accounting/reporting/euer_report_use_case.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

void main() {
  group('reporting contracts: EÜR workspace', () {
    late AppDatabase db;
    late EuerReportUseCase useCase;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      useCase = EuerReportUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertKategorie({required int id, required int zeile, String bezeichnung = 'Test Kategorie'}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[id, bezeichnung, '800$zeile', '400$zeile', zeile, 'catalog_verified', 'TEST-EUER', '2025-form.1'],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String art = 'Einnahme',
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, art],
      );
    }

    test('test_e_r_zeile_12_kleinunternehmer_19', () async {
      await insertKategorie(id: 921, zeile: 12, bezeichnung: 'Kleinunternehmer §19');
      await insertJournal(kategorieId: 921, betrag: '1000.00', datum: '2025-02-15');
      await insertJournal(kategorieId: 921, betrag: '500.50', datum: '2025-06-01');

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      final EuerPreview preview = result.value!;
      // 2025 field mapping displays the sum of eligible recognized amounts.
      expect(preview.zeile(12), '1500.50');
      // The result records the 2025 form and source versions.
      expect(preview.formVersion, 'anlage-euer-2025');
      expect(preview.sourceVersions['TEST-EUER'], '2025-form.1');
    });

    test('test_e_r_zeile_15_umsatzsteuerpflichtige_betriebseinnahmen', () async {
      await insertKategorie(id: 922, zeile: 15, bezeichnung: 'Ust-pflichtig');
      await insertJournal(kategorieId: 922, betrag: '2000.00', datum: '2025-03-10');
      await insertJournal(kategorieId: 922, betrag: '300.00', datum: '2025-04-20');

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.zeile(15), '2300.00');
    });

    test('test_e_r_zeile_16_steuerfreie_betriebseinnahmen_4', () async {
      await insertKategorie(id: 923, zeile: 16, bezeichnung: 'Steuerfrei §4');
      await insertJournal(kategorieId: 923, betrag: '750.25', datum: '2025-05-05');

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.zeile(16), '750.25');
    });

    test('test_e_r_zeile_33_abschreibungen_afa', () async {
      await insertKategorie(id: 924, zeile: 33, bezeichnung: 'AfA Kategorie');
      // Journal entry for line 33 must not substitute the fixed-asset source.
      await insertJournal(kategorieId: 924, betrag: '9999.99', datum: '2025-07-01');
      // Anlageverzeichnis: 1200 / 3 = 400.00 linear, no privat.
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'privatanteil, status, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, '
        'privat_anteil_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Laptop', '2022-01-01', '1200.00', 3, '0', 'aktiv', 'EDV', '1200.00', 3, 'linear', '0'],
      );

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.zeile(33), '400.00');
      expect(result.value!.zeile(33) != '9999.99', isTrue);
    });

    test('test_e_r_zeile_60_sonstige_betriebsausgaben', () async {
      await insertKategorie(id: 925, zeile: 60, bezeichnung: 'Sonstige Betriebsausgaben');
      await insertJournal(kategorieId: 925, betrag: '420.00', datum: '2025-08-12', art: 'Ausgabe');

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.zeile(60), '420.00');
    });

    test('test_e_r_zeile_106_107_privatentnahme_privateinlage', () async {
      await insertKategorie(id: 926, zeile: 12, bezeichnung: 'Einnahme');
      await insertKategorie(id: 927, zeile: 60, bezeichnung: 'Ausgabe');
      await insertKategorie(id: 928, zeile: 106, bezeichnung: 'Privatentnahme');
      await insertKategorie(id: 929, zeile: 107, bezeichnung: 'Privateinlage');
      await insertJournal(kategorieId: 926, betrag: '1000.00', datum: '2025-01-10');
      await insertJournal(kategorieId: 927, betrag: '200.00', datum: '2025-02-10', art: 'Ausgabe');
      await insertJournal(kategorieId: 928, betrag: '500.00', datum: '2025-03-10', art: 'Ausgabe');
      await insertJournal(kategorieId: 929, betrag: '300.00', datum: '2025-04-10');

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      final EuerPreview preview = result.value!;
      // Hinweiszeilen are visible but excluded from Gewinn.
      expect(preview.hinweise[106], '500.00');
      expect(preview.hinweise[107], '300.00');
      expect(preview.gewinn, '800.00');
    });

    test('test_vorsteuerabzug_soll_prinzip', () async {
      // Configured accepted cutover at the 2025 period start.
      await db.executor.runCustom('ALTER TABLE unternehmen ADD COLUMN euer_cutover_datum TEXT', const <Object?>[]);
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO unternehmen (id, name, euer_cutover_datum) VALUES (1, ?, ?)',
        <Object?>['Testfirma', '2025-01-01'],
      );
      // Soll input tax from vorsteuer_ansprueche: 190 + 19 = 209.
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status) VALUES (?, ?, ?)',
        <Object?>['190.00', '2025-03-15', 'offen'],
      );
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status) VALUES (?, ?, ?)',
        <Object?>['19.00', '2025-04-10', 'offen'],
      );
      await insertKategorie(id: 930, zeile: 15, bezeichnung: 'Umsatz');
      await insertJournal(kategorieId: 930, betrag: '1000.00', datum: '2025-05-01');

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.vorsteuerBetrag, '209.00');
    });

    test('test_e_r_with_no_journal_entries', () async {
      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      final EuerPreview preview = result.value!;
      // Official form's required empty/zero representation on every line.
      for (int z = 12; z <= 107; z++) {
        expect(preview.zeilen[z], '0.00', reason: 'Zeile $z not zero-represented');
      }
      // The result records that source coverage was complete.
      expect(preview.sourceCoverageComplete, isTrue);
    });

    test('test_e_r_2026_has_no_accepted_mapping', () async {
      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2026);

      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, 'unsupportedFormYear');
      // No 2025 fields or calculations are reused.
      expect(result.value, isNull);
    });

    test('test_e_r_source_contract_is_unapproved', () async {
      // Unapproved prerequisite path: settlement data exists, so an
      // unverified legacy row blocks generation with its identity.
      await insertKategorie(id: 931, zeile: 15, bezeichnung: 'Ust-pflichtig');
      final int bank = await db.executor.runInsert('INSERT INTO konten (name) VALUES (?)', <Object?>['Bank']);
      expect(bank, greaterThan(0));
      final int legacyId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2025-02-01', 'Altbuchung', 931, '999.00', 'Einnahme'],
      );
      await db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Kunde', 'Str. 1', '10115', 'Berlin', 'DE')",
        const <Object?>[],
      );
      final List<Map<String, Object?>> kunden = await db.executor.runSelect(
        'SELECT id FROM kunden ORDER BY id DESC LIMIT 1',
        const <Object?>[],
      );
      final ForderungenRepository forderungen = ForderungenRepository(db.executor);
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kunden.first['id']! as int,
      );
      final PostingGroupService postings = PostingGroupService(db.executor);
      await postings.ensureSchema();
      await postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: 'cash-unapproved',
        signedAmountCents: 4000,
        settlementDate: '2025-04-15',
        bankKontoId: bank,
        counterKontoId: bank,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: 931,
      );

      final ReportWorkspaceResult<EuerPreview> result = await useCase.preview(jahr: 2025);

      // Unavailable with the blocking prerequisite identified, no write-up as complete.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.value, isNull);
      expect(result.reasonCode, contains('$legacyId'));
    });
  });
}
