import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';
import 'package:openaccounting/features/dashboard/dashboard_widgets.dart';

const String _dashboardLoadError = 'Fehler beim Laden';

String _dashboardErrorMessage(String area, Object error, StackTrace stackTrace) {
  debugPrint('dashboard $area failed: $error\n$stackTrace');
  return _dashboardLoadError;
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
      appBar: AppBar(
        title: const Text('Übersicht'),
        actions: <Widget>[
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
        error: (Object e, StackTrace stackTrace) =>
            Center(child: Text(_dashboardErrorMessage('config', e, stackTrace))),
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
                    childAspectRatio: 1.6,
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
                error: (Object e, StackTrace stackTrace) =>
                    Center(child: Text(_dashboardErrorMessage('config', e, stackTrace))),
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
    return dataAsync.when(
      loading: () => DashboardCard(title: title, icon: icon, isLoading: true),
      error: (Object e, StackTrace stackTrace) =>
          DashboardCard(title: title, icon: icon, error: _dashboardErrorMessage('widget $id', e, stackTrace)),
      data: (WidgetData? data) {
        if (data == null) return const SizedBox.shrink();
        final Widget content = _buildContent(context, data);
        final String? empty = _emptyFor(data);
        return DashboardCard(
          title: data.title,
          icon: data.icon,
          content: empty == null ? content : null,
          emptyMessage: empty,
          subtitle: data.subtitle,
          onTap: route != null ? () => _navigate(context, route) : null,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetData d) {
    switch (d.id) {
      case 'offene_rechnungen':
      case 'ueberfaellige_rechnungen':
      case 'offene_verbindlichkeiten':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${d.count ?? 0} Rechnungen', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${d.sum ?? '0.00'} €'),
          ],
        );
      case 'kontostand':
        return Text('${d.sum ?? '0.00'} €', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
      case 'einnahmen_ausgaben':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[Text('Einnahmen: ${d.sum ?? '0.00'} €'), Text('Ausgaben: ${d.subtitle ?? '0.00'} €')],
        );
      case 'quick_links':
        final List<QuickLink>? links = d.raw as List<QuickLink>?;
        if (links == null || links.isEmpty) return const Text('Keine Links');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final QuickLink l in links)
              InkWell(
                onTap: () => context.go(l.route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${l.label} → ${l.route}', style: const TextStyle(color: Colors.blue)),
                ),
              ),
          ],
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
    if (d.id == 'lagerbestand' && (d.count ?? 0) == 0) return 'Kein Lagerbestand';
    if (d.id == 'mahnung_warnung' && (d.count ?? 0) == 0) return 'Keine Mahnungen';
    if (d.id == 'fristen' && (d.count ?? 0) == 0) return 'Keine Fristen';
    if (d.id == 'aktivitaets_log' && (d.count ?? 0) == 0) return 'Keine Aktivitäten';
    if (d.id == 'zahlungseingaenge' && (d.count ?? 0) == 0) return 'Keine Zahlungen';
    return null;
  }

  void _navigate(BuildContext context, String route) {
    context.go(route);
  }
}
