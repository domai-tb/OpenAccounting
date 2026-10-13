import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/core/router/master_data_routes.dart';
import 'package:openaccounting/features/recurring/recurring_booking_wiring.dart';

/// Canonical route inventory for the recurring workspace
/// (specs/specs/typed-route-workspaces): `/recurring` resolves through its
/// use case, aliases preserve deep links, and unknown routes stay truthful.
Future<AppDatabase> _openDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  return db;
}

void main() {
  group('Recurring booking workspace routes', () {
    test('test_every_canonical_route_has_a_useful_surface', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      const List<String> expected = <String>[
        '/',
        '/invoices',
        '/invoices/new',
        '/invoices/:id',
        '/receipts',
        '/banking',
        '/contacts',
        '/taxes',
        '/reports',
        '/assets',
        '/settings',
        '/help',
        '/setup',
        '/inventory',
        '/recurring',
      ];
      for (final String path in expected) {
        final MasterDataRouteTarget? target = matrix.ownerOf(path);
        expect(target, isNotNull, reason: '$path has no typed surface');
        expect(target!.title.isNotEmpty, isTrue, reason: '$path has no title');
        expect(
          target.primaryActionLabel != null || target.boundary != null,
          isTrue,
          reason: '$path has neither primary action nor boundary',
        );
      }
      expect(matrix.canonicalPaths, contains('/recurring'));
    });

    test('test_recurring_workspace_resolves_through_its_use_case', () async {
      expect(AppRoute.recurring.path, '/recurring');
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final MasterDataRouteTarget? target = matrix.ownerOf('/recurring');
      expect(target, isNotNull);
      expect(target!.owner, MasterDataOwner.recurring);
      expect(target.title, 'Wiederkehrend');
      expect(target.primaryActionLabel, 'Neue Vorlage');

      // The route's data seam is the workspace use case, not page SQL.
      final AppDatabase db = await _openDatabase();
      try {
        final useCases = buildTestRecurringBookingUseCases(db.executor);
        expect(await useCases.listTemplates(), isEmpty);
        final String pageSource = File('lib/features/recurring/recurring_booking_page.dart').readAsStringSync();
        expect(pageSource.contains('runInsert'), isFalse);
        expect(pageSource.contains('runUpdate'), isFalse);
        expect(pageSource.contains('runDelete'), isFalse);
        expect(pageSource.contains('runCustom'), isFalse);
      } finally {
        await db.close();
      }
    });

    test('test_database_outage_is_not_an_empty_route', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final MasterDataUnavailable outage = matrix.unavailable('/recurring');

      // The outage preserves the requested route and never looks empty.
      expect(outage.route, '/recurring');
      expect(outage.state, 'unavailable');
      expect(outage.state, isNot('empty'));
      expect(outage.route, isNot('/setup'));
      expect(matrix.truthfulBoundary('/recurring'), 'ok');
    });

    test('test_alias_matrix_preserves_deep_links', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      expect(matrix.canonicalize('/rechnungen/123?status=offen&seite=2'), '/invoices/123?status=offen&seite=2');
      expect(matrix.canonicalize('/belege/456?filter=unbezahlt'), '/receipts/456?filter=unbezahlt');
      expect(matrix.canonicalize('/wiederkehrend?seite=2'), '/recurring?seite=2');
      expect(matrix.canonicalize('/wiederkehrend'), '/recurring');
    });

    test('test_route_matrix_exposes_a_truthful_boundary', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      expect(matrix.truthfulBoundary('/recurring'), 'ok');
      expect(matrix.truthfulBoundary('/geheim'), 'unavailable');
      // The matrix never substitutes a generic table fallback.
      expect(matrix.fallbackSqlFor('/recurring'), isNull);
      expect(matrix.fallbackSqlFor('/geheim'), isNull);
    });
  });
}
