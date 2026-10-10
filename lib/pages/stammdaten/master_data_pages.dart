import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_inspector.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';

/// Typed master-data workspaces per design.md: customer/supplier lists with
/// tabs, search, filters, pagination, inspector, archive/restore, and routed
/// create/update forms on the regular page canvas.

AppServices _servicesOf(BuildContext context, WidgetRef ref) {
  return AppScope.maybeOf(context)?.services ?? ref.read(appServicesProvider);
}

/// Narrow-viewport safety: full-width AppBar actions overflow at 320 px, so
/// primary actions collapse to icon-only below 560 px (dashboard pattern).
List<Widget> _primaryAction(
  BuildContext context,
  AppLocalizations l10n,
  String label,
  IconData icon,
  VoidCallback? onPressed,
) {
  if (MediaQuery.sizeOf(context).width < 560) {
    return <Widget>[IconButton(icon: Icon(icon), tooltip: label, onPressed: onPressed)];
  }
  return <Widget>[FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label))];
}

class MasterDataErrorView extends StatelessWidget {
  const MasterDataErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.workspaceUnavailable, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.workspaceUnavailableMessage, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l10n.actionRetry)),
          ],
        ),
      ),
    );
  }
}

class MasterDataEmptyView extends StatelessWidget {
  const MasterDataEmptyView({required this.icon, required this.createLabel, required this.onCreate, super.key});

  final IconData icon;
  final String createLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(appLocalizationsOf(context).emptyEntries, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: Text(createLabel)),
          ],
        ),
      ),
    );
  }
}

class MasterDataTypeSelectionView extends StatelessWidget {
  const MasterDataTypeSelectionView({
    required this.requestedId,
    required this.firstLabel,
    required this.secondLabel,
    required this.onSelectFirst,
    required this.onSelectSecond,
    this.title,
    this.message,
    super.key,
  });

  final String requestedId;
  final String firstLabel;
  final String secondLabel;
  final VoidCallback onSelectFirst;
  final VoidCallback onSelectSecond;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      header: AppPageHeader(
        title: title ?? l10n.contactTypeSelectionTitle,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => context.go('/contacts'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message ?? l10n.contactTypeSelectionMessage),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.recordIdLabel(requestedId)),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton(onPressed: onSelectFirst, child: Text(firstLabel)),
                OutlinedButton(onPressed: onSelectSecond, child: Text(secondLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmArchive(BuildContext context, {required bool isRestore}) async {
  final AppLocalizations l10n = appLocalizationsOf(context);
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(isRestore ? l10n.restoreConfirmTitle : l10n.archiveConfirmTitle),
      content: Text(isRestore ? l10n.restoreConfirmMessage : l10n.archiveConfirmMessage),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionConfirm)),
      ],
    ),
  );
  return confirmed ?? false;
}

String _contactDisplayName({String? firma, required String name, required String number}) {
  final String company = firma?.trim() ?? '';
  final String core = company.isEmpty ? name.trim() : '$company · ${name.trim()}';
  return '$number · $core';
}

@immutable
class _ContactRow {
  const _ContactRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.archived,
    required this.onArchive,
  });

  final int id;
  final String title;
  final String subtitle;
  final bool archived;
  final VoidCallback onArchive;
}

class ContactsWorkspaceView extends ConsumerStatefulWidget {
  const ContactsWorkspaceView({super.key});

  @override
  ConsumerState<ContactsWorkspaceView> createState() => _ContactsWorkspaceViewState();
}

class _ContactsWorkspaceViewState extends ConsumerState<ContactsWorkspaceView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _listFocus = FocusNode();
  final Set<int> _selected = <int>{};
  int _reloadToken = 0;
  String _search = '';
  bool _archivedOnly = false;
  int _page = 1;
  Object? _error;

  @override
  void dispose() {
    _searchController.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  bool get _isSupplierTab {
    try {
      return GoRouterState.of(context).uri.queryParameters['tab'] == 'suppliers';
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _currentQuery() {
    try {
      return Map<String, String>.from(GoRouterState.of(context).uri.queryParameters);
    } catch (_) {
      return <String, String>{};
    }
  }

  void _goWith(Map<String, String> query) {
    final String next = Uri(path: '/contacts', queryParameters: query.isEmpty ? null : query).toString();
    context.go(next);
  }

  Future<void> _bulkArchive() async {
    if (_selected.isEmpty) return;
    final AppServices services = _servicesOf(context, ref);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String saveFailed = appLocalizationsOf(context).saveFailed;
    if (!await _confirmArchive(context, isRestore: false)) return;
    try {
      if (_isSupplierTab) {
        await services.supplierWorkspace.bulkArchive(_selected);
      } else {
        await services.customerWorkspace.bulkArchive(_selected);
      }
      if (mounted) {
        setState(() {
          _selected.clear();
          _reloadToken++;
        });
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$saveFailed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool suppliers = _isSupplierTab;
    final String tab = suppliers ? 'suppliers' : 'customers';
    final String kind = suppliers ? 'supplier' : 'customer';
    final String createLabel = suppliers ? l10n.actionCreateSupplier : l10n.actionCreateCustomer;
    return AppPage(
      maxWidth: 1180,
      header: AppPageHeader(
        title: l10n.routeContacts,
        searchController: _searchController,
        searchHint: '${l10n.routeContacts} ${l10n.actionSearch.toLowerCase()}…',
        onSearchChanged: (String value) => setState(() {
          _search = value;
          _page = 1;
          _selected.clear();
        }),
        filterButtonLabel: _archivedOnly ? l10n.filterArchived : l10n.filterActive,
        onFilterPressed: () => setState(() {
          _archivedOnly = !_archivedOnly;
          _page = 1;
          _selected.clear();
        }),
        activeFilters: <String>[
          if (suppliers) l10n.contactsTabSuppliers else l10n.contactsTabCustomers,
          if (_search.trim().isNotEmpty) '${l10n.actionSearch}: ${_search.trim()}',
          if (_archivedOnly) l10n.filterArchived,
        ],
        onFilterRemoved: (String label) => setState(() {
          _searchController.clear();
          _search = '';
          _archivedOnly = false;
          _page = 1;
        }),
        removeFilterLabel: l10n.actionRemoveFilter,
        tabs: <Widget>[
          Tab(text: l10n.contactsTabCustomers),
          Tab(text: l10n.contactsTabSuppliers),
        ],
        initialTabIndex: suppliers ? 1 : 0,
        onTabChanged: (int index) {
          final Map<String, String> query = _currentQuery()..['tab'] = index == 1 ? 'suppliers' : 'customers';
          _goWith(query);
          setState(() {
            _selected.clear();
            _page = 1;
          });
        },
        actions: <Widget>[
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: l10n.actionBulkArchive,
              onPressed: _bulkArchive,
            ),
          ..._primaryAction(
            context,
            l10n,
            createLabel,
            Icons.add,
            () => context.go('/contacts/new?kind=$kind&tab=$tab'),
          ),
        ],
      ),
      child: _ContactListBody(
        key: ValueKey<String>('contacts_$tab${_archivedOnly ? '_archived' : ''}_$_reloadToken'),
        suppliers: suppliers,
        search: _search,
        archivedOnly: _archivedOnly,
        page: _page,
        selected: _selected,
        listFocus: _listFocus,
        onSelectionChanged: () => setState(() {}),
        onPageChanged: (int next) => setState(() => _page = next),
        onError: (Object error) => setState(() => _error = error),
        error: _error,
        onRetry: () => setState(() {
          _error = null;
          _reloadToken++;
        }),
        onOpen: (int id) {
          final Map<String, String> query = _currentQuery();
          final String preserved = Uri(queryParameters: query.isEmpty ? null : query).query;
          context.go(preserved.isEmpty ? '/contacts/$id?kind=$kind' : '/contacts/$id?kind=$kind&$preserved');
        },
      ),
    );
  }
}

class _ContactListBody extends ConsumerStatefulWidget {
  const _ContactListBody({
    required this.suppliers,
    required this.search,
    required this.archivedOnly,
    required this.page,
    required this.selected,
    required this.listFocus,
    required this.onSelectionChanged,
    required this.onPageChanged,
    required this.onError,
    required this.error,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  final bool suppliers;
  final String search;
  final bool archivedOnly;
  final int page;
  final Set<int> selected;
  final FocusNode listFocus;
  final VoidCallback onSelectionChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Object> onError;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<int> onOpen;

  @override
  ConsumerState<_ContactListBody> createState() => _ContactListBodyState();
}

class _ContactListBodyState extends ConsumerState<_ContactListBody> {
  int _focusedIndex = 0;
  _ContactRow? _inspected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (widget.error != null) {
      return MasterDataErrorView(onRetry: widget.onRetry);
    }
    if (widget.suppliers) {
      return _buildSupplierList(context, l10n);
    }
    return _buildCustomerList(context, l10n);
  }

  Widget _buildCustomerList(BuildContext context, AppLocalizations l10n) {
    final AppServices services = _servicesOf(context, ref);
    return FutureBuilder<CustomerPage>(
      future: services.customerWorkspace.query(
        search: widget.search,
        archivedOnly: widget.archivedOnly,
        page: widget.page,
      ),
      builder: (BuildContext context, AsyncSnapshot<CustomerPage> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError(snapshot.error!));
          return const SizedBox.shrink();
        }
        final CustomerPage page = snapshot.data!;
        if (page.items.isEmpty) {
          return MasterDataEmptyView(
            icon: Icons.people_outline,
            createLabel: l10n.actionCreateCustomer,
            onCreate: () => context.go('/contacts/new?kind=customer&tab=customers'),
          );
        }
        return _customerRows(context, l10n, services, page);
      },
    );
  }

  Widget _buildSupplierList(BuildContext context, AppLocalizations l10n) {
    final AppServices services = _servicesOf(context, ref);
    return FutureBuilder<SupplierPage>(
      future: services.supplierWorkspace.query(
        search: widget.search,
        archivedOnly: widget.archivedOnly,
        page: widget.page,
      ),
      builder: (BuildContext context, AsyncSnapshot<SupplierPage> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError(snapshot.error!));
          return const SizedBox.shrink();
        }
        final SupplierPage page = snapshot.data!;
        if (page.items.isEmpty) {
          return MasterDataEmptyView(
            icon: Icons.local_shipping_outlined,
            createLabel: l10n.actionCreateSupplier,
            onCreate: () => context.go('/contacts/new?kind=supplier&tab=suppliers'),
          );
        }
        return _supplierRows(context, l10n, services, page);
      },
    );
  }

  Widget _customerRows(BuildContext context, AppLocalizations l10n, AppServices services, CustomerPage page) {
    final List<_ContactRow> rows = <_ContactRow>[
      for (final Kunde customer in page.items)
        _ContactRow(
          id: customer.id,
          title: _contactDisplayName(firma: customer.firma, name: customer.name, number: customer.debitorNr),
          subtitle: customer.ort,
          archived: customer.isArchived,
          onArchive: () => unawaited(_archiveCustomer(context, services, customer.id)),
        ),
    ];
    return _rows(context, l10n, rows, page.totalCount);
  }

  Widget _supplierRows(BuildContext context, AppLocalizations l10n, AppServices services, SupplierPage page) {
    final List<_ContactRow> rows = <_ContactRow>[
      for (final Lieferant supplier in page.items)
        _ContactRow(
          id: supplier.id,
          title: _contactDisplayName(firma: supplier.firma, name: supplier.name, number: supplier.kreditorNr),
          subtitle: supplier.ort,
          archived: supplier.isArchived,
          onArchive: () => unawaited(_archiveSupplier(context, services, supplier.id)),
        ),
    ];
    return _rows(context, l10n, rows, page.totalCount);
  }

  /// Keyboard row navigation with an optional inspector: arrows move the
  /// focused row, Enter opens it, `inspect` shows the 360–440 px overlay.
  Widget _rows(BuildContext context, AppLocalizations l10n, List<_ContactRow> rows, int totalCount) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveFocus(rows, 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveFocus(rows, -1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (rows.isEmpty) return;
          widget.onOpen(rows[_focusedIndex.clamp(0, rows.length - 1)].id);
        },
      },
      child: Focus(
        focusNode: widget.listFocus,
        autofocus: true,
        child: Column(
          children: <Widget>[
            _rowsCard(context, l10n, rows, totalCount),
            AppInspector(
              isOpen: _inspected != null,
              onClose: () => setState(() => _inspected = null),
              title: _inspected?.title,
              child: _inspected == null
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_inspected!.subtitle),
                        if (_inspected!.archived) Text(l10n.contactArchived),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: () => widget.onOpen(_inspected!.id),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(l10n.actionOpen),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _moveFocus(List<_ContactRow> rows, int delta) {
    if (rows.isEmpty) return;
    setState(() {
      _focusedIndex = _focusedIndex.clamp(0, rows.length - 1);
      _inspected = rows[_focusedIndex];
    });
  }

  Widget _rowsCard(BuildContext context, AppLocalizations l10n, List<_ContactRow> rows, int totalCount) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$totalCount ${widget.suppliers ? l10n.countSuppliers : l10n.countCustomers}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text('$totalCount ${l10n.countResults}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          for (int index = 0; index < rows.length; index++) ...<Widget>[
            _contactTile(
              context,
              l10n,
              row: rows[index],
              focused: index == _focusedIndex,
              onInspect: () => setState(() {
                _focusedIndex = index;
                _inspected = rows[index];
              }),
            ),
            if (index < rows.length - 1) const Divider(height: 1, indent: 72),
          ],
          _pagination(context, l10n, totalCount),
        ],
      ),
    );
  }

  Widget _contactTile(
    BuildContext context,
    AppLocalizations l10n, {
    required _ContactRow row,
    required bool focused,
    required VoidCallback onInspect,
  }) {
    final bool selected = widget.selected.contains(row.id);
    final int id = row.id;
    final String title = row.title;
    final String subtitle = row.subtitle;
    final bool archived = row.archived;
    final VoidCallback onArchive = row.onArchive;
    return Semantics(
      button: true,
      selected: selected,
      focused: focused,
      label: title,
      child: InkWell(
        onTap: () => widget.onOpen(id),
        onDoubleTap: onInspect,
        autofocus: focused,
        child: Container(
          color: focused ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: selected,
                  onChanged: (bool? value) {
                    if (value == true) {
                      widget.selected.add(id);
                    } else {
                      widget.selected.remove(id);
                    }
                    widget.onSelectionChanged();
                  },
                ),
                const CircleAvatar(child: Icon(Icons.person_outline, size: 20)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      if (subtitle.isNotEmpty) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                      if (archived)
                        Text(l10n.contactArchived, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: l10n.actionOpen,
                  onSelected: (String action) {
                    switch (action) {
                      case 'inspect':
                        onInspect();
                      case 'open':
                        widget.onOpen(id);
                      case 'archive':
                        onArchive();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'inspect', child: Text(l10n.actionInspect)),
                    PopupMenuItem<String>(value: 'open', child: Text(l10n.actionEdit)),
                    PopupMenuItem<String>(value: 'archive', child: Text(l10n.actionArchive)),
                  ],
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pagination(BuildContext context, AppLocalizations l10n, int totalCount) {
    const int limit = 25;
    final int pageCount = totalCount == 0 ? 1 : ((totalCount - 1) ~/ limit) + 1;
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            tooltip: l10n.filterPreviousPage,
            onPressed: widget.page > 1 ? () => widget.onPageChanged(widget.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(l10n.filterPageCount(widget.page, pageCount)),
          IconButton(
            tooltip: l10n.filterNextPage,
            onPressed: widget.page < pageCount ? () => widget.onPageChanged(widget.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveCustomer(BuildContext context, AppServices services, int id) async {
    if (!await _confirmArchive(context, isRestore: false)) return;
    try {
      await services.customerWorkspace.archive(id);
      widget.onRetry();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).saveFailed}: $error')));
      }
    }
  }

  Future<void> _archiveSupplier(BuildContext context, AppServices services, int id) async {
    if (!await _confirmArchive(context, isRestore: false)) return;
    try {
      await services.supplierWorkspace.archive(id);
      widget.onRetry();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).saveFailed}: $error')));
      }
    }
  }
}

/// Typed contact detail: kind-discriminated lookup with not-found and
/// type-selection boundaries. List return state stays in the query string.
class ContactRecordView extends ConsumerWidget {
  const ContactRecordView({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Uri uri = GoRouterState.of(context).uri;
    final String? kind = uri.queryParameters['kind'];
    if (kind != 'customer' && kind != 'supplier') {
      return MasterDataTypeSelectionView(
        requestedId: id,
        firstLabel: l10n.actionSelectCustomer,
        secondLabel: l10n.actionSelectSupplier,
        onSelectFirst: () => context.go('${uri.path}?kind=customer'),
        onSelectSecond: () => context.go('${uri.path}?kind=supplier'),
      );
    }
    final int? recordId = int.tryParse(id);
    if (recordId == null) {
      return AppPage(
        header: AppPageHeader(title: l10n.notFound, showFilterToolbar: false),
        child: AppCard(child: Text(l10n.errorRecordNotFound(id))),
      );
    }
    if (kind == 'customer') {
      return _CustomerRecordBody(id: recordId, returnQuery: uri.query);
    }
    return _SupplierRecordBody(id: recordId, returnQuery: uri.query);
  }
}

String _backToContacts(String query) {
  if (query.isEmpty) return '/contacts';
  return '/contacts?$query';
}

class _CustomerRecordBody extends ConsumerStatefulWidget {
  const _CustomerRecordBody({required this.id, required this.returnQuery});

  final int id;
  final String returnQuery;

  @override
  ConsumerState<_CustomerRecordBody> createState() => _CustomerRecordBodyState();
}

class _CustomerRecordBodyState extends ConsumerState<_CustomerRecordBody> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _servicesOf(context, ref);
    return FutureBuilder<Kunde?>(
      key: ValueKey<String>('customer_${widget.id}_$_reloadToken'),
      future: services.contactDetail.customerById(widget.id),
      builder: (BuildContext context, AsyncSnapshot<Kunde?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppPage(
            header: AppPageHeader(title: l10n.routeContacts, showFilterToolbar: false),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AppPage(
            header: AppPageHeader(title: l10n.routeContacts, showFilterToolbar: false),
            child: MasterDataErrorView(onRetry: () => setState(() => _reloadToken++)),
          );
        }
        final Kunde? customer = snapshot.data;
        if (customer == null) {
          return AppPage(
            header: AppPageHeader(
              title: l10n.notFound,
              showFilterToolbar: false,
              leading: IconButton(
                onPressed: () => context.go(_backToContacts(widget.returnQuery)),
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.actionBack,
              ),
            ),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.errorRecordNotFound('${widget.id}')),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => context.go(_backToContacts(widget.returnQuery)),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.actionBack),
                  ),
                ],
              ),
            ),
          );
        }
        return AppPage(
          maxWidth: 860,
          header: AppPageHeader(
            title: _contactDisplayName(firma: customer.firma, name: customer.name, number: customer.debitorNr),
            showFilterToolbar: false,
            leading: IconButton(
              onPressed: () => context.go(_backToContacts(widget.returnQuery)),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.actionBack,
            ),
            actions: _primaryAction(
              context,
              l10n,
              l10n.actionEdit,
              Icons.edit_outlined,
              () => context.go('/contacts/${widget.id}/edit?kind=customer&${widget.returnQuery}'),
            ),
          ),
          child: ListView(
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _detailRow(l10n.formCompany, customer.firma ?? '—'),
                    _detailRow('Straße', '${customer.strasse} ${customer.hausnummer ?? ''}'.trim()),
                    _detailRow('PLZ / Ort', '${customer.plz} ${customer.ort}'.trim()),
                    _detailRow('Land', customer.land),
                    _detailRow('E-Mail', customer.email ?? '—'),
                    _detailRow('Telefon', customer.telefon ?? '—'),
                    _detailRow('USt-IdNr.', customer.ustIdNr ?? '—'),
                    _detailRow('Debitor-Nr.', customer.debitorNr),
                    if (customer.isArchived) _detailRow(l10n.contactArchived, customer.archivedAt ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => unawaited(_toggleArchive(context, services, customer)),
                        icon: Icon(customer.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                        label: Text(customer.isArchived ? l10n.actionRestore : l10n.actionArchive),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleArchive(BuildContext context, AppServices services, Kunde customer) async {
    if (!await _confirmArchive(context, isRestore: customer.isArchived)) return;
    try {
      if (customer.isArchived) {
        await services.customerWorkspace.restore(customer.id);
      } else {
        await services.customerWorkspace.archive(customer.id);
      }
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).saveFailed}: $error')));
      }
    }
  }
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 160,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _SupplierRecordBody extends ConsumerStatefulWidget {
  const _SupplierRecordBody({required this.id, required this.returnQuery});

  final int id;
  final String returnQuery;

  @override
  ConsumerState<_SupplierRecordBody> createState() => _SupplierRecordBodyState();
}

class _SupplierRecordBodyState extends ConsumerState<_SupplierRecordBody> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppServices services = _servicesOf(context, ref);
    return FutureBuilder<Lieferant?>(
      key: ValueKey<String>('supplier_${widget.id}_$_reloadToken'),
      future: services.contactDetail.supplierById(widget.id),
      builder: (BuildContext context, AsyncSnapshot<Lieferant?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppPage(
            header: AppPageHeader(title: l10n.routeContacts, showFilterToolbar: false),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AppPage(
            header: AppPageHeader(title: l10n.routeContacts, showFilterToolbar: false),
            child: MasterDataErrorView(onRetry: () => setState(() => _reloadToken++)),
          );
        }
        final Lieferant? supplier = snapshot.data;
        if (supplier == null) {
          return AppPage(
            header: AppPageHeader(
              title: l10n.notFound,
              showFilterToolbar: false,
              leading: IconButton(
                onPressed: () => context.go(_backToContacts(widget.returnQuery)),
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.actionBack,
              ),
            ),
            child: AppCard(child: Text(l10n.errorRecordNotFound('${widget.id}'))),
          );
        }
        return AppPage(
          maxWidth: 860,
          header: AppPageHeader(
            title: _contactDisplayName(firma: supplier.firma, name: supplier.name, number: supplier.kreditorNr),
            showFilterToolbar: false,
            leading: IconButton(
              onPressed: () => context.go(_backToContacts(widget.returnQuery)),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.actionBack,
            ),
            actions: _primaryAction(
              context,
              l10n,
              l10n.actionEdit,
              Icons.edit_outlined,
              () => context.go('/contacts/${widget.id}/edit?kind=supplier&${widget.returnQuery}'),
            ),
          ),
          child: ListView(
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _detailRow(l10n.formCompany, supplier.firma ?? '—'),
                    _detailRow('Straße', '${supplier.strasse} ${supplier.hausnummer ?? ''}'.trim()),
                    _detailRow('PLZ / Ort', '${supplier.plz} ${supplier.ort}'.trim()),
                    _detailRow('Land', supplier.land),
                    _detailRow('E-Mail', supplier.email ?? '—'),
                    _detailRow('Telefon', supplier.telefon ?? '—'),
                    _detailRow('IBAN', supplier.iban ?? '—'),
                    _detailRow('USt-IdNr.', supplier.ustIdNr ?? '—'),
                    _detailRow('Kreditor-Nr.', supplier.kreditorNr),
                    if (supplier.isArchived) _detailRow(l10n.contactArchived, supplier.archivedAt ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => unawaited(_toggleArchive(context, services, supplier)),
                        icon: Icon(supplier.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                        label: Text(supplier.isArchived ? l10n.actionRestore : l10n.actionArchive),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleArchive(BuildContext context, AppServices services, Lieferant supplier) async {
    if (!await _confirmArchive(context, isRestore: supplier.isArchived)) return;
    try {
      if (supplier.isArchived) {
        await services.supplierWorkspace.restore(supplier.id);
      } else {
        await services.supplierWorkspace.archive(supplier.id);
      }
      if (mounted) setState(() => _reloadToken++);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).saveFailed}: $error')));
      }
    }
  }
}

/// Typed contact create/update form on the regular page canvas. Entered values
/// survive validation and persistence failures; archive controls stay visually
/// separate from Save.
class ContactFormView extends ConsumerStatefulWidget {
  const ContactFormView({this.recordId, super.key});

  final String? recordId;

  @override
  ConsumerState<ContactFormView> createState() => _ContactFormViewState();
}

class _ContactFormViewState extends ConsumerState<ContactFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _street = TextEditingController();
  final TextEditingController _postalCode = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _vatId = TextEditingController();
  final TextEditingController _iban = TextEditingController();
  bool _saving = false;
  bool _loaded = false;
  String? _loadError;

  bool get _isEdit => widget.recordId != null;

  String? get _kind {
    try {
      return GoRouterState.of(context).uri.queryParameters['kind'];
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded && _isEdit && _loadError == null) {
      _loaded = true;
      unawaited(_loadRecord());
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadRecord() async {
    final int? id = int.tryParse(widget.recordId ?? '');
    final String? kind = _kind;
    if (id == null || (kind != 'customer' && kind != 'supplier')) return;
    try {
      final AppServices services = _servicesOf(context, ref);
      if (kind == 'customer') {
        final Kunde? customer = await services.contactDetail.customerById(id);
        if (!mounted) return;
        if (customer == null) {
          setState(() => _loadError = 'not-found');
          return;
        }
        _fill(
          name: customer.name,
          company: customer.firma,
          street: '${customer.strasse} ${customer.hausnummer ?? ''}'.trim(),
          postalCode: customer.plz,
          city: customer.ort,
          email: customer.email,
          phone: customer.telefon,
          vatId: customer.ustIdNr,
        );
      } else {
        final Lieferant? supplier = await services.contactDetail.supplierById(id);
        if (!mounted) return;
        if (supplier == null) {
          setState(() => _loadError = 'not-found');
          return;
        }
        _fill(
          name: supplier.name,
          company: supplier.firma,
          street: '${supplier.strasse} ${supplier.hausnummer ?? ''}'.trim(),
          postalCode: supplier.plz,
          city: supplier.ort,
          email: supplier.email,
          phone: supplier.telefon,
          vatId: supplier.ustIdNr,
          iban: supplier.iban,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = 'unavailable');
    }
  }

  void _fill({
    required String name,
    String? company,
    required String street,
    required String postalCode,
    required String city,
    String? email,
    String? phone,
    String? vatId,
    String? iban,
  }) {
    setState(() {
      _name.text = name;
      _company.text = company ?? '';
      _street.text = street;
      _postalCode.text = postalCode;
      _city.text = city;
      _email.text = email ?? '';
      _phone.text = phone ?? '';
      _vatId.text = vatId ?? '';
      _iban.text = iban ?? '';
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _street.dispose();
    _postalCode.dispose();
    _city.dispose();
    _email.dispose();
    _phone.dispose();
    _vatId.dispose();
    _iban.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    final String? kind = _kind;
    if (kind != 'customer' && kind != 'supplier') return;
    setState(() => _saving = true);
    try {
      final AppServices services = _servicesOf(context, ref);
      final int? id = int.tryParse(widget.recordId ?? '');
      if (kind == 'customer') {
        if (id != null) {
          await services.contactForm.updateCustomer(id, <String, dynamic>{
            'name': _name.text.trim(),
            'firma': _nullIfEmpty(_company.text),
            'strasse': _street.text.trim(),
            'plz': _postalCode.text.trim(),
            'ort': _city.text.trim(),
            'email': _nullIfEmpty(_email.text),
            'telefon': _nullIfEmpty(_phone.text),
            'ust_idnr': _nullIfEmpty(_vatId.text),
          });
          if (mounted) context.go('/contacts/$id?kind=customer');
        } else {
          final Kunde created = await services.contactForm.createCustomer(
            name: _name.text.trim(),
            firma: _nullIfEmpty(_company.text),
            strasse: _street.text.trim(),
            plz: _postalCode.text.trim(),
            ort: _city.text.trim(),
            email: _nullIfEmpty(_email.text),
            telefon: _nullIfEmpty(_phone.text),
            ustIdNr: _nullIfEmpty(_vatId.text),
          );
          if (mounted) context.go('/contacts/${created.id}?kind=customer');
        }
      } else {
        if (id != null) {
          await services.contactForm.updateSupplier(id, <String, dynamic>{
            'name': _name.text.trim(),
            'firma': _nullIfEmpty(_company.text),
            'strasse': _street.text.trim(),
            'plz': _postalCode.text.trim(),
            'ort': _city.text.trim(),
            'email': _nullIfEmpty(_email.text),
            'telefon': _nullIfEmpty(_phone.text),
            'ust_idnr': _nullIfEmpty(_vatId.text),
            'iban': _nullIfEmpty(_iban.text),
          });
          if (mounted) context.go('/contacts/$id?kind=supplier');
        } else {
          final Lieferant created = await services.contactForm.createSupplier(
            name: _name.text.trim(),
            firma: _nullIfEmpty(_company.text),
            strasse: _street.text.trim(),
            plz: _postalCode.text.trim(),
            ort: _city.text.trim(),
            email: _nullIfEmpty(_email.text),
            telefon: _nullIfEmpty(_phone.text),
            ustIdNr: _nullIfEmpty(_vatId.text),
            iban: _nullIfEmpty(_iban.text),
          );
          if (mounted) context.go('/contacts/${created.id}?kind=supplier');
        }
      }
    } catch (error) {
      // Input is preserved: controllers are never cleared on failure.
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).saveFailed}: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String? kind = _kind;
    if (kind != 'customer' && kind != 'supplier') {
      return MasterDataTypeSelectionView(
        requestedId: 'neu',
        title: l10n.contactTypeSelectionTitle,
        message: l10n.contactTypeSelectionMessage,
        firstLabel: l10n.actionSelectCustomer,
        secondLabel: l10n.actionSelectSupplier,
        onSelectFirst: () => context.go('/contacts/new?kind=customer'),
        onSelectSecond: () => context.go('/contacts/new?kind=supplier'),
      );
    }
    final bool supplier = kind == 'supplier';
    if (_loadError == 'not-found') {
      return AppPage(
        header: AppPageHeader(title: l10n.notFound, showFilterToolbar: false),
        child: AppCard(child: Text(l10n.errorRecordNotFound(widget.recordId ?? ''))),
      );
    }
    if (_loadError != null) {
      return AppPage(
        header: AppPageHeader(title: l10n.routeContacts, showFilterToolbar: false),
        child: MasterDataErrorView(onRetry: () => setState(() => _loadError = null)),
      );
    }
    final String title = _isEdit
        ? (supplier ? l10n.supplierEditTitle : l10n.customerEditTitle)
        : (supplier ? l10n.actionCreateSupplier : l10n.actionCreateCustomer);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: title,
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: _saving ? null : () => context.go('/contacts?tab=${supplier ? 'suppliers' : 'customers'}'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Text(l10n.formSectionBasic, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: '${l10n.formName} *'),
              validator: (String? value) => value == null || value.trim().isEmpty ? l10n.formRequiredField : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _company,
              decoration: InputDecoration(labelText: l10n.formCompany),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _street,
              decoration: InputDecoration(labelText: '${l10n.formStreet} *'),
              validator: (String? value) => value == null || value.trim().isEmpty ? l10n.formRequiredField : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _postalCode,
                    decoration: InputDecoration(labelText: '${l10n.formPostalCode} *'),
                    validator: (String? value) => value == null || value.trim().isEmpty ? l10n.formRequiredField : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _city,
                    decoration: InputDecoration(labelText: '${l10n.formCity} *'),
                    validator: (String? value) => value == null || value.trim().isEmpty ? l10n.formRequiredField : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.formSectionContact, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: l10n.formEmail),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              decoration: InputDecoration(labelText: l10n.formPhone),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(l10n.formSectionTax, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _vatId,
              decoration: InputDecoration(labelText: l10n.formVatId),
            ),
            if (supplier) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _iban,
                decoration: InputDecoration(labelText: l10n.formIban),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: _saving ? null : () => context.go('/contacts?tab=${supplier ? 'suppliers' : 'customers'}'),
                  child: Text(l10n.actionCancel),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? l10n.actionSaving : l10n.actionSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
