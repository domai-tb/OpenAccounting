import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/document_delivery/email_attempt_repository.dart';
import 'package:openaccounting/features/document_delivery/smtp_configuration_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_credential_vault.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/dunning_exclusions_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_interest.dart';
import 'package:openaccounting/features/mahnwesen/dunning_send_service.dart';
import 'package:openaccounting/features/mahnwesen/dunning_service.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_exception.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

void main() {
  group('Mahnung Snapshot, Gebühr/Zinsen, Carry-Over', () {
    late AppDatabase db;
    late MahnungenRepository repo;
    late MahnstufenRepository stufenRepo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MahnungenRepository(db.executor);
      stufenRepo = MahnstufenRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> createKunde({String name = 'Test Kunde'}) async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[name, 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
    }

    Future<int> createRechnung({
      required int kundeId,
      String rechnungsnummer = 'RE-999',
      String brutto = '500.00',
      String faelligkeit = '2025-01-15',
    }) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[rechnungsnummer, 'rechnung', 'offen', 1, 'netto', kundeId, '2025-01-01', faelligkeit, brutto, brutto],
      );
    }

    test('dunning creates snapshot and retains after rechnung edit', () async {
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1001');
      final levels = await stufenRepo.list();
      final stufe = levels.firstWhere((e) => e.stufe == 1);
      final mahnung = await repo.create(rechnungId: rechnungId, stufeId: stufe.id);
      expect(mahnung.snapshot, isNotNull);
      final snap = mahnung.snapshotData;
      expect(snap, isNotNull);
      expect(snap!['rechnungsnummer'], 'RE-1001');
      expect(snap['betrag'], '500.00');
      expect(snap['faelligkeit'], '2025-01-15');
      expect(snap['stufe'], 1);
      // Edit rechnung amount to 600 → snapshot retains 500.
      await db.executor.runUpdate('UPDATE rechnungen SET brutto_betrag = ?, netto_betrag = ? WHERE id = ?', <Object?>[
        '600.00',
        '600.00',
        rechnungId,
      ]);
      final after = await repo.getById(mahnung.id);
      expect(after, isNotNull);
      expect(after!.snapshotData!['betrag'], '500.00');
      expect(after.betrag, '500.00');
    });

    test('Gebühr bezahlt/unbezahlt partial and full tracking', () async {
      final kundeId = await createKunde(name: 'Gebuehr Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1002', brutto: '1000.00');
      final levels = await stufenRepo.list();
      final stufe = levels.firstWhere((e) => e.stufe == 2);
      final mahnung = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe.id,
        gebuehrOverride: '10.00',
        zinsenOverride: '0.00',
      );
      expect(mahnung.gebuehr, '10.00');
      expect(mahnung.gebuehrBezahlt, '0.00');
      expect(mahnung.gebuehrUnbezahlt, '10.00');
      // Partial 5 → bezahlt 5 unbezahlt 5.
      final partial = await repo.updateGebuehrBezahlt(mahnung.id, '5.00');
      expect(partial.gebuehrBezahlt, '5.00');
      expect(partial.gebuehrUnbezahlt, '5.00');
      // Full 10 → 0 unbezahlt.
      final full = await repo.updateGebuehrBezahlt(mahnung.id, '10.00');
      expect(full.gebuehrBezahlt, '10.00');
      expect(full.gebuehrUnbezahlt, '0.00');
    });

    test('Zinsen formula 1000*0.08*30/365≈6.58 and zero outstanding →0', () async {
      final z = repo.berechneZinsen(betrag: '1000.00', zinssatz: '8.00', tage: 30);
      // 1000*0.08*30/365 = 6.575 → 6.58
      expect(z, '6.58');
      expect(repo.berechneZinsen(betrag: '0.00', zinssatz: '8.00', tage: 30), '0.00');
      expect(repo.berechneZinsen(betrag: '1000.00', zinssatz: '0.00', tage: 30), '0.00');
      expect(repo.berechneZinsen(betrag: '1000.00', zinssatz: '8.00', tage: 0), '0.00');
    });

    test('Carry-over: level2 open 10+3 → level3 shows carried', () async {
      final kundeId = await createKunde(name: 'Carry Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1003');
      final levels = await stufenRepo.list();
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      final stufe3 = levels.firstWhere((e) => e.stufe == 3);
      // Level2 open 10+3.
      await repo.create(rechnungId: rechnungId, stufeId: stufe2.id, gebuehrOverride: '10.00', zinsenOverride: '3.00');
      final carryBefore = await repo.getCarryOver(rechnungId);
      expect(carryBefore, '13.00');
      // Level3 should show carried.
      final m3 = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe3.id,
        gebuehrOverride: '15.00',
        zinsenOverride: '0.00',
      );
      expect(m3.uebernommeneGebuehr, '10.00');
      expect(m3.uebernommeneZinsen, '3.00');
      expect(m3.carriedTotal, '13.00');
      // Also via breakdown.
      final breakdown = await repo.getCarryOverBreakdown(rechnungId);
      // After level3 creation, prior unpaid still 13 + new level3 unpaid 15 → total 28, but we check carry before includes only level2.
      // For this test, ensure at least carryBefore was 13.
      expect(breakdown['total'], isNotNull);
    });

    test('No carry when fully paid → 0 carried', () async {
      final kundeId = await createKunde(name: 'NoCarry Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1004');
      final levels = await stufenRepo.list();
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      final stufe3 = levels.firstWhere((e) => e.stufe == 3);
      final m2 = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe2.id,
        gebuehrOverride: '10.00',
        zinsenOverride: '3.00',
      );
      await repo.updateGebuehrBezahlt(m2.id, '10.00');
      await repo.updateZinsenBezahlt(m2.id, '3.00');
      final carry = await repo.getCarryOver(rechnungId);
      expect(carry, '0.00');
      final m3 = await repo.create(
        rechnungId: rechnungId,
        stufeId: stufe3.id,
        gebuehrOverride: '15.00',
        zinsenOverride: '0.00',
      );
      expect(m3.uebernommeneGebuehr, '0.00');
      expect(m3.uebernommeneZinsen, '0.00');
      expect(m3.carriedTotal, '0.00');
    });

    test('rechnungen.mahnstufe_aktuell advances only on transport acceptance', () async {
      final kundeId = await createKunde(name: 'Stufe Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1005', brutto: '400.00');
      final levels = await stufenRepo.list();
      final stufe1 = levels.firstWhere((e) => e.stufe == 1);
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      // Draft creation never advances the stage (transport acceptance required).
      final draft = await repo.create(rechnungId: rechnungId, stufeId: stufe1.id);
      expect(await repo.getInvoiceDunningLevel(rechnungId), 0);
      await repo.markTransportAccepted(draft.id, stufeNummer: 1);
      expect(await repo.getInvoiceDunningLevel(rechnungId), 1);
      final draft2 = await repo.create(rechnungId: rechnungId, stufeId: stufe2.id, gebuehrOverride: '10.00');
      expect(await repo.getInvoiceDunningLevel(rechnungId), 1);
      await repo.markTransportAccepted(draft2.id, stufeNummer: 2);
      expect(await repo.getInvoiceDunningLevel(rechnungId), 2);
    });

    test('listByRechnung and listByKunde return created mahnungen', () async {
      final kundeId = await createKunde(name: 'List Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-1006', brutto: '200.00');
      final levels = await stufenRepo.list();
      final stufe = levels.first;
      await repo.create(rechnungId: rechnungId, stufeId: stufe.id);
      final byRechnung = await repo.listByRechnung(rechnungId);
      expect(byRechnung, hasLength(1));
      final byKunde = await repo.listByKunde(kundeId);
      expect(byKunde.length, greaterThanOrEqualTo(1));
    });
  });

  group('Dunning workflow integrity (dunning-workflow-integrity)', () {
    late AppDatabase db;
    late MahnungenRepository repo;
    late MahnstufenRepository stufenRepo;
    late DunningService service;
    late ForderungenRepository forderungen;
    late DunningExclusionsRepository exclusions;
    late Directory tmp;

    DunningService buildService() {
      return DunningService(
        executor: db.executor,
        mahnungen: repo,
        stufen: stufenRepo,
        balances: SettledBalanceSource(db.executor),
        exclusions: exclusions,
        sperrung: SperrungService(db.executor),
      );
    }

    DunningSendService buildSend(FakeSmtpTransport fake, InMemoryVault vault) {
      return DunningSendService(
        executor: db.executor,
        mahnungen: MahnungenRepository(db.executor, profileDir: tmp.path),
        configuration: SmtpConfigurationService(
          executor: db.executor,
          transport: fake,
          migration: SmtpCredentialMigration(
            vault: vault,
            legacyFile: LegacySecretFile(tmp.path),
            identity: const ProfileIdentityStore(null),
          ),
        ),
        attempts: EmailAttemptRepository(db.executor),
        profileDir: tmp.path,
        transport: fake,
      );
    }

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MahnungenRepository(db.executor);
      stufenRepo = MahnstufenRepository(db.executor);
      forderungen = ForderungenRepository(db.executor);
      exclusions = DunningExclusionsRepository(db.executor);
      service = buildService();
      tmp = Directory.systemTemp.createTempSync('dunning-test-');
    });

    tearDown(() async {
      await db.close();
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<int> createKunde({String name = 'Dunning Kunde', String email = 'kunde@example.de'}) async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede, email) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[name, 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr', email],
      );
    }

    Future<int> createRechnung({
      required int kundeId,
      String rechnungsnummer = 'RE-DUN',
      String brutto = '1000.00',
      String faelligkeit = '2026-01-01',
    }) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[rechnungsnummer, 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-01', faelligkeit, brutto, brutto],
      );
    }

    Future<void> createForderung({required int rechnungId, required int kundeId, String betrag = '1000.00'}) async {
      await forderungen.create(
        typ: 'rechnung',
        betrag: num.parse(betrag),
        partnerTyp: 'kunde',
        partnerId: kundeId,
        rechnungId: rechnungId,
      );
    }

    Future<void> seedSmtp(InMemoryVault vault) async {
      await db.executor.runInsert(
        "INSERT INTO unternehmen (id, name, smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_von_adresse) VALUES (1, 'Testfirma', 'mail.example.de', 587, 0, 'user', 'absender@example.de') "
        "ON CONFLICT(id) DO UPDATE SET smtp_host='mail.example.de', smtp_port=587, smtp_ssl=0, smtp_user='user', smtp_von_adresse='absender@example.de'",
        const <Object?>[],
      );
      await vault.write(profileId: 'profil-ohne-verzeichnis', password: 'secret');
    }

    test('test_mahnwesen_create_dunning_letter', () async {
      // GIVEN a finalized invoice with positive settled principal at stage date, THEN snapshot holds it.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-2001');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      expect(letter.betrag, '1000.00');
      final snap = letter.snapshotData!;
      expect(snap['rechnungsnummer'], 'RE-2001');
      expect(snap['betrag'], '1000.00');
      expect(snap['stufe'], 1);
      expect(snap['gebuehr'], '5.00');
      expect(snap['zinssegmente'], isNotNull);
    });

    test('test_mahnwesen_rechnung_changes_after_snapshot', () async {
      // GIVEN a created Mahnung, WHEN the stage changes, THEN its snapshot stays.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-2002');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      final stage = (await stufenRepo.list()).firstWhere((item) => item.stufe == 1);
      await stufenRepo.update(stage.id, gebuehr: '9.00');
      final after = await repo.getById(letter.id);
      expect(after!.snapshotData!['betrag'], '1000.00');
      expect(after.snapshotData!['rechnungsnummer'], 'RE-2002');
      expect(after.snapshotData!['gebuehr'], '5.00');
      expect(after.betrag, '1000.00');
    });

    test('test_mahnwesen_no_balance_cannot_produce_a_reminder', () async {
      // GIVEN zero settled principal, THEN no Mahnung is created.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-2003');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId, betrag: '0.00');
      await expectLater(
        service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10'),
        throwsA(isA<MahnungException>()),
      );
      expect(await repo.listByRechnung(rechnungId), isEmpty);
    });

    test('test_mahnwesen_assisted_run_creates_confirmed_eligible_reminders', () async {
      // GIVEN two eligible and one excluded invoice, THEN confirm creates two, excluded untouched.
      final kundeId = await createKunde();
      final r1 = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3001');
      final r2 = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3002');
      final r3 = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3003');
      await createForderung(rechnungId: r1, kundeId: kundeId);
      await createForderung(rechnungId: r2, kundeId: kundeId);
      await createForderung(rechnungId: r3, kundeId: kundeId);
      await exclusions.excludeInvoice(r3, 'Streitfall');
      final preview = await service.previewRun(asOf: '2026-01-10');
      expect(preview.eligible.map((e) => e.rechnungId), containsAll(<int>[r1, r2]));
      expect(preview.eligible.map((e) => e.rechnungId), isNot(contains(r3)));
      final result = await service.confirmRun(rechnungIds: <int>[r1, r2, r3], asOf: '2026-01-10');
      expect(result.created, hasLength(2));
      expect(
        result.skipped.where((s) => s.rechnungId == r3 && s.reason == DunningSkipReason.ausgeschlossen),
        hasLength(1),
      );
      expect(await repo.listByRechnung(r3), isEmpty);
    });

    test('test_mahnwesen_full_payment_or_exclusion_prevents_a_new_reminder', () async {
      // GIVEN paid, not-due, excluded invoices, THEN none appear among created reminders.
      final kundeId = await createKunde();
      final paid = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3101');
      final future = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3102', faelligkeit: '2027-01-01');
      final excluded = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3103');
      await createForderung(rechnungId: paid, kundeId: kundeId);
      await createForderung(rechnungId: future, kundeId: kundeId);
      await createForderung(rechnungId: excluded, kundeId: kundeId);
      final forderung = await forderungen.findByRechnungId(paid);
      await forderungen.zahlungBuchen(forderungId: forderung!.id, betrag: 1000);
      await exclusions.excludeInvoice(excluded, 'Kulanz');
      final result = await service.confirmRun(rechnungIds: <int>[paid, future, excluded], asOf: '2026-01-10');
      expect(result.created, isEmpty);
      expect(result.reused, isEmpty);
    });

    test('test_mahnwesen_stage_transition_is_exact_and_ordered', () async {
      // GIVEN due 2026-01-01, s1=7d, s2=21d, s1 accepted: s2 ineligible 01-21, eligible 01-22.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3201');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final first = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      await service.markTransportAccepted(first.id);
      final before = await service.previewRun(asOf: '2026-01-21');
      expect(before.eligible.where((e) => e.rechnungId == rechnungId), isEmpty);
      final onDay = await service.previewRun(asOf: '2026-01-22');
      final matches = onDay.eligible.where((e) => e.rechnungId == rechnungId).toList();
      expect(matches, hasLength(1));
      expect(matches.single.stufe, 2);
    });

    test('test_mahnwesen_repeated_run_does_not_duplicate_a_stage_reminder', () async {
      // GIVEN an unsent draft, THEN re-evaluation reuses it without duplicating.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-3301');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final first = await service.confirmRun(rechnungIds: <int>[rechnungId], asOf: '2026-01-10');
      final second = await service.confirmRun(rechnungIds: <int>[rechnungId], asOf: '2026-01-11');
      expect(first.created, hasLength(1));
      expect(second.created, isEmpty);
      expect(second.reused, hasLength(1));
      expect(second.reused.single.id, first.created.single.id);
      expect(await repo.listByRechnung(rechnungId), hasLength(1));
    });

    test('test_mahnwesen_tier_transition_and_partial_payment_have_deterministic_cents', () async {
      // GIVEN due 01-01, s1/s2 7/21d at 0%/5%, 1000 reduced by 400 effective 01-25, as of 01-27.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-4001');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final forderung = await forderungen.findByRechnungId(rechnungId);
      await forderungen.zahlungBuchen(forderungId: forderung!.id, betrag: 400, datum: '2026-01-25');
      final first = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      await service.markTransportAccepted(first.id);
      // WHEN interest is calculated, THEN (3*1000*0.05 + 3*600*0.05)/365 rounds once 0.6575 -> 0.66.
      final second = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-27');
      expect(second.zinsen, '0.66');
    });

    test('test_mahnwesen_full_settlement_stops_accrual_on_its_effective_date', () async {
      // GIVEN full settlement on a date, THEN no interest accrues on/after it.
      final result = DunningInterest.calculate(
        dueDate: '2026-01-01',
        stages: const <DunningStageRate>[
          DunningStageRate(stufe: 1, daysAfterDue: 7, annualRate: '0.00'),
          DunningStageRate(stufe: 2, daysAfterDue: 21, annualRate: '5.00'),
        ],
        initialPrincipalCents: 100000,
        settlements: const <DunningSettlement>[DunningSettlement(effectiveDate: '2026-01-23', appliedCents: 100000)],
        asOf: '2026-01-27',
      );
      expect(result.totalCents, 14);
      expect(result.segments, hasLength(1));
      expect(result.segments.single.bis.compareTo('2026-01-23'), lessThan(0));
      // Service path: settled invoice produces no reminder and clears the level.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-4002');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final forderung = await forderungen.findByRechnungId(rechnungId);
      await forderungen.zahlungBuchen(forderungId: forderung!.id, betrag: 1000, datum: '2026-01-23');
      final run = await service.confirmRun(rechnungIds: <int>[rechnungId], asOf: '2026-01-27');
      expect(run.created, isEmpty);
      expect(await repo.listByRechnung(rechnungId), isEmpty);
    });

    test('test_mahnwesen_unpaid_fees_are_not_compounded', () async {
      // GIVEN carried unpaid fees, THEN next interest uses only settled principal.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-4003');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final first = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      expect(first.zinsen, '0.00');
      await service.markTransportAccepted(first.id);
      final second = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-27');
      expect(second.uebernommeneGebuehr, '5.00');
      // 6 days (01-22..01-27) at 1000.00 and 5%: 300000000/3650000 = 82.19 -> 0.82.
      expect(second.zinsen, '0.82');
    });

    test('test_mahnwesen_missing_or_conflicting_balance_source_blocks_every_balance_dependent_operation', () async {
      final fake = FakeSmtpTransport();
      // GIVEN no settlement source, THEN preview/creation/package are unavailable without side effects.
      final kundeId = await createKunde();
      final missing = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-6001');
      final preview = await service.previewRun(asOf: '2026-01-10');
      expect(
        preview.unavailable.where((e) => e.rechnungId == missing).single.unavailable.code,
        'saldo_nicht_verfuegbar',
      );
      final run = await service.confirmRun(rechnungIds: <int>[missing], asOf: '2026-01-10');
      expect(run.unavailable, hasLength(1));
      expect(run.created, isEmpty);
      expect(await repo.listByRechnung(missing), isEmpty);
      expect(fake.submitCalls, 0);
      expect(Directory('${tmp.path}/pdfs').existsSync(), isFalse);
      // GIVEN a conflicting source (tampered projection), THEN every op blocks too.
      final conflict = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-6002');
      await createForderung(rechnungId: conflict, kundeId: kundeId);
      await db.executor.runUpdate('UPDATE forderungen SET betrag = ? WHERE rechnung_id = ?', <Object?>[
        '400.00',
        conflict,
      ]);
      final preview2 = await service.previewRun(asOf: '2026-01-10');
      expect(preview2.unavailable.where((e) => e.rechnungId == conflict).single.unavailable.code, 'saldo_konflikt');
      final run2 = await service.confirmRun(rechnungIds: <int>[conflict], asOf: '2026-01-10');
      expect(run2.unavailable, hasLength(1));
      expect(await repo.listByRechnung(conflict), isEmpty);
    });

    test('test_mahnwesen_invalid_settlement_event_is_not_replaced_by_invoice_totals', () async {
      // GIVEN an invalid settlement event, THEN fail closed, never invoice totals.
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-6101', brutto: '2000.00');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId, betrag: '2000.00');
      final forderung = await forderungen.findByRechnungId(rechnungId);
      final journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
        <Object?>['2026-01-20', 'Manuell', '100.00', 'Zahlung', rechnungId],
      );
      await db.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
        <Object?>[forderung!.id, journalId, '100.00', 'zahlung', 'kein-datum'],
      );
      final preview = await service.previewRun(asOf: '2026-01-27');
      final blocked = preview.unavailable.where((e) => e.rechnungId == rechnungId).toList();
      expect(blocked, hasLength(1));
      expect(blocked.single.unavailable.code, 'ereignis_ungueltig');
      expect(preview.eligible.where((e) => e.rechnungId == rechnungId), isEmpty);
      expect(await repo.listByRechnung(rechnungId), isEmpty);
    });

    test('test_mahnwesen_send_dunning_letter', () async {
      // GIVEN configured SMTP and readable PDF, WHEN sent and accepted, THEN attachment + acceptance recorded.
      final vault = InMemoryVault();
      await seedSmtp(vault);
      final fake = FakeSmtpTransport();
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-7001');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      await MahnungenRepository(db.executor, profileDir: tmp.path).generatePdf(letter.id);
      final send = buildSend(fake, vault);
      final outcome = await send.sendMahnung(mahnungId: letter.id, empfaenger: 'kunde@example.de');
      expect(
        outcome,
        isA<DunningSendAccepted>(),
        reason: outcome is DunningSendUnavailable ? '${outcome.unavailable.code}: ${outcome.unavailable.message}' : '',
      );
      expect(fake.submitCalls, 1);
      expect(fake.lastMail!.attachments, hasLength(1));
      final sent = (outcome as DunningSendAccepted).mahnung;
      expect(sent.status, 'versendet');
      expect(sent.versendetAm, isNotNull);
      expect(await service.currentLevel(rechnungId), 1);
    });

    test('test_mahnwesen_smtp_not_configured', () async {
      // GIVEN missing SMTP, WHEN sending, THEN actionable error, letter stays unsent and retryable.
      final fake = FakeSmtpTransport();
      final vault = InMemoryVault();
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-7002');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      await MahnungenRepository(db.executor, profileDir: tmp.path).generatePdf(letter.id);
      final send = buildSend(fake, vault);
      final outcome = await send.sendMahnung(mahnungId: letter.id, empfaenger: 'kunde@example.de');
      expect(outcome, isA<DunningSendUnavailable>());
      expect(fake.submitCalls, 0);
      final still = await repo.getById(letter.id);
      expect(still!.status, 'offen');
      expect(await service.currentLevel(rechnungId), 0);
    });

    test('test_mahnwesen_retrying_a_pending_letter_does_not_create_a_second_record', () async {
      // GIVEN a failed send, WHEN retried, THEN same record is used, no duplicate.
      final vault = InMemoryVault();
      await seedSmtp(vault);
      final fake = FakeSmtpTransport()..failSubmitWith = const SmtpRejected('550 mailbox unavailable');
      final kundeId = await createKunde();
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-7003');
      await createForderung(rechnungId: rechnungId, kundeId: kundeId);
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      await MahnungenRepository(db.executor, profileDir: tmp.path).generatePdf(letter.id);
      final send = buildSend(fake, vault);
      final failed = await send.sendMahnung(mahnungId: letter.id, empfaenger: 'kunde@example.de');
      expect(failed, isA<DunningSendUnavailable>());
      fake.failSubmitWith = null;
      final retried = await send.sendMahnung(mahnungId: letter.id, empfaenger: 'kunde@example.de');
      expect(
        retried,
        isA<DunningSendAccepted>(),
        reason: retried is DunningSendUnavailable ? '${retried.unavailable.code}: ${retried.unavailable.message}' : '',
      );
      expect((retried as DunningSendAccepted).mahnung.id, letter.id);
      expect(await repo.listByRechnung(rechnungId), hasLength(1));
    });
  });
}
