import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';

/// Widget data holder — ponytail minimal.
class WidgetData {
  const WidgetData({
    required this.id,
    required this.title,
    this.count,
    this.sum,
    this.subtitle,
    this.icon,
    this.route,
    this.raw,
  });

  final String id;
  final String title;
  final int? count;
  final String? sum;
  final String? subtitle;
  final IconData? icon;
  final String? route;
  final Object? raw;
}

/// Icon mapping per widget.
const Map<String, IconData> dashboardWidgetIcons = <String, IconData>{
  'offene_rechnungen': Icons.receipt_long,
  'zahlungseingaenge': Icons.payments,
  'lagerwarnung': Icons.warning_amber,
  'mahnung_warnung': Icons.notification_important,
  'fristen': Icons.event,
  'ustva_frist': Icons.calendar_month,
  'quick_links': Icons.link,
  'einnahmen_ausgaben': Icons.bar_chart,
  'ueberfaellige_rechnungen': Icons.error_outline,
  'offene_verbindlichkeiten': Icons.request_quote,
  'kontostand': Icons.account_balance,
  'aktivitaets_log': Icons.history,
  'lagerbestand': Icons.inventory_2,
};

/// Route mapping for clickable KPIs.
const Map<String, String> dashboardWidgetRoutes = <String, String>{
  'offene_rechnungen': '/invoices?status=offen',
  'zahlungseingaenge': '/banking',
  'lagerwarnung': '/contacts',
  'mahnung_warnung': '/invoices?status=ueberfaellig',
  'fristen': '/taxes',
  'ustva_frist': '/taxes',
  'quick_links': '/',
  'einnahmen_ausgaben': '/reports',
  'ueberfaellige_rechnungen': '/invoices?status=ueberfaellig',
  'offene_verbindlichkeiten': '/invoices?typ=eingangsrechnung',
  'kontostand': '/banking',
  'aktivitaets_log': '/reports',
  'lagerbestand': '/contacts',
};

/// Reusable dashboard card — title/icon/content, loading/error/empty, onTap.
///
/// DESIGN §11 numbers first, §10 radius 12, §6 32 padding.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.title,
    this.icon,
    this.content,
    this.subtitle,
    this.isLoading = false,
    this.error,
    this.emptyMessage,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData? icon;
  final Widget? content;
  final String? subtitle;
  final bool isLoading;
  final String? error;
  final String? emptyMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (isLoading) {
      body = const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    } else if (emptyMessage != null && content == null) {
      body = Center(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(emptyMessage!)),
      );
    } else {
      body = content ?? const SizedBox.shrink();
    }

    final card = Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[Icon(icon, size: 18), const SizedBox(width: 8)],
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Expanded(child: body),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: card);
    }
    return card;
  }
}

/// Riverpod providers — one per widget, respects visibility (hidden => no fetch).
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DashboardRepository(db.executor);
});

final dashboardConfigProvider = FutureProvider<DashboardConfig>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.loadConfig();
});

Future<WidgetData> _fetchWidgetData(DashboardRepository repo, String id) async {
  final title = dashboardWidgetTitles[id] ?? id;
  final icon = dashboardWidgetIcons[id];
  final route = dashboardWidgetRoutes[id];
  switch (id) {
    case 'offene_rechnungen':
      final m = await repo.fetchOffeneRechnungen();
      return WidgetData(
        id: id,
        title: title,
        count: m['count'] as int?,
        sum: m['sum'] as String?,
        icon: icon,
        route: route,
        raw: m,
      );
    case 'ueberfaellige_rechnungen':
      final m = await repo.fetchUeberfaelligeRechnungen();
      return WidgetData(
        id: id,
        title: title,
        count: m['count'] as int?,
        sum: m['sum'] as String?,
        icon: icon,
        route: route,
        raw: m,
      );
    case 'zahlungseingaenge':
      final list = await repo.fetchZahlungseingaenge();
      return WidgetData(id: id, title: title, count: list.length, icon: icon, route: route, raw: list);
    case 'lagerwarnung':
      final list = await repo.fetchLagerwarnung();
      return WidgetData(id: id, title: title, count: list.length, icon: icon, route: route, raw: list);
    case 'lagerbestand':
      final list = await repo.fetchLagerbestand();
      return WidgetData(id: id, title: title, count: list.length, icon: icon, route: route, raw: list);
    case 'mahnung_warnung':
      final list = await repo.fetchMahnungWarnung();
      return WidgetData(id: id, title: title, count: list.length, icon: icon, route: route, raw: list);
    case 'fristen':
      final list = await repo.fetchFristen();
      return WidgetData(id: id, title: title, count: list.length, icon: icon, route: route, raw: list);
    case 'ustva_frist':
      final m = await repo.fetchUstvaFrist();
      return WidgetData(id: id, title: title, subtitle: m['label'] as String?, icon: icon, route: route, raw: m);
    case 'quick_links':
      final cfg = await repo.loadConfig();
      return WidgetData(
        id: id,
        title: title,
        count: cfg.quickLinks.length,
        icon: icon,
        route: route,
        raw: cfg.quickLinks,
      );
    case 'einnahmen_ausgaben':
      final m = await repo.fetchEinnahmenAusgaben();
      return WidgetData(
        id: id,
        title: title,
        sum: m['einnahmen'] as String?,
        subtitle: m['ausgaben'] as String?,
        icon: icon,
        route: route,
        raw: m,
      );
    case 'offene_verbindlichkeiten':
      final m = await repo.fetchOffeneVerbindlichkeiten();
      return WidgetData(
        id: id,
        title: title,
        count: m['count'] as int?,
        sum: m['sum'] as String?,
        icon: icon,
        route: route,
        raw: m,
      );
    case 'kontostand':
      final m = await repo.fetchKontostand();
      return WidgetData(id: id, title: title, sum: m['sum'] as String?, icon: icon, route: route, raw: m);
    case 'aktivitaets_log':
      final list = await repo.fetchAktivitaetsLog();
      return WidgetData(id: id, title: title, count: list.length, icon: icon, route: route, raw: list);
    default:
      return WidgetData(id: id, title: title, icon: icon, route: route);
  }
}

/// Generic widget data provider — checks visibility, returns null if hidden (no fetch).
final dashboardWidgetDataProvider = FutureProvider.family<WidgetData?, String>((ref, id) async {
  final cfg = await ref.watch(dashboardConfigProvider.future);
  if (cfg.visibility[id] == false) return null;
  final repo = ref.watch(dashboardRepositoryProvider);
  return _fetchWidgetData(repo, id);
});
