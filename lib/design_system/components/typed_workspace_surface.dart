import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/typed_workspace_search.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';

class TypedWorkspaceSurface extends ConsumerStatefulWidget {
  const TypedWorkspaceSurface({
    required this.title,
    required this.criteria,
    required this.onCriteriaChanged,
    this.invalidFields = const <TypedWorkspaceFilterField>{},
    this.icon = Icons.list_alt,
    this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.onOpen,
    this.topContent,
    super.key,
  });

  final String title;
  final TypedWorkspaceSearchCriteria criteria;
  final ValueChanged<TypedWorkspaceSearchCriteria> onCriteriaChanged;
  final Set<TypedWorkspaceFilterField> invalidFields;
  final IconData icon;
  final String? subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final ValueChanged<TypedWorkspaceRecord>? onOpen;
  final Widget? topContent;

  @override
  ConsumerState<TypedWorkspaceSurface> createState() => _TypedWorkspaceSurfaceState();
}

class _TypedWorkspaceSurfaceState extends ConsumerState<TypedWorkspaceSurface> {
  late final TextEditingController _queryController;
  late final TextEditingController _statusController;
  late final TextEditingController _amountFromController;
  late final TextEditingController _amountToController;
  late TypedWorkspaceSearchCriteria _criteria;
  late Set<TypedWorkspaceFilterField> _invalidFields;

  @override
  void initState() {
    super.initState();
    _criteria = widget.criteria;
    _invalidFields = Set<TypedWorkspaceFilterField>.from(widget.invalidFields);
    _queryController = TextEditingController(text: _criteria.text);
    _statusController = TextEditingController(text: _criteria.status ?? '');
    _amountFromController = TextEditingController(text: _formatAmount(_criteria.amountFrom));
    _amountToController = TextEditingController(text: _formatAmount(_criteria.amountTo));
  }

  @override
  void didUpdateWidget(covariant TypedWorkspaceSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.criteria != oldWidget.criteria) {
      _criteria = widget.criteria;
      if (_queryController.text != _criteria.text) _queryController.text = _criteria.text;
      _statusController.text = _criteria.status ?? '';
      _amountFromController.text = _formatAmount(_criteria.amountFrom, locale: _activeLocale);
      _amountToController.text = _formatAmount(_criteria.amountTo, locale: _activeLocale);
    }
    if (widget.invalidFields != oldWidget.invalidFields) {
      _invalidFields = Set<TypedWorkspaceFilterField>.from(widget.invalidFields);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String locale = _activeLocale;
    if (_criteria.amountFrom != null) _amountFromController.text = _formatAmount(_criteria.amountFrom, locale: locale);
    if (_criteria.amountTo != null) _amountToController.text = _formatAmount(_criteria.amountTo, locale: locale);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _statusController.dispose();
    _amountFromController.dispose();
    _amountToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String locale = localeTag(Localizations.localeOf(context));
    final AsyncValue<TypedWorkspaceSearchPage> result = ref.watch(typedWorkspaceSearchResultsProvider(_criteria));
    final int? count = _invalidFields.isNotEmpty || !result.hasValue ? null : result.value!.totalCount;
    final List<({String label, TypedWorkspaceSearchCriteria next})> chips = _filterChips(l10n, locale);
    final Map<String, TypedWorkspaceSearchCriteria> removable = <String, TypedWorkspaceSearchCriteria>{
      for (final ({String label, TypedWorkspaceSearchCriteria next}) chip in chips) chip.label: chip.next,
    };
    final Widget body = _invalidFields.isNotEmpty
        ? _buildInvalidCriteria(l10n)
        : result.when(
            loading: _buildLoading,
            error: (Object error, StackTrace stackTrace) => _buildError(l10n, _criteria),
            data: (TypedWorkspaceSearchPage page) => _buildData(context, page, l10n, locale),
          );
    final Widget content = widget.topContent == null
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              widget.topContent!,
              Expanded(child: body),
            ],
          );
    return AppPage(
      maxWidth: 1180,
      header: AppPageHeader(
        title: widget.title,
        subtitle: widget.subtitle,
        searchController: _queryController,
        searchHint: '${widget.title} ${l10n.actionSearch.toLowerCase()}…',
        onSearchChanged: (String value) => _apply(_criteria.copyWith(text: value, page: 1)),
        filterButtonLabel: l10n.actionFilter,
        onFilterPressed: _openFilterEditor,
        activeFilters: <String>[
          for (final ({String label, TypedWorkspaceSearchCriteria next}) chip in chips) chip.label,
        ],
        onFilterRemoved: (String label) {
          final TypedWorkspaceSearchCriteria? next = removable[label];
          if (next != null) _apply(next);
        },
        removeFilterLabel: l10n.actionRemoveFilter,
        resultCount: count,
        resultCountLabelBuilder: (int value) => _countLabel(value, l10n),
        resetFiltersLabel: l10n.filterClearAll,
        onResetFilters: _criteria.hasFilters || _invalidFields.isNotEmpty ? _resetFilters : null,
      ),
      child: content,
    );
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator());

  Widget _buildInvalidCriteria(AppLocalizations l10n) {
    final bool dateInvalid =
        _invalidFields.contains(TypedWorkspaceFilterField.dateFrom) ||
        _invalidFields.contains(TypedWorkspaceFilterField.dateTo);
    final bool rangeInvalid =
        _invalidFields.contains(TypedWorkspaceFilterField.amountFrom) &&
        _invalidFields.contains(TypedWorkspaceFilterField.amountTo);
    final String message = dateInvalid
        ? l10n.filterInvalidDateRange
        : rangeInvalid
        ? l10n.filterInvalidAmountRange
        : l10n.filterInvalidAmount;
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.filter_alt_off, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _openFilterEditor,
            icon: const Icon(Icons.filter_list),
            label: Text(l10n.actionFilter),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n, TypedWorkspaceSearchCriteria criteria) => AppCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.cloud_off_outlined, size: 36),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.loadError),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(typedWorkspaceSearchResultsProvider(criteria)),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.actionRetry),
        ),
      ],
    ),
  );

  Widget _buildData(BuildContext context, TypedWorkspaceSearchPage page, AppLocalizations l10n, String locale) {
    if (page.records.isEmpty) {
      return AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(_criteria.hasFilters ? Icons.search_off : widget.icon, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(_criteria.hasFilters ? l10n.emptyResults : l10n.emptyEntries),
            if (_criteria.hasFilters) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: _resetFilters, child: Text(l10n.filterClearAll)),
            ],
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              key: const ValueKey<String>('typed_workspace_results'),
              itemCount: page.records.length,
              separatorBuilder: (BuildContext context, int index) => const Divider(height: 1, indent: 72),
              itemBuilder: (BuildContext context, int index) => _recordTile(page.records[index], l10n, locale),
            ),
          ),
        ),
        if (page.pageCount > 1) _pagination(page, l10n),
      ],
    );
  }

  Widget _recordTile(TypedWorkspaceRecord record, AppLocalizations l10n, String locale) {
    final String label = switch (record) {
      InvoiceWorkspaceRecord(number: final String number, id: final int id) =>
        number.isEmpty ? l10n.globalSearchInvoiceFallback('$id') : number,
      ReceiptWorkspaceRecord(number: final String number, id: final int id) =>
        number.isEmpty ? l10n.globalSearchReceiptFallback('$id') : number,
      BankTransactionWorkspaceRecord(
        counterpartyName: final String name,
        counterpartyAccount: final String account,
        id: final int id,
      ) =>
        name.isNotEmpty
            ? name
            : account.isNotEmpty
            ? account
            : l10n.globalSearchTransactionFallback('$id'),
    };
    final String details = switch (record) {
      InvoiceWorkspaceRecord(:final party, :final date, :final status) => _join(<String>[party, date, status]),
      ReceiptWorkspaceRecord(:final description, :final supplier, :final date, :final status) => _join(<String>[
        description,
        supplier,
        date,
        status,
      ]),
      BankTransactionWorkspaceRecord(:final counterpartyAccount, :final remittance, :final date, :final status) =>
        _join(<String>[counterpartyAccount, remittance, date, status]),
    };
    final IconData icon = switch (record) {
      InvoiceWorkspaceRecord() => Icons.receipt_long,
      ReceiptWorkspaceRecord() => Icons.receipt_outlined,
      BankTransactionWorkspaceRecord() => Icons.account_balance,
    };
    return Semantics(
      button: widget.onOpen != null,
      label: <String>[
        label,
        details,
        formatMoney(record.amount, locale: locale),
      ].where((String part) => part.isNotEmpty).join(', '),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: ListTile(
          key: ValueKey<String>('typed_workspace_record_${record.id}'),
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: details.isEmpty ? null : Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: SizedBox(width: 132, child: MoneyText(record.amount, locale: locale)),
          onTap: widget.onOpen == null ? null : () => widget.onOpen!(record),
        ),
      ),
    );
  }

  Widget _pagination(TypedWorkspaceSearchPage page, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: l10n.filterPreviousPage,
          onPressed: page.page > 1 ? () => _apply(_criteria.copyWith(page: page.page - 1)) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(l10n.filterPageCount(page.page, page.pageCount)),
        IconButton(
          tooltip: l10n.filterNextPage,
          onPressed: page.page < page.pageCount ? () => _apply(_criteria.copyWith(page: page.page + 1)) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  List<({String label, TypedWorkspaceSearchCriteria next})> _filterChips(AppLocalizations l10n, String locale) {
    final List<({String label, TypedWorkspaceSearchCriteria next})> chips =
        <({String label, TypedWorkspaceSearchCriteria next})>[];
    if (_criteria.text.trim().isNotEmpty) {
      chips.add((label: '${l10n.actionSearch}: ${_criteria.text.trim()}', next: _criteria.copyWith(text: '', page: 1)));
    }
    if (_criteria.invoiceType case final String type when type.isNotEmpty) {
      chips.add((label: l10n.filterTypeLabel(type), next: _criteria.copyWith(clearInvoiceType: true, page: 1)));
    }
    if (_criteria.dateFrom case final DateTime dateFrom) {
      chips.add((
        label: '${l10n.filterDateFrom}: ${formatDate(dateFrom, locale: locale)}',
        next: _criteria.copyWith(clearDateFrom: true, page: 1),
      ));
    }
    if (_criteria.dateTo case final DateTime dateTo) {
      chips.add((
        label: '${l10n.filterDateTo}: ${formatDate(dateTo, locale: locale)}',
        next: _criteria.copyWith(clearDateTo: true, page: 1),
      ));
    }
    if (_criteria.status case final String status when status.isNotEmpty) {
      chips.add((label: '${l10n.filterStatusExact}: $status', next: _criteria.copyWith(clearStatus: true, page: 1)));
    }
    if (_criteria.amountFrom case final num amountFrom) {
      chips.add((
        label: '${l10n.filterAmountFrom}: ${formatMoney(amountFrom, locale: locale)}',
        next: _criteria.copyWith(clearAmountFrom: true, page: 1),
      ));
    }
    if (_criteria.amountTo case final num amountTo) {
      chips.add((
        label: '${l10n.filterAmountTo}: ${formatMoney(amountTo, locale: locale)}',
        next: _criteria.copyWith(clearAmountTo: true, page: 1),
      ));
    }
    return chips;
  }

  Future<void> _openFilterEditor() async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String locale = localeTag(Localizations.localeOf(context));
    _statusController.text = _criteria.status ?? '';
    _amountFromController.text = _formatAmount(_criteria.amountFrom, locale: locale);
    _amountToController.text = _formatAmount(_criteria.amountTo, locale: locale);
    DateTime? dateFrom = _criteria.dateFrom;
    DateTime? dateTo = _criteria.dateTo;
    String? error;
    final TypedWorkspaceSearchCriteria? updated = await showDialog<TypedWorkspaceSearchCriteria>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
          title: Text(l10n.actionFilter),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _dateFilterButton(
                    context: dialogContext,
                    label: l10n.filterDateFrom,
                    value: dateFrom,
                    locale: locale,
                    onPick: (DateTime value) => setDialogState(() => dateFrom = value),
                    onClear: dateFrom == null ? null : () => setDialogState(() => dateFrom = null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _dateFilterButton(
                    context: dialogContext,
                    label: l10n.filterDateTo,
                    value: dateTo,
                    locale: locale,
                    onPick: (DateTime value) => setDialogState(() => dateTo = value),
                    onClear: dateTo == null ? null : () => setDialogState(() => dateTo = null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _statusController,
                    decoration: InputDecoration(labelText: l10n.filterStatusExact),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _amountFromController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: l10n.filterAmountFrom),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _amountToController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: l10n.filterAmountTo),
                  ),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.actionCancel)),
            FilledButton(
              onPressed: () {
                final String minRaw = _amountFromController.text.trim();
                final String maxRaw = _amountToController.text.trim();
                final num? amountFrom = minRaw.isEmpty ? null : parseLocalizedWorkspaceAmount(minRaw, locale);
                final num? amountTo = maxRaw.isEmpty ? null : parseLocalizedWorkspaceAmount(maxRaw, locale);
                if ((minRaw.isNotEmpty && amountFrom == null) || (maxRaw.isNotEmpty && amountTo == null)) {
                  setDialogState(() => error = l10n.filterInvalidAmount);
                  return;
                }
                if (dateFrom != null && dateTo != null && dateFrom!.isAfter(dateTo!)) {
                  setDialogState(() => error = l10n.filterInvalidDateRange);
                  return;
                }
                if (amountFrom != null && amountTo != null && amountFrom > amountTo) {
                  setDialogState(() => error = l10n.filterInvalidAmountRange);
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _criteria.copyWith(
                    dateFrom: dateFrom,
                    clearDateFrom: dateFrom == null,
                    dateTo: dateTo,
                    clearDateTo: dateTo == null,
                    status: _statusController.text.trim(),
                    clearStatus: _statusController.text.trim().isEmpty,
                    amountFrom: amountFrom,
                    clearAmountFrom: amountFrom == null,
                    amountTo: amountTo,
                    clearAmountTo: amountTo == null,
                    page: 1,
                  ),
                );
              },
              child: Text(l10n.filterApply),
            ),
          ],
        ),
      ),
    );
    if (updated != null) {
      _apply(updated);
    }
  }

  Widget _dateFilterButton({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required String locale,
    required ValueChanged<DateTime> onPick,
    required VoidCallback? onClear,
  }) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final DateTime? selected = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (selected != null) onPick(DateTime(selected.year, selected.month, selected.day));
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(value == null ? label : '$label: ${formatDate(value, locale: locale)}'),
          ),
        ),
        IconButton(tooltip: l10n.actionReset, onPressed: onClear, icon: const Icon(Icons.close)),
      ],
    );
  }

  void _apply(TypedWorkspaceSearchCriteria next) {
    setState(() {
      _criteria = next;
      _invalidFields = <TypedWorkspaceFilterField>{};
      if (_queryController.text != next.text) _queryController.text = next.text;
      _statusController.text = next.status ?? '';
      final String locale = localeTag(Localizations.localeOf(context));
      _amountFromController.text = _formatAmount(next.amountFrom, locale: locale);
      _amountToController.text = _formatAmount(next.amountTo, locale: locale);
    });
    widget.onCriteriaChanged(next);
  }

  void _resetFilters() {
    _statusController.clear();
    _amountFromController.clear();
    _amountToController.clear();
    _queryController.clear();
    _apply(TypedWorkspaceSearchCriteria(domain: _criteria.domain));
  }

  String _formatAmount(num? value, {String? locale}) =>
      value == null ? '' : formatMoney(value, locale: locale ?? 'de_DE', symbol: '');

  String get _activeLocale => localeTag(Localizations.localeOf(context));

  String _join(List<String> parts) => parts.where((String part) => part.isNotEmpty).join(' · ');

  String _countLabel(int count, AppLocalizations l10n) {
    final String noun = switch (_criteria.domain) {
      TypedWorkspaceDomain.invoices => l10n.countInvoices,
      TypedWorkspaceDomain.receipts => l10n.countReceipts,
      TypedWorkspaceDomain.bankTransactions => l10n.countTransactions,
    };
    return '$count $noun';
  }
}
