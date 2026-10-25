import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/cashbook/account_date_balance.dart';

/// A company that can be selected for a daily cash close.
class CashbookCompanyOption {
  const CashbookCompanyOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// A cash account that can be selected for a daily cash close.
class CashbookAccountOption {
  const CashbookAccountOption({required this.id, required this.name, required this.currencyCode});

  final int id;
  final String name;
  final String currencyCode;
}

/// Reads verified v26 opening sources and committed cash payment groups.
///
/// Missing schema, ambiguous links, legacy rows, and incomplete groups all
/// produce an unavailable balance. This source never derives a balance from
/// the mutable `konten.saldo` field.
class CashbookBalanceSource {
  CashbookBalanceSource(this.executor);

  final QueryExecutor executor;
  static const CashbookBalanceCalculator _calculator = CashbookBalanceCalculator();

  Future<List<CashbookCompanyOption>> companies() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name FROM unternehmen ORDER BY name, id',
      const <Object?>[],
    );
    return <CashbookCompanyOption>[
      for (final Map<String, Object?> row in rows)
        if (_positiveInt(row['id']) case final int id)
          if (row['name'] is String && (row['name']! as String).trim().isNotEmpty)
            CashbookCompanyOption(id: id, name: (row['name']! as String).trim()),
    ];
  }

  Future<List<CashbookAccountOption>> cashAccounts(int companyId) async {
    if (companyId <= 0) return const <CashbookAccountOption>[];
    final List<Map<String, Object?>> rows = await executor.runSelect(
      "SELECT id, name, waehrung FROM konten WHERE unternehmen_id = ? AND kontoart = 'Kasse' ORDER BY name, id",
      <Object?>[companyId],
    );
    return <CashbookAccountOption>[
      for (final Map<String, Object?> row in rows)
        if (_positiveInt(row['id']) case final int id)
          if (row['name'] is String && row['waehrung'] is String)
            CashbookAccountOption(
              id: id,
              name: (row['name']! as String).trim(),
              currencyCode: (row['waehrung']! as String).trim(),
            ),
    ];
  }

  /// Resolves exactly the company, cash account, currency, and local date
  /// provided by the user.
  Future<CashbookBalanceResult> resolve(CashbookBalanceRequest request) async {
    try {
      final int? companyId = _positiveInt(request.companyId);
      final int? accountId = _positiveInt(request.accountId);
      if (companyId == null || accountId == null || !_isValidLocalDate(request.asOfDate)) {
        return _calculateUnavailable(request, openingSourceAvailable: false);
      }

      final List<Map<String, Object?>> accountRows = await executor.runSelect(
        'SELECT id, unternehmen_id, kontoart, waehrung FROM konten WHERE id = ? AND unternehmen_id = ?',
        <Object?>[accountId, companyId],
      );
      if (accountRows.length != 1 || accountRows.single['kontoart'] != 'Kasse') {
        return _calculateUnavailable(request, openingSourceAvailable: false);
      }
      final String? accountCurrency = accountRows.single['waehrung'] as String?;
      if (accountCurrency == null || accountCurrency.trim().isEmpty) {
        return _calculateUnavailable(request, openingSourceAvailable: false);
      }

      final List<Map<String, Object?>> openingRows = await executor.runSelect(
        'SELECT s.id AS source_id, s.unternehmen_id AS source_company_id, s.konto_id AS source_account_id, '
        's.journal_id AS source_journal_id, s.effective_date AS source_effective_date, '
        's.amount_cents AS source_amount_cents, s.currency_code AS source_currency_code, '
        's.source_reference AS source_reference, k.unternehmen_id AS account_company_id, '
        'k.kontoart AS account_type, k.waehrung AS account_currency, j.id AS journal_id, '
        'j.konto_id AS journal_account_id, j.datum AS journal_date, j.betrag AS journal_amount, '
        'j.beleg_typ AS journal_type, j.is_opening_balance AS journal_is_opening_balance '
        'FROM account_opening_balance_sources AS s '
        'LEFT JOIN konten AS k ON k.id = s.konto_id '
        'LEFT JOIN journal AS j ON j.id = s.journal_id '
        'WHERE s.konto_id = ? ORDER BY s.id',
        <Object?>[accountId],
      );
      if (openingRows.length != 1) {
        return _calculateUnavailable(
          request,
          openingSourceAvailable: true,
          reason: openingRows.isEmpty
              ? CashbookBalanceUnavailableReason.openingBalanceMissing
              : CashbookBalanceUnavailableReason.openingBalanceAmbiguous,
        );
      }

      final _VerifiedOpening? opening = _verifyOpening(
        openingRows.single,
        companyId: companyId,
        accountId: accountId,
        accountCurrency: accountCurrency,
      );
      if (opening == null) {
        return _calculateUnavailable(
          request,
          openingSourceAvailable: true,
          reason: CashbookBalanceUnavailableReason.openingBalanceUnverified,
        );
      }

      final List<CashbookMovementEvidence> movements = await _movements(
        companyId: companyId,
        accountId: accountId,
        accountCurrency: accountCurrency,
        asOfDate: request.asOfDate,
        opening: opening,
      );
      return _calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[opening.evidence],
          movements: movements,
        ),
      );
    } catch (_) {
      return _calculateUnavailable(request, openingSourceAvailable: false);
    }
  }

  CashbookBalanceResult _calculateUnavailable(
    CashbookBalanceRequest request, {
    required bool openingSourceAvailable,
    CashbookBalanceUnavailableReason reason = CashbookBalanceUnavailableReason.historyCoverageIncomplete,
  }) {
    final CashbookBalanceResult calculated = _calculator.calculate(
      request,
      CashbookBalanceEvidence(
        openingSourceAvailable: openingSourceAvailable,
        historyCoverageComplete: false,
        openingBalances: const <CashbookOpeningBalance>[],
        movements: const <CashbookMovementEvidence>[],
      ),
    );
    if (calculated.unavailableReason == reason || calculated.complete) return calculated;
    return CashbookBalanceResult.unavailable(
      companyId: request.companyId,
      accountId: request.accountId,
      asOfDate: DateTime(request.asOfDate.year, request.asOfDate.month, request.asOfDate.day, 23, 59, 59, 999, 999),
      currencyCode: request.currencyCode,
      sourceReference: calculated.sourceReference,
      sourceReferences: calculated.sourceReferences,
      reason: reason,
    );
  }

  _VerifiedOpening? _verifyOpening(
    Map<String, Object?> row, {
    required int companyId,
    required int accountId,
    required String accountCurrency,
  }) {
    final int? sourceId = _positiveInt(row['source_id']);
    final int? sourceCompanyId = _positiveInt(row['source_company_id']);
    final int? sourceAccountId = _positiveInt(row['source_account_id']);
    final int? journalId = _positiveInt(row['source_journal_id']);
    final int? linkedJournalId = _positiveInt(row['journal_id']);
    final int? journalAccountId = _positiveInt(row['journal_account_id']);
    final int? openingCents = _integer(row['source_amount_cents']);
    final String? effectiveDate = row['source_effective_date'] as String?;
    final String? journalDate = row['journal_date'] as String?;
    final String? sourceCurrency = row['source_currency_code'] as String?;
    final String? sourceReference = row['source_reference'] as String?;
    final String? journalType = row['journal_type'] as String?;
    final int? journalIsOpening = _integer(row['journal_is_opening_balance']);
    final int? journalAmountCents = _moneyCents(row['journal_amount']);
    final DateTime? openingDate = effectiveDate == null ? null : _parseLocalDate(effectiveDate);
    if (sourceId == null ||
        sourceCompanyId != companyId ||
        sourceAccountId != accountId ||
        journalId == null ||
        journalId != linkedJournalId ||
        journalAccountId != accountId ||
        row['account_company_id'] != companyId ||
        row['account_type'] != 'Kasse' ||
        openingCents == null ||
        openingCents < 0 ||
        effectiveDate == null ||
        openingDate == null ||
        journalDate != effectiveDate ||
        sourceCurrency == null ||
        sourceCurrency != accountCurrency ||
        row['account_currency'] != accountCurrency ||
        sourceReference == null ||
        sourceReference.trim().isEmpty ||
        journalType != 'Eroeffnung' ||
        journalIsOpening != 1 ||
        journalAmountCents != openingCents) {
      return null;
    }
    return _VerifiedOpening(
      journalId: journalId,
      evidence: CashbookOpeningBalance(
        identity: 'v26:$sourceId:$journalId',
        companyId: companyId.toString(),
        accountId: accountId.toString(),
        effectiveAt: openingDate,
        balanceCents: openingCents,
        currencyCode: sourceCurrency,
        sourceReference: sourceReference,
        verified: true,
        identityUnambiguous: true,
      ),
    );
  }

  Future<List<CashbookMovementEvidence>> _movements({
    required int companyId,
    required int accountId,
    required String accountCurrency,
    required DateTime asOfDate,
    required _VerifiedOpening opening,
  }) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, betrag, konto_id, soll, haben, soll_konto_id, haben_konto_id, gruppe_id, immutable, '
      'legacy_unverified, source_kind, source_id, reversal_of_group_id, is_opening_balance '
      'FROM journal WHERE konto_id = ? OR soll_konto_id = ? OR haben_konto_id = ? ORDER BY id',
      <Object?>[accountId, accountId, accountId],
    );
    final Map<int, DateTime> candidateGroups = <int, DateTime>{};
    var linkedOpeningRows = 0;
    for (final Map<String, Object?> row in rows) {
      final int? id = _positiveInt(row['id']);
      final String? rawDate = row['datum'] as String?;
      final DateTime? localDate = rawDate == null ? null : _parseLocalDate(rawDate);
      if (id == null || localDate == null) throw const _IncompleteCashbookHistory();
      if (id == opening.journalId) {
        if (_integer(row['is_opening_balance']) != 1) throw const _IncompleteCashbookHistory();
        linkedOpeningRows++;
        continue;
      }
      if (_integer(row['is_opening_balance']) == 1) throw const _IncompleteCashbookHistory();
      if (localDate.isAfter(asOfDate)) continue;
      if (localDate.isBefore(opening.evidence.effectiveAt)) continue;
      final int? rootId = _positiveInt(row['gruppe_id']);
      if (rootId == null) throw const _IncompleteCashbookHistory();
      candidateGroups[rootId] = localDate;
    }
    if (linkedOpeningRows != 1) throw const _IncompleteCashbookHistory();

    final List<CashbookMovementEvidence> movements = <CashbookMovementEvidence>[];
    for (final MapEntry<int, DateTime> candidate in candidateGroups.entries) {
      movements.add(
        await _verifyCashPaymentGroup(
          rootId: candidate.key,
          candidateDate: candidate.value,
          companyId: companyId,
          accountId: accountId,
          accountCurrency: accountCurrency,
        ),
      );
    }
    return movements;
  }

  Future<CashbookMovementEvidence> _verifyCashPaymentGroup({
    required int rootId,
    required DateTime candidateDate,
    required int companyId,
    required int accountId,
    required String accountCurrency,
  }) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, betrag, beschreibung, kategorie_id, beleg_id, konto_id, soll, haben, soll_konto_id, '
      'haben_konto_id, gruppe_id, immutable, legacy_unverified, source_kind, source_id, reversal_of_group_id '
      'FROM journal WHERE gruppe_id = ? OR id = ? ORDER BY id',
      <Object?>[rootId, rootId],
    );
    if (rows.length < 2) throw const _IncompleteCashbookHistory();
    final List<int> groupAccountEffects = <int>[];
    final Set<int> receiptIds = <int>{};
    var totalDebitCents = BigInt.zero;
    var totalCreditCents = BigInt.zero;
    var hasRoot = false;
    String? sourceId;
    String? groupDate;
    for (final Map<String, Object?> row in rows) {
      final int? id = _positiveInt(row['id']);
      final int? rowGroupId = _positiveInt(row['gruppe_id']);
      final int? rowAccountId = _positiveInt(row['konto_id']);
      final String? date = row['datum'] as String?;
      final DateTime? parsedDate = date == null ? null : _parseLocalDate(date);
      final String? kind = row['source_kind'] as String?;
      final String? rowSourceId = row['source_id'] as String?;
      final int? debitCents = _moneyCents(row['soll']);
      final int? creditCents = _moneyCents(row['haben']);
      final int? amountCents = _moneyCents(row['betrag']);
      final int? debitAccountId = _positiveInt(row['soll_konto_id']);
      final int? creditAccountId = _positiveInt(row['haben_konto_id']);
      final Object? rawReceiptId = row['beleg_id'];
      final int? receiptId = rawReceiptId == null ? null : _positiveInt(rawReceiptId);
      if (id == null ||
          rowGroupId != rootId ||
          rowAccountId == null ||
          parsedDate == null ||
          kind != 'cash_payment' ||
          rowSourceId == null ||
          rowSourceId.trim().isEmpty ||
          (rawReceiptId != null && receiptId == null) ||
          _integer(row['immutable']) != 1 ||
          _integer(row['legacy_unverified']) != 0 ||
          debitCents == null ||
          creditCents == null ||
          amountCents == null ||
          debitCents < 0 ||
          creditCents < 0 ||
          (debitCents == 0) == (creditCents == 0) ||
          amountCents != debitCents - creditCents ||
          (debitAccountId != null) == (creditAccountId != null) ||
          (debitCents > 0 && debitAccountId != rowAccountId) ||
          (creditCents > 0 && creditAccountId != rowAccountId)) {
        throw const _IncompleteCashbookHistory();
      }
      if (receiptId != null) receiptIds.add(receiptId);
      if (groupDate != null && groupDate != date) throw const _IncompleteCashbookHistory();
      if (sourceId != null && sourceId != rowSourceId) throw const _IncompleteCashbookHistory();
      groupDate = date;
      sourceId = rowSourceId;
      hasRoot = hasRoot || id == rootId;
      totalDebitCents += BigInt.from(debitCents);
      totalCreditCents += BigInt.from(creditCents);
      if (rowAccountId == accountId) groupAccountEffects.add(amountCents);
    }
    if (!hasRoot || groupAccountEffects.isEmpty || totalDebitCents != totalCreditCents || groupDate == null) {
      throw const _IncompleteCashbookHistory();
    }
    final DateTime? parsedGroupDate = _parseLocalDate(groupDate);
    if (parsedGroupDate == null || !_sameLocalDate(parsedGroupDate, candidateDate)) {
      throw const _IncompleteCashbookHistory();
    }
    final int effectCents = groupAccountEffects.fold<int>(0, (int sum, int amount) => sum + amount);
    if (effectCents == 0) throw const _IncompleteCashbookHistory();
    final Map<String, Object?> root = rows.firstWhere((Map<String, Object?> row) => _positiveInt(row['id']) == rootId);
    final String? description = root['beschreibung'] as String?;
    if (description == null || description.trim().isEmpty) throw const _IncompleteCashbookHistory();
    final List<Map<String, Object?>> settlementRows = await executor.runSelect(
      'SELECT id, source_kind, source_id, signed_amount_cents, settlement_date, unapplied_cents, '
      'group_root_journal_id FROM settlement_groups WHERE source_kind = ? AND source_id = ?',
      <Object?>['cash_payment', sourceId],
    );
    if (settlementRows.length != 1) throw const _IncompleteCashbookHistory();
    final Map<String, Object?> settlement = settlementRows.single;
    final int? settlementId = _positiveInt(settlement['id']);
    final int? settlementRootId = _positiveInt(settlement['group_root_journal_id']);
    final int? signedAmountCents = _integer(settlement['signed_amount_cents']);
    final int? unappliedCents = _integer(settlement['unapplied_cents']);
    final int? rootAmountCents = _moneyCents(root['betrag']);
    if (settlementId == null ||
        settlement['source_kind'] != 'cash_payment' ||
        settlement['source_id'] != sourceId ||
        settlementRootId != rootId ||
        settlement['settlement_date'] != groupDate ||
        signedAmountCents == null ||
        rootAmountCents != signedAmountCents ||
        signedAmountCents != effectCents ||
        unappliedCents == null) {
      throw const _IncompleteCashbookHistory();
    }
    final List<Map<String, Object?>> allocationRows = await executor.runSelect(
      'SELECT a.applied_cents, a.kategorie_id, a.ust_satz, k.bezeichnung AS category_name '
      'FROM settlement_allocations AS a LEFT JOIN kategorien AS k ON k.id = a.kategorie_id '
      'WHERE a.group_id = ? ORDER BY a.id',
      <Object?>[settlementId],
    );
    if (allocationRows.isEmpty) throw const _IncompleteCashbookHistory();
    var allocatedMagnitude = BigInt.zero;
    final List<CashbookAllocationEvidence> allocations = <CashbookAllocationEvidence>[];
    for (final Map<String, Object?> allocation in allocationRows) {
      final int? appliedCents = _integer(allocation['applied_cents']);
      final int? categoryId = _positiveInt(allocation['kategorie_id']);
      final String? categoryName = allocation['category_name'] as String?;
      final Object? rawTaxRate = allocation['ust_satz'];
      final num? taxRate = rawTaxRate == null
          ? null
          : rawTaxRate is num
          ? rawTaxRate
          : num.tryParse(rawTaxRate.toString());
      if (appliedCents == null ||
          appliedCents == 0 ||
          categoryId == null ||
          categoryName == null ||
          categoryName.trim().isEmpty ||
          (rawTaxRate != null && taxRate == null) ||
          (taxRate != null && (taxRate < 0 || taxRate > 100))) {
        throw const _IncompleteCashbookHistory();
      }
      allocatedMagnitude += BigInt.from(appliedCents).abs();
      allocations.add(CashbookAllocationEvidence(categoryName: categoryName, taxRate: taxRate));
    }
    if (allocatedMagnitude + BigInt.from(unappliedCents).abs() != BigInt.from(signedAmountCents).abs()) {
      throw const _IncompleteCashbookHistory();
    }
    String? receiptReference;
    if (receiptIds.length > 1) throw const _IncompleteCashbookHistory();
    if (receiptIds.isNotEmpty) {
      final int receiptId = receiptIds.single;
      final List<Map<String, Object?>> receipts = await executor.runSelect(
        'SELECT belegnummer FROM belege WHERE id = ?',
        <Object?>[receiptId],
      );
      if (receipts.length != 1) throw const _IncompleteCashbookHistory();
      final String? receiptNumber = receipts.single['belegnummer']?.toString();
      receiptReference = receiptNumber == null || receiptNumber.trim().isEmpty ? '#$receiptId' : receiptNumber.trim();
    }
    return CashbookMovementEvidence(
      postingGroupId: rootId.toString(),
      sourceReference: sourceId,
      companyId: companyId.toString(),
      accountId: accountId.toString(),
      effectiveAt: parsedGroupDate,
      amountCents: effectCents,
      currencyCode: accountCurrency,
      status: CashbookMovementStatus.committed,
      kind: CashbookMovementKind.cashPayment,
      balanced: true,
      linkedToAccount: true,
      direction: effectCents > 0 ? CashbookMovementDirection.income : CashbookMovementDirection.expense,
      amountBasis: CashbookMovementAmountBasis.committedCashEffect,
      allocations: List<CashbookAllocationEvidence>.unmodifiable(allocations),
      description: description.trim(),
      receiptReference: receiptReference,
    );
  }

  static int? _positiveInt(Object? value) {
    final int? parsed = _integer(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _moneyCents(Object? value) {
    if (value is! num && value is! String) return null;
    try {
      return money.parseScaled(value.toString(), scale: 2, field: 'cashbook amount');
    } on money.MoneyParseException {
      return null;
    }
  }

  static bool _isValidLocalDate(DateTime value) =>
      _parseLocalDate(
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
      ) !=
      null;

  static DateTime? _parseLocalDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final List<String> parts = value.split('-');
    final int year = int.parse(parts[0]);
    final int month = int.parse(parts[1]);
    final int day = int.parse(parts[2]);
    final DateTime parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) return null;
    return parsed;
  }

  static bool _sameLocalDate(DateTime left, DateTime right) =>
      left.year == right.year && left.month == right.month && left.day == right.day;
}

class _VerifiedOpening {
  const _VerifiedOpening({required this.journalId, required this.evidence});

  final int journalId;
  final CashbookOpeningBalance evidence;
}

class _IncompleteCashbookHistory implements Exception {
  const _IncompleteCashbookHistory();
}
