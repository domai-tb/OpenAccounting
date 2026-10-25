import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/accounting/tagesabschluss_creation.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';
import 'package:openaccounting/features/cashbook/cashbook_balance_source.dart';

void main() {
  test('test_expected_balance_or_persistence_mapping_is_unavailable', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult unavailable = CashbookBalanceResult.unavailable(
      companyId: '1',
      accountId: '9001',
      asOfDate: DateTime.now(),
      currencyCode: 'EUR',
      sourceReference: 'unavailable',
      sourceReferences: const <String>[],
      reason: CashbookBalanceUnavailableReason.historyCoverageIncomplete,
    );

    await expectLater(
      TagesabschlussFinalization(db.executor).finalize(balance: unavailable, countedBalanceCents: 10000),
      throwsA(
        isA<TagesabschlussFinalizationException>().having(
          (TagesabschlussFinalizationException error) => error.failure,
          'failure',
          TagesabschlussFinalizationFailure.unavailableBalance,
        ),
      ),
    );
    expect(
      (await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM tagesabschluesse',
        const <Object?>[],
      )).single['count'],
      0,
    );
  });

  test('test_discrepancy_explanation_is_enforced_by_finalization', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    expect(balance.complete, isTrue);

    await expectLater(
      TagesabschlussFinalization(db.executor).finalize(balance: balance, countedBalanceCents: 9000),
      throwsA(
        isA<TagesabschlussFinalizationException>().having(
          (TagesabschlussFinalizationException error) => error.failure,
          'failure',
          TagesabschlussFinalizationFailure.explanationRequired,
        ),
      ),
    );
    expect(
      (await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM tagesabschluesse',
        const <Object?>[],
      )).single['count'],
      0,
    );
  });

  test('test_daily_close_finalization_persists_evidence', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    expect(balance.complete, isTrue);

    await TagesabschlussFinalization(db.executor).finalize(balance: balance, countedBalanceCents: 10000);

    final List<Map<String, Object?>> rows = await db.executor.runSelect(
      'SELECT zaehlung_json, integrity_hash FROM tagesabschluesse',
      const <Object?>[],
    );
    expect(rows, hasLength(1));
  });

  test('test_daily_close_finalization_revalidates_balance_before_persisting', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    expect(balance.complete, isTrue);
    await db.executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id) VALUES (?, ?, ?, ?, ?)',
      <Object?>[_localDate(DateTime.now()), 'Legacy imported row', '18.50', 'Import', 9001],
    );

    await expectLater(
      TagesabschlussFinalization(db.executor).finalize(balance: balance, countedBalanceCents: 10000),
      throwsA(
        isA<TagesabschlussFinalizationException>().having(
          (TagesabschlussFinalizationException error) => error.failure,
          'failure',
          TagesabschlussFinalizationFailure.balanceChanged,
        ),
      ),
    );
    expect(
      (await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM tagesabschluesse',
        const <Object?>[],
      )).single['count'],
      0,
    );
  });

  test('test_daily_close_persistence_failure_rolls_back', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    expect(balance.complete, isTrue);
    await db.executor.runCustom('''
CREATE TRIGGER reject_test_daily_close_insert
BEFORE INSERT ON tagesabschluesse
BEGIN
  SELECT RAISE(ABORT, 'injected persistence failure');
END
''');

    await expectLater(
      TagesabschlussFinalization(db.executor).finalize(balance: balance, countedBalanceCents: 10000),
      throwsA(isA<Exception>()),
    );
    expect(
      (await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM tagesabschluesse',
        const <Object?>[],
      )).single['count'],
      0,
    );
  });

  testWidgets('test_existing_close_remains_read_only', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    final TagesabschlussFinalization finalization = TagesabschlussFinalization(db.executor);
    final TagesabschlussCloseLookup created = await finalization.finalize(balance: balance, countedBalanceCents: 10000);
    expect(created.status, TagesabschlussCloseStatus.verified);
    expect(created.created, isTrue);
    final CashbookBalanceResult unavailable = CashbookBalanceResult.unavailable(
      companyId: '1',
      accountId: '9001',
      asOfDate: balance.asOfDate,
      currencyCode: 'EUR',
      sourceReference: 'unavailable',
      sourceReferences: const <String>[],
      reason: CashbookBalanceUnavailableReason.historyCoverageIncomplete,
    );
    final TagesabschlussCloseLookup replay = await finalization.finalize(
      balance: unavailable,
      countedBalanceCents: 999,
    );
    expect(replay.status, TagesabschlussCloseStatus.verified);
    expect(replay.created, isFalse);
    final List<Map<String, Object?>> before = await db.executor.runSelect(
      'SELECT datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
      'FROM tagesabschluesse ORDER BY id',
      const <Object?>[],
    );

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=close');
    await tester.pumpAndSettle();
    await _selectDailyCloseAccountAndDate(tester);

    expect(find.byKey(const ValueKey<String>('daily-close-verified-snapshot')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-counted-balance')), findsNothing);
    expect(find.byKey(const ValueKey<String>('daily-close-explanation')), findsNothing);
    expect(find.byKey(const ValueKey<String>('daily-close-finalize')), findsNothing);
    expect(
      await db.executor.runSelect(
        'SELECT datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
        'FROM tagesabschluesse ORDER BY id',
        const <Object?>[],
      ),
      before,
    );
  });

  test('test_tampered_finalized_close_is_unverified_and_never_replaced', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    final String date = _localDate(balance.asOfDate);
    final Map<String, Object?> snapshot = <String, Object?>{
      'account_id': '9001',
      'company_id': '1',
      'counted_amount_cents': 10000,
      'currency_code': 'EUR',
      'date': date,
      'difference_cents': 0,
      'expected_amount_cents': 10000,
      'explanation': null,
      'schema_version': 1,
      'source_reference': balance.sourceReference,
    };
    await db.executor.runInsert(
      'INSERT INTO tagesabschluesse '
      '(datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[date, '100.00', '100.00', '0.00', 1, 9001, jsonEncode(snapshot), 'sha256:tampered'],
    );
    final TagesabschlussFinalization finalization = TagesabschlussFinalization(db.executor);
    final List<Map<String, Object?>> before = await db.executor.runSelect(
      'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
      'FROM tagesabschluesse ORDER BY id',
      const <Object?>[],
    );

    final TagesabschlussCloseLookup lookup = await finalization.lookupExisting(
      companyId: '1',
      accountId: '9001',
      asOfDate: balance.asOfDate,
    );
    expect(lookup.status, TagesabschlussCloseStatus.unverified);
    final TagesabschlussCloseLookup replay = await finalization.finalize(balance: balance, countedBalanceCents: 10000);
    expect(replay.status, TagesabschlussCloseStatus.unverified);
    expect(
      await db.executor.runSelect(
        'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
        'FROM tagesabschluesse ORDER BY id',
        const <Object?>[],
      ),
      before,
    );
  });

  test('test_schema_version_json_double_is_unverified_without_mutation', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    final String date = _localDate(balance.asOfDate);
    final Map<String, Object?> snapshot = <String, Object?>{
      'account_id': '9001',
      'company_id': '1',
      'counted_amount_cents': 10000,
      'currency_code': 'EUR',
      'date': date,
      'difference_cents': 0,
      'expected_amount_cents': 10000,
      'explanation': null,
      'schema_version': 1.0,
      'source_reference': balance.sourceReference,
    };
    final String canonicalJson = jsonEncode(snapshot);
    expect(canonicalJson, contains('"schema_version":1.0'));
    final String correctDigest = 'sha256:${sha256.convert(utf8.encode(canonicalJson))}';
    await db.executor.runInsert(
      'INSERT INTO tagesabschluesse '
      '(datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[date, '100.00', '100.00', '0.00', 1, 9001, canonicalJson, correctDigest],
    );
    final TagesabschlussFinalization finalization = TagesabschlussFinalization(db.executor);
    final List<Map<String, Object?>> before = await db.executor.runSelect(
      'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
      'FROM tagesabschluesse ORDER BY id',
      const <Object?>[],
    );

    final TagesabschlussCloseLookup lookup = await finalization.lookupExisting(
      companyId: '1',
      accountId: '9001',
      asOfDate: balance.asOfDate,
    );
    expect(lookup.status, TagesabschlussCloseStatus.unverified);
    final TagesabschlussCloseLookup replay = await finalization.finalize(balance: balance, countedBalanceCents: 10000);
    expect(replay.status, TagesabschlussCloseStatus.unverified);
    expect(
      await db.executor.runSelect(
        'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
        'FROM tagesabschluesse ORDER BY id',
        const <Object?>[],
      ),
      before,
    );
  });

  test('test_concurrent_close_finalization_cannot_duplicate_a_record', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    final TagesabschlussFinalization finalization = TagesabschlussFinalization(db.executor);

    final List<TagesabschlussCloseLookup> results = await Future.wait<TagesabschlussCloseLookup>(
      <Future<TagesabschlussCloseLookup>>[
        finalization.finalize(balance: balance, countedBalanceCents: 10000),
        finalization.finalize(balance: balance, countedBalanceCents: 10000),
      ],
    );
    expect(
      results.map((TagesabschlussCloseLookup result) => result.status),
      everyElement(TagesabschlussCloseStatus.verified),
    );
    expect(results.where((TagesabschlussCloseLookup result) => result.created), hasLength(1));

    expect(
      (await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM tagesabschluesse',
        const <Object?>[],
      )).single['count'],
      1,
    );
  });

  test('test_ambiguous_legacy_closes_block_finalization', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final String date = _localDate(DateTime.now());
    await _insertLegacyClose(db, date: date, companyId: 1, accountId: 9001, expected: '100.00', counted: '95.00');
    await _insertLegacyClose(db, date: date, companyId: 1, accountId: 9001, expected: '100.00', counted: '90.00');
    await _insertLegacyClose(db, date: date, companyId: 1, accountId: null, expected: '100.00', counted: '85.00');
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    final List<Map<String, Object?>> before = await db.executor.runSelect(
      'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur, zaehlung_json, '
      'integrity_hash FROM tagesabschluesse ORDER BY id',
      const <Object?>[],
    );

    final TagesabschlussCloseLookup close = await TagesabschlussFinalization(db.executor)
        .finalize(balance: balance, countedBalanceCents: 10000);
    expect(close.status, TagesabschlussCloseStatus.unverified);

    expect(
      await db.executor.runSelect(
        'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur, zaehlung_json, '
        'integrity_hash FROM tagesabschluesse ORDER BY id',
        const <Object?>[],
      ),
      before,
    );
  });

  testWidgets('test_single_unsigned_legacy_close_blocks_finalization', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final String date = _localDate(DateTime.now());
    await _insertLegacyClose(db, date: date, companyId: 1, accountId: 9001, expected: '100.00', counted: '95.00');
    final List<Map<String, Object?>> before = await db.executor.runSelect(
      'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur, zaehlung_json, '
      'integrity_hash FROM tagesabschluesse ORDER BY id',
      const <Object?>[],
    );

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=close');
    await tester.pumpAndSettle();
    await _selectDailyCloseAccountAndDate(tester);

    expect(find.byKey(const ValueKey<String>('daily-close-unverified-history')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-counted-balance')), findsNothing);
    expect(find.byKey(const ValueKey<String>('daily-close-finalize')), findsNothing);
    final TagesabschlussCloseLookup close = await TagesabschlussFinalization(db.executor).finalize(
      balance: await CashbookBalanceSource(db.executor).resolve(
        CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'),
      ),
      countedBalanceCents: 10000,
    );
    expect(close.status, TagesabschlussCloseStatus.unverified);
    expect(
      await db.executor.runSelect(
        'SELECT id, datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur, zaehlung_json, '
        'integrity_hash FROM tagesabschluesse ORDER BY id',
        const <Object?>[],
      ),
      before,
    );
  });

  testWidgets('test_approved_cash_event_appears_in_the_cashbook', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final PostingGroupService postings = PostingGroupService(db.executor);
    await postings.ensureSchema();
    await db.executor.runInsert(
      'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, '
      'mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
      <Object?>[7001, 'Kassenumsatz', '8400', '4400', 12, 'catalog_verified', 'TEST', '2026-test.1'],
    );
    final DateTime today = DateTime.now();
    final SettlementGroupSummary event = await postings.postSettlement(
      sourceKind: PostingSource.cashPayment,
      sourceId: 'approved-cash-receipt-1',
      signedAmountCents: 1250,
      settlementDate: _localDate(today),
      bankKontoId: 9001,
      counterKontoId: 9002,
      allocations: <SettlementAllocationInput>[
        const SettlementAllocationInput(appliedCents: 1250, kategorieId: 7001, euerZeile: 12),
      ],
      beschreibung: 'Approved cash receipt',
    );

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=cashbook');
    await tester.pumpAndSettle();
    await _selectCashbookAccountAndDate(tester);

    expect(find.byKey(ValueKey<String>('cashbook-event-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-date-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-direction-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-amount-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-amount-basis-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-category-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-tax-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-description-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-posting-${event.rootJournalId}')), findsOneWidget);
    expect(find.byKey(ValueKey<String>('cashbook-event-receipt-${event.rootJournalId}')), findsNothing);
    expect(find.text('Approved cash receipt'), findsOneWidget);
    expect(find.text('Richtung: Einnahme'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(ValueKey<String>('cashbook-event-amount-${event.rootJournalId}'))).data,
      matches(RegExp('Betrag: 12[,.]50 EUR')),
    );
    expect(find.text('Betragsgrundlage: Gebuchte Kassenwirkung'), findsOneWidget);
    expect(find.text('Kategorie: Kassenumsatz'), findsOneWidget);
    expect(find.text('Steuerbehandlung: Steuersatz nicht hinterlegt'), findsOneWidget);
    expect(find.text('Buchungsidentität: #${event.rootJournalId} · approved-cash-receipt-1'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cashbook-event-list')), findsOneWidget);
  });

  testWidgets('test_missing_posting_contract_blocks_cash_entry', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    await PostingGroupService(db.executor).ensureSchema();
    final List<Map<String, Object?>> before = await db.executor.runSelect(
      'SELECT (SELECT COUNT(*) FROM journal) AS journal_rows, '
      '(SELECT COUNT(*) FROM settlement_groups) AS posting_groups, '
      '(SELECT COUNT(*) FROM journal WHERE beleg_id IS NOT NULL) AS receipt_links',
      const <Object?>[],
    );

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=cashbook');
    await tester.pumpAndSettle();
    await _selectCashbookAccountAndDate(tester);

    expect(find.byKey(const ValueKey<String>('cashbook-event-list')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cashbook-result-unavailable')), findsNothing);
    final Finder unavailable = find.byKey(const ValueKey<String>('cashbook-entry-contract-unavailable'));
    expect(unavailable, findsOneWidget);
    expect(
      tester.widget<Text>(unavailable).data,
      'Schreibgeschützte Kassenhistorie aus gebuchten Kassenbewegungen und verifizierter Saldenvorschau.',
    );
    expect(find.byKey(const ValueKey<String>('cashbook-entry-form')), findsNothing);
    expect(find.byKey(const ValueKey<String>('cashbook-entry-submit')), findsNothing);

    final List<Map<String, Object?>> after = await db.executor.runSelect(
      'SELECT (SELECT COUNT(*) FROM journal) AS journal_rows, '
      '(SELECT COUNT(*) FROM settlement_groups) AS posting_groups, '
      '(SELECT COUNT(*) FROM journal WHERE beleg_id IS NOT NULL) AS receipt_links',
      const <Object?>[],
    );
    expect(after, before);
  });

  test('test_cash_posting_and_receipt_reference_roll_back_together', () async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final PostingGroupService postings = PostingGroupService(db.executor);
    await postings.ensureSchema();
    await db.executor.runInsert(
      'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, '
      'mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
      <Object?>[7001, 'Kassenumsatz', '8400', '4400', 12, 'catalog_verified', 'TEST', '2026-test.1'],
    );
    final DateTime today = DateTime.now();
    final int receiptId = await db.executor.runInsert('INSERT INTO belege (datum, betrag) VALUES (?, ?)', <Object?>[
      _localDate(today),
      '12.50',
    ]);
    await db.executor.runCustom(
      'CREATE TRIGGER reject_cash_receipt_reference BEFORE UPDATE OF beleg_id ON journal '
      '''WHEN NEW.beleg_id IS NOT NULL BEGIN SELECT RAISE(ABORT, 'injected receipt reference failure'); END''',
    );

    Future<SettlementGroupSummary> postCash(int selectedReceiptId) => postings.postSettlement(
      sourceKind: PostingSource.cashPayment,
      sourceId: 'cash-receipt-reference-atomicity',
      signedAmountCents: 1250,
      settlementDate: _localDate(today),
      bankKontoId: 9001,
      counterKontoId: 9002,
      allocations: <SettlementAllocationInput>[
        const SettlementAllocationInput(appliedCents: 1250, kategorieId: 7001, euerZeile: 12),
      ],
      beschreibung: 'Cash receipt reference rollback',
      receiptId: selectedReceiptId,
    );

    await expectLater(() => postCash(receiptId), throwsA(isA<PostingException>()));

    final List<Map<String, Object?>> groups = await db.executor.runSelect(
      'SELECT id FROM settlement_groups WHERE source_kind = ? AND source_id = ?',
      <Object?>[PostingSource.cashPayment, 'cash-receipt-reference-atomicity'],
    );
    final List<Map<String, Object?>> lines = await db.executor.runSelect(
      'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
      <Object?>[PostingSource.cashPayment, 'cash-receipt-reference-atomicity'],
    );
    final List<Map<String, Object?>> references = await db.executor.runSelect(
      'SELECT id FROM journal WHERE beleg_id = ?',
      <Object?>[receiptId],
    );
    final List<Map<String, Object?>> receiptRows = await db.executor.runSelect(
      'SELECT status FROM belege WHERE id = ?',
      <Object?>[receiptId],
    );
    final CashbookBalanceResult balance = await CashbookBalanceSource(db.executor)
        .resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: today, currencyCode: 'EUR'));

    expect(
      <Object?>[
        groups.length,
        lines.length,
        references.length,
        balance.balanceCents,
        balance.complete,
        receiptRows.single['status'],
      ],
      <Object?>[0, 0, 0, 10000, true, 'neu'],
    );

    await db.executor.runCustom('DROP TRIGGER reject_cash_receipt_reference');
    final SettlementGroupSummary event = await postCash(receiptId);
    final SettlementGroupSummary replay = await postCash(receiptId);
    final List<Map<String, Object?>> linkedRows = await db.executor.runSelect(
      'SELECT id FROM journal WHERE beleg_id = ?',
      <Object?>[receiptId],
    );
    final CashbookBalanceResult balanceAfterSuccess = await CashbookBalanceSource(db.executor)
        .resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: today, currencyCode: 'EUR'));
    final int otherReceiptId = await db.executor.runInsert(
      'INSERT INTO belege (datum, betrag) VALUES (?, ?)',
      <Object?>[_localDate(today), '12.50'],
    );
    await expectLater(() => postCash(otherReceiptId), throwsA(isA<PostingException>()));

    expect(
      <Object?>[
        event.rootJournalId,
        replay.rootJournalId,
        linkedRows.map((Map<String, Object?> row) => row['id']).toList(),
        balanceAfterSuccess.balanceCents,
        balanceAfterSuccess.complete,
      ],
      <Object?>[
        event.rootJournalId,
        event.rootJournalId,
        <int>[event.rootJournalId],
        11250,
        true,
      ],
    );
  });

  testWidgets('test_complete_daily_close_is_finalized', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final String date = _localDate(DateTime.now());
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));
    expect(balance.complete, isTrue);
    final int journalCountBefore =
        (await db.executor.runSelect('SELECT COUNT(*) AS count FROM journal', const <Object?>[])).single['count']!
            as int;

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=close');
    await tester.pumpAndSettle();
    await _selectDailyCloseAccountAndDate(tester);

    final Finder countedField = find.byKey(const ValueKey<String>('daily-close-counted-balance'));
    expect(countedField, findsOneWidget);
    await tester.enterText(countedField, '100,00');
    await tester.pumpAndSettle();
    final Finder finalizeButton = find.byKey(const ValueKey<String>('daily-close-finalize'));
    expect(finalizeButton, findsOneWidget);
    expect(tester.widget<FilledButton>(finalizeButton).onPressed, isNotNull);
    await tester.ensureVisible(finalizeButton);
    await tester.tap(finalizeButton);
    await tester.pumpAndSettle();

    final List<Map<String, Object?>> rows = await db.executor.runSelect(
      'SELECT datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, signatur, zaehlung_json, integrity_hash '
      'FROM tagesabschluesse',
      const <Object?>[],
    );
    expect(rows, hasLength(1));
    final Map<String, Object?> close = rows.single;
    final String snapshotText = close['zaehlung_json']! as String;
    expect(
      snapshotText,
      jsonEncode(<String, Object?>{
        'account_id': '9001',
        'company_id': '1',
        'counted_amount_cents': 10000,
        'currency_code': 'EUR',
        'date': date,
        'difference_cents': 0,
        'expected_amount_cents': 10000,
        'explanation': null,
        'schema_version': 1,
        'source_reference': balance.sourceReference,
      }),
    );
    expect(jsonDecode(snapshotText), <String, Object?>{
      'account_id': '9001',
      'company_id': '1',
      'counted_amount_cents': 10000,
      'currency_code': 'EUR',
      'date': date,
      'difference_cents': 0,
      'expected_amount_cents': 10000,
      'explanation': null,
      'schema_version': 1,
      'source_reference': balance.sourceReference,
    });
    expect(close['datum'], date);
    expect(close['betrag'], 100);
    expect(close['kassenbestand'], 100);
    expect(close['differenz'], 0);
    expect(close['unternehmen_id'], 1);
    expect(close['konto_id'], 9001);
    expect(close['signatur'], isNull);
    expect(close['integrity_hash'], 'sha256:${sha256.convert(utf8.encode(snapshotText))}');
    expect(
      (await db.executor.runSelect('SELECT COUNT(*) AS count FROM journal', const <Object?>[])).single['count'],
      journalCountBefore,
    );
    expect(find.byKey(const ValueKey<String>('daily-close-finalized')), findsOneWidget);
  });

  testWidgets('test_unavailable_daily_close_has_no_finalization_controls', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    await db.executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id) VALUES (?, ?, ?, ?, ?)',
      <Object?>[_localDate(DateTime.now()), 'Legacy imported row', '18.50', 'Import', 9001],
    );

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=close');
    await tester.pumpAndSettle();
    await _selectDailyCloseAccountAndDate(tester);

    expect(find.byKey(const ValueKey<String>('daily-close-result-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('daily-close-counted-balance')), findsNothing);
    expect(find.byKey(const ValueKey<String>('daily-close-finalize')), findsNothing);
    expect(
      (await db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM tagesabschluesse',
        const <Object?>[],
      )).single['count'],
      0,
    );
  });

  testWidgets('test_discrepancy_requires_an_explanation', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    addTearDown(db.close);
    final String date = _localDate(DateTime.now());
    final CashbookBalanceResult balance = await CashbookBalanceSource(
      db.executor,
    ).resolve(CashbookBalanceRequest(companyId: '1', accountId: '9001', asOfDate: DateTime.now(), currencyCode: 'EUR'));

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=close');
    await tester.pumpAndSettle();
    await _selectDailyCloseAccountAndDate(tester);

    await tester.enterText(find.byKey(const ValueKey<String>('daily-close-counted-balance')), '90,00');
    await tester.pumpAndSettle();
    final Finder explanationField = find.byKey(const ValueKey<String>('daily-close-explanation'));
    expect(explanationField, findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey<String>('daily-close-finalize'))).onPressed, isNull);

    await tester.enterText(explanationField, 'Zählungsabweichung geprüft');
    await tester.pumpAndSettle();
    final Finder finalizeButton = find.byKey(const ValueKey<String>('daily-close-finalize'));
    expect(tester.widget<FilledButton>(finalizeButton).onPressed, isNotNull);
    await tester.ensureVisible(finalizeButton);
    await tester.tap(finalizeButton);
    await tester.pumpAndSettle();

    final Map<String, Object?> close = (await db.executor.runSelect(
      'SELECT differenz, zaehlung_json, integrity_hash FROM tagesabschluesse',
      const <Object?>[],
    )).single;
    final String snapshotText = close['zaehlung_json']! as String;
    expect(
      snapshotText,
      jsonEncode(<String, Object?>{
        'account_id': '9001',
        'company_id': '1',
        'counted_amount_cents': 9000,
        'currency_code': 'EUR',
        'date': date,
        'difference_cents': -1000,
        'expected_amount_cents': 10000,
        'explanation': 'Zählungsabweichung geprüft',
        'schema_version': 1,
        'source_reference': balance.sourceReference,
      }),
    );
    expect((jsonDecode(snapshotText) as Map<String, Object?>)['explanation'], 'Zählungsabweichung geprüft');
    expect(close['differenz'], -10);
    expect(close['integrity_hash'], 'sha256:${sha256.convert(utf8.encode(snapshotText))}');
  });

  testWidgets('test_imported_or_legacy_row_is_not_treated_as_cash', (WidgetTester tester) async {
    final AppDatabase db = await _cashbookDatabase();
    final DateTime today = DateTime.now();
    await db.executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id) VALUES (?, ?, ?, ?, ?)',
      <Object?>[_localDate(today), 'Legacy imported row', '18.50', 'Import', 9001],
    );
    addTearDown(db.close);

    final GoRouter router = createRouter(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          locale: const Locale('de'),
          routerConfig: router,
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/banking?view=cashbook');
    await tester.pumpAndSettle();
    await _selectCashbookAccountAndDate(tester);

    expect(find.byKey(const ValueKey<String>('cashbook-result-unavailable')), findsOneWidget);
    expect(find.text('Legacy imported row'), findsNothing);
    expect(find.byKey(const ValueKey<String>('cashbook-event-list')), findsNothing);
  });
}

Future<void> _selectDailyCloseAccountAndDate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('daily-close-company')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test GmbH').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('daily-close-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Kasse').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('daily-close-date-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _insertLegacyClose(
  AppDatabase db, {
  required String date,
  required int? companyId,
  required int? accountId,
  required String expected,
  required String counted,
}) async {
  final int expectedCents = int.parse(expected.replaceAll('.', ''));
  final int countedCents = int.parse(counted.replaceAll('.', ''));
  await db.executor.runInsert(
    'INSERT INTO tagesabschluesse (datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id) '
    'VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[date, expected, counted, (countedCents - expectedCents) / 100, companyId, accountId],
  );
}

Future<AppDatabase> _cashbookDatabase() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
  await db.executor.runCustom("INSERT INTO unternehmen (id, name) VALUES (1, 'Test GmbH')");
  await db.executor.runInsert(
    'INSERT INTO konten (id, name, kontoart, waehrung, unternehmen_id) VALUES (?, ?, ?, ?, ?)',
    <Object?>[9001, 'Test Kasse', 'Kasse', 'EUR', 1],
  );
  await db.executor.runInsert(
    'INSERT INTO konten (id, name, kontoart, waehrung, unternehmen_id) VALUES (?, ?, ?, ?, ?)',
    <Object?>[9002, 'Gegenkonto', 'Ertrag', 'EUR', 1],
  );
  final List<Map<String, Object?>> journalColumns = await db.executor.runSelect(
    'PRAGMA table_info(journal)',
    const <Object?>[],
  );
  if (journalColumns.every((Map<String, Object?> column) => column['name'] != 'is_opening_balance')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN is_opening_balance INTEGER NOT NULL DEFAULT 0');
  }
  final DateTime openingDate = DateTime.now().subtract(const Duration(days: 1));
  final String effectiveDate = _localDate(openingDate);
  final int openingJournalId = await db.executor.runInsert(
    'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
    'VALUES (?, ?, ?, ?, ?, 0, 1)',
    <Object?>[effectiveDate, 'Eröffnung Kasse', '100.00', 'Eroeffnung', 9001],
  );
  await db.executor.runInsert(
    'INSERT INTO account_opening_balance_sources '
    '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[1, 9001, openingJournalId, effectiveDate, 10000, 'EUR', 'setup-opening:1:9001'],
  );
  return db;
}

Future<void> _selectCashbookAccountAndDate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('cashbook-company')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test GmbH').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('cashbook-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Kasse').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('cashbook-date-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

String _localDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
