import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';
import 'package:openaccounting/features/dashboard/dashboard_widgets.dart';

String _dashboardLoadError(BuildContext context) =>
    AppLocalizations.of(context)?.backendUnreachable ??
    'Fehler beim Laden'; // ponytail: 1 key reused, add dashboard.* keys when full i18n needed

String _dashboardErrorMessage(BuildContext context, String area, Object error, StackTrace stackTrace) {
  debugPrint('dashboard $area failed: $error\n$stackTrace');
  return _dashboardLoadError(context);
}

/// Dashboard page — scrollable grid 2-4 columns responsive via LayoutBuilder.
/// DESIGN §6 32px padding, §11 Dashboard numbers first, §10 radius 12.
class DashboardPageImpl extends ConsumerWidget {
  const DashboardPageImpl({super.key});

  int _columnsForWidth(double w) {
    if (w >= 1600) return 4;
    if (w >= 1200) return 3;
    if (w >= 900) return 2;
    if (w < 700) return 1;
    return 2;
  }

  void _showConfig(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _DashboardConfigSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfgAsync = ref.watch(dashboardConfigProvider);
    return Scaffold(
      appBar: AppPageHeader(
        title:
            AppLocalizations.of(context)?.sidebarOverview ??
            'Übersicht', // ponytail: reuses sidebarOverview, add dedicated dashboardTitle when needed
        showFilterToolbar: false,
        actions: <Widget>[
          FilledButton.icon(
            onPressed: () => context.go('/invoices/new'),
            icon: const Icon(Icons.add),
            label: const Text('Neue Rechnung'),
          ),
          IconButton(icon: const Icon(Icons.tune), tooltip: 'Anpassen', onPressed: () => _showConfig(context)),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () => ref.invalidate(dashboardConfigProvider),
          ),
        ],
      ),
      body: cfgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace stackTrace) => _DashboardErrorState(
          message: _dashboardErrorMessage(context, 'config', e, stackTrace),
          onRetry: () => ref.invalidate(dashboardConfigProvider),
        ),
        data: (DashboardConfig cfg) {
          final List<String> visible = cfg.order.where((String id) => cfg.visibility[id] ?? true).toList();
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int cols = _columnsForWidth(c.maxWidth);
              return Padding(
                padding: const EdgeInsets.all(32),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.9,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (BuildContext context, int i) {
                    final String id = visible[i];
                    return _WidgetCard(id: id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Minimal config sheet — SwitchListTile per widget + ReorderableListView.
/// ponytail: immediate save via repo.* + ref.invalidate ensures hidden not fetch.
class _DashboardConfigSheet extends ConsumerWidget {
  const _DashboardConfigSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DashboardConfig> cfgAsync = ref.watch(dashboardConfigProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('Dashboard anpassen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: cfgAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace stackTrace) => _DashboardErrorState(
                  message: _dashboardErrorMessage(context, 'config', e, stackTrace),
                  onRetry: () => ref.invalidate(dashboardConfigProvider),
                ),
                data: (DashboardConfig cfg) {
                  final List<String> order = cfg.order;
                  return ReorderableListView.builder(
                    itemCount: order.length,
                    // ignore: deprecated_member_use
                    onReorder: (int oldIndex, int newIndex) {
                      var target = newIndex;
                      if (target > oldIndex) target -= 1;
                      final String id = order[oldIndex];
                      final DashboardRepository repo = ref.read(dashboardRepositoryProvider);
                      unawaited(repo.reorderWidget(id, target).then((_) => ref.invalidate(dashboardConfigProvider)));
                    },
                    itemBuilder: (BuildContext context, int index) {
                      final String id = order[index];
                      final String title = dashboardWidgetTitles[id] ?? id;
                      final bool visible = cfg.visibility[id] ?? true;
                      return SwitchListTile(
                        key: ValueKey<String>(id),
                        title: Text(title),
                        subtitle: Text(id),
                        value: visible,
                        secondary: const Icon(Icons.drag_handle),
                        onChanged: (bool value) {
                          final DashboardRepository repo = ref.read(dashboardRepositoryProvider);
                          unawaited(
                            repo.toggleVisibility(id, value).then((_) => ref.invalidate(dashboardConfigProvider)),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetCard extends ConsumerWidget {
  const _WidgetCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WidgetData?> dataAsync = ref.watch(dashboardWidgetDataProvider(id));
    final String title = dashboardWidgetTitles[id] ?? id;
    final IconData? icon = dashboardWidgetIcons[id];
    final String? route = dashboardWidgetRoutes[id];
    final bool inventoryUnavailable = id == 'lagerwarnung' || id == 'lagerbestand';
    final bool privacyMode = ref.watch(privacyModeProvider);
    return dataAsync.when(
      loading: () => DashboardCard(title: title, icon: icon, isLoading: true),
      error: (Object e, StackTrace stackTrace) => DashboardCard(
        title: title,
        icon: icon,
        error: _dashboardErrorMessage(context, 'widget $id', e, stackTrace),
        onRetry: () => ref.invalidate(dashboardWidgetDataProvider(id)),
      ),
      data: (WidgetData? data) {
        if (data == null) return const SizedBox.shrink();
        final Widget content = _buildContent(context, data, privacyMode);
        final String? empty = _emptyFor(data);
        return DashboardCard(
          title: data.title,
          icon: data.icon,
          content: inventoryUnavailable ? null : (empty == null ? content : null),
          emptyMessage: inventoryUnavailable ? 'Noch nicht verfügbar' : empty,
          subtitle: inventoryUnavailable ? 'Noch nicht verfügbar' : data.subtitle,
          onTap: !inventoryUnavailable && route != null && route != '/' ? () => _navigate(context, route) : null,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetData d, bool privacyMode) {
    switch (d.id) {
      case 'offene_rechnungen':
      case 'ueberfaellige_rechnungen':
      case 'offene_verbindlichkeiten':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${d.count ?? 0} Rechnungen', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            MoneyText(_parseDashboardMoney(d.sum), textAlign: TextAlign.left, obscured: privacyMode),
          ],
        );
      case 'kontostand':
        return MoneyText(
          _parseDashboardMoney(d.sum),
          textAlign: TextAlign.left,
          obscured: privacyMode,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
      case 'einnahmen_ausgaben':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _DashboardMoneyLine(label: 'Einnahmen', amount: _parseDashboardMoney(d.sum), obscured: privacyMode),
            _DashboardMoneyLine(label: 'Ausgaben', amount: _parseDashboardMoney(d.subtitle), obscured: privacyMode),
          ],
        );
      case 'quick_links':
        final List<QuickLink>? links = d.raw as List<QuickLink>?;
        if (links == null || links.isEmpty) return const Text('Keine Links');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[for (final QuickLink l in links) _QuickLinkRow(link: l)],
        );
      case 'ustva_frist':
        return Text(d.subtitle ?? '');
      default:
        final List<dynamic>? list = d.raw as List?;
        if (list == null || list.isEmpty) return const SizedBox.shrink();
        return Text('${d.count} Einträge');
    }
  }

  String? _emptyFor(WidgetData d) {
    if (d.id == 'lagerwarnung' && (d.count ?? 0) == 0) return 'Keine Warnungen';
    if (d.id == 'lagerbestand' && (d.count ?? 0) == 0) {
      return 'Kein Lagerbestand';
    }
    if (d.id == 'mahnung_warnung' && (d.count ?? 0) == 0) {
      return 'Keine Mahnungen';
    }
    if (d.id == 'fristen' && (d.count ?? 0) == 0) return 'Keine Fristen';
    if (d.id == 'aktivitaets_log' && (d.count ?? 0) == 0) {
      return 'Keine Aktivitäten';
    }
    if (d.id == 'zahlungseingaenge' && (d.count ?? 0) == 0) {
      return 'Keine Zahlungen';
    }
    return null;
  }

  void _navigate(BuildContext context, String route) {
    context.go(route);
  }
}

class _QuickLinkRow extends StatelessWidget {
  const _QuickLinkRow({required this.link});

  final QuickLink link;

  @override
  Widget build(BuildContext context) {
    final bool unavailable = link.route == '/inventory';
    final Color color = unavailable
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.primary;
    final String label = unavailable ? '${link.label} (nicht verfügbar)' : link.label;
    return Semantics(
      button: !unavailable,
      label: label,
      child: InkWell(
        onTap: unavailable || link.route.isEmpty ? null : () => context.go(link.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(label, style: TextStyle(color: color)),
              ),
              const SizedBox(width: 4),
              Icon(unavailable ? Icons.lock_outline : Icons.arrow_forward, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

num _parseDashboardMoney(String? raw) {
  final String value = raw?.trim().replaceAll('€', '').replaceAll('\u00A0', '').trim() ?? '';
  if (value.isEmpty) {
    return 0;
  }
  if (value.contains(',') && value.contains('.')) {
    return num.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }
  return num.tryParse(value.replaceAll(',', '.')) ?? 0;
}

class _DashboardMoneyLine extends StatelessWidget {
  const _DashboardMoneyLine({required this.label, required this.amount, required this.obscured});

  final String label;
  final num amount;
  final bool obscured;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text('$label:')),
        MoneyText(amount, obscured: obscured),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}
