import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/features/mahnwesen/dunning_service.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Typed dunning workspace at the canonical `/mahnwesen` route.
///
/// Shallow business destination with page header, run-preview primary action,
/// searchable/filterable typed rows, right-aligned money values, and an
/// invoice detail inspector. Below 900 logical pixels it uses a full-width
/// list with a focused detail page instead of a side-by-side split. Loading,
/// populated, empty, failure, excluded, draft, transport-accepted, and
/// unavailable states are localized and keyboard reachable.
class MahnwesenWorkspacePage extends ConsumerStatefulWidget {
  const MahnwesenWorkspacePage({this.routeUri, super.key});

  final Uri? routeUri;

  @override
  ConsumerState<MahnwesenWorkspacePage> createState() => _MahnwesenWorkspacePageState();
}

class _MahnwesenWorkspacePageState extends ConsumerState<MahnwesenWorkspacePage> {
  late final TextEditingController _searchController;
  String _statusFilter = '';
  int? _selectedRechnungId;
  Future<_WorkspaceData>? _future;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.routeUri?.queryParameters['q'] ?? '');
    _statusFilter = widget.routeUri?.queryParameters['status'] ?? '';
  }

  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // dependOnInheritedWidget (via AppScope) is unavailable in initState.
    if (!_loadedOnce) {
      _loadedOnce = true;
      _reload();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DunningService _dunning(BuildContext context) {
    final AppScope? scope = AppScope.maybeOf(context);
    if (scope != null) return scope.services.dunning;
    return ref.read(appServicesProvider).dunning;
  }

  AppServices _services(BuildContext context) {
    final AppScope? scope = AppScope.maybeOf(context);
    if (scope != null) return scope.services;
    return ref.read(appServicesProvider);
  }

  String _today() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _reload() {
    final DunningService dunning = _dunning(context);
    final AppServices services = _services(context);
    setState(() {
      _future = _load(dunning, services);
    });
  }

  Future<_WorkspaceData> _load(DunningService dunning, AppServices services) async {
    final DunningPreview preview = await dunning.previewRun(asOf: _today());
    final List<Map<String, Object?>> exclusions = await services.dunningAusschluesse.list();
    final int grace = (await services.mahnwesenEinstellungen.get()).graceTage;
    return _WorkspaceData(preview: preview, exclusions: exclusions, graceTage: grace);
  }

  void _syncRoute() {
    if (GoRouter.maybeOf(context) == null) return;
    final Map<String, String> query = <String, String>{};
    if (_searchController.text.trim().isNotEmpty) query['q'] = _searchController.text.trim();
    if (_statusFilter.isNotEmpty) query['status'] = _statusFilter;
    final String location = Uri(path: '/mahnwesen', queryParameters: query.isEmpty ? null : query).toString();
    if (widget.routeUri.toString() != location) {
      context.go(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      maxWidth: 1180,
      header: AppPageHeader(
        title: l10n.dunningTitle,
        subtitle: l10n.dunningSubtitle,
        searchController: _searchController,
        searchHint: l10n.searchHint,
        onSearchChanged: (_) => setState(() {}),
        primaryActionLabel: l10n.dunningPreviewAction,
        onPrimaryAction: _reload,
      ),
      child: FutureBuilder<_WorkspaceData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_WorkspaceData> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Semantics(label: l10n.loading, child: const CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return _failureCard(l10n, snapshot.error);
          }
          final _WorkspaceData data = snapshot.requireData;
          return _body(context, l10n, data);
        },
      ),
    );
  }

  Widget _failureCard(AppLocalizations l10n, Object? error) {
    return AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.dunningLoadFailed, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(l10n.actionRetry)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, _WorkspaceData data) {
    final List<EligibleInvoice> rows = data.preview.eligible
        .where((EligibleInvoice row) {
          final String query = _searchController.text.trim().toLowerCase();
          final bool matchesQuery = query.isEmpty || row.rechnungsnummer.toLowerCase().contains(query);
          final bool matchesStatus = _statusFilter.isEmpty || 'stufe-${row.stufe}' == _statusFilter;
          return matchesQuery && matchesStatus;
        })
        .toList(growable: false);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < 900;
        final Widget list = _list(context, l10n, data, rows, narrow: narrow);
        if (narrow) return list;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: list),
            const SizedBox(width: AppSpacing.lg),
            SizedBox(width: 360, child: _inspector(context, l10n, data)),
          ],
        );
      },
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    _WorkspaceData data,
    List<EligibleInvoice> rows, {
    required bool narrow,
  }) {
    final List<Widget> children = <Widget>[
      _filterChips(l10n),
      if (rows.isEmpty)
        AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.mark_email_read_outlined, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.dunningEmpty, textAlign: TextAlign.center),
            ],
          ),
        )
      else
        AppCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (BuildContext context, int index) => const Divider(height: 1, indent: 72),
            itemBuilder: (BuildContext context, int index) => _row(context, l10n, rows[index], narrow: narrow),
          ),
        ),
      if (data.preview.unavailable.isNotEmpty) _unavailableCard(l10n, data),
      if (data.exclusions.isNotEmpty) _exclusionsCard(l10n, data),
      _graceCard(l10n, data),
    ];
    return ListView(
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          children[i],
          if (i < children.length - 1) const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }

  Widget _filterChips(AppLocalizations l10n) {
    final List<String> options = <String>['', 'stufe-1', 'stufe-2', 'stufe-3', 'stufe-4'];
    return Wrap(
      spacing: AppSpacing.sm,
      children: <Widget>[
        for (final String option in options)
          ChoiceChip(
            label: Text(option.isEmpty ? l10n.filterClearAll : '${l10n.dunningStageLabel} ${option.split('-').last}'),
            selected: _statusFilter == option,
            onSelected: (_) {
              setState(() => _statusFilter = option);
              _syncRoute();
            },
          ),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, EligibleInvoice row, {required bool narrow}) {
    final String locale = localeTag(Localizations.localeOf(context));
    final bool selected = _selectedRechnungId == row.rechnungId;
    void open() {
      setState(() => _selectedRechnungId = row.rechnungId);
      if (narrow) {
        unawaitedRefresh(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => _DetailPage(rechnungId: row.rechnungId, asOf: _today()),
            ),
          ),
        );
      }
    }

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${row.rechnungsnummer}, ${l10n.dunningStageLabel} ${row.stufe}, ${formatMoney(_toNum(row.outstanding), locale: locale)}',
      child: Focus(
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
            open();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (BuildContext context) {
            final bool focused = Focus.of(context).hasFocus;
            return Material(
              color: selected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : focused
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Theme.of(context).colorScheme.surface,
              child: ListTile(
                key: ValueKey<String>('dunning_row_${row.rechnungId}'),
                selected: selected,
                leading: const CircleAvatar(child: Icon(Icons.markunread_mailbox_outlined)),
                title: Text(row.rechnungsnummer, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${l10n.dunningStageLabel} ${row.stufe} · ${l10n.dunningFeeLabel} ${row.effektiveGebuehr} · '
                  '${l10n.dunningRateLabel} ${row.zinssatz} % · ${l10n.dunningInterestLabel} ${row.zinssumme}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: SizedBox(width: 132, child: MoneyText(_toNum(row.outstanding), locale: locale)),
                onTap: open,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _unavailableCard(AppLocalizations l10n, _WorkspaceData data) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.dunningUnavailable)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final DunningOpUnavailable entry in data.preview.unavailable)
            ListTile(
              dense: true,
              title: Text('${l10n.dunningNoBalance}: ${entry.rechnungId}'),
              subtitle: Text(entry.unavailable.message),
              trailing: IconButton(tooltip: l10n.actionRetry, icon: const Icon(Icons.refresh), onPressed: _reload),
            ),
        ],
      ),
    );
  }

  Widget _exclusionsCard(AppLocalizations l10n, _WorkspaceData data) {
    final AppServices services = _services(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(l10n.dunningExclusionsTitle, style: Theme.of(context).textTheme.titleMedium)),
              TextButton.icon(
                onPressed: () => _addExclusion(services),
                icon: const Icon(Icons.add),
                label: Text(l10n.dunningAddExclusion),
              ),
            ],
          ),
          for (final Map<String, Object?> row in data.exclusions)
            ListTile(
              dense: true,
              title: Text('${row['grund'] ?? ''}'),
              subtitle: Text(_exclusionTarget(row)),
              trailing: IconButton(
                tooltip: l10n.dunningRemoveExclusion,
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await services.dunningAusschluesse.removeExclusion((row['id']! as num).toInt());
                  _reload();
                },
              ),
            ),
        ],
      ),
    );
  }

  String _exclusionTarget(Map<String, Object?> row) {
    if (row['rechnung_id'] != null) return 'Rechnung ${row['rechnung_id']}';
    return 'Kunde ${row['kunde_id']}';
  }

  Future<void> _addExclusion(AppServices services) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController targetController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    bool forCustomer = false;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) => AlertDialog(
          title: Text(l10n.dunningAddExclusion),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, label: Text(l10n.documentInvoice)),
                  ButtonSegment<bool>(value: true, label: Text(l10n.routeContacts)),
                ],
                selected: <bool>{forCustomer},
                onSelectionChanged: (Set<bool> value) => setDialogState(() => forCustomer = value.single),
              ),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ID'),
              ),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(labelText: l10n.dunningExclusionReasonHint),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final int? target = int.tryParse(targetController.text.trim());
    final String reason = reasonController.text.trim();
    if (target == null || reason.isEmpty) return;
    if (forCustomer) {
      await services.dunningAusschluesse.excludeCustomer(target, reason);
    } else {
      await services.dunningAusschluesse.excludeInvoice(target, reason);
    }
    _reload();
  }

  Widget _graceCard(AppLocalizations l10n, _WorkspaceData data) {
    return AppCard(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history_outlined),
        title: Text(l10n.dunningGraceDeprecated),
        subtitle: Text('${data.graceTage}'),
      ),
    );
  }

  Widget _inspector(BuildContext context, AppLocalizations l10n, _WorkspaceData data) {
    final int? selected = _selectedRechnungId;
    final List<EligibleInvoice> matches = selected == null
        ? const <EligibleInvoice>[]
        : data.preview.eligible.where((EligibleInvoice row) => row.rechnungId == selected).toList(growable: false);
    if (matches.isEmpty) {
      return AppCard(child: Text(l10n.dunningEmpty, textAlign: TextAlign.center));
    }
    return _InspectorCard(row: matches.single, asOf: data.preview.asOf);
  }

  static num _toNum(String raw) => num.tryParse(raw) ?? 0;

  void unawaitedRefresh(Future<void> future) {
    unawaited(
      future.whenComplete(() {
        if (mounted) _reload();
      }),
    );
  }
}

class _WorkspaceData {
  const _WorkspaceData({required this.preview, required this.exclusions, required this.graceTage});

  final DunningPreview preview;
  final List<Map<String, Object?>> exclusions;
  final int graceTage;
}

/// Focused invoice detail for narrow windows: full-width page with logical
/// keyboard order and visible focus instead of a side-by-side split.
class _DetailPage extends ConsumerWidget {
  const _DetailPage({required this.rechnungId, required this.asOf});

  final int rechnungId;
  final String asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AppScope? scope = AppScope.maybeOf(context);
    final AppServices services = scope?.services ?? ref.read(appServicesProvider);
    return Scaffold(
      appBar: AppPageHeader(
        title: l10n.dunningDetailTitle('$rechnungId'),
        showFilterToolbar: false,
        leading: IconButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _InspectorCardLoader(services: services, rechnungId: rechnungId, asOf: asOf),
          ),
        ),
      ),
    );
  }
}

class _InspectorCardLoader extends StatelessWidget {
  const _InspectorCardLoader({required this.services, required this.rechnungId, required this.asOf});

  final AppServices services;
  final int rechnungId;
  final String asOf;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return FutureBuilder<DunningPreview>(
      future: services.dunning.previewRun(asOf: asOf),
      builder: (BuildContext context, AsyncSnapshot<DunningPreview> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return AppCard(child: Text(l10n.dunningLoadFailed, textAlign: TextAlign.center));
        }
        final List<EligibleInvoice> matches = snapshot.requireData.eligible
            .where((EligibleInvoice row) => row.rechnungId == rechnungId)
            .toList(growable: false);
        if (matches.isEmpty) {
          return AppCard(child: Text(l10n.dunningEmpty, textAlign: TextAlign.center));
        }
        return _InspectorCard(row: matches.single, asOf: asOf);
      },
    );
  }
}

class _InspectorCard extends ConsumerWidget {
  const _InspectorCard({required this.row, required this.asOf});

  final EligibleInvoice row;
  final String asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String locale = localeTag(Localizations.localeOf(context));
    final AppScope? scope = AppScope.maybeOf(context);
    final AppServices services = scope?.services ?? ref.read(appServicesProvider);
    return AppCard(
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(row.rechnungsnummer, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _fact(l10n.dunningOutstandingLabel, formatMoney(num.tryParse(row.outstanding) ?? 0, locale: locale)),
            _fact(l10n.dunningStageLabel, '${row.stufe}'),
            _fact(l10n.dunningFeeLabel, row.effektiveGebuehr),
            _fact(l10n.dunningRateLabel, '${row.zinssatz} %'),
            _fact(l10n.dunningInterestLabel, row.zinssumme),
            _fact(l10n.dunningDraftState, row.faelligkeit),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              autofocus: true,
              onPressed: () async {
                await services.dunning.confirmRun(rechnungIds: <int>[row.rechnungId], asOf: asOf);
              },
              icon: const Icon(Icons.preview_outlined),
              label: Text(l10n.dunningConfirmAction),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () async {
                final Mahnung letter = await services.dunning.createForInvoice(rechnungId: row.rechnungId, asOf: asOf);
                await services.mahnungen.generatePdf(letter.id);
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n.actionPreview),
            ),
            const SizedBox(height: AppSpacing.sm),
            _HistorySection(services: services, kundeId: row.kundeId),
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.services, required this.kundeId});

  final AppServices services;
  final int? kundeId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final int? id = kundeId;
    if (id == null) return const SizedBox.shrink();
    return FutureBuilder<List<Mahnung>>(
      future: services.sperrung.getHistory(id),
      builder: (BuildContext context, AsyncSnapshot<List<Mahnung>> snapshot) {
        final List<Mahnung> history = snapshot.data ?? const <Mahnung>[];
        if (history.isEmpty) {
          return Text(l10n.emptyEntries, textAlign: TextAlign.center);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.dunningHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
            for (final Mahnung entry in history)
              ListTile(
                dense: true,
                title: Text('M-${entry.id} · ${entry.betrag}'),
                subtitle: Text(entry.status == 'versendet' ? l10n.dunningTransportAccepted : l10n.dunningDraftState),
              ),
          ],
        );
      },
    );
  }
}
