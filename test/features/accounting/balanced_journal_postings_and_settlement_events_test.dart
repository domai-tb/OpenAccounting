import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/accounting/journal_repository.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

/// TDD suite for the balanced-journal posting boundary (§1, §2, §5–§8).
/// Each scenario first failed against the legacy single-row writers (no
/// source identity, no balanced legs, no allocation restore), then passed
/// through [PostingGroupService]. Blocked money-contract trio 9.1–9.3 is
/// not covered here.
void main() {
  group('Balanced journal postings and settlement events (accounting)', () {
    late AppDatabase db;
    late PostingGroupService postings;
    late ForderungenRepository forderungen;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      postings = PostingGroupService(db.executor);
      await postings.ensureSchema();
      forderungen = ForderungenRepository(db.executor);
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

    Future<int> seedRechnung({int? kundeId, int? lieferantId, String brutto = '100.00'}) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, lieferant_id, '
        'datum, brutto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'RE-${DateTime.now().microsecondsSinceEpoch}',
          'rechnung',
          'offen',
          0,
          'netto',
          kundeId,
          lieferantId,
          '2026-01-10',
          brutto,
        ],
      );
    }

    Future<int> legacyRowCount() async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM journal WHERE source_kind IS NULL',
        const <Object?>[],
      );
      return ((rows.single['c'] as num?) ?? 0).toInt();
    }

    test('test_post_a_finalized_invoice', () async {
      final int kat = await seedKategorie(id: 101, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int erloes = await seedKonto(name: 'Erloese');
      final int kundeId = await seedKunde();
      final int rechnungId = await seedRechnung(kundeId: kundeId, brutto: '119.00');

      final PostingGroupSummary group = await postings.postInvoice(
        eventId: 'inv-1',
        datum: '2026-03-01',
        beschreibung: 'Rechnung RE-1',
        kategorieId: kat,
        totalCents: 11900,
        debitKontoId: bank,
        creditKontoId: erloes,
        rechnungId: rechnungId,
        belegNr: 'RE-1',
      );

      expect(group.legIds.length, greaterThanOrEqualTo(2));
      expect(group.debitCents, group.creditCents);
      expect(group.debitCents, 11900);
      final List<Map<String, Object?>> legs = await postings.groupLegs(group.rootJournalId);
      expect(legs.length, group.legIds.length);
      var debitSum = 0;
      var creditSum = 0;
      for (final Map<String, Object?> leg in legs) {
        final int soll = money.toCents(money.formatBetrag((leg['soll'] ?? 0).toString()));
        final int haben = money.toCents(money.formatBetrag((leg['haben'] ?? 0).toString()));
        expect(soll > 0 || haben > 0, isTrue, reason: 'Leg ${leg['id']} braucht genau eine belegte Seite');
        expect(soll > 0 && haben > 0, isFalse, reason: 'Leg ${leg['id']} darf nicht beide Seiten belegen');
        expect(leg['source_kind'], PostingSource.invoiceEvent);
        expect(leg['source_id'], 'inv-1');
        expect(leg['rechnung_id'], rechnungId);
        debitSum += soll;
        creditSum += haben;
      }
      expect(debitSum, creditSum);
    });

    test('test_required_posting_mapping_is_missing', () async {
      final int bank = await seedKonto(name: 'Bank');
      final int erloes = await seedKonto(name: 'Erloese');
      final int before = await legacyRowCount();

      await expectLater(
        postings.postInvoice(
          eventId: 'inv-missing-kat',
          datum: '2026-03-01',
          beschreibung: 'Ohne Kategorie',
          kategorieId: 999999,
          totalCents: 10000,
          debitKontoId: bank,
          creditKontoId: erloes,
        ),
        throwsA(
          predicate<Object>(
            (Object e) => e.toString().contains('Kategorie 999999') && e.toString().contains('Mapping'),
          ),
        ),
      );
      final int kat = await seedKategorie(id: 102, zeile: 15);
      await expectLater(
        postings.postInvoice(
          eventId: 'inv-missing-konto',
          datum: '2026-03-01',
          beschreibung: 'Ohne Konto',
          kategorieId: kat,
          totalCents: 10000,
          debitKontoId: bank,
          creditKontoId: 999999,
        ),
        throwsA(predicate<Object>((Object e) => e.toString().contains('Konto 999999'))),
      );
      // Rollback: no journal line was committed for either attempt.
      expect(await postings.findInvoiceGroup('inv-missing-kat'), isNull);
      expect(await postings.findInvoiceGroup('inv-missing-konto'), isNull);
      expect(await legacyRowCount(), before);
    });

    test('test_retry_a_source_event', () async {
      final int kat = await seedKategorie(id: 103, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int erloes = await seedKonto(name: 'Erloese');

      final PostingGroupSummary first = await postings.postInvoice(
        eventId: 'inv-retry',
        datum: '2026-03-01',
        beschreibung: 'Wiederholt',
        kategorieId: kat,
        totalCents: 5000,
        debitKontoId: bank,
        creditKontoId: erloes,
      );
      final PostingGroupSummary retry = await postings.postInvoice(
        eventId: 'inv-retry',
        datum: '2026-03-01',
        beschreibung: 'Wiederholt',
        kategorieId: kat,
        totalCents: 5000,
        debitKontoId: bank,
        creditKontoId: erloes,
      );

      expect(retry.rootJournalId, first.rootJournalId);
      expect((await postings.groupLegs(first.rootJournalId)).length, first.legIds.length);
    });

    test('test_repair_the_legacy_all_legs_source_index', () async {
      await db.executor.runCustom('DROP INDEX idx_journal_source_unique');
      await db.executor.runCustom(
        'CREATE UNIQUE INDEX idx_journal_source_unique ON journal(source_kind, source_id) '
        'WHERE source_kind IS NOT NULL AND source_id IS NOT NULL',
      );

      final MigrationRunner runner = MigrationRunner(executor: db.executor, profileDir: '');
      expect(await runner.run(createSchema: () async {}), isTrue);
      final List<Map<String, Object?>> index = await db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'index' AND name = 'idx_journal_source_unique'",
        const <Object?>[],
      );
      expect(index.single['sql'].toString(), contains('gruppe_id = id'));
    });

    test('test_reverse_a_posted_group', () async {
      final int kat = await seedKategorie(id: 104, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int erloes = await seedKonto(name: 'Erloese');
      final int kundeId = await seedKunde();
      final int rechnungId = await seedRechnung(kundeId: kundeId, brutto: '119.00');
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (rechnung_id, betrag, faelligkeit, status) VALUES (?, ?, ?, ?)',
        <Object?>[rechnungId, '19.00', '2026-03-01', 'offen'],
      );
      final PostingGroupSummary original = await postings.postInvoice(
        eventId: 'inv-storno',
        datum: '2026-03-01',
        beschreibung: 'Original',
        kategorieId: kat,
        totalCents: 11900,
        debitKontoId: bank,
        creditKontoId: erloes,
        rechnungId: rechnungId,
      );
      final List<Map<String, Object?>> beforeLegs = await postings.groupLegs(original.rootJournalId);

      final PostingGroupSummary reversal = await postings.reverseInvoiceGroup(
        eventId: 'inv-storno',
        reversalDate: '2026-04-01',
      );

      expect(reversal.debitCents, original.creditCents);
      expect(reversal.creditCents, original.debitCents);
      expect(reversal.rootJournalId, isNot(original.rootJournalId));
      // Original stays unchanged.
      final List<Map<String, Object?>> afterLegs = await postings.groupLegs(original.rootJournalId);
      expect(afterLegs.length, beforeLegs.length);
      for (var i = 0; i < afterLegs.length; i++) {
        expect(afterLegs[i]['soll'].toString(), beforeLegs[i]['soll'].toString());
        expect(afterLegs[i]['haben'].toString(), beforeLegs[i]['haben'].toString());
      }
      // VAT-claim linkage: negated claim row, original untouched.
      final List<Map<String, Object?>> claims = await db.executor.runSelect(
        'SELECT betrag FROM vorsteuer_ansprueche WHERE rechnung_id = ? ORDER BY id',
        <Object?>[rechnungId],
      );
      expect(claims.length, 2);
      expect(money.toCents(money.formatBetrag(claims[1]['betrag'].toString())), -1900);
      // Duplicate reversal is rejected.
      await expectLater(
        postings.reverseInvoiceGroup(eventId: 'inv-storno', reversalDate: '2026-05-01'),
        throwsA(predicate<Object>((Object e) => e.toString().contains('bereits storniert'))),
      );
    });

    test('test_post_a_partial_receipt', () async {
      final int kat = await seedKategorie(id: 105, zeile: 15);
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
        sourceId: 'bt-partial',
        signedAmountCents: 4000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );

      expect(group.unappliedCents, 0);
      expect(group.allocationIds.length, 1);
      final List<StoredAllocation> allocations = await postings.allocationsOf(group.id);
      expect(allocations.single.forderungId, forderung.id);
      expect(allocations.single.settlementDate, '2026-04-02');
      final Forderung? updated = await forderungen.findById(forderung.id);
      expect(updated!.betrag.toStringAsFixed(2), '60.00');
      expect(updated.status, 'teilbezahlt');
    });

    test('test_do_not_post_an_unconfirmed_bank_row', () async {
      final int kontoId = await seedKonto(name: 'Bank');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final int bankId = await db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck, gegenkonto_name, status) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[kontoId, '2026-04-02', '40.00', 'Rechnung 1', 'Kunde', 'neu'],
      );

      // No confirmation happened: nothing was posted.
      expect(await postings.findSettlementByBankRow(bankId), isNull);
      final List<Map<String, Object?>> groups = await db.executor.runSelect(
        'SELECT id FROM settlement_groups',
        const <Object?>[],
      );
      expect(groups, isEmpty);
      final Forderung? untouched = await forderungen.findById(forderung.id);
      expect(untouched!.betrag.toStringAsFixed(2), '100.00');
      expect(untouched.status, 'offen');
    });

    test('test_reverse_a_settlement_restores_the_open_item', () async {
      final int kat = await seedKategorie(id: 106, zeile: 15);
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
        sourceId: 's-restore',
        signedAmountCents: 10000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 10000),
        ],
        kategorieId: kat,
      );

      final SettlementGroupSummary reversal = await postings.reverseSettlementGroup(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 's-restore',
        reversalDate: '2026-05-01',
      );

      final Forderung? restored = await forderungen.findById(forderung.id);
      expect(restored!.betrag.toStringAsFixed(2), '100.00');
      expect(restored.status, 'offen');
      final List<StoredAllocation> reversalAllocations = await postings.allocationsOf(reversal.id);
      expect(reversalAllocations.single.appliedCents, -10000);
      expect(reversalAllocations.single.settlementDate, '2026-05-01');
    });

    test('test_reject_invoice_reversal_with_applied_settlements', () async {
      final int kat = await seedKategorie(id: 107, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final int rechnungId = await seedRechnung(kundeId: kundeId);
      await postings.postInvoice(
        eventId: 'inv-blocked',
        datum: '2026-01-10',
        beschreibung: 'Blockiert',
        kategorieId: kat,
        totalCents: 10000,
        debitKontoId: bank,
        creditKontoId: clearing,
        rechnungId: rechnungId,
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
        rechnungId: rechnungId,
      );
      final SettlementGroupSummary settlement = await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 's-blocking',
        signedAmountCents: 4000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );
      final int legsBefore =
          (await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const <Object?>[])).single['c']! as int;

      await expectLater(
        postings.reverseInvoiceGroup(eventId: 'inv-blocked', reversalDate: '2026-05-01'),
        throwsA(predicate<Object>((Object e) => e.toString().contains('${settlement.id}'))),
      );

      final int legsAfter =
          (await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const <Object?>[])).single['c']! as int;
      expect(legsAfter, legsBefore);
      final Forderung? unchanged = await forderungen.findById(forderung.id);
      expect(unchanged!.betrag.toStringAsFixed(2), '60.00');
    });

    test('test_post_a_supplier_payment', () async {
      final int kat = await seedKategorie(id: 108, zeile: 60);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Verbindlichkeiten');
      final int lieferantId = await seedLieferant();
      final Forderung payable = await forderungen.create(
        typ: 'rechnung_eingang',
        betrag: 200.00,
        partnerTyp: 'lieferant',
        partnerId: lieferantId,
      );

      final SettlementGroupSummary group = await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-supplier',
        signedAmountCents: -20000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: payable.id, appliedCents: 20000),
        ],
        kategorieId: kat,
      );

      expect(group.signedAmountCents, -20000);
      final Forderung? updated = await forderungen.findById(payable.id);
      expect(updated!.betrag.toStringAsFixed(2), '0.00');
      expect(updated.status, 'bezahlt');
    });

    test('test_split_one_transaction_across_invoices', () async {
      final int kat = await seedKategorie(id: 109, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung first = await forderungen.create(
        typ: 'rechnung',
        betrag: 40.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final Forderung second = await forderungen.create(
        typ: 'rechnung',
        betrag: 60.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );

      final SettlementGroupSummary group = await postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-split',
        signedAmountCents: 10000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: first.id, appliedCents: 4000),
          SettlementAllocationInput(forderungId: second.id, appliedCents: 6000),
        ],
        kategorieId: kat,
      );

      expect(group.allocationIds.length, 2);
      expect(group.unappliedCents, 0);
      final List<StoredAllocation> allocations = await postings.allocationsOf(group.id);
      final int applied = allocations.fold<int>(0, (int sum, StoredAllocation a) => sum + a.appliedCents);
      expect(applied + group.unappliedCents, 10000);
      expect((await forderungen.findById(first.id))!.status, 'bezahlt');
      expect((await forderungen.findById(second.id))!.status, 'bezahlt');
    });

    test('test_retain_an_overpayment_as_credit', () async {
      final int kat = await seedKategorie(id: 110, zeile: 15);
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
        sourceId: 'bt-over',
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

      expect((await forderungen.findById(forderung.id))!.status, 'bezahlt');
      expect(group.unappliedCents, 2000);
      // Excess is a separately classified leg, not invoice income.
      final List<Map<String, Object?>> legs = await postings.groupLegs(group.rootJournalId);
      expect(legs.length, 3);
    });

    test('test_repeated_confirmation_does_not_re_apply', () async {
      final int kat = await seedKategorie(id: 111, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      Future<SettlementGroupSummary> settle() => postings.postSettlement(
        sourceKind: PostingSource.bankTransaction,
        sourceId: 'bt-repeat',
        signedAmountCents: 4000,
        settlementDate: '2026-04-02',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );

      final SettlementGroupSummary first = await settle();
      final SettlementGroupSummary retry = await settle();

      expect(retry.id, first.id);
      final Forderung? updated = await forderungen.findById(forderung.id);
      expect(updated!.betrag.toStringAsFixed(2), '60.00');
      expect((await postings.allocationsOf(first.id)).length, 1);
    });

    test('test_in_scope_invoice_does_not_use_the_single_row_path', () async {
      final int kat = await seedKategorie(id: 112, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int erloes = await seedKonto(name: 'Erloese');
      final int legacyBefore = await legacyRowCount();

      final PostingGroupSummary group = await postings.postInvoice(
        eventId: 'inv-nosingle',
        datum: '2026-03-01',
        beschreibung: 'Kein Einzelrow',
        kategorieId: kat,
        totalCents: 10000,
        debitKontoId: bank,
        creditKontoId: erloes,
      );

      // No legacy single gross row was created for the in-scope event.
      expect(await legacyRowCount(), legacyBefore);
      final List<Map<String, Object?>> legs = await postings.groupLegs(group.rootJournalId);
      expect(legs.length, greaterThanOrEqualTo(2));
      var debitSum = 0;
      var creditSum = 0;
      for (final Map<String, Object?> leg in legs) {
        final int soll = money.toCents(money.formatBetrag((leg['soll'] ?? 0).toString()));
        final int haben = money.toCents(money.formatBetrag((leg['haben'] ?? 0).toString()));
        expect(soll > 0 || haben > 0, isTrue);
        expect(soll > 0 && haben > 0, isFalse);
        debitSum += soll;
        creditSum += haben;
      }
      expect(debitSum, creditSum);
    });

    test('test_out_of_scope_writer_keeps_its_maintained_behavior', () async {
      final int kat = await seedKategorie(id: 113, zeile: 15);
      final JournalRepository journal = JournalRepository(db.executor);

      // Recurring-template and setup opening-balance style single rows keep
      // their maintained behavior: one row, self-rooted, durable legacy mark.
      final entry = await journal.create(
        datum: DateTime(2026, 3, 15),
        bezeichnung: 'Vorlage monatlich',
        kategorieId: kat,
        betrag: '50.00',
        art: 'Ausgabe',
      );

      expect(entry.betrag, '50.00');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT gruppe_id, source_kind, legacy_unverified FROM journal WHERE id = ?',
        <Object?>[entry.id],
      );
      expect(rows.single['gruppe_id'], entry.id);
      expect(rows.single['source_kind'], isNull);
      expect(rows.single['legacy_unverified'], 1);
      final List<Map<String, Object?>> groups = await db.executor.runSelect(
        'SELECT id FROM settlement_groups',
        const <Object?>[],
      );
      expect(groups, isEmpty);
    });

    test('test_eur_reads_settlements_not_invoice_dates', () async {
      final int kat = await seedKategorie(id: 114, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      await postings.postInvoice(
        eventId: 'inv-eur',
        datum: '2025-01-10',
        beschreibung: 'Januarrechnung',
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
        sourceKind: PostingSource.cashPayment,
        sourceId: 'cash-eur',
        signedAmountCents: 4000,
        settlementDate: '2025-04-15',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );

      final EuerService euer = EuerService(db.executor);
      final result = await euer.generate(jahr: 2025);

      expect(result.zeile(15), '40.00');
    });

    test('test_eur_rejects_mixed_legacy_and_settlement_data', () async {
      final int kat = await seedKategorie(id: 115, zeile: 15);
      final int bank = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final int legacyId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2025-02-01', 'Altbuchung', kat, '999.00', 'Einnahme'],
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      await postings.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: 'cash-mixed',
        signedAmountCents: 4000,
        settlementDate: '2025-04-15',
        bankKontoId: bank,
        counterKontoId: clearing,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(forderungId: forderung.id, appliedCents: 4000),
        ],
        kategorieId: kat,
      );

      final EuerService euer = EuerService(db.executor);
      await expectLater(
        euer.generate(jahr: 2025),
        throwsA(predicate<Object>((Object e) => e.toString().contains('$legacyId'))),
      );
    });
  });
}
