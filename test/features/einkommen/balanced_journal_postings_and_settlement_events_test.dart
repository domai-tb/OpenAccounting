import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/accounting/eur_settlement_reader.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

/// TDD suite for cash-basis EÜR settlement timing (§3, §9 including the
/// mixed-category remainder-rule trio 9.1–9.3). The authoritative settlement date
/// is the bank booking/value date (manual payment date for cash); the
/// reconciliation-confirmation date is never substituted.
void main() {
  group('Cash-basis EÜR settlement timing (einkommen)', () {
    late AppDatabase db;
    late PostingGroupService postings;
    late ForderungenRepository forderungen;
    late EuerService euer;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      postings = PostingGroupService(db.executor);
      await postings.ensureSchema();
      forderungen = ForderungenRepository(db.executor);
      euer = EuerService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedKategorie({required int id, required int zeile}) async {
      return db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, '
        'mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[id, 'Kat $id', '840$id', '440$id', zeile, 'catalog_verified', 'TEST', '2026-test.1'],
      );
    }

    Future<int> seedKonto({String name = 'Konto'}) async {
      return db.executor.runInsert('INSERT INTO konten (name) VALUES (?)', <Object?>[name]);
    }

    Future<int> seedKunde({String name = 'Kunde'}) async {
      return db.executor.runInsert(
        "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', ?, 'Str. 1', '10115', 'Berlin', 'DE')",
        <Object?>[name],
      );
    }

    Future<int> seedLieferant({String name = 'Lieferant'}) async {
      return db.executor.runInsert(
        "INSERT INTO lieferanten (anrede, name, strasse, plz, ort, land) VALUES ('Herr', ?, 'Str. 1', '10115', 'Berlin', 'DE')",
        <Object?>[name],
      );
    }

    test('test_include_an_ordinary_receipt_in_its_settlement_period', () async {
      final int kat = await seedKategorie(id: 201, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      await postings.postInvoice(
        eventId: 'inv-march',
        datum: '2025-12-10',
        beschreibung: 'Dezemberrechnung',
        kategorieId: kat,
        totalCents: 10000,
        debitKontoId: bank,
        creditKontoId: clearing,
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-april',
        signedAmountCents: 4000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );

      final prior = await euer.generate(jahr: 2025);
      final current = await euer.generate(jahr: 2026);

      // Bank booking date rules: nothing in the issue year, 40.00 in April.
      expect(prior.zeile(15), '0.00');
      expect(current.zeile(15), '40.00');
    });

    test('test_allocate_a_mixed_category_partial_settlement', () async {
      final int firstKategorie = await seedKategorie(id: 207, zeile: 15);
      final int secondKategorie = await seedKategorie(id: 208, zeile: 16);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final int rechnungId = await db.executor.runInsert(
        'INSERT INTO rechnungen (typ, status, ist_entwurf, kunde_id, datum, brutto_betrag) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['rechnung', 'offen', 0, kundeId, '2026-02-01', '80.00'],
      );
      final int firstJournalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, rechnung_id, ust_satz, '
        'immutable, legacy_unverified, source_kind, source_id) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?)',
        <Object?>[
          '2026-02-01',
          'Rechnungsposition 1',
          firstKategorie,
          '-50.01',
          'Einnahme',
          rechnungId,
          19,
          PostingSource.invoiceEvent,
          'inv-mixed-207',
        ],
      );
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, rechnung_id, ust_satz, '
        'immutable, legacy_unverified, source_kind, source_id) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, ?, ?)',
        <Object?>[
          '2026-02-01',
          'Rechnungsposition 2',
          secondKategorie,
          '-29.99',
          'Einnahme',
          rechnungId,
          7,
          PostingSource.invoiceEvent,
          'inv-mixed-208',
        ],
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 80.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
        rechnungId: rechnungId,
        journalId: firstJournalId,
      );

      await postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: 'cash-mixed-categories',
        signedAmountCents: 4000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
      );

      final result = await euer.generate(jahr: 2026);

      expect(result.zeile(15), '25.01');
      expect(result.zeile(16), '14.99');
      final List<Map<String, Object?>> allocations = await db.executor.runSelect(
        'SELECT applied_cents, kategorie_id, euer_zeile, ust_satz FROM settlement_allocations '
        'WHERE forderung_id = ? ORDER BY id',
        <Object?>[forderung.id],
      );
      expect(
        allocations
            .map(
              (Map<String, Object?> row) => <Object?>[
                row['applied_cents'],
                row['kategorie_id'],
                row['euer_zeile'],
                row['ust_satz'],
              ],
            )
            .toList(),
        <List<Object?>>[
          <Object?>[2501, firstKategorie, 15, 19],
          <Object?>[1499, secondKategorie, 16, 7],
        ],
      );
    });

    test('test_exclude_an_unpaid_invoice', () async {
      final int kat = await seedKategorie(id: 202, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      await postings.postInvoice(
        eventId: 'inv-unpaid',
        datum: '2026-02-01',
        beschreibung: 'Unbezahlt',
        kategorieId: kat,
        totalCents: 10000,
        debitKontoId: bank,
        creditKontoId: clearing,
      );

      final result = await euer.generate(jahr: 2026);

      expect(result.zeile(15), '0.00');
      expect(result.gewinn, '0.00');
    });

    test('test_split_a_settlement_across_reporting_periods', () async {
      final int kat = await seedKategorie(id: 203, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      Future<void> settle(String source, int cents, String date) => postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: source,
        signedAmountCents: cents,
        settlementDate: date,
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: cents),
        ],
        kategorieId: kat,
      );
      await settle('split-a', 4000, '2025-12-20');
      await settle('split-b', 6000, '2026-01-10');

      final first = await euer.generate(jahr: 2025);
      final second = await euer.generate(jahr: 2026);

      expect(first.zeile(15), '40.00');
      expect(second.zeile(15), '60.00');
    });

    test('test_keep_input_tax_claim_timing_independent', () async {
      final int kat = await seedKategorie(id: 204, zeile: 60);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Verbindlichkeiten');
      final int lieferantId = await seedLieferant();
      await postings.postInvoice(
        eventId: 'inv-supplier',
        datum: '2025-12-01',
        beschreibung: 'Lieferantenrechnung',
        kategorieId: kat,
        totalCents: 20000,
        debitKontoId: clearing,
        creditKontoId: bank,
        art: 'Ausgabe',
      );
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status) VALUES (?, ?, ?)',
        <Object?>['38.00', '2025-12-15', 'offen'],
      );
      final Forderung payable = await forderungen.create(
        typ: 'rechnung_eingang',
        betrag: 200.00,
        partnerTyp: 'lieferant',
        partnerId: lieferantId,
      );
      await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-supplier-pay',
        signedAmountCents: -20000,
        settlementDate: '2026-01-10',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: payable.id, appliedCents: 20000),
        ],
        kategorieId: kat,
      );
      final DateTime cutover = DateTime(2025);

      final claimYear = await euer.generate(jahr: 2025, cutoverDatum: cutover);
      final payYear = await euer.generate(jahr: 2026, cutoverDatum: cutover);

      // UStVA keeps the approved claim date/basis; EÜR expense follows payment.
      expect(claimYear.vorsteuerBetrag, '38.00');
      expect(claimYear.zeile(60), '0.00');
      expect(payYear.zeile(60), '200.00');
    });

    test('test_apply_an_approved_statutory_timing_exception', () async {
      final int kat = await seedKategorie(id: 205, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final SettlementGroupSummary group = await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-yearend',
        signedAmountCents: 4000,
        settlementDate: '2025-12-30',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );
      await EurSettlementReader.applyTimingException(
        db.executor,
        ruleId: 'ESTG11',
        ruleVersion: '2026.1',
        legalBasis: '§ 11 EStG',
        affectedYear: 2025,
        approver: 'Steuerberatung',
        sourceTrace: 'Jahresgrenzbeleg 2025/42',
        settlementGroupId: group.id,
        attributedYear: 2026,
      );

      final oldYear = await euer.generate(jahr: 2025);
      final newYear = await euer.generate(jahr: 2026);

      expect(oldYear.zeile(15), '0.00');
      expect(newYear.zeile(15), '40.00');
      final List<Object?> rules =
          (newYear.provenanceSnapshot['statutory_rules'] as List<Object?>?) ?? const <Object?>[];
      expect(rules.any((Object? r) => (r! as Map<String, Object?>)['rule_id'] == 'ESTG11'), isTrue);
    });

    test('test_do_not_infer_an_exception', () async {
      final int kat = await seedKategorie(id: 206, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-no-rule',
        signedAmountCents: 4000,
        settlementDate: '2025-12-30',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
        beschreibung: 'Regelmaessig wiederkehrend § 11 EStG Zuordnung',
      );

      // No approved rule result: actual settlement date rules, not the text.
      expect((await euer.generate(jahr: 2025)).zeile(15), '40.00');
      expect((await euer.generate(jahr: 2026)).zeile(15), '0.00');
    });

    test('test_recognize_a_direct_cash_receipt_without_an_invoice', () async {
      final int kat = await seedKategorie(id: 207, zeile: 15);
      final int kasse = await seedKonto(name: 'Kasse');
      final int clearing = await seedKonto(name: 'Verrechnung');
      await postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: 'cash-direct',
        signedAmountCents: 2500,
        settlementDate: '2026-03-05',
        bankKontoId: kasse,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[SettlementAllocationInput(appliedCents: 2500, kategorieId: kat)],
      );

      final result = await euer.generate(jahr: 2026);

      expect(result.zeile(15), '25.00');
    });

    test('test_exclude_a_write_off_from_operating_receipts', () async {
      final int kat = await seedKategorie(id: 208, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      await postings.postInvoice(
        eventId: 'inv-writeoff',
        datum: '2026-02-01',
        beschreibung: 'Uneinbringlich',
        kategorieId: kat,
        totalCents: 7500,
        debitKontoId: bank,
        creditKontoId: clearing,
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 75.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final Forderung written = await forderungen.ausbuchen(forderungId: forderung.id, grund: 'Kunde zahlungsunfähig');

      expect(written.status, 'ausgebucht');
      final result = await euer.generate(jahr: 2026);
      expect(result.zeile(15), '0.00');
    });

    test('test_classify_an_overpayment_credit_separately', () async {
      final int kat = await seedKategorie(id: 209, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int credit = await seedKonto(name: 'Ueberzahlung');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final SettlementGroupSummary group = await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-credit',
        signedAmountCents: 12000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        creditKontoId: credit,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 10000),
        ],
        kategorieId: kat,
      );

      final result = await euer.generate(jahr: 2026);

      // Only the applied invoice portion is invoice income; the 20.00
      // credit follows the receivables-contract classification.
      expect(result.zeile(15), '100.00');
      expect(group.unappliedCents, 2000);
    });

    test('test_reclassify_a_reversed_settlement_in_the_reversal_period', () async {
      final int kat = await seedKategorie(id: 210, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-reclass',
        signedAmountCents: 4000,
        settlementDate: '2025-12-05',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );
      await postings.reverseSettlementGroup(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-reclass',
        reversalDate: '2026-01-10',
      );

      final originalYear = await euer.generate(jahr: 2025);
      final reversalYear = await euer.generate(jahr: 2026);

      expect(originalYear.zeile(15), '40.00');
      expect(reversalYear.zeile(15), '-40.00');
    });

    test('test_exclude_legacy_unverified_rows_from_settlement_totals', () async {
      final int kat = await seedKategorie(id: 211, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final int legacyId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-02-01', 'Altbuchung', kat, '999.00', 'Einnahme'],
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      await postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: 'cash-legacy',
        signedAmountCents: 4000,
        settlementDate: '2026-04-15',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );

      // Mixed periods fail closed instead of presenting partial totals.
      await expectLater(
        euer.generate(jahr: 2026),
        throwsA(predicate<Object>((Object e) => e.toString().contains('$legacyId'))),
      );
    });
  });
}
