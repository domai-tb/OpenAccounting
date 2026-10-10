import 'package:flutter/foundation.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';

/// Typed master-data route matrix per design.md.
/// Every canonical route has an owning typed service, a title, and either a
/// primary action or an explicit read-only/unavailable boundary. No route
/// falls back to a generic `SELECT *` reader.

enum MasterDataOwner {
  dashboard,
  invoices,
  invoiceDetail,
  receipts,
  banking,
  customers,
  suppliers,
  contactForm,
  contactDetail,
  articles,
  articleGroups,
  articleForm,
  articleGroupForm,
  articleDetail,
  articleGroupDetail,
  taxes,
  reports,
  settings,
  company,
  categories,
  accounts,
  taxRates,
  numberRanges,
  help,
  setup,
  inventory,
}

@immutable
class MasterDataRouteTarget {
  const MasterDataRouteTarget({required this.owner, required this.title, this.primaryActionLabel, this.boundary});

  final MasterDataOwner owner;
  final String title;
  final String? primaryActionLabel;
  final String? boundary;
}

@immutable
class ContactDetailTarget {
  const ContactDetailTarget({
    required this.requestedId,
    required this.listQuery,
    this.contactKind,
    this.needsTypeSelection = false,
  });

  final String requestedId;
  final String listQuery;
  final ContactKind? contactKind;
  final bool needsTypeSelection;

  /// Exactly one entity table per discriminator; null when selection is pending.
  String? get table => switch (contactKind) {
    ContactKind.customer => 'kunden',
    ContactKind.supplier => 'lieferanten',
    null => null,
  };

  MasterDataOwner? get owner => switch (contactKind) {
    ContactKind.customer || ContactKind.supplier => MasterDataOwner.contactDetail,
    null => null,
  };
}

@immutable
class ArticleDetailTarget {
  const ArticleDetailTarget({required this.requestedId, this.articleKind, this.needsTypeSelection = false});

  final String requestedId;
  final ArticleKind? articleKind;
  final bool needsTypeSelection;

  MasterDataOwner? get owner => switch (articleKind) {
    ArticleKind.item => MasterDataOwner.articleDetail,
    ArticleKind.group => MasterDataOwner.articleGroupDetail,
    null => null,
  };
}

@immutable
class MasterDataUnavailable {
  const MasterDataUnavailable({required this.route, required this.state});

  final String route;
  final String state;
}

class MasterDataRouteMatrix {
  const MasterDataRouteMatrix();

  static const List<MasterDataRouteTarget> _inventory = <MasterDataRouteTarget>[
    MasterDataRouteTarget(owner: MasterDataOwner.dashboard, title: 'Übersicht', primaryActionLabel: 'Neue Rechnung'),
    MasterDataRouteTarget(owner: MasterDataOwner.invoices, title: 'Rechnungen', primaryActionLabel: 'Neue Rechnung'),
    MasterDataRouteTarget(
      owner: MasterDataOwner.invoices,
      title: 'Neue Rechnung',
      primaryActionLabel: 'Entwurf speichern',
    ),
    MasterDataRouteTarget(owner: MasterDataOwner.invoiceDetail, title: 'Rechnung', primaryActionLabel: 'Ansehen'),
    MasterDataRouteTarget(owner: MasterDataOwner.receipts, title: 'Belege', primaryActionLabel: 'Beleg erfassen'),
    MasterDataRouteTarget(owner: MasterDataOwner.banking, title: 'Banking', primaryActionLabel: 'Import starten'),
    MasterDataRouteTarget(owner: MasterDataOwner.customers, title: 'Kunden', primaryActionLabel: 'Kunde anlegen'),
    MasterDataRouteTarget(
      owner: MasterDataOwner.contactForm,
      title: 'Kontakt anlegen',
      primaryActionLabel: 'Kontakt speichern',
    ),
    MasterDataRouteTarget(owner: MasterDataOwner.contactDetail, title: 'Kontakt', primaryActionLabel: 'Bearbeiten'),
    MasterDataRouteTarget(owner: MasterDataOwner.articles, title: 'Artikel', primaryActionLabel: 'Artikel anlegen'),
    MasterDataRouteTarget(
      owner: MasterDataOwner.articleForm,
      title: 'Artikel anlegen',
      primaryActionLabel: 'Artikel speichern',
    ),
    MasterDataRouteTarget(owner: MasterDataOwner.articleDetail, title: 'Artikel', primaryActionLabel: 'Bearbeiten'),
    MasterDataRouteTarget(owner: MasterDataOwner.taxes, title: 'Steuern', boundary: 'read-only'),
    MasterDataRouteTarget(owner: MasterDataOwner.reports, title: 'Auswertungen', boundary: 'read-only'),
    MasterDataRouteTarget(owner: MasterDataOwner.settings, title: 'Einstellungen', boundary: 'read-only'),
    MasterDataRouteTarget(
      owner: MasterDataOwner.company,
      title: 'Firmendaten',
      primaryActionLabel: 'Firmendaten speichern',
    ),
    MasterDataRouteTarget(
      owner: MasterDataOwner.categories,
      title: 'Kategorien',
      primaryActionLabel: 'Kategorie anlegen',
    ),
    MasterDataRouteTarget(owner: MasterDataOwner.accounts, title: 'Bankkonten', primaryActionLabel: 'Konto anlegen'),
    MasterDataRouteTarget(owner: MasterDataOwner.taxRates, title: 'Steuersätze', primaryActionLabel: 'Satz anlegen'),
    MasterDataRouteTarget(
      owner: MasterDataOwner.numberRanges,
      title: 'Nummernkreise',
      primaryActionLabel: 'Nummernkreis anlegen',
    ),
    MasterDataRouteTarget(owner: MasterDataOwner.help, title: 'Hilfe', boundary: 'read-only'),
    MasterDataRouteTarget(owner: MasterDataOwner.setup, title: 'Einrichtung', primaryActionLabel: 'Profil anlegen'),
    MasterDataRouteTarget(owner: MasterDataOwner.inventory, title: 'Lager', boundary: 'unavailable'),
  ];

  static const List<String> _paths = <String>[
    '/',
    '/invoices',
    '/invoices/new',
    '/invoices/:id',
    '/receipts',
    '/banking',
    '/contacts',
    '/contacts/new',
    '/contacts/:id',
    '/articles',
    '/articles/new',
    '/articles/:id',
    '/taxes',
    '/reports',
    '/settings',
    '/settings/company',
    '/settings/categories',
    '/settings/accounts',
    '/settings/tax-rates',
    '/settings/number-ranges',
    '/help',
    '/setup',
    '/inventory',
  ];

  List<MasterDataRouteTarget> get canonicalRoutes => List<MasterDataRouteTarget>.unmodifiable(_inventory);

  List<String> get canonicalPaths => List<String>.unmodifiable(_paths);

  /// Resolves a canonical path to its typed surface. `/articles` exposes the
  /// group workspace through `view=groups`.
  MasterDataRouteTarget? ownerOf(String path, {String? view}) {
    if (path == '/articles' && view == 'groups') {
      return const MasterDataRouteTarget(
        owner: MasterDataOwner.articleGroups,
        title: 'Warengruppen',
        primaryActionLabel: 'Gruppe anlegen',
      );
    }
    final int index = _paths.indexOf(path);
    if (index < 0) return null;
    return _inventory[index];
  }

  /// Contact detail discriminator: same numeric IDs in both tables resolve
  /// strictly per kind; missing/invalid kind selects a type without querying.
  ContactDetailTarget resolveContactDetail(String id, {String? kind, String listQuery = ''}) {
    return switch (kind) {
      'customer' => ContactDetailTarget(requestedId: id, listQuery: listQuery, contactKind: ContactKind.customer),
      'supplier' => ContactDetailTarget(requestedId: id, listQuery: listQuery, contactKind: ContactKind.supplier),
      _ => ContactDetailTarget(requestedId: id, listQuery: listQuery, needsTypeSelection: true),
    };
  }

  ArticleDetailTarget resolveArticleDetail(String id, {String? kind}) {
    return switch (kind) {
      'item' => const ArticleDetailTarget(requestedId: '', articleKind: ArticleKind.item),
      'group' => const ArticleDetailTarget(requestedId: '', articleKind: ArticleKind.group),
      _ => const ArticleDetailTarget(requestedId: '', needsTypeSelection: true),
    }.copyWithId(id);
  }

  /// Localized detail boundary for a typed lookup result. Never exposes SQL.
  String detailState(String path, {String? kind, required bool recordFound}) {
    if (path.startsWith('/contacts')) {
      final ContactDetailTarget target = resolveContactDetail(path, kind: kind);
      if (target.needsTypeSelection) return 'type-selection';
      return recordFound ? 'populated' : 'not-found';
    }
    if (path.startsWith('/articles')) {
      final ArticleDetailTarget target = resolveArticleDetail(path, kind: kind);
      if (target.needsTypeSelection) return 'type-selection';
      return recordFound ? 'populated' : 'not-found';
    }
    return recordFound ? 'populated' : 'not-found';
  }

  /// Canonicalizes a German alias while preserving IDs and the full query.
  String canonicalize(String location) {
    final Uri uri = Uri.parse(location);
    final String canonical = switch (uri.path) {
      '/rechnungen' => '/invoices',
      '/belege' => '/receipts',
      '/bank' => '/banking',
      '/kontakte' => '/contacts',
      '/steuern' => '/taxes',
      '/auswertungen' => '/reports',
      '/einrichtung' => '/setup',
      _ when uri.path.startsWith('/rechnungen/') => uri.path.replaceFirst('/rechnungen/', '/invoices/'),
      _ when uri.path.startsWith('/belege/') => uri.path.replaceFirst('/belege/', '/receipts/'),
      _ => uri.path,
    };
    if (uri.query.isEmpty) return canonical;
    return '$canonical?${uri.query}';
  }

  /// Database outage boundary: preserves the requested route, never setup.
  MasterDataUnavailable unavailable(String route) => MasterDataUnavailable(route: route, state: 'unavailable');

  /// Truthful boundary for any path: registered routes are usable, unknown
  /// routes are unavailable. Never a generic table fallback.
  String truthfulBoundary(String path) {
    final String bare = path.split('?').first;
    if (_paths.contains(bare)) return 'ok';
    if (bare == '/articles' || bare.startsWith('/articles/')) return 'ok';
    return 'unavailable';
  }

  /// The matrix never substitutes raw column listings: always null.
  String? fallbackSqlFor(String path) => null;
}

extension on ArticleDetailTarget {
  ArticleDetailTarget copyWithId(String id) {
    return ArticleDetailTarget(requestedId: id, articleKind: articleKind, needsTypeSelection: needsTypeSelection);
  }
}
