// ignore_for_file: prefer_single_quotes
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';

/// Dashboard repository — JSON config in unternehmen.dashboard_config.
/// Ponytail ultra: raw SQL via drift executor, no codegen, minimal boilerplate.
class DashboardRepository {
  DashboardRepository(this.executor);

  final QueryExecutor executor;

  List<String> get widgetIds => dashboardWidgetIds;

  Map<String, String> get widgetTitles => dashboardWidgetTitles;

  DashboardConfig defaultConfig() => defaultDashboardConfig();

  Future<void> ensureColumn() async {
    try {
      // ponytail: minimal ALTER, rely on DB ensureOpen + UnternehmenRepository; idempotent.
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN dashboard_config TEXT');
    } catch (_) {
      // column exists — ignore
    }
  }

  Future<DashboardConfig> loadConfig() async {
    await ensureColumn();
    try {
      final rows = await executor.runSelect('SELECT dashboard_config FROM unternehmen LIMIT 1', const <Object?>[]);
      if (rows.isEmpty) return defaultConfig();
      final raw = rows.first['dashboard_config'];
      if (raw == null) return defaultConfig();
      final str = raw.toString();
      if (str.trim().isEmpty) return defaultConfig();
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map<String, Object?>) {
          return _mergeWithDefaults(DashboardConfig.fromJson(decoded));
        }
        if (decoded is Map) {
          return _mergeWithDefaults(DashboardConfig.fromJson(Map<String, Object?>.from(decoded)));
        }
        return defaultConfig();
      } catch (_) {
        return defaultConfig();
      }
    } catch (e) {
      debugPrint('dashboard loadConfig fallback: $e');
      return defaultConfig();
    }
  }

  DashboardConfig _mergeWithDefaults(DashboardConfig loaded) {
    // ponytail: ensure all 13 ids present, visibility complete, order sane.
    final Set<String> all = dashboardWidgetIds.toSet();
    final List<String> order = loaded.order.where(all.contains).toList();
    for (final id in dashboardWidgetIds) {
      if (!order.contains(id)) order.add(id);
    }
    final Map<String, bool> vis = <String, bool>{for (final id in dashboardWidgetIds) id: true};
    for (final entry in loaded.visibility.entries) {
      if (all.contains(entry.key)) vis[entry.key] = entry.value;
    }
    final List<QuickLink> links = loaded.quickLinks.isEmpty
        ? List<QuickLink>.from(defaultQuickLinks)
        : loaded.quickLinks;
    return DashboardConfig(order: order, visibility: vis, quickLinks: links);
  }

  Future<void> saveConfig(DashboardConfig config) async {
    await ensureColumn();
    final json = config.toJsonString();
    try {
      final rows = await executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const <Object?>[]);
      if (rows.isEmpty) {
        await executor.runInsert('INSERT INTO unternehmen (name, dashboard_config) VALUES (?, ?)', <Object?>[
          'Standard',
          json,
        ]);
      } else {
        final id = rows.first['id'];
        await executor.runUpdate('UPDATE unternehmen SET dashboard_config = ? WHERE id = ?', <Object?>[json, id]);
      }
    } catch (e) {
      debugPrint('dashboard saveConfig: $e');
      rethrow;
    }
  }

  Future<List<String>> visibleOrder() async {
    final cfg = await loadConfig();
    return cfg.order.where((id) => cfg.visibility[id] ?? true).toList();
  }

  /// Ponytail ultra: immediate persistence helpers — YAGNI, one-liner wrappers over load/save.
  // ignore: avoid_positional_boolean_parameters
  Future<void> toggleVisibility(String id, bool visible) async {
    final cfg = await loadConfig();
    final vis = Map<String, bool>.from(cfg.visibility)..[id] = visible;
    await saveConfig(cfg.copyWith(visibility: vis));
  }

  Future<void> updateOrder(List<String> ids) async {
    final cfg = await loadConfig();
    final all = dashboardWidgetIds.toSet();
    final order = ids.where(all.contains).toList();
    for (final d in dashboardWidgetIds) {
      if (!order.contains(d)) order.add(d);
    }
    await saveConfig(cfg.copyWith(order: order));
  }

  Future<void> reorderWidget(String id, int newIndex) async {
    final cfg = await loadConfig();
    final order = List<String>.from(cfg.order);
    final old = order.indexOf(id);
    if (old == -1) return;
    order.removeAt(old);
    // ignore: noop_primitive_operations
    final clamped = newIndex.clamp(0, order.length).toInt();
    order.insert(clamped, id);
    await saveConfig(cfg.copyWith(order: order));
  }

  Future<void> addQuickLink(QuickLink link) async {
    final cfg = await loadConfig();
    final links = List<QuickLink>.from(cfg.quickLinks)..add(link);
    await saveConfig(cfg.copyWith(quickLinks: links));
  }

  Future<void> removeQuickLink(String route) async {
    final cfg = await loadConfig();
    final links = cfg.quickLinks.where((e) => e.route != route).toList();
    await saveConfig(cfg.copyWith(quickLinks: links));
  }

  Future<void> setQuickLinks(List<QuickLink> links) async {
    final cfg = await loadConfig();
    await saveConfig(cfg.copyWith(quickLinks: List<QuickLink>.from(links)));
  }

  // --- Widget data queries (ponytail: minimal, resilient to empty tables) ---

  Future<Map<String, Object?>> fetchOffeneRechnungen() async {
    final rows = await executor.runSelect(
      "SELECT COUNT(*) as c, COALESCE(SUM(brutto_betrag),0) as s "
      "FROM rechnungen WHERE status != 'bezahlt' AND typ = 'rechnung'",
      const <Object?>[],
    );
    final c = (rows.first['c'] as num?)?.toInt() ?? 0;
    final s = money.formatBetrag('${rows.first['s']}');
    return <String, Object?>{'count': c, 'sum': s};
  }

  Future<Map<String, Object?>> fetchUeberfaelligeRechnungen() async {
    final rows = await executor.runSelect(
      "SELECT COUNT(*) as c, COALESCE(SUM(brutto_betrag),0) as s "
      "FROM rechnungen WHERE status != 'bezahlt' AND faelligkeit IS NOT NULL "
      "AND date(faelligkeit) < date('now')",
      const <Object?>[],
    );
    final c = (rows.first['c'] as num?)?.toInt() ?? 0;
    final s = money.formatBetrag('${rows.first['s']}');
    return <String, Object?>{'count': c, 'sum': s};
  }

  Future<List<Map<String, Object?>>> fetchZahlungseingaenge({int limit = 5}) async {
    return executor.runSelect(
      'SELECT id, datum, betrag, verwendungszweck FROM bank_transaktionen '
      'WHERE betrag > 0 ORDER BY datum DESC LIMIT ?',
      <Object?>[limit],
    );
  }

  Future<List<Map<String, Object?>>> fetchLagerwarnung() async {
    return executor.runSelect(
      'SELECT id, bezeichnung, bestand_aktuell, mindestbestand FROM artikel '
      'WHERE mindestbestand > 0 AND bestand_aktuell <= mindestbestand',
      const <Object?>[],
    );
  }

  Future<List<Map<String, Object?>>> fetchLagerbestand() async {
    return executor.runSelect(
      'SELECT id, bezeichnung, bestand_aktuell, mindestbestand FROM artikel WHERE aktiv = 1 LIMIT 20',
      const <Object?>[],
    );
  }

  Future<List<Map<String, Object?>>> fetchMahnungWarnung() async {
    return executor.runSelect(
      "SELECT id, rechnung_id, betrag, status FROM mahnungen WHERE status = 'offen' "
      "ORDER BY datum DESC LIMIT 10",
      const <Object?>[],
    );
  }

  Future<List<Map<String, Object?>>> fetchFristen() async {
    return executor.runSelect(
      "SELECT id, rechnungsnummer, faelligkeit, brutto_betrag FROM rechnungen "
      "WHERE faelligkeit IS NOT NULL AND date(faelligkeit) BETWEEN date('now') AND date('now','+30 days') "
      "ORDER BY faelligkeit ASC LIMIT 10",
      const <Object?>[],
    );
  }

  Future<Map<String, Object?>> fetchUstvaFrist() async {
    // ponytail: next 10th of month as VAT deadline.
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 10);
    final frist = DateTime(now.day <= 10 ? now.year : nextMonth.year, now.day <= 10 ? now.month : nextMonth.month, 10);
    return <String, Object?>{
      'frist': frist.toIso8601String().substring(0, 10),
      'label':
          'UStVA fällig am ${frist.day.toString().padLeft(2, '0')}.'
          '${frist.month.toString().padLeft(2, '0')}.${frist.year}',
    };
  }

  Future<Map<String, Object?>> fetchEinnahmenAusgaben() async {
    final rows = await executor.runSelect(
      'SELECT COALESCE(SUM(CASE WHEN betrag > 0 THEN betrag ELSE 0 END),0) as ein, '
      'COALESCE(SUM(CASE WHEN betrag < 0 THEN betrag ELSE 0 END),0) as aus FROM journal',
      const <Object?>[],
    );
    final ein = money.formatBetrag('${rows.first['ein']}');
    final aus = money.formatBetrag('${rows.first['aus']}');
    return <String, Object?>{'einnahmen': ein, 'ausgaben': aus};
  }

  Future<Map<String, Object?>> fetchOffeneVerbindlichkeiten() async {
    final rows = await executor.runSelect(
      "SELECT COUNT(*) as c, COALESCE(SUM(brutto_betrag),0) as s "
      "FROM rechnungen WHERE status != 'bezahlt' AND typ = 'eingangsrechnung'",
      const <Object?>[],
    );
    final c = (rows.first['c'] as num?)?.toInt() ?? 0;
    final s = money.formatBetrag('${rows.first['s']}');
    return <String, Object?>{'count': c, 'sum': s};
  }

  Future<Map<String, Object?>> fetchKontostand() async {
    final rows = await executor.runSelect('SELECT COALESCE(SUM(saldo),0) as s FROM konten', const <Object?>[]);
    final s = money.formatBetrag('${rows.first['s']}');
    final details = await executor.runSelect(
      'SELECT id, name, saldo FROM konten ORDER BY name LIMIT 10',
      const <Object?>[],
    );
    return <String, Object?>{'sum': s, 'konten': details};
  }

  Future<List<Map<String, Object?>>> fetchAktivitaetsLog({int limit = 10}) async {
    return executor.runSelect(
      'SELECT id, datum, beschreibung, betrag FROM journal ORDER BY datum DESC, id DESC LIMIT ?',
      <Object?>[limit],
    );
  }
}
