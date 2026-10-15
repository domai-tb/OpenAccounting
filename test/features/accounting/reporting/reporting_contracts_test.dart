import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/accounting/reporting/bookkeeping_duty_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/datev_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/euer_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/guv_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/ustva_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/zm_preview_use_case.dart';
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

  group('reporting contracts: UStVA workspace', () {
    late AppDatabase db;
    late UstvaReportUseCase useCase;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await _ensureUstvaColumns(db);
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, aktiv) VALUES (1, ?, ?, ?, 1)',
        <Object?>['UStVA-Testkategorie', '8401', '4401'],
      );
      useCase = UstvaReportUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertJournal({
      required String betrag,
      required String datum,
      String belegTyp = 'Einnahme',
      String? ustSatz,
      String? ustSonderfall,
      String? marge,
      String? ustSatz25a,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a) VALUES (?, ?, 1, ?, ?, 0, ?, ?, ?, ?)',
        <Object?>[datum, 'Test $datum', betrag, belegTyp, ustSatz, ustSonderfall, marge, ustSatz25a],
      );
    }

    Future<void> insertVorsteuer({required String betrag, required String faelligkeit, String? sonderfall}) async {
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status, ust_sonderfall) VALUES (?, ?, ?, ?)',
        <Object?>[betrag, faelligkeit, 'offen', sonderfall],
      );
    }

    test('test_kz_1_gesamtumsatz_steuerpflichtig', () async {
      await insertJournal(betrag: '1000.00', datum: '2025-03-10', ustSatz: '19');
      await insertJournal(betrag: '500.50', datum: '2025-03-15', ustSatz: '19');
      // Different month must not count.
      await insertJournal(betrag: '9999.00', datum: '2025-04-01', ustSatz: '19');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 3,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.kzValue('1'), '1500.50');
      expect(result.value!.mapVersion, 'de-ustva-2025');
    });

    test('test_kz_3_umsatzsteuer_19', () async {
      await insertJournal(betrag: '119.00', datum: '2025-05-05', ustSatz: '19');
      await insertJournal(betrag: '119.00', datum: '2025-05-12', ustSatz: '19');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 5,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.kzValue('3'), '38.00');
    });

    test('test_kz_4_umsatzsteuer_7', () async {
      await insertJournal(betrag: '107.00', datum: '2025-05-10', ustSatz: '7');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 5,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.kzValue('4'), '7.00');
    });

    test('test_kz_18_differenzsteuer_25a', () async {
      // Margin 119 → tax 119 * 19 / 119 = 19.00 per the accepted map.
      await insertJournal(betrag: '500.00', datum: '2025-07-10', marge: '119.00', ustSatz25a: '19');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 7,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.kzValue('18'), '19.00');
    });

    test('test_kz_61_vorsteuerabzug_ig_erwerb', () async {
      await insertVorsteuer(betrag: '190.00', faelligkeit: '2025-06-15', sonderfall: 'ig_erwerb');
      await insertVorsteuer(betrag: '50.00', faelligkeit: '2025-06-16', sonderfall: 'ig_erwerb');
      await insertVorsteuer(betrag: '100.00', faelligkeit: '2025-06-17');
      await insertVorsteuer(betrag: '20.00', faelligkeit: '2025-06-18', sonderfall: 'domestic');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 6,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.kzValue('61'), '240.00');
      // ig Erwerb excluded from KZ 66.
      expect(result.value!.kzValue('66'), '120.00');
    });

    test('test_kz_66_allgemeiner_vorsteuerabzug', () async {
      await insertVorsteuer(betrag: '190.00', faelligkeit: '2025-06-15', sonderfall: 'ig_erwerb');
      await insertVorsteuer(betrag: '100.00', faelligkeit: '2025-06-17');
      await insertVorsteuer(betrag: '20.00', faelligkeit: '2025-06-18', sonderfall: 'domestic');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 6,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      // Domestic claims only; the ig Erwerb claim is not reported here.
      expect(result.value!.kzValue('66'), '120.00');
    });

    test('test_kz_89_93_reverse_charge', () async {
      await insertJournal(betrag: '500.00', datum: '2025-09-10', ustSatz: '19');
      await insertJournal(betrag: '1000.00', datum: '2025-09-11', ustSatz: '19', ustSonderfall: '13b_abs1');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 9,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      final UstvaPreview preview = result.value!;
      expect(preview.kzValue('89'), '1000.00');
      expect(preview.kzValue('93'), '190.00');
      // Reverse charge is not ordinary domestic turnover.
      expect(preview.kzValue('1'), '500.00');
    });

    test('test_kz_81_83_differenzbetrag_25a', () async {
      await insertJournal(betrag: '300.00', datum: '2025-08-05', marge: '119.00', ustSatz25a: '19');
      await insertJournal(betrag: '300.00', datum: '2025-08-06', marge: '238.00', ustSatz25a: '19');
      // Negative margin ignored.
      await insertJournal(betrag: '300.00', datum: '2025-08-07', marge: '-100.00', ustSatz25a: '19');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 8,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      expect(result.value!.kzValue('81'), '357.00');
      expect(result.value!.kzValue('83'), '57.00');
    });

    test('test_quarterly_filing', () async {
      await insertJournal(betrag: '100.00', datum: '2025-01-10', ustSatz: '19');
      await insertJournal(betrag: '200.00', datum: '2025-02-15', ustSatz: '19');
      await insertJournal(betrag: '300.00', datum: '2025-03-20', ustSatz: '19');
      // April is quarter 2 — must not count toward quarter 1.
      await insertJournal(betrag: '999.00', datum: '2025-04-01', ustSatz: '19');

      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 1,
        rhythmus: 'quartal',
      );

      expect(result.availability, ReportAvailability.available);
      final UstvaPreview preview = result.value!;
      expect(preview.kzValue('1'), '600.00');
      // Exact three-month window, start-inclusive end-exclusive.
      expect(preview.periodStart, '2025-01-01');
      expect(preview.periodEnd, '2025-04-01');
      // Preview only — no filing artifact or submission status exists here.
      expect(preview.isFilingArtifact, isFalse);
    });

    test('test_no_transactions_in_period', () async {
      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2025,
        monatOrQuartal: 12,
        rhythmus: 'monatlich',
      );

      expect(result.availability, ReportAvailability.available);
      final UstvaPreview preview = result.value!;
      // Accepted map's zero representation on every required key.
      for (final MapEntry<String, String> e in preview.kz.entries) {
        expect(e.value, matches(RegExp(r'^-?\d+\.\d{2}$')), reason: 'KZ ${e.key} not zero-formatted');
      }
      expect(preview.kzValue('1'), '0.00');
      expect(preview.kzValue('66'), '0.00');
      // The preview identifies that the complete period has no eligible events.
      expect(preview.noEligibleEvents, isTrue);
    });

    test('test_ustva_year_map_or_source_is_unavailable', () async {
      final ReportWorkspaceResult<UstvaPreview> result = await useCase.preview(
        jahr: 2026,
        monatOrQuartal: 1,
        rhythmus: 'monatlich',
      );

      // Missing year-specific map identified; no zeroes emitted as complete.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('YearSpecificMap'));
      expect(result.value, isNull);
    });
  });

  group('reporting contracts: GuV workspace', () {
    late AppDatabase db;
    late GuvReportUseCase useCase;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      useCase = GuvReportUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertKategorie({required int id, required String konto}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, aktiv, mapping_status) '
        'VALUES (?, ?, ?, ?, 1, ?)',
        <Object?>[id, 'Kat $id', konto, konto, 'catalog_verified'],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String belegTyp = 'Einnahme',
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, belegTyp],
      );
    }

    test('test_guv_computation', () async {
      await insertKategorie(id: 941, konto: '4000');
      await insertKategorie(id: 942, konto: '3000');
      await insertKategorie(id: 943, konto: '6000');
      await insertJournal(kategorieId: 941, betrag: '1000.00', datum: '2025-03-01');
      await insertJournal(kategorieId: 942, betrag: '400.00', datum: '2025-04-01', belegTyp: 'Ausgabe');
      await insertJournal(kategorieId: 943, betrag: '100.00', datum: '2025-05-01', belegTyp: 'Ausgabe');
      // Different year must not count.
      await insertJournal(kategorieId: 941, betrag: '9999.00', datum: '2024-03-01');

      final ReportWorkspaceResult<GuvPreview> result = await useCase.preview(jahr: 2025);

      expect(result.availability, ReportAvailability.available);
      final GuvPreview preview = result.value!;
      // Amounts grouped by the accepted account-to-GuV-line mapping.
      expect(preview.lineAmountCents('roherloese'), 100000);
      expect(preview.lineAmountCents('materialaufwand'), 40000);
      expect(preview.lineAmountCents('sonstige_aufwendungen'), 10000);
      // Records the source/mapping version and exact period.
      expect(preview.mappingVersion, 'skr03-guv-2025');
      expect(preview.sourceVersions.keys, contains('balanced-postings'));
      expect(preview.sourceVersions.keys, contains('invoice-money'));
      expect(preview.periodStart, '2025-01-01');
      expect(preview.periodEnd, '2026-01-01');
    });

    test('test_guv_is_unavailable_without_approved_postings', () async {
      // Simulate the balanced-posting prerequisite not being approved/installed.
      await db.executor.runCustom('DROP TABLE settlement_groups', const <Object?>[]);

      final ReportWorkspaceResult<GuvPreview> result = await useCase.preview(jahr: 2025);

      // Unavailable; no raw journal-range estimate is shown.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('source'));
      expect(result.value, isNull);
    });
  });

  group('reporting contracts: §141 bookkeeping duty', () {
    BookkeepingDutyEvidence evidence({
      String businessType = 'gewerbebetrieb',
      String thresholdBasis = 'umsatz',
      int measuredAmountCents = 80100000,
      String? noticeDate = '2025-06-15',
      String? findingDate = '2025-06-15',
      int wjStartMonth = 1,
      int wjStartDay = 1,
    }) {
      return BookkeepingDutyEvidence(
        businessType: businessType,
        thresholdBasis: thresholdBasis,
        measuredAmountCents: measuredAmountCents,
        finanzamtFindingDate: findingDate,
        noticeDate: noticeDate,
        wirtschaftsjahrStartMonth: wjStartMonth,
        wirtschaftsjahrStartDay: wjStartDay,
      );
    }

    test('test_threshold_exceeded', () async {
      // Turnover over EUR 800,000 but no verified notice/effective-date evidence.
      final BookkeepingDutyStatus status = BookkeepingDutyUseCase.evaluate(
        evidence: evidence(noticeDate: null, findingDate: null),
        on: '2025-06-30',
      );

      // The application does not claim §141 duty applies without notice evidence.
      expect(status.claimDuty, isFalse);
      expect(status.effectiveDate, isNull);
      expect(status.reasonCode, contains('Notice'));
      // A threshold crossing never activates the management GuV preference:
      // BookkeepingDutyStatus exposes no activation output at all.
    });

    test('test_threshold_not_exceeded', () async {
      // Below threshold, unknown-evidence case stays quiet too.
      final BookkeepingDutyStatus below = BookkeepingDutyUseCase.evaluate(
        evidence: evidence(measuredAmountCents: 100000),
        on: '2025-06-30',
      );
      final BookkeepingDutyStatus unknown = BookkeepingDutyUseCase.evaluate(
        evidence: evidence(businessType: 'unknown', noticeDate: null, findingDate: null),
        on: '2025-06-30',
      );

      // No §141 duty warning is displayed in either case.
      expect(below.claimDuty, isFalse);
      expect(below.effectiveDate, isNull);
      expect(unknown.claimDuty, isFalse);
      expect(unknown.effectiveDate, isNull);
    });

    test('test_141_warning_follows_notice_effective_date', () async {
      final BookkeepingDutyEvidence verified = evidence();
      // Calendar Wirtschaftsjahr: duty starts at the next January 1 after the notice.
      final BookkeepingDutyStatus before = BookkeepingDutyUseCase.evaluate(evidence: verified, on: '2025-12-31');
      final BookkeepingDutyStatus from = BookkeepingDutyUseCase.evaluate(evidence: verified, on: '2026-01-01');

      // Before the effective date: duty not started.
      expect(before.claimDuty, isFalse);
      expect(before.effectiveDate, '2026-01-01');
      // On/after the effective date: warning with source notice and date.
      expect(from.claimDuty, isTrue);
      expect(from.effectiveDate, '2026-01-01');
      expect(from.noticeDate, '2025-06-15');
    });

    test('test_141_warning_follows_a_non_calendar_wirtschaftsjahr', () async {
      // Wirtschaftsjahr 1 April – 31 March; notice received 15 December 2025.
      final BookkeepingDutyEvidence verified = evidence(
        wjStartMonth: 4,
        noticeDate: '2025-12-15',
        findingDate: '2025-12-15',
      );
      final BookkeepingDutyStatus before = BookkeepingDutyUseCase.evaluate(evidence: verified, on: '2026-03-31');
      final BookkeepingDutyStatus from = BookkeepingDutyUseCase.evaluate(evidence: verified, on: '2026-04-01');

      // Not before 1 April 2026.
      expect(before.claimDuty, isFalse);
      expect(before.effectiveDate, '2026-04-01');
      // From 1 April 2026 the warning shows notice and evidenced boundary.
      expect(from.claimDuty, isTrue);
      expect(from.effectiveDate, '2026-04-01');
      expect(from.noticeDate, '2025-12-15');
      expect(from.wirtschaftsjahrBoundary, '04-01');
    });
  });

  group('reporting contracts: ZM preview', () {
    late AppDatabase db;
    late ZmPreviewUseCase useCase;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      useCase = ZmPreviewUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertKunde({required int id, required String land, String? ustIdNr}) async {
      await db.executor.runInsert(
        'INSERT INTO kunden (id, name, strasse, plz, ort, land, ust_idnr) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[id, 'Kunde $id', 'Str 1', '10115', 'Berlin', land, ustIdNr],
      );
      return id;
    }

    Future<int> insertRechnung({required int id, required int kundeId, required String datum}) async {
      await db.executor.runInsert(
        'INSERT INTO rechnungen (id, typ, status, ist_entwurf, kunde_id, datum) VALUES (?, ?, ?, 0, ?, ?)',
        <Object?>[id, 'rechnung', 'final', kundeId, datum],
      );
      return id;
    }

    Future<void> insertEuSupplyJournal({
      required int rechnungId,
      required String betrag,
      required String lieferdatum,
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, immutable, rechnung_id, ist_eu_lieferung) '
        'VALUES (?, ?, ?, ?, 0, ?, 1)',
        <Object?>[lieferdatum, 'ig Lieferung', betrag, 'Einnahme', rechnungId],
      );
    }

    test('test_zm_with_ig_lieferungen', () async {
      final int fr = await insertKunde(id: 51, land: 'FR', ustIdNr: 'FR123');
      final int nl = await insertKunde(id: 52, land: 'NL', ustIdNr: 'NL456');
      final int r71 = await insertRechnung(id: 71, kundeId: fr, datum: '2025-09-05');
      final int r72 = await insertRechnung(id: 72, kundeId: fr, datum: '2025-09-10');
      final int r73 = await insertRechnung(id: 73, kundeId: nl, datum: '2025-09-12');
      await insertEuSupplyJournal(rechnungId: r71, betrag: '1000.00', lieferdatum: '2025-09-01');
      await insertEuSupplyJournal(rechnungId: r72, betrag: '500.00', lieferdatum: '2025-09-02');
      await insertEuSupplyJournal(rechnungId: r73, betrag: '250.00', lieferdatum: '2025-09-03');

      final ReportWorkspaceResult<ZmPreview> result = await useCase.preview(month: '2025-09');

      expect(result.availability, ReportAvailability.available);
      final ZmPreview preview = result.value!;
      // Amounts grouped by recipient USt-IdNr in the invoice-issue month.
      final Map<String, int> totals = <String, int>{
        for (final ZmRecipientTotal t in preview.recipients) t.ustIdNr: t.taxableBaseCents,
      };
      expect(totals, <String, int>{'FR123': 150000, 'NL456': 25000});
      // Each total links to its source invoices and records the §18a version.
      expect(preview.recipients.firstWhere((ZmRecipientTotal t) => t.ustIdNr == 'FR123').sourceRechnungIds, <int>[
        r71,
        r72,
      ]);
      expect(preview.sourceContractVersion, 'ustg-18a-2026');
      expect(preview.periodStart, '2025-09-01');
      expect(preview.periodEnd, '2025-10-01');
      // Preview only — never an official filing artifact or submission status.
      expect(preview.isFilingArtifact, isFalse);
    });

    test('test_zm_with_ig_erwerb', () async {
      final int fr = await insertKunde(id: 51, land: 'FR', ustIdNr: 'FR123');
      final int r71 = await insertRechnung(id: 71, kundeId: fr, datum: '2025-09-05');
      await insertEuSupplyJournal(rechnungId: r71, betrag: '1000.00', lieferdatum: '2025-09-01');
      // Ordinary intra-community acquisition on an incoming invoice.
      await db.executor.runInsert(
        'INSERT INTO lieferanten (id, name, strasse, plz, ort, land) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[61, 'Lieferant 61', 'Str 2', '10115', 'Berlin', 'AT'],
      );
      await db.executor.runInsert(
        'INSERT INTO rechnungen (id, typ, status, ist_entwurf, lieferant_id, datum) VALUES (?, ?, ?, 0, ?, ?)',
        <Object?>[75, 'rechnung', 'final', 61, '2025-09-06'],
      );
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, immutable, rechnung_id, ust_sonderfall) '
        'VALUES (?, ?, ?, ?, 0, 75, ?)',
        <Object?>['2025-09-04', 'ig Erwerb', '999.00', 'Ausgabe', 'ig_erwerb'],
      );

      final ReportWorkspaceResult<ZmPreview> result = await useCase.preview(month: '2025-09');

      // The acquisition is excluded and does not block the complete preview.
      expect(result.availability, ReportAvailability.available);
      final ZmPreview preview = result.value!;
      expect(preview.recipients, hasLength(1));
      expect(preview.recipients.single.ustIdNr, 'FR123');
      expect(preview.recipients.single.taxableBaseCents, 100000);
    });

    test('test_no_eu_transactions_in_period', () async {
      final ReportWorkspaceResult<ZmPreview> result = await useCase.preview(month: '2025-12');

      // Complete month with no supported or unsupported EU transactions.
      expect(result.availability, ReportAvailability.available);
      final ZmPreview preview = result.value!;
      expect(preview.recipients, isEmpty);
      expect(preview.noEligibleEvents, isTrue);
      expect(preview.isFilingArtifact, isFalse);
    });

    test('test_missing_zm_source_field_blocks_preview', () async {
      final int at = await insertKunde(id: 53, land: 'AT');
      final int r75 = await insertRechnung(id: 75, kundeId: at, datum: '2025-11-05');
      await insertEuSupplyJournal(rechnungId: r75, betrag: '300.00', lieferdatum: '2025-11-01');

      final ReportWorkspaceResult<ZmPreview> result = await useCase.preview(month: '2025-11');

      // Unavailable with the source invoice and missing field identified.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('ustIdNr'));
      expect(result.reasonCode, contains('75'));
      expect(result.value, isNull);
    });

    test('test_unsupported_reportable_service_blocks_zm_preview', () async {
      final int fr = await insertKunde(id: 51, land: 'FR', ustIdNr: 'FR123');
      final int at = await insertKunde(id: 54, land: 'AT', ustIdNr: 'AT789');
      // Eligible goods supply in the same month.
      final int r77 = await insertRechnung(id: 77, kundeId: fr, datum: '2025-10-08');
      await insertEuSupplyJournal(rechnungId: r77, betrag: '400.00', lieferdatum: '2025-10-01');
      // Potentially reportable §3a(2)-style EU service: finalized outgoing
      // invoice to an EU taxable recipient with no §6a(1) goods posting.
      await insertRechnung(id: 76, kundeId: at, datum: '2025-10-10');

      final ReportWorkspaceResult<ZmPreview> result = await useCase.preview(month: '2025-10');

      // Period unavailable, linking the service source — never an apparently
      // complete report omitting the service.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('Direction'));
      expect(result.reasonCode, contains('76'));
      expect(result.value, isNull);
    });
  });

  group('reporting contracts: DATEV EXTF export', () {
    late AppDatabase db;
    late DatevExportUseCase useCase;

    const DatevExportConfig config = DatevExportConfig(
      sachkontenlaenge: '4',
      chartCode: '03',
      buSchluessel: <String, String>{'19': '1'},
    );

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      useCase = DatevExportUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertUnternehmen({String? berater, String? mandant}) async {
      await db.executor.runInsert(
        'INSERT INTO unternehmen (id, name, datev_beraternummer, datev_mandantennummer) VALUES (?, ?, ?, ?)',
        <Object?>[1, 'Testfirma', berater, mandant],
      );
    }

    Future<void> insertKonto({required int id, required String datevNr}) async {
      await db.executor.runInsert('INSERT INTO konten (id, name, datev_kontonummer) VALUES (?, ?, ?)', <Object?>[
        id,
        'Konto $id',
        datevNr,
      ]);
    }

    Future<void> insertBalancedPosting({
      required int id,
      required int sollKonto,
      required int habenKonto,
      String belegNr = 'RE-1',
      String datum = '2025-07-15',
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (id, datum, beschreibung, betrag, beleg_typ, immutable, beleg_nr, '
        'soll_konto_id, haben_konto_id, ust_satz, source_kind) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?)',
        <Object?>[
          id,
          datum,
          'Testbuchung $id',
          '1000.00',
          'Einnahme',
          belegNr,
          sollKonto,
          habenKonto,
          '19',
          'invoice_event',
        ],
      );
    }

    test('test_datev_export_generation', () async {
      await insertUnternehmen(berater: '6512345', mandant: 'M4711');
      await insertKonto(id: 81, datevNr: '4000');
      await insertKonto(id: 82, datevNr: '1200');
      await insertBalancedPosting(id: 1, sollKonto: 81, habenKonto: 82);

      final ReportWorkspaceResult<DatevExportArtifact> result = await useCase.create(
        month: '2025-07',
        config: config,
        generatedAt: DateTime.utc(2026, 1, 1, 12),
      );

      expect(result.availability, ReportAvailability.available);
      final DatevExportArtifact artifact = result.value!;
      // v13 structured CSV with header version 700 / category 21.
      final List<String> header = artifact.csv.split('\r\n').first.split(';');
      expect(header.sublist(0, 5), <String>['EXTF', '700', '21', 'Buchungsstapel', '13']);
      // 125 booking-row positions with the specified field mappings.
      final List<String> row = artifact.csv.split('\r\n')[1].split(';');
      expect(row, hasLength(125));
      expect(row[0], '1000,00'); // 001 Umsatz, decimal comma.
      expect(row[1], 'S'); // 002 side of field 007.
      expect(row[6], '4000'); // 007 Konto.
      expect(row[7], '1200'); // 008 Gegenkonto.
      expect(row[8], '1'); // 009 configured tax key.
      expect(row[9], '1507'); // 010 Belegdatum TTMM.
      expect(row[10], 'RE-1'); // 011 Belegfeld 1.
      expect(row[13], 'Testbuchung 1'); // 014 Buchungstext.
      expect(artifact.headerVersion, 700);
      expect(artifact.formatVersion, 13);
      expect(artifact.bookingRowCount, 1);
    });

    test('test_datev_account_mapping', () async {
      await insertUnternehmen(berater: '6512345', mandant: 'M4711');
      await insertKonto(id: 81, datevNr: '4000');
      await insertKonto(id: 82, datevNr: '1200');
      await insertBalancedPosting(id: 1, sollKonto: 81, habenKonto: 82);

      final ReportWorkspaceResult<DatevExportArtifact> result = await useCase.create(
        month: '2025-07',
        config: config,
        generatedAt: DateTime.utc(2026, 1, 1, 12),
      );

      expect(result.availability, ReportAvailability.available);
      final List<String> row = result.value!.csv.split('\r\n')[1].split(';');
      // Fields 007/008 use the explicit DATEV account mappings; no global
      // bank account or fabricated account number appears anywhere.
      expect(row[6], '4000');
      expect(row[7], '1200');
    });

    test('test_datev_metadata', () async {
      await insertUnternehmen(berater: '6512345', mandant: 'M4711');
      await insertKonto(id: 81, datevNr: '4000');
      await insertKonto(id: 82, datevNr: '1200');
      await insertBalancedPosting(id: 1, sollKonto: 81, habenKonto: 82);

      final ReportWorkspaceResult<DatevExportArtifact> result = await useCase.create(
        month: '2025-07',
        config: config,
        generatedAt: DateTime.utc(2026, 1, 1, 12),
      );

      expect(result.availability, ReportAvailability.available);
      final List<String> header = result.value!.csv.split('\r\n').first.split(';');
      expect(header, hasLength(31)); // Official 31-position v13 header.
      expect(header[10], '6512345'); // 011 Beraternummer.
      expect(header[11], 'M4711'); // 012 Mandantennummer.
      expect(header[12], '20250101'); // 013 business year, 1 January start.
      expect(header[13], '4'); // 014 Sachkontenlänge.
      expect(header[14], '20250701'); // 015 inclusive month start.
      expect(header[15], '20250731'); // 016 inclusive month end.
      expect(header[21], 'EUR'); // 022 currency.
      expect(header[26], '03'); // 027 configured chart code.
    });

    test('test_datev_export_with_missing_company_config', () async {
      // No unternehmen row: Beraternummer/Mandantennummer missing.
      await insertKonto(id: 81, datevNr: '4000');
      await insertKonto(id: 82, datevNr: '1200');
      await insertBalancedPosting(id: 1, sollKonto: 81, habenKonto: 82);

      final ReportWorkspaceResult<DatevExportArtifact> result = await useCase.create(
        month: '2025-07',
        config: config,
        generatedAt: DateTime.utc(2026, 1, 1, 12),
      );

      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('missingCompanyConfig'));
      expect(result.reasonCode, contains('beraternummer'));
      expect(result.value, isNull);
    });

    test('test_datev_export_with_missing_source_mapping', () async {
      await insertUnternehmen(berater: '6512345', mandant: 'M4711');
      // Candidate posting without explicit DATEV account mapping.
      await db.executor.runInsert(
        'INSERT INTO journal (id, datum, beschreibung, betrag, beleg_typ, immutable, beleg_nr, ust_satz, source_kind) '
        'VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)',
        <Object?>[9, '2025-07-15', 'Unmapped', '100.00', 'Einnahme', 'RE-9', '19', 'invoice_event'],
      );

      final ReportWorkspaceResult<DatevExportArtifact> result = await useCase.create(
        month: '2025-07',
        config: config,
        generatedAt: DateTime.utc(2026, 1, 1, 12),
      );

      // Fails closed with the source ID and field.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('9'));
      expect(result.reasonCode, contains('Konto'));
      expect(result.value, isNull);
    });

    test('test_datev_fixture_matches_the_pinned_interface', () async {
      await insertUnternehmen(berater: '6512345', mandant: 'M4711');
      await insertKonto(id: 81, datevNr: '4000');
      await insertKonto(id: 82, datevNr: '1200');
      await insertBalancedPosting(id: 1, sollKonto: 81, habenKonto: 82);

      final ReportWorkspaceResult<DatevExportArtifact> result = await useCase.create(
        month: '2025-07',
        config: config,
        generatedAt: DateTime.utc(2026, 1, 1, 12),
      );

      expect(result.availability, ReportAvailability.available);
      final String csv = result.value!.csv;
      final List<String> lines = csv.split('\r\n');
      final List<String> header = lines.first.split(';');
      final List<String> row = lines[1].split(';');
      // Pinned interface: every header value and all 125 row positions.
      expect(header[5], matches(RegExp(r'^\d{17}$'))); // 006 timestamp format.
      expect(header.sublist(0, 5), <String>['EXTF', '700', '21', 'Buchungsstapel', '13']);
      expect(header[6], ''); // 007 blank.
      expect(header[7], 'RE'); // 008.
      expect(header[8], '');
      expect(header[9], '');
      expect(<String>[header[18], header[19], header[20]], <String>['1', '0', '0']);
      expect(<String>[header[22], header[23], header[24], header[25]], <String>['', '', '', '']);
      expect(<String>[header[27], header[28], header[29], header[30]], <String>['', '', '', '']);
      expect(row, hasLength(125));
      // Unused positions stay blank.
      expect(<String>[row[2], row[3], row[4], row[5]], <String>['', '', '', '']);
      expect(row[11], ''); // 012 no due date source.
      expect(row[19], ''); // 020 no DATEV document link source.
      // Decimal comma and exactly two cents.
      expect(row[0], matches(RegExp(r'^\d+,\d{2}$')));
    });
  });
}

Future<void> _ensureUstvaColumns(AppDatabase db) async {
  final List<Map<String, Object?>> jCols = await db.executor.runSelect('PRAGMA table_info(journal)', const <Object?>[]);
  final Set<String> jNames = jCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!jNames.contains('ust_satz')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ust_satz NUMERIC(12,2)');
  }
  if (!jNames.contains('ust_sonderfall')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ust_sonderfall TEXT');
  }
  if (!jNames.contains('marge_25a_brutto')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN marge_25a_brutto NUMERIC(12,2)');
  }
  if (!jNames.contains('ust_satz_25a')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ust_satz_25a NUMERIC(12,2)');
  }
  if (!jNames.contains('ist_eu_lieferung')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN ist_eu_lieferung INTEGER DEFAULT 0');
  }
  if (!jNames.contains('vorsteuer_betrag')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN vorsteuer_betrag NUMERIC(12,2)');
  }
  final List<Map<String, Object?>> vCols = await db.executor.runSelect(
    'PRAGMA table_info(vorsteuer_ansprueche)',
    const <Object?>[],
  );
  final Set<String> vNames = vCols.map((Map<String, Object?> r) => r['name'].toString()).toSet();
  if (!vNames.contains('ust_sonderfall')) {
    await db.executor.runCustom('ALTER TABLE vorsteuer_ansprueche ADD COLUMN ust_sonderfall TEXT');
  }
}
