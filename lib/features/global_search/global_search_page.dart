import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/features/global_search/global_business_search.dart';
import 'package:openaccounting/features/global_search/global_search_entity.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Search palette opened from the desktop shell.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  String _query = '';
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Size viewport = MediaQuery.sizeOf(context);
    final String query = _query.trim();
    final AsyncValue<GlobalBusinessSearchResponse> response = ref.watch(globalBusinessSearchResultsProvider(query));
    final List<GlobalSearchItem> items = response.hasValue
        ? _itemsFor(query, response.value!, l10n)
        : <GlobalSearchItem>[];

    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown && items.isNotEmpty) {
          setState(() => _selectedIndex = (_selectedIndex + 1).clamp(0, items.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp && items.isNotEmpty) {
          setState(() => _selectedIndex = (_selectedIndex - 1).clamp(0, items.length - 1));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && items.isNotEmpty) {
          _selectItem(context, items[_selectedIndex.clamp(0, items.length - 1)]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        key: const ValueKey<String>('global_search_palette'),
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: ConstrainedBox(
          key: const ValueKey<String>('global_search_palette_content'),
          constraints: BoxConstraints(maxWidth: 640, maxHeight: viewport.height - 32),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.globalSearchTitle, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  autofocus: true,
                  key: const ValueKey<String>('global_search_query'),
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: l10n.globalSearchPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                    counterText: '',
                  ),
                  onChanged: (String value) {
                    setState(() {
                      _query = value;
                      _selectedIndex = 0;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _results(context, query, response, items, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(
    BuildContext context,
    String query,
    AsyncValue<GlobalBusinessSearchResponse> response,
    List<GlobalSearchItem> items,
    AppLocalizations l10n,
  ) {
    if (query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(l10n.globalSearchEmptyPrompt),
      );
    }
    return response.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(l10n.globalSearchLoading),
      ),
      error: (Object error, StackTrace stackTrace) => _retryState(
        context,
        l10n.globalSearchPartialFailure,
        () => ref.invalidate(globalBusinessSearchResultsProvider(query)),
        l10n,
      ),
      data: (GlobalBusinessSearchResponse data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final GlobalSearchSource source
              in (data.failedSources.toList()..sort((a, b) => a.index.compareTo(b.index))))
            _retryState(
              context,
              l10n.globalSearchSourceUnavailable(_sourceLabel(source, l10n)),
              () => ref.invalidate(globalBusinessSearchResultsProvider(query)),
              l10n,
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(l10n.globalSearchNoResults),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  final GlobalSearchItem item = items[index];
                  final bool selected = index == _selectedIndex;
                  return _resultTile(context, item, index, selected, l10n);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _retryState(BuildContext context, String message, VoidCallback onRetry, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
        ],
      ),
    );
  }

  Widget _resultTile(BuildContext context, GlobalSearchItem item, int index, bool selected, AppLocalizations l10n) {
    final String type = _typeLabel(item, l10n);
    final String label = _itemLabel(item, l10n);
    return Semantics(
      button: true,
      selected: selected,
      label: <String>[type, label, item.summary].where((String value) => value.isNotEmpty).join(', '),
      child: ListTile(
        key: ValueKey<String>('global_search_result_$index'),
        selected: selected,
        leading: Icon(_iconFor(item)),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          <String>[type, item.summary].where((String value) => value.isNotEmpty).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _selectItem(context, item),
      ),
    );
  }

  List<GlobalSearchItem> _itemsFor(String query, GlobalBusinessSearchResponse response, AppLocalizations l10n) {
    final String normalized = query.toLowerCase();
    final List<GlobalSearchItem> items = <GlobalSearchItem>[...response.results];
    final GlobalSearchDestination settings = GlobalSearchDestination(
      label: l10n.globalSearchSettingsDestination,
      summary: '',
      route: '/settings',
    );
    if (_matches(normalized, <String>[settings.label, 'settings', 'einstellungen'])) items.add(settings);

    final GlobalSearchCommand newInvoice = GlobalSearchCommand(
      id: GlobalSearchCommandId.createInvoice,
      label: l10n.globalSearchNewInvoiceCommand,
      summary: '',
    );
    if (_matches(normalized, <String>[newInvoice.label, 'new invoice', 'neue rechnung'])) items.add(newInvoice);
    return items;
  }

  bool _matches(String query, List<String> candidates) =>
      candidates.any((String candidate) => candidate.toLowerCase().contains(query));

  String _typeLabel(GlobalSearchItem item, AppLocalizations l10n) => switch (item) {
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.invoice) => l10n.globalSearchInvoiceType,
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.contact) => l10n.globalSearchContactType,
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.receipt) => l10n.globalSearchReceiptType,
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.bankTransaction) => l10n.globalSearchBankTransactionType,
    GlobalSearchDestination() => l10n.globalSearchDestinationType,
    GlobalSearchCommand() => l10n.globalSearchCommandType,
  };

  String _sourceLabel(GlobalSearchSource source, AppLocalizations l10n) => switch (source) {
    GlobalSearchSource.invoices => l10n.globalSearchInvoiceType,
    GlobalSearchSource.contacts => l10n.globalSearchContactType,
    GlobalSearchSource.receipts => l10n.globalSearchReceiptType,
    GlobalSearchSource.bankTransactions => l10n.globalSearchBankTransactionType,
  };

  String _itemLabel(GlobalSearchItem item, AppLocalizations l10n) {
    if (item.label.isNotEmpty) return item.label;
    return switch (item) {
      GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.invoice, recordId: final int id) =>
        l10n.globalSearchInvoiceFallback('$id'),
      GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.receipt, recordId: final int id) =>
        l10n.globalSearchReceiptFallback('$id'),
      GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.bankTransaction, recordId: final int id) =>
        l10n.globalSearchTransactionFallback('$id'),
      _ => item.summary,
    };
  }

  IconData _iconFor(GlobalSearchItem item) => switch (item) {
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.invoice) => Icons.receipt_long,
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.contact) => Icons.person_outline,
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.receipt) => Icons.receipt_outlined,
    GlobalBusinessSearchResult(kind: GlobalSearchRecordKind.bankTransaction) => Icons.account_balance,
    GlobalSearchDestination() => Icons.settings_outlined,
    GlobalSearchCommand() => Icons.bolt_outlined,
  };

  void _selectItem(BuildContext context, GlobalSearchItem item) {
    final GoRouter router = GoRouter.of(context);
    final String route = switch (item) {
      GlobalBusinessSearchResult(:final route) => route,
      GlobalSearchDestination(:final route) => route,
      GlobalSearchCommand(id: GlobalSearchCommandId.createInvoice) => '/invoices/new',
    };
    Navigator.of(context).pop();
    router.go(route);
  }
}
