import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/cashbook/account_date_balance.dart';
import 'package:openaccounting/features/cashbook/cashbook_balance_source.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class TagesabschlussFinalization {
  TagesabschlussFinalization(this.executor);

  static final BigInt _maximumSafeJsonInteger = BigInt.from(9007199254740991);
  static const List<String> _snapshotKeys = <String>[
    'account_id',
    'company_id',
    'counted_amount_cents',
    'currency_code',
    'date',
    'difference_cents',
    'expected_amount_cents',
    'explanation',
    'schema_version',
    'source_reference',
  ];

  final QueryExecutor executor;

  Future<TagesabschlussCloseLookup> lookupExisting({
    required String companyId,
    required String accountId,
    required DateTime asOfDate,
  }) async {
    final int? parsedCompanyId = _canonicalId(companyId);
    final int? parsedAccountId = _canonicalId(accountId);
    if (parsedCompanyId == null || parsedAccountId == null) {
      return const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.unverified);
    }
    final String date = _dateKey(asOfDate);
    final transaction = executor.beginTransaction();
    var transactionOpened = false;
    try {
      await transaction.ensureOpen(_DailyCloseTransactionUser());
      transactionOpened = true;
      final TagesabschlussCloseLookup existing = await _lookupExistingInTransaction(
        transaction,
        companyId: parsedCompanyId,
        accountId: parsedAccountId,
        date: date,
      );
      await transaction.send();
      return existing;
    } catch (_) {
      if (transactionOpened) await transaction.rollback();
      rethrow;
    }
  }

  Future<TagesabschlussCloseLookup> finalize({
    required CashbookBalanceResult balance,
    required int countedBalanceCents,
    String? explanation,
  }) async {
    final int? companyId = _canonicalId(balance.companyId);
    final int? accountId = _canonicalId(balance.accountId);
    if (companyId == null || accountId == null) {
      throw const TagesabschlussFinalizationException(TagesabschlussFinalizationFailure.unavailableBalance);
    }
    final String company = companyId.toString();
    final String account = accountId.toString();
    final DateTime localDate = DateTime(balance.asOfDate.year, balance.asOfDate.month, balance.asOfDate.day);
    final String date = _dateKey(localDate);

    final transaction = executor.beginTransaction();
    var transactionOpened = false;
    try {
      await transaction.ensureOpen(_DailyCloseTransactionUser());
      transactionOpened = true;
      final TagesabschlussCloseLookup existing = await _lookupExistingInTransaction(
        transaction,
        companyId: companyId,
        accountId: accountId,
        date: date,
      );
      if (existing.status != TagesabschlussCloseStatus.absent) {
        await transaction.send();
        return existing;
      }

      final int? expectedBalanceCents = balance.balanceCents;
      if (!balance.complete ||
          expectedBalanceCents == null ||
          !RegExp(r'^[A-Z]{3}$').hasMatch(balance.currencyCode) ||
          balance.sourceReference.trim().isEmpty) {
        throw const TagesabschlussFinalizationException(TagesabschlussFinalizationFailure.unavailableBalance);
      }

      final BigInt difference = BigInt.from(countedBalanceCents) - BigInt.from(expectedBalanceCents);
      if (!_isSafeJsonInteger(BigInt.from(countedBalanceCents)) ||
          !_isSafeJsonInteger(BigInt.from(expectedBalanceCents)) ||
          !_isSafeJsonInteger(difference)) {
        throw const TagesabschlussFinalizationException(TagesabschlussFinalizationFailure.amountOutOfRange);
      }

      final String? normalizedExplanation = explanation == null ? null : unorm.nfc(explanation);
      if (difference != BigInt.zero && (normalizedExplanation == null || normalizedExplanation.trim().isEmpty)) {
        throw const TagesabschlussFinalizationException(TagesabschlussFinalizationFailure.explanationRequired);
      }
      final String? savedExplanation = normalizedExplanation == null || normalizedExplanation.trim().isEmpty
          ? null
          : normalizedExplanation;
      final CashbookBalanceResult currentBalance = await CashbookBalanceSource(transaction).resolve(
        CashbookBalanceRequest(
          companyId: company,
          accountId: account,
          asOfDate: localDate,
          currencyCode: balance.currencyCode,
        ),
      );
      if (!currentBalance.complete ||
          currentBalance.balanceCents != expectedBalanceCents ||
          currentBalance.companyId != company ||
          currentBalance.accountId != account ||
          currentBalance.currencyCode != balance.currencyCode ||
          currentBalance.sourceReference != balance.sourceReference) {
        throw const TagesabschlussFinalizationException(TagesabschlussFinalizationFailure.balanceChanged);
      }

      final Map<String, Object?> snapshot = <String, Object?>{
        'account_id': account,
        'company_id': company,
        'counted_amount_cents': countedBalanceCents,
        'currency_code': balance.currencyCode,
        'date': date,
        'difference_cents': difference.toInt(),
        'expected_amount_cents': expectedBalanceCents,
        'explanation': savedExplanation,
        'schema_version': 1,
        'source_reference': unorm.nfc(currentBalance.sourceReference),
      };
      final String canonicalSnapshot = jsonEncode(snapshot);
      final String integrityHash = 'sha256:${sha256.convert(utf8.encode(canonicalSnapshot))}';
      await transaction.runInsert(
        'INSERT INTO tagesabschluesse '
        '(datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          date,
          money.fromCents(expectedBalanceCents),
          money.fromCents(countedBalanceCents),
          money.fromCents(difference.toInt()),
          companyId,
          accountId,
          canonicalSnapshot,
          integrityHash,
        ],
      );
      final TagesabschlussCloseLookup persisted = await _lookupExistingInTransaction(
        transaction,
        companyId: companyId,
        accountId: accountId,
        date: date,
      );
      if (persisted.status != TagesabschlussCloseStatus.verified || persisted.snapshot == null) {
        throw StateError('Persisted daily close did not pass verification.');
      }
      await transaction.send();
      return TagesabschlussCloseLookup(
        status: TagesabschlussCloseStatus.verified,
        snapshot: persisted.snapshot,
        created: true,
      );
    } catch (_) {
      if (transactionOpened) await transaction.rollback();
      rethrow;
    }
  }

  Future<TagesabschlussCloseLookup> _lookupExistingInTransaction(
    QueryExecutor transaction, {
    required int companyId,
    required int accountId,
    required String date,
  }) async {
    final List<Map<String, Object?>> rows = await transaction.runSelect(
      'SELECT datum, betrag, kassenbestand, differenz, unternehmen_id, konto_id, zaehlung_json, integrity_hash '
      'FROM tagesabschluesse WHERE datum = ? AND '
      '(konto_id = ? OR (konto_id IS NULL AND (unternehmen_id = ? OR unternehmen_id IS NULL))) ORDER BY id',
      <Object?>[date, accountId, companyId],
    );
    if (rows.isEmpty) return const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.absent);
    if (rows.length != 1) return const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.unverified);
    final TagesabschlussFinalizedSnapshot? snapshot = _verifiedSnapshot(
      rows.single,
      companyId: companyId,
      accountId: accountId,
      date: date,
    );
    if (snapshot == null) return const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.unverified);
    return TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.verified, snapshot: snapshot);
  }

  static TagesabschlussFinalizedSnapshot? _verifiedSnapshot(
    Map<String, Object?> row, {
    required int companyId,
    required int accountId,
    required String date,
  }) {
    try {
      final Object? rawJson = row['zaehlung_json'];
      final Object? rawHash = row['integrity_hash'];
      if (rawJson is! String || rawHash is! String || !rawHash.startsWith('sha256:')) return null;
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;
      final Map<String, Object?> snapshot = Map<String, Object?>.from(decoded);
      if (snapshot.keys.join('\u0000') != _snapshotKeys.join('\u0000')) return null;
      final String expectedCompany = companyId.toString();
      final String expectedAccount = accountId.toString();
      final Object? snapshotCompany = snapshot['company_id'];
      final Object? snapshotAccount = snapshot['account_id'];
      final Object? snapshotDate = snapshot['date'];
      final Object? counted = snapshot['counted_amount_cents'];
      final Object? expected = snapshot['expected_amount_cents'];
      final Object? difference = snapshot['difference_cents'];
      final Object? currency = snapshot['currency_code'];
      final Object? explanationValue = snapshot['explanation'];
      final Object? schemaVersion = snapshot['schema_version'];
      final Object? sourceReference = snapshot['source_reference'];
      if (snapshotCompany != expectedCompany ||
          snapshotAccount != expectedAccount ||
          snapshotDate != date ||
          counted is! int ||
          expected is! int ||
          difference is! int ||
          currency is! String ||
          !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
          (explanationValue != null && explanationValue is! String) ||
          (explanationValue is String &&
              (unorm.nfc(explanationValue) != explanationValue || explanationValue.trim().isEmpty)) ||
          schemaVersion is! int ||
          schemaVersion != 1 ||
          sourceReference is! String ||
          sourceReference.trim().isEmpty ||
          unorm.nfc(sourceReference) != sourceReference ||
          !_isSafeJsonInteger(BigInt.from(counted)) ||
          !_isSafeJsonInteger(BigInt.from(expected)) ||
          !_isSafeJsonInteger(BigInt.from(difference)) ||
          BigInt.from(counted) - BigInt.from(expected) != BigInt.from(difference) ||
          (difference != 0 && (explanationValue == null || (explanationValue as String).trim().isEmpty))) {
        return null;
      }
      if (row['datum'] != date || row['unternehmen_id'] != companyId || row['konto_id'] != accountId) return null;
      final int? expectedColumnCents = _columnCents(row['betrag']);
      final int? countedColumnCents = _columnCents(row['kassenbestand']);
      final int? differenceColumnCents = _columnCents(row['differenz']);
      if (expectedColumnCents != expected || countedColumnCents != counted || differenceColumnCents != difference) {
        return null;
      }
      if (jsonEncode(snapshot) != rawJson) return null;
      final String expectedHash = 'sha256:${sha256.convert(utf8.encode(rawJson))}';
      if (rawHash != expectedHash) return null;
      return TagesabschlussFinalizedSnapshot(
        companyId: expectedCompany,
        accountId: expectedAccount,
        asOfDate: DateTime.parse(date),
        expectedBalanceCents: expected,
        countedBalanceCents: counted,
        differenceCents: difference,
        currencyCode: currency,
        explanation: explanationValue as String?,
        sourceReference: sourceReference,
        integrityHash: rawHash,
      );
    } catch (_) {
      return null;
    }
  }

  static int? _canonicalId(String value) {
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0 || parsed.toString() != value) return null;
    return parsed;
  }

  static int? _columnCents(Object? value) {
    if (value is! num) return null;
    return money.toCurrencyCents(value);
  }

  static bool _isSafeJsonInteger(BigInt value) => value.abs() <= _maximumSafeJsonInteger;

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

enum TagesabschlussFinalizationFailure { unavailableBalance, amountOutOfRange, explanationRequired, balanceChanged }

enum TagesabschlussCloseStatus { absent, verified, unverified }

class TagesabschlussCloseLookup {
  const TagesabschlussCloseLookup({required this.status, this.snapshot, this.created = false});

  final TagesabschlussCloseStatus status;
  final TagesabschlussFinalizedSnapshot? snapshot;
  final bool created;
}

class TagesabschlussFinalizedSnapshot {
  const TagesabschlussFinalizedSnapshot({
    required this.companyId,
    required this.accountId,
    required this.asOfDate,
    required this.expectedBalanceCents,
    required this.countedBalanceCents,
    required this.differenceCents,
    required this.currencyCode,
    required this.explanation,
    required this.sourceReference,
    required this.integrityHash,
  });

  final String companyId;
  final String accountId;
  final DateTime asOfDate;
  final int expectedBalanceCents;
  final int countedBalanceCents;
  final int differenceCents;
  final String currencyCode;
  final String? explanation;
  final String sourceReference;
  final String integrityHash;
}

class TagesabschlussFinalizationException implements Exception {
  const TagesabschlussFinalizationException(this.failure);

  final TagesabschlussFinalizationFailure failure;
}

class _DailyCloseTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

class TagesabschlussCreation {
  const TagesabschlussCreation();

  TagesabschlussDraft? prepare(CashbookBalanceResult balance) {
    final int? expectedBalanceCents = balance.balanceCents;
    if (!balance.complete || expectedBalanceCents == null) return null;

    return TagesabschlussDraft(
      companyId: balance.companyId,
      accountId: balance.accountId,
      asOfDate: balance.asOfDate,
      expectedBalanceCents: expectedBalanceCents,
      currencyCode: balance.currencyCode,
      sourceReference: balance.sourceReference,
      complete: balance.complete,
    );
  }
}

class TagesabschlussDraft {
  const TagesabschlussDraft({
    required this.companyId,
    required this.accountId,
    required this.asOfDate,
    required this.expectedBalanceCents,
    required this.currencyCode,
    required this.sourceReference,
    required this.complete,
  });

  final String companyId;
  final String accountId;
  final DateTime asOfDate;
  final int expectedBalanceCents;
  final String currencyCode;
  final String sourceReference;
  final bool complete;
}
