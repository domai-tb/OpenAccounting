import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';

void main() {
  test('resolves a verified opening source plus one committed balanced cash payment', () async {
    final AppDatabase db = await _database();
    addTearDown(db.close);
    final DateTime openingDate = DateTime.now();
    await _seedCompany(db, companyId: 1);
    await _seedAccount(db, accountId: 1, companyId: 1, saldo: '100.00');
    await _seedOpening(db, companyId: 1, accountId: 1, amount: '100.00', date: openingDate);
    await _seedCashPayment(
      db,
      accountId: 1,
      counterAccountId: 2,
      date: openingDate.add(const Duration(days: 1)),
      amount: '12.34',
      sourceId: 'cash-receipt-1',
    );

    final CashbookBalanceResult result = await _resolve(
      db,
      CashbookBalanceRequest(
        companyId: '1',
        accountId: '1',
        asOfDate: openingDate.add(const Duration(days: 1)),
        currencyCode: 'EUR',
      ),
    );

    expect(result.complete, isTrue);
    expect(result.balanceCents, 11234);
    expect(result.sourceReferences, containsAll(<String>['setup-opening:1:1', 'cash-receipt-1']));
  });

  test('fails closed for missing or mismatched opening evidence and legacy account rows', () async {
    final AppDatabase missingSourceDb = await _database();
    addTearDown(missingSourceDb.close);
    final DateTime openingDate = DateTime.now();
    await _seedCompany(missingSourceDb, companyId: 1);
    await _seedAccount(missingSourceDb, accountId: 1, companyId: 1, saldo: '100.00');
    await _seedOpeningJournal(missingSourceDb, accountId: 1, amount: '100.00', date: openingDate);

    expect(
      (await _resolve(missingSourceDb, _request(1, 1, openingDate))).balanceCents,
      isNull,
      reason: 'A saldo and an opening marker without a v26 source are not authoritative.',
    );

    final AppDatabase mismatchDb = await _database();
    addTearDown(mismatchDb.close);
    await _seedCompany(mismatchDb, companyId: 1);
    await _seedAccount(mismatchDb, accountId: 1, companyId: 1, saldo: '100.00');
    await _seedOpening(mismatchDb, companyId: 1, accountId: 1, amount: '100.00', date: openingDate);
    await mismatchDb.executor.runUpdate('UPDATE journal SET betrag = ? WHERE is_opening_balance = 1', <Object?>[
      '99.00',
    ]);

    expect((await _resolve(mismatchDb, _request(1, 1, openingDate))).balanceCents, isNull);

    final AppDatabase legacyRowDb = await _database();
    addTearDown(legacyRowDb.close);
    await _seedCompany(legacyRowDb, companyId: 1);
    await _seedAccount(legacyRowDb, accountId: 1, companyId: 1, saldo: '100.00');
    await _seedOpening(legacyRowDb, companyId: 1, accountId: 1, amount: '100.00', date: openingDate);
    await legacyRowDb.executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
      'VALUES (?, ?, ?, ?, ?, 0, 0)',
      <Object?>[
        openingDate.add(const Duration(days: 1)).toIso8601String().substring(0, 10),
        'Legacy',
        '5.00',
        'Einnahme',
        1,
      ],
    );

    expect(
      (await _resolve(legacyRowDb, _request(1, 1, openingDate.add(const Duration(days: 1))))).balanceCents,
      isNull,
    );
  });

  test('isolates the selected company, account, and requested local date', () async {
    final AppDatabase db = await _database();
    addTearDown(db.close);
    final DateTime openingDate = DateTime.now();
    await _seedCompany(db, companyId: 1);
    await _seedCompany(db, companyId: 2);
    await _seedAccount(db, accountId: 1, companyId: 1, saldo: '100.00');
    await _seedAccount(db, accountId: 2, companyId: 1, saldo: '300.00');
    await _seedAccount(db, accountId: 3, companyId: 2, saldo: '900.00');
    await _seedOpening(db, companyId: 1, accountId: 1, amount: '100.00', date: openingDate);
    await _seedOpening(db, companyId: 1, accountId: 2, amount: '300.00', date: openingDate);
    await _seedOpening(db, companyId: 2, accountId: 3, amount: '900.00', date: openingDate);
    await _seedCashPayment(
      db,
      accountId: 1,
      counterAccountId: 11,
      date: openingDate.add(const Duration(days: 1)),
      amount: '5.00',
      sourceId: 'selected-account-event',
    );
    await _seedCashPayment(
      db,
      accountId: 2,
      counterAccountId: 12,
      date: openingDate.add(const Duration(days: 1)),
      amount: '70.00',
      sourceId: 'other-account-event',
    );
    await _seedCashPayment(
      db,
      accountId: 3,
      counterAccountId: 13,
      date: openingDate.add(const Duration(days: 1)),
      amount: '40.00',
      sourceId: 'other-company-event',
    );
    await _seedCashPayment(
      db,
      accountId: 1,
      counterAccountId: 14,
      date: openingDate.add(const Duration(days: 3)),
      amount: '100.00',
      sourceId: 'future-event',
    );

    final CashbookBalanceResult result = await _resolve(db, _request(1, 1, openingDate.add(const Duration(days: 1))));

    expect(result.complete, isTrue);
    expect(result.balanceCents, 10500);
    expect(result.sourceReferences, contains('selected-account-event'));
    expect(result.sourceReferences, isNot(contains('other-account-event')));
    expect(result.sourceReferences, isNot(contains('other-company-event')));
    expect(result.sourceReferences, isNot(contains('future-event')));
  });
}

Future<AppDatabase> _database() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  final List<Map<String, Object?>> columns = await db.executor.runSelect(
    'PRAGMA table_info(journal)',
    const <Object?>[],
  );
  if (columns.every((Map<String, Object?> column) => column['name'] != 'is_opening_balance')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN is_opening_balance INTEGER NOT NULL DEFAULT 0');
  }
  return db;
}

Future<void> _seedCompany(AppDatabase db, {required int companyId}) async {
  await db.executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (?, ?)', <Object?>[
    companyId,
    'Firma $companyId',
  ]);
}

Future<void> _seedAccount(
  AppDatabase db, {
  required int accountId,
  required int companyId,
  required String saldo,
}) async {
  await db.executor.runInsert(
    'INSERT INTO konten (id, name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[accountId, 'Kasse $accountId', 'Kasse', 'EUR', companyId, saldo],
  );
}

Future<void> _seedOpening(
  AppDatabase db, {
  required int companyId,
  required int accountId,
  required String amount,
  required DateTime date,
}) async {
  final String effectiveDate = _dateKey(date);
  final int journalId = await _seedOpeningJournal(db, accountId: accountId, amount: amount, date: date);
  await db.executor.runInsert(
    'INSERT INTO account_opening_balance_sources '
    '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      companyId,
      accountId,
      journalId,
      effectiveDate,
      money.parseScaled(amount, scale: 2),
      'EUR',
      'setup-opening:$companyId:$accountId',
    ],
  );
}

Future<int> _seedOpeningJournal(
  AppDatabase db, {
  required int accountId,
  required String amount,
  required DateTime date,
}) {
  return db.executor.runInsert(
    'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
    'VALUES (?, ?, ?, ?, ?, 0, 1)',
    <Object?>[_dateKey(date), 'Eröffnung Kasse', amount, 'Eroeffnung', accountId],
  );
}

Future<void> _seedCashPayment(
  AppDatabase db, {
  required int accountId,
  required int counterAccountId,
  required DateTime date,
  required String amount,
  required String sourceId,
}) async {
  final List<Map<String, Object?>> accountRows = await db.executor.runSelect(
    'SELECT unternehmen_id FROM konten WHERE id = ?',
    <Object?>[accountId],
  );
  final int companyId = (accountRows.single['unternehmen_id']! as num).toInt();
  await db.executor.runInsert(
    'INSERT INTO konten (id, name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[counterAccountId, 'Gegenkonto $counterAccountId', 'Sachkonto', 'EUR', companyId, '0.00'],
  );
  final int categoryId = await db.executor.runInsert(
    'INSERT INTO kategorien (bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status, '
    'catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, 1, ?, ?, ?)',
    <Object?>['Kassenumsatz', '8400', '4400', 12, 'catalog_verified', 'TEST', '2026-test.1'],
  );
  await PostingGroupService(db.executor).postSettlement(
    sourceKind: PostingSource.cashPayment,
    sourceId: sourceId,
    signedAmountCents: money.parseScaled(amount, scale: 2),
    settlementDate: _dateKey(date),
    bankKontoId: accountId,
    counterKontoId: counterAccountId,
    allocations: <SettlementAllocationInput>[
      SettlementAllocationInput(
        appliedCents: money.parseScaled(amount, scale: 2),
        kategorieId: categoryId,
        euerZeile: 12,
      ),
    ],
    beschreibung: 'Kasseneinnahme',
  );
}

Future<CashbookBalanceResult> _resolve(AppDatabase db, CashbookBalanceRequest request) async {
  return AppServices(db).cashbookBalanceSource.resolve(request);
}

CashbookBalanceRequest _request(int companyId, int accountId, DateTime date) => CashbookBalanceRequest(
  companyId: companyId.toString(),
  accountId: accountId.toString(),
  asOfDate: date,
  currencyCode: 'EUR',
);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
