import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/settlement_confirmation_service.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

/// TDD suite for confirmed payment application (§4, §10). Suggestions alone
/// never post; only explicit confirmation writes the atomic settlement group
/// plus the open-item update. The dunning trigger clears on full payment.
void main() {
  group('Confirmed payment application posts settlement atomically', () {
    late AppDatabase db;
    late SettlementConfirmationService confirmations;
    late ForderungenRepository forderungen;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      confirmations = SettlementConfirmationService(db.executor);
      await confirmations.ensureSchema();
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

    Future<int> seedBankRow({required int kontoId, required String datum, required String betrag}) async {
      return db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck, gegenkonto_name, status) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[kontoId, datum, betrag, 'Rechnung', 'Partner', 'neu'],
      );
    }

    Future<String> bankStatus(int id) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT status FROM bank_transaktionen WHERE id = ?',
        <Object?>[id],
      );
      return rows.single['status'].toString();
    }

    test('test_confirm_a_matched_receipt', () async {
      final int kat = await seedKategorie(id: 301, zeile: 15);
      final int bankKonto = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '40.00');
      await seedKategorie(id: 302, zeile: 15);

      final SettlementGroupSummary group = await confirmations.confirm(
        bankTransactionId: bankId,
        allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: forderung.id, appliedCents: 4000)],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        kategorieId: kat,
      );

      // Balanced group references transaction and receivable; both commit together.
      expect(group.signedAmountCents, 4000);
      expect(group.settlementDate, '2026-04-02');
      expect(group.unappliedCents, 0);
      final PostingGroupService postings = PostingGroupService(db.executor);
      final List<StoredAllocation> allocations = await postings.allocationsOf(group.id);
      final int applied = allocations.fold<int>(0, (int sum, StoredAllocation a) => sum + a.appliedCents);
      expect(applied + group.unappliedCents, 4000);
      final Forderung? updated = await forderungen.findById(forderung.id);
      expect(updated!.betrag.toStringAsFixed(2), '60.00');
      expect(updated.status, 'teilbezahlt');
      expect(await bankStatus(bankId), 'gebucht');

      // Remainder on a second bank row closes the item.
      final int secondBank = await seedBankRow(kontoId: bankKonto, datum: '2026-04-10', betrag: '60.00');
      await confirmations.confirm(
        bankTransactionId: secondBank,
        allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: forderung.id, appliedCents: 6000)],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        kategorieId: kat,
      );
      final Forderung? closed = await forderungen.findById(forderung.id);
      expect(closed!.betrag.toStringAsFixed(2), '0.00');
      expect(closed.status, 'bezahlt');
    });

    test('test_leave_an_ambiguous_suggestion_unapplied', () async {
      final int bankKonto = await seedKonto(name: 'Bank');
      final int kundeId = await seedKunde();
      final Forderung first = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final Forderung second = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final BankImportService imports = BankImportService(db.executor);
      final ImportResult result = await imports.importTransactions(
        kontoId: bankKonto,
        rawTxs: <RawTx>[
          RawTx(datum: DateTime(2026, 4, 2), betrag: '100.00', verwendungszweck: 'Rechnung unklar', partner: 'Kunde'),
        ],
        locale: 'de',
      );

      // Multiple candidate invoices, no user confirmation: nothing applied.
      expect(result.imported, 1);
      final List<Map<String, Object?>> groups = await db.executor.runSelect(
        'SELECT id FROM settlement_groups',
        const <Object?>[],
      );
      expect(groups, isEmpty);
      expect((await forderungen.findById(first.id))!.status, 'offen');
      expect((await forderungen.findById(second.id))!.status, 'offen');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        "SELECT status FROM bank_transaktionen WHERE konto_id = ? AND status = 'neu'",
        <Object?>[bankKonto],
      );
      expect(rows.length, 1);
    });

    test('test_roll_back_a_failed_settlement', () async {
      final int kat = await seedKategorie(id: 303, zeile: 15);
      final int bankKonto = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '40.00');

      // Unresolvable bank account: the whole confirmation rolls back.
      await expectLater(
        confirmations.confirm(
          bankTransactionId: bankId,
          allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: forderung.id, appliedCents: 4000)],
          bankKontoId: 999999,
          counterKontoId: clearing,
          kategorieId: kat,
        ),
        throwsA(isA<SettlementConfirmationException>()),
      );

      final Forderung? unchanged = await forderungen.findById(forderung.id);
      expect(unchanged!.betrag.toStringAsFixed(2), '100.00');
      expect(unchanged.status, 'offen');
      expect(await bankStatus(bankId), 'neu');
      final List<Map<String, Object?>> groups = await db.executor.runSelect(
        'SELECT id FROM settlement_groups',
        const <Object?>[],
      );
      expect(groups, isEmpty);
    });

    test('test_confirm_a_supplier_payment', () async {
      final int kat = await seedKategorie(id: 304, zeile: 60);
      final int bankKonto = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Verbindlichkeiten');
      final int lieferantId = await seedLieferant();
      final Forderung payable = await forderungen.create(
        typ: 'rechnung_eingang',
        betrag: 200.00,
        partnerTyp: 'lieferant',
        partnerId: lieferantId,
      );
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '-200.00');

      final SettlementGroupSummary group = await confirmations.confirm(
        bankTransactionId: bankId,
        allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: payable.id, appliedCents: 20000)],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        kategorieId: kat,
      );

      expect(group.signedAmountCents, -20000);
      expect(group.settlementDate, '2026-04-02');
      final Forderung? updated = await forderungen.findById(payable.id);
      expect(updated!.betrag.toStringAsFixed(2), '0.00');
      expect(updated.status, 'bezahlt');
    });

    test('test_split_one_transaction_across_invoices', () async {
      final int kat = await seedKategorie(id: 305, zeile: 15);
      final int bankKonto = await seedKonto(name: 'Bank');
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
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '100.00');

      final SettlementGroupSummary group = await confirmations.confirm(
        bankTransactionId: bankId,
        allocations: <ConfirmationAllocation>[
          ConfirmationAllocation(forderungId: first.id, appliedCents: 4000),
          ConfirmationAllocation(forderungId: second.id, appliedCents: 6000),
        ],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        kategorieId: kat,
      );

      final PostingGroupService postings = PostingGroupService(db.executor);
      final List<StoredAllocation> allocations = await postings.allocationsOf(group.id);
      expect(allocations.length, 2);
      final int applied = allocations.fold<int>(0, (int sum, StoredAllocation a) => sum + a.appliedCents);
      expect(applied + group.unappliedCents, 10000);
      // Exactly one group for the one bank transaction.
      final List<Map<String, Object?>> groups = await db.executor.runSelect(
        'SELECT id FROM settlement_groups WHERE bank_transaction_id = ?',
        <Object?>[bankId],
      );
      expect(groups.length, 1);
    });

    test('test_retain_a_confirmed_overpayment_as_credit', () async {
      final int kat = await seedKategorie(id: 306, zeile: 15);
      final int bankKonto = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int credit = await seedKonto(name: 'Ueberzahlung');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '120.00');

      final SettlementGroupSummary group = await confirmations.confirm(
        bankTransactionId: bankId,
        allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: forderung.id, appliedCents: 10000)],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        creditKontoId: credit,
        kategorieId: kat,
      );

      final Forderung? closed = await forderungen.findById(forderung.id);
      expect(closed!.status, 'bezahlt');
      expect(group.unappliedCents, 2000);
    });

    test('test_repeated_confirmation_does_not_duplicate', () async {
      final int kat = await seedKategorie(id: 307, zeile: 15);
      final int bankKonto = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
      );
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '40.00');
      Future<SettlementGroupSummary> confirm() => confirmations.confirm(
        bankTransactionId: bankId,
        allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: forderung.id, appliedCents: 4000)],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        kategorieId: kat,
      );

      final SettlementGroupSummary first = await confirm();
      final SettlementGroupSummary retry = await confirm();

      expect(retry.id, first.id);
      final Forderung? updated = await forderungen.findById(forderung.id);
      expect(updated!.betrag.toStringAsFixed(2), '60.00');
      final List<Map<String, Object?>> groups = await db.executor.runSelect(
        'SELECT id FROM settlement_groups WHERE bank_transaction_id = ?',
        <Object?>[bankId],
      );
      expect(groups.length, 1);
    });

    test('test_full_payment_clears_the_dunning_trigger', () async {
      final int kat = await seedKategorie(id: 308, zeile: 15);
      final int bankKonto = await seedKonto(name: 'Bank');
      final int clearing = await seedKonto(name: 'Forderungen');
      final int kundeId = await seedKunde();
      final int rechnungId = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
        'brutto_betrag, mahnstufe_aktuell) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-DUN', 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-10', '100.00', 2],
      );
      final Forderung forderung = await forderungen.create(
        typ: 'rechnung',
        betrag: 100.00,
        partnerTyp: 'kunde',
        partnerId: kundeId,
        rechnungId: rechnungId,
      );
      final int bankId = await seedBankRow(kontoId: bankKonto, datum: '2026-04-02', betrag: '100.00');

      await confirmations.confirm(
        bankTransactionId: bankId,
        allocations: <ConfirmationAllocation>[ConfirmationAllocation(forderungId: forderung.id, appliedCents: 10000)],
        bankKontoId: bankKonto,
        counterKontoId: clearing,
        kategorieId: kat,
      );

      final Forderung? closed = await forderungen.findById(forderung.id);
      expect(closed!.status, 'bezahlt');
      expect(closed.betrag.toStringAsFixed(2), '0.00');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT mahnstufe_aktuell FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      expect(rows.single['mahnstufe_aktuell'], 0);
    });
  });
}
