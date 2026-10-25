import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/tagesabschluss_creation.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';
import 'package:openaccounting/features/cashbook/cashbook_balance_source.dart';
import 'package:openaccounting/l10n/l10n.dart';

class TagesabschlussPage extends ConsumerStatefulWidget {
  const TagesabschlussPage({super.key, this.cashbook = false});

  final bool cashbook;

  @override
  ConsumerState<TagesabschlussPage> createState() => _TagesabschlussPageState();
}

class _TagesabschlussPageState extends ConsumerState<TagesabschlussPage> {
  List<CashbookCompanyOption> _companies = const <CashbookCompanyOption>[];
  List<CashbookAccountOption> _accounts = const <CashbookAccountOption>[];
  int? _companyId;
  int? _accountId;
  DateTime? _asOfDate;
  CashbookBalanceResult? _balance;
  bool _companiesLoading = true;
  bool _accountsLoading = false;
  bool _balanceLoading = false;
  bool _finalizationInProgress = false;
  bool _finalized = false;
  TagesabschlussCloseLookup _existingClose = const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.absent);
  int _requestGeneration = 0;
  final TextEditingController _countedBalanceController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadCompanies());
  }

  @override
  void dispose() {
    _countedBalanceController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  void _resetFinalization() {
    _countedBalanceController.clear();
    _explanationController.clear();
    _finalizationInProgress = false;
    _finalized = false;
    _existingClose = const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.absent);
  }

  Future<void> _loadCompanies() async {
    try {
      final List<CashbookCompanyOption> companies = await ref
          .read(appServicesProvider)
          .cashbookBalanceSource
          .companies();
      if (!mounted) return;
      setState(() {
        _companies = companies;
        _companiesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _companiesLoading = false);
    }
  }

  Future<void> _changeCompany(int? companyId) async {
    ++_requestGeneration;
    _resetFinalization();
    setState(() {
      _companyId = companyId;
      _accountId = null;
      _accounts = const <CashbookAccountOption>[];
      _accountsLoading = companyId != null;
      _balance = null;
      _balanceLoading = false;
    });
    if (companyId == null) return;
    try {
      final List<CashbookAccountOption> accounts = await ref
          .read(appServicesProvider)
          .cashbookBalanceSource
          .cashAccounts(companyId);
      if (!mounted || _companyId != companyId) return;
      setState(() {
        _accounts = accounts;
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted || _companyId != companyId) return;
      setState(() => _accountsLoading = false);
    }
  }

  void _changeAccount(int? accountId) {
    _resetFinalization();
    setState(() {
      _accountId = accountId;
      _balance = null;
    });
    unawaited(_resolveBalance());
  }

  Future<void> _chooseDate() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _asOfDate ?? today,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    _resetFinalization();
    setState(() {
      _asOfDate = DateTime(picked.year, picked.month, picked.day);
      _balance = null;
    });
    unawaited(_resolveBalance());
  }

  Future<void> _resolveBalance() async {
    final int generation = ++_requestGeneration;
    final int? companyId = _companyId;
    final int? accountId = _accountId;
    final DateTime? asOfDate = _asOfDate;
    CashbookAccountOption? account;
    for (final CashbookAccountOption option in _accounts) {
      if (option.id == accountId) {
        account = option;
        break;
      }
    }
    if (companyId == null || accountId == null || account == null || asOfDate == null) {
      if (!mounted) return;
      setState(() {
        _balance = null;
        _balanceLoading = false;
      });
      return;
    }
    setState(() {
      _balance = null;
      _balanceLoading = true;
    });
    CashbookBalanceResult? result;
    try {
      result = await ref
          .read(appServicesProvider)
          .cashbookBalanceSource
          .resolve(
            CashbookBalanceRequest(
              companyId: companyId.toString(),
              accountId: accountId.toString(),
              asOfDate: asOfDate,
              currencyCode: account.currencyCode,
            ),
          );
    } catch (_) {
      result = null;
    }
    TagesabschlussCloseLookup existingClose;
    try {
      existingClose = await ref
          .read(appServicesProvider)
          .tagesabschlussFinalization
          .lookupExisting(companyId: companyId.toString(), accountId: accountId.toString(), asOfDate: asOfDate);
    } catch (_) {
      existingClose = const TagesabschlussCloseLookup(status: TagesabschlussCloseStatus.unverified);
    }
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _balance = result;
      _existingClose = existingClose;
      _balanceLoading = false;
    });
  }

  int? _countedBalanceCents() {
    final String raw = _countedBalanceController.text.trim();
    if (raw.isEmpty) return null;
    try {
      return money.parseScaled(raw, scale: 2, field: 'counted balance');
    } on money.MoneyParseException {
      return null;
    }
  }

  Future<void> _finalizeClose(CashbookBalanceResult balance, int countedBalanceCents) async {
    if (_finalizationInProgress || _finalized) return;
    setState(() => _finalizationInProgress = true);
    try {
      final TagesabschlussCloseLookup close = await ref
          .read(appServicesProvider)
          .tagesabschlussFinalization
          .finalize(
            balance: balance,
            countedBalanceCents: countedBalanceCents,
            explanation: _explanationController.text,
          );
      if (!mounted) return;
      setState(() {
        _finalizationInProgress = false;
        _existingClose = close;
        _finalized = close.status == TagesabschlussCloseStatus.verified;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _finalizationInProgress = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).saveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = ref.watch(appServicesProvider);
    final TagesabschlussCreation creation = services.tagesabschlussCreation;
    final CashbookBalanceResult? result = _balance;
    final TagesabschlussDraft? draft = result == null ? null : creation.prepare(result);
    final int? countedBalanceCents = _countedBalanceCents();
    final BigInt? difference = draft == null || countedBalanceCents == null
        ? null
        : BigInt.from(countedBalanceCents) - BigInt.from(draft.expectedBalanceCents);
    final bool explanationRequired = difference != null && difference != BigInt.zero;
    final bool canFinalize =
        draft != null &&
        result != null &&
        countedBalanceCents != null &&
        !_finalizationInProgress &&
        !_finalized &&
        (!explanationRequired || _explanationController.text.trim().isNotEmpty);
    final String locale = Localizations.localeOf(context).toString();
    final String? companyName = _companyName();
    final String? accountName = _accountName();
    final bool cashbook = widget.cashbook;
    final bool hasSelection = _companyId != null && _accountId != null && _asOfDate != null;

    return AppPage(
      maxWidth: 1000,
      header: AppPageHeader(
        title: cashbook ? l10n.cashbookTitle : l10n.tagesabschlussTitle,
        subtitle: cashbook ? l10n.cashbookSubtitle : l10n.tagesabschlussSubtitle,
        showFilterToolbar: false,
        actions: cashbook
            ? <Widget>[
                TextButton.icon(
                  onPressed: () => context.go('/banking?view=close'),
                  icon: const Icon(Icons.fact_check),
                  label: Text(l10n.bankViewClose),
                ),
              ]
            : const <Widget>[],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (cashbook)
              AppCard(
                child: Text(l10n.cashbookSubtitle, key: const ValueKey<String>('cashbook-entry-contract-unavailable')),
              ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>(cashbook ? 'cashbook-company' : 'daily-close-company'),
                    initialValue: _companyId,
                    decoration: InputDecoration(labelText: l10n.tagesabschlussCompany),
                    items: <DropdownMenuItem<int>>[
                      for (final CashbookCompanyOption company in _companies)
                        DropdownMenuItem<int>(value: company.id, child: Text(company.name)),
                    ],
                    onChanged: _companiesLoading || _finalizationInProgress ? null : _changeCompany,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey<String>(cashbook ? 'cashbook-account' : 'daily-close-account'),
                    initialValue: _accountId,
                    decoration: InputDecoration(labelText: l10n.tagesabschlussAccount),
                    items: <DropdownMenuItem<int>>[
                      for (final CashbookAccountOption account in _accounts)
                        DropdownMenuItem<int>(value: account.id, child: Text(account.name)),
                    ],
                    onChanged: _companyId == null || _accountsLoading || _finalizationInProgress
                        ? null
                        : _changeAccount,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: ValueKey<String>(cashbook ? 'cashbook-date-picker' : 'daily-close-date-picker'),
                      onPressed: _finalizationInProgress ? null : _chooseDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _asOfDate == null
                            ? l10n.tagesabschlussDate
                            : '${l10n.tagesabschlussDate}: ${formatDate(_asOfDate!, locale: locale)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (cashbook && hasSelection && !_balanceLoading && result?.complete != true)
              AppCard(
                child: Text(
                  l10n.cashbookMovementsUnavailable,
                  key: const ValueKey<String>('cashbook-movements-unavailable'),
                ),
              ),
            if (cashbook && result?.complete == true) ...<Widget>[
              const SizedBox(height: 16),
              _cashbookEvents(l10n, locale, result!.movements),
            ],
            const SizedBox(height: 16),
            if (_balanceLoading) const Center(child: CircularProgressIndicator()),
            if (!cashbook && _existingClose.status == TagesabschlussCloseStatus.unverified)
              AppCard(
                child: Text(
                  l10n.tagesabschlussUnavailable,
                  key: const ValueKey<String>('daily-close-unverified-history'),
                ),
              )
            else if (!cashbook &&
                _existingClose.status == TagesabschlussCloseStatus.verified &&
                _existingClose.snapshot != null)
              _verifiedCloseCard(l10n, locale, _existingClose.snapshot!)
            else if (draft == null && (!cashbook || !_balanceLoading))
              AppCard(
                child: Text(
                  cashbook
                      ? hasSelection
                            ? l10n.cashbookUnavailable
                            : l10n.cashbookSelectionPrompt
                      : l10n.tagesabschlussUnavailable,
                  key: ValueKey<String>(cashbook ? 'cashbook-result-unavailable' : 'daily-close-result-unavailable'),
                ),
              )
            else if (draft != null) ...<Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _field(l10n.tagesabschlussCompany, companyName ?? draft.companyId),
                    _field(l10n.tagesabschlussAccount, accountName ?? draft.accountId),
                    _field(l10n.tagesabschlussDate, formatDate(draft.asOfDate, locale: locale)),
                    _field(
                      cashbook ? l10n.cashbookBalance : l10n.tagesabschlussExpectedBalance,
                      _formatCents(draft.expectedBalanceCents, draft.currencyCode, locale),
                    ),
                    _field(l10n.tagesabschlussCurrency, draft.currencyCode),
                    _field(l10n.tagesabschlussSource, draft.sourceReference),
                    _field(
                      l10n.tagesabschlussCompleteness,
                      draft.complete ? l10n.tagesabschlussComplete : l10n.tagesabschlussUnavailable,
                    ),
                  ],
                ),
              ),
              if (!cashbook) ...<Widget>[
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        key: const ValueKey<String>('daily-close-counted-balance'),
                        controller: _countedBalanceController,
                        enabled: !_finalized && !_finalizationInProgress,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l10n.tagesabschlussCountedBalance),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (explanationRequired || _explanationController.text.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey<String>('daily-close-explanation'),
                          controller: _explanationController,
                          enabled: !_finalized && !_finalizationInProgress,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: '${l10n.mileageCorrectionReason}${explanationRequired ? ' *' : ''}',
                            helperText: explanationRequired ? l10n.mileageCorrectionReasonRequired : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const ValueKey<String>('daily-close-finalize'),
                        onPressed: canFinalize ? () => unawaited(_finalizeClose(result, countedBalanceCents)) : null,
                        icon: const Icon(Icons.fact_check),
                        label: Text(l10n.close),
                      ),
                      if (_finalizationInProgress) const LinearProgressIndicator(),
                      if (_finalized)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            l10n.tagesabschlussComplete,
                            key: const ValueKey<String>('daily-close-finalized'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _cashbookEvents(AppLocalizations l10n, String locale, List<CashbookMovementEvidence> movements) {
    final NumberFormat numberFormat = NumberFormat.decimalPattern(locale);
    return AppCard(
      child: Column(
        key: const ValueKey<String>('cashbook-event-list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.cashbookEventsTitle, style: Theme.of(context).textTheme.titleMedium),
          if (movements.isEmpty)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(l10n.cashbookEventsEmpty)),
          for (final CashbookMovementEvidence movement in movements)
            Padding(
              key: ValueKey<String>('cashbook-event-${movement.postingGroupId}'),
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    movement.description!,
                    key: ValueKey<String>('cashbook-event-description-${movement.postingGroupId}'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${l10n.tagesabschlussDate}: ${formatDate(movement.effectiveAt!, locale: locale)}',
                    key: ValueKey<String>('cashbook-event-date-${movement.postingGroupId}'),
                  ),
                  Text(
                    '${l10n.cashbookEventDirection}: ${movement.direction == CashbookMovementDirection.income ? l10n.cashbookEventIncome : l10n.cashbookEventExpense}',
                    key: ValueKey<String>('cashbook-event-direction-${movement.postingGroupId}'),
                  ),
                  Text(
                    '${l10n.cashbookEventAmount}: ${_formatCents(movement.amountCents!, movement.currencyCode!, locale)}',
                    key: ValueKey<String>('cashbook-event-amount-${movement.postingGroupId}'),
                  ),
                  Text(
                    '${l10n.cashbookEventAmountBasis}: ${movement.amountBasis == CashbookMovementAmountBasis.committedCashEffect ? l10n.cashbookPostedCashAmountBasis : l10n.cashbookEventAmountBasisUnavailable}',
                    key: ValueKey<String>('cashbook-event-amount-basis-${movement.postingGroupId}'),
                  ),
                  Text(
                    '${l10n.cashbookEventCategory}: ${movement.allocations.map((CashbookAllocationEvidence allocation) => allocation.categoryName).toSet().join(', ')}',
                    key: ValueKey<String>('cashbook-event-category-${movement.postingGroupId}'),
                  ),
                  Text(
                    '${l10n.cashbookEventTaxTreatment}: ${movement.allocations.map((CashbookAllocationEvidence allocation) => allocation.taxRate == null ? l10n.cashbookEventTaxNotRecorded : '${numberFormat.format(allocation.taxRate)}%').toSet().join(', ')}',
                    key: ValueKey<String>('cashbook-event-tax-${movement.postingGroupId}'),
                  ),
                  Text(
                    '${l10n.cashbookEventPosting}: #${movement.postingGroupId} · ${movement.sourceReference}',
                    key: ValueKey<String>('cashbook-event-posting-${movement.postingGroupId}'),
                  ),
                  if (movement.receiptReference != null)
                    Text(
                      '${l10n.documentReceipt}: ${movement.receiptReference}',
                      key: ValueKey<String>('cashbook-event-receipt-${movement.postingGroupId}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _verifiedCloseCard(AppLocalizations l10n, String locale, TagesabschlussFinalizedSnapshot snapshot) {
    return AppCard(
      child: Column(
        key: const ValueKey<String>('daily-close-verified-snapshot'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.tagesabschlussComplete,
            key: const ValueKey<String>('daily-close-finalized'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          _field(l10n.tagesabschlussCompany, _companyName() ?? snapshot.companyId),
          _field(l10n.tagesabschlussAccount, _accountName() ?? snapshot.accountId),
          _field(l10n.tagesabschlussDate, formatDate(snapshot.asOfDate, locale: locale)),
          _field(
            l10n.tagesabschlussExpectedBalance,
            _formatCents(snapshot.expectedBalanceCents, snapshot.currencyCode, locale),
          ),
          _field(
            l10n.tagesabschlussCountedBalance,
            _formatCents(snapshot.countedBalanceCents, snapshot.currencyCode, locale),
          ),
          _field(l10n.tagesabschlussCurrency, snapshot.currencyCode),
          _field(l10n.tagesabschlussSource, snapshot.sourceReference),
          if (snapshot.explanation != null) _field(l10n.mileageCorrectionReason, snapshot.explanation!),
        ],
      ),
    );
  }

  String? _companyName() {
    for (final CashbookCompanyOption company in _companies) {
      if (company.id == _companyId) return company.name;
    }
    return null;
  }

  String? _accountName() {
    for (final CashbookAccountOption account in _accounts) {
      if (account.id == _accountId) return account.name;
    }
    return null;
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, softWrap: true),
      ],
    ),
  );

  String _formatCents(int cents, String currencyCode, String locale) {
    final NumberFormat numberFormat = NumberFormat.decimalPattern(locale);
    final int absoluteCents = cents.abs();
    final String whole = numberFormat.format(absoluteCents ~/ 100);
    final String fraction = (absoluteCents % 100).toString().padLeft(2, '0');
    final String sign = cents < 0 ? '-' : '';
    return '$sign$whole${numberFormat.symbols.DECIMAL_SEP}$fraction $currencyCode';
  }
}
