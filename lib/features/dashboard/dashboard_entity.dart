import 'dart:convert';

/// Ponytail ultra: Dashboard config stored JSON in unternehmen.dashboard_config.
/// 13 widget ids per spec, visibility, quickLinks.
class QuickLink {
  const QuickLink({required this.label, required this.route});

  final String label;
  final String route;

  Map<String, Object?> toJson() => <String, Object?>{'label': label, 'route': route};

  factory QuickLink.fromJson(Map<String, Object?> json) {
    return QuickLink(label: (json['label'] as String?) ?? '', route: (json['route'] as String?) ?? '');
  }
}

class DashboardConfig {
  const DashboardConfig({required this.order, required this.visibility, required this.quickLinks});

  final List<String> order;
  final Map<String, bool> visibility;
  final List<QuickLink> quickLinks;

  Map<String, Object?> toJson() => <String, Object?>{
    'order': order,
    'visibility': visibility,
    'quickLinks': quickLinks.map((e) => e.toJson()).toList(),
  };

  factory DashboardConfig.fromJson(Map<String, Object?> json) {
    final List<String> order = (json['order'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    final Map<String, bool> visibility = <String, bool>{};
    final visRaw = json['visibility'];
    if (visRaw is Map) {
      for (final entry in visRaw.entries) {
        visibility[entry.key.toString()] = entry.value == true;
      }
    }
    final List<QuickLink> links = <QuickLink>[];
    final linksRaw = json['quickLinks'];
    if (linksRaw is List) {
      for (final item in linksRaw) {
        if (item is Map<String, Object?>) {
          links.add(QuickLink.fromJson(item));
        } else if (item is Map) {
          links.add(QuickLink.fromJson(Map<String, Object?>.from(item)));
        }
      }
    }
    return DashboardConfig(order: order, visibility: visibility, quickLinks: links);
  }

  String toJsonString() => jsonEncode(toJson());

  static DashboardConfig fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) return DashboardConfig.fromJson(decoded);
    if (decoded is Map) return DashboardConfig.fromJson(Map<String, Object?>.from(decoded));
    throw const FormatException('dashboard_config not a JSON object');
  }

  DashboardConfig copyWith({List<String>? order, Map<String, bool>? visibility, List<QuickLink>? quickLinks}) {
    return DashboardConfig(
      order: order ?? this.order,
      visibility: visibility ?? this.visibility,
      quickLinks: quickLinks ?? this.quickLinks,
    );
  }
}

/// 13 widget ids per spec Requirement 13+ widgets.
const List<String> dashboardWidgetIds = <String>[
  'offene_rechnungen',
  'zahlungseingaenge',
  'lagerwarnung',
  'mahnung_warnung',
  'fristen',
  'ustva_frist',
  'quick_links',
  'einnahmen_ausgaben',
  'ueberfaellige_rechnungen',
  'offene_verbindlichkeiten',
  'kontostand',
  'aktivitaets_log',
  'lagerbestand',
];

/// Human-readable German titles per spec/DESIGN §11.
const Map<String, String> dashboardWidgetTitles = <String, String>{
  'offene_rechnungen': 'Offene Rechnungen',
  'zahlungseingaenge': 'Zahlungseingänge',
  'lagerwarnung': 'Lagerwarnung',
  'mahnung_warnung': 'Mahnung-Warnung',
  'fristen': 'Fristen',
  'ustva_frist': 'UStVA-Frist',
  'quick_links': 'Schnellzugriff',
  'einnahmen_ausgaben': 'Einnahmen/Ausgaben',
  'ueberfaellige_rechnungen': 'Überfällige Rechnungen',
  'offene_verbindlichkeiten': 'Offene Verbindlichkeiten',
  'kontostand': 'Kontostand',
  'aktivitaets_log': 'Aktivitäts-Log',
  'lagerbestand': 'Lagerbestand',
};

/// Default quick links per spec.
const List<QuickLink> defaultQuickLinks = <QuickLink>[
  QuickLink(label: 'Neue Rechnung', route: '/invoices'),
  QuickLink(label: 'Journal', route: '/reports'),
  QuickLink(label: 'Artikel', route: '/contacts'),
];

DashboardConfig defaultDashboardConfig() {
  return DashboardConfig(
    order: List<String>.from(dashboardWidgetIds),
    visibility: <String, bool>{for (final id in dashboardWidgetIds) id: true},
    quickLinks: List<QuickLink>.from(defaultQuickLinks),
  );
}
