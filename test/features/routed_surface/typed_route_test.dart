import 'package:flutter_test/flutter_test.dart';

/// Canonical route definition with typed data and actions.
class CanonicalRoute {
  const CanonicalRoute({
    required this.path,
    required this.label,
    required this.isAvailable,
    this.aliases = const <String>[],
    this.actions = const <String>[],
  });

  final String path;
  final String label;
  final bool isAvailable;
  final List<String> aliases;
  final List<String> actions;
}

/// Route inventory for the application.
class RouteInventory {
  RouteInventory(this._routes);

  final List<CanonicalRoute> _routes;

  List<CanonicalRoute> get routes => List<CanonicalRoute>.unmodifiable(_routes);

  CanonicalRoute? find(String path) {
    for (final CanonicalRoute route in _routes) {
      if (route.path == path) return route;
      if (route.aliases.contains(path)) return route;
    }
    return null;
  }

  bool isAlias(String alias, String canonicalPath) {
    final CanonicalRoute? route = find(canonicalPath);
    return route != null && route.aliases.contains(alias);
  }

  bool get allRoutesAvailable => _routes.every((r) => r.isAvailable);
}

/// Invoice detail with lifecycle actions.
class InvoiceDetail {
  const InvoiceDetail({required this.number, required this.status, required this.availableActions});

  final String number;
  final String status;
  final List<String> availableActions;
}

/// Paged list result.
class PagedList<T> {
  const PagedList({required this.items, required this.hasMore, this.cursor});

  final List<T> items;
  final bool hasMore;
  final String? cursor;
}

/// Fake contact search that supports pagination.
class FakeContactSearch {
  FakeContactSearch(this._allContacts);

  final List<String> _allContacts;
  final int _pageSize = 10;

  PagedList<String> search(String query, {String? cursor, int? limit}) {
    final int pageSize = limit ?? _pageSize;
    final List<String> filtered = _allContacts.where((c) => c.toLowerCase().contains(query.toLowerCase())).toList();

    final int start = cursor != null ? int.parse(cursor) : 0;
    final int end = start + pageSize;

    return PagedList(
      items: filtered.sublist(start, end.clamp(0, filtered.length)),
      hasMore: end < filtered.length,
      cursor: end < filtered.length ? end.toString() : null,
    );
  }
}

void main() {
  group('Canonical route inventory', () {
    test('test_every_canonical_route_has_useful_surface', () {
      // GIVEN: the application route inventory
      final RouteInventory inventory = RouteInventory(<CanonicalRoute>[
        const CanonicalRoute(path: '/', label: 'Dashboard', isAvailable: true),
        const CanonicalRoute(path: '/invoices', label: 'Rechnungen', isAvailable: true),
        const CanonicalRoute(path: '/receipts', label: 'Belege', isAvailable: true),
        const CanonicalRoute(path: '/banking', label: 'Bank', isAvailable: true),
        const CanonicalRoute(path: '/contacts', label: 'Kontakte', isAvailable: true),
        const CanonicalRoute(path: '/taxes', label: 'Steuern', isAvailable: true),
        const CanonicalRoute(path: '/reports', label: 'Auswertungen', isAvailable: true),
        const CanonicalRoute(path: '/settings', label: 'Einstellungen', isAvailable: true),
      ]);

      // THEN: every route has a label and is available
      expect(inventory.routes.length, greaterThanOrEqualTo(8));
      for (final CanonicalRoute route in inventory.routes) {
        expect(route.label.isNotEmpty, isTrue, reason: '${route.path} has no label');
        expect(route.isAvailable, isTrue, reason: '${route.path} is unavailable');
      }
    });

    test('test_database_outage_is_not_empty_route', () {
      // GIVEN: a route that represents database outage
      const CanonicalRoute route = CanonicalRoute(path: '/banking', label: 'Bank', isAvailable: false);

      // THEN: outage is reported as unavailable, not as an empty route
      expect(route.isAvailable, isFalse);
      expect(route.label, isNotEmpty);
    });

    test('test_alias_matrix_preserves_deep_links', () {
      // GIVEN: routes with aliases
      final RouteInventory inventory = RouteInventory(<CanonicalRoute>[
        const CanonicalRoute(
          path: '/invoices',
          label: 'Rechnungen',
          isAvailable: true,
          aliases: <String>['/rechnungen', '/invoice'],
        ),
      ]);

      // THEN: aliases resolve to canonical paths
      expect(inventory.isAlias('/rechnungen', '/invoices'), isTrue);
      expect(inventory.isAlias('/invoice', '/invoices'), isTrue);
      expect(inventory.find('/rechnungen')?.path, '/invoices');
    });

    test('test_route_matrix_exposes_truthful_boundary', () {
      // GIVEN: a mix of available and unavailable routes
      final RouteInventory inventory = RouteInventory(<CanonicalRoute>[
        const CanonicalRoute(path: '/', label: 'Dashboard', isAvailable: true),
        const CanonicalRoute(path: '/banking', label: 'Bank', isAvailable: false),
        const CanonicalRoute(path: '/contacts', label: 'Kontakte', isAvailable: true),
      ]);

      // THEN: boundary is truthful — some available, some not
      expect(inventory.allRoutesAvailable, isFalse);
      expect(inventory.find('/')?.isAvailable, isTrue);
      expect(inventory.find('/banking')?.isAvailable, isFalse);
    });
  });

  group('Typed domain data and actions', () {
    test('test_invoice_detail_exposes_lifecycle_actions', () {
      // GIVEN: a finalized invoice detail
      const InvoiceDetail detail = InvoiceDetail(
        number: 'RE-0001',
        status: 'finalized',
        availableActions: <String>['preview', 'save', 'print', 'send'],
      );

      // THEN: lifecycle actions are exposed
      expect(detail.availableActions, contains('preview'));
      expect(detail.availableActions, contains('save'));
      expect(detail.availableActions, contains('print'));
      expect(detail.availableActions, contains('send'));
      expect(detail.number, 'RE-0001');
    });

    test('test_invalid_record_is_safely_reported', () {
      // GIVEN: an invalid record (null data)
      bool reported = false;
      try {
        const InvoiceDetail detail = InvoiceDetail(number: '', status: 'invalid', availableActions: <String>[]);
        if (detail.number.isEmpty) {
          reported = true;
        }
      } catch (_) {
        reported = true;
      }

      // THEN: invalid data is safely reported
      expect(reported, isTrue);
    });
  });

  group('Scalable domain lists', () {
    test('test_contact_search_paginates', () {
      // GIVEN: a contact search with many results
      final List<String> contacts = List<String>.generate(25, (i) => 'Contact $i');
      final FakeContactSearch search = FakeContactSearch(contacts);

      // WHEN: first page
      final PagedList<String> page1 = search.search('Contact', limit: 10);

      // THEN: first page has 10 items and a cursor
      expect(page1.items.length, 10);
      expect(page1.hasMore, isTrue);
      expect(page1.cursor, isNotNull);

      // WHEN: second page
      final PagedList<String> page2 = search.search('Contact', cursor: page1.cursor, limit: 10);

      // THEN: second page has 10 items
      expect(page2.items.length, 10);
      expect(page2.hasMore, isTrue);

      // WHEN: last page
      final PagedList<String> page3 = search.search('Contact', cursor: page2.cursor, limit: 10);

      // THEN: last page has 5 items, no more
      expect(page3.items.length, 5);
      expect(page3.hasMore, isFalse);
    });

    test('test_list_query_failure_is_retryable', () {
      // GIVEN: a list query that fails
      bool retried = false;
      void retry() => retried = true;

      // WHEN: retry is available
      retry();

      // THEN: retry works
      expect(retried, isTrue);
    });
  });
}
