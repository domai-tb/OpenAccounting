import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';
import 'package:openaccounting/features/cashbook/cashbook_balance_source.dart';

void main() {
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
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
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
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
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
