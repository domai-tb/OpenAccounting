import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/features/accounting/tagesabschluss_creation.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';
import 'package:openaccounting/features/cashbook/cashbook_balance_source.dart';
import 'package:openaccounting/l10n/l10n.dart';

class TagesabschlussPage extends ConsumerStatefulWidget {
  const TagesabschlussPage({super.key});

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
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCompanies());
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
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _balance = result;
      _balanceLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = ref.watch(appServicesProvider);
    final TagesabschlussCreation creation = services.tagesabschlussCreation;
    final CashbookBalanceResult? result = _balance;
    final TagesabschlussDraft? draft = result == null ? null : creation.prepare(result);
    final String locale = Localizations.localeOf(context).toString();
    final String? companyName = _companyName();
    final String? accountName = _accountName();

    return AppPage(
      maxWidth: 1000,
      header: AppPageHeader(
        title: l10n.tagesabschlussTitle,
        subtitle: l10n.tagesabschlussSubtitle,
        showFilterToolbar: false,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    key: const ValueKey<String>('daily-close-company'),
                    initialValue: _companyId,
                    decoration: InputDecoration(labelText: l10n.tagesabschlussCompany),
                    items: <DropdownMenuItem<int>>[
                      for (final CashbookCompanyOption company in _companies)
                        DropdownMenuItem<int>(value: company.id, child: Text(company.name)),
                    ],
                    onChanged: _companiesLoading ? null : _changeCompany,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: const ValueKey<String>('daily-close-account'),
                    initialValue: _accountId,
                    decoration: InputDecoration(labelText: l10n.tagesabschlussAccount),
                    items: <DropdownMenuItem<int>>[
                      for (final CashbookAccountOption account in _accounts)
                        DropdownMenuItem<int>(value: account.id, child: Text(account.name)),
                    ],
                    onChanged: _companyId == null || _accountsLoading ? null : _changeAccount,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('daily-close-date-picker'),
                      onPressed: _chooseDate,
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
            const SizedBox(height: 16),
            if (_balanceLoading) const Center(child: CircularProgressIndicator()),
            if (draft == null)
              AppCard(
                child: Text(
                  l10n.tagesabschlussUnavailable,
                  key: const ValueKey<String>('daily-close-result-unavailable'),
                ),
              )
            else ...<Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _field(l10n.tagesabschlussCompany, companyName ?? draft.companyId),
                    _field(l10n.tagesabschlussAccount, accountName ?? draft.accountId),
                    _field(l10n.tagesabschlussDate, formatDate(draft.asOfDate, locale: locale)),
                    _field(
                      l10n.tagesabschlussExpectedBalance,
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
              const SizedBox(height: 16),
              AppCard(
                child: TextField(
                  key: const ValueKey<String>('daily-close-counted-balance'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.tagesabschlussCountedBalance),
                ),
              ),
            ],
          ],
        ),
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
