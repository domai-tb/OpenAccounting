import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/router/master_data_routes.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';

/// Typed master-data route behavior (typed-route-workspaces delta, groups 4 and 5).
void main() {
  group('Master-data route actions', () {
    test('test_settings_link_opens_a_typed_master_data_surface', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final MasterDataRouteTarget? target = matrix.ownerOf('/settings/number-ranges');
      expect(target, isNotNull);
      expect(target!.owner, MasterDataOwner.numberRanges);
      expect(target.title, isNotEmpty);
      expect(target.primaryActionLabel ?? target.boundary, isNotNull);
    });

    test('test_invalid_master_data_record_is_safely_reported', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      expect(matrix.detailState('/contacts/missing', kind: 'customer', recordFound: false), 'not-found');
      expect(matrix.detailState('/articles/missing', kind: 'item', recordFound: false), 'not-found');
      expect(matrix.detailState('/contacts/1', kind: 'customer', recordFound: true), 'populated');
      // A not-found state never leaks storage internals.
      expect(matrix.detailState('/contacts/missing', kind: 'customer', recordFound: false), isNot(contains('SELECT')));
      expect(
        matrix.detailState('/contacts/missing', kind: 'customer', recordFound: false),
        isNot(contains('StackTrace')),
      );
    });
  });

  group('Canonical route inventory', () {
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
      expect(matrix.canonicalRoutes.length, expected.length);
    });

    test('test_contact_detail_discriminator_selects_the_correct_record_type', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final ContactDetailTarget supplier = matrix.resolveContactDetail(
        '42',
        kind: 'supplier',
        listQuery: 'tab=suppliers',
      );
      expect(supplier.needsTypeSelection, isFalse);
      expect(supplier.contactKind, ContactKind.supplier);
      expect(supplier.table, 'lieferanten');

      final ContactDetailTarget customer = matrix.resolveContactDetail(
        '42',
        kind: 'customer',
        listQuery: 'tab=customers',
      );
      expect(customer.needsTypeSelection, isFalse);
      expect(customer.contactKind, ContactKind.customer);
      expect(customer.table, 'kunden');

      // Same numeric ID in both tables resolves strictly per discriminator.
      expect(supplier.table, isNot(customer.table));
      expect(supplier.listQuery, 'tab=suppliers');
      expect(customer.listQuery, 'tab=customers');
    });

    test('test_missing_or_invalid_contact_discriminator_does_not_guess', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final ContactDetailTarget missing = matrix.resolveContactDetail('42');
      expect(missing.needsTypeSelection, isTrue);
      expect(missing.contactKind, isNull);

      final ContactDetailTarget invalid = matrix.resolveContactDetail('42', kind: 'partner');
      expect(invalid.needsTypeSelection, isTrue);
      expect(invalid.contactKind, isNull);

      // The type-selection state performs no entity-table lookup.
      expect(missing.requestedId, '42');
      expect(invalid.requestedId, '42');
    });

    test('test_article_and_article_group_routes_use_their_typed_owner', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final ArticleDetailTarget group = matrix.resolveArticleDetail('42', kind: 'group');
      expect(group.needsTypeSelection, isFalse);
      expect(group.articleKind, ArticleKind.group);
      expect(group.owner, MasterDataOwner.articleGroupDetail);

      final ArticleDetailTarget item = matrix.resolveArticleDetail('42', kind: 'item');
      expect(item.needsTypeSelection, isFalse);
      expect(item.articleKind, ArticleKind.item);
      expect(item.owner, MasterDataOwner.articleDetail);

      final MasterDataRouteTarget? groups = matrix.ownerOf('/articles', view: 'groups');
      expect(groups, isNotNull);
      expect(groups!.owner, MasterDataOwner.articleGroups);

      final MasterDataRouteTarget? items = matrix.ownerOf('/articles');
      expect(items, isNotNull);
      expect(items!.owner, MasterDataOwner.articles);
    });

    test('test_database_outage_is_not_an_empty_route', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final MasterDataUnavailable outage = matrix.unavailable('/contacts/42?kind=customer&tab=customers');
      expect(outage.route, '/contacts/42?kind=customer&tab=customers');
      expect(outage.state, 'unavailable');
      expect(outage.state, isNot('empty'));
      expect(outage.state, isNot('setup'));
    });

    test('test_alias_matrix_preserves_deep_links', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      expect(matrix.canonicalize('/rechnungen/123?status=offen&seite=2'), '/invoices/123?status=offen&seite=2');
      expect(matrix.canonicalize('/belege/456?filter=unbezahlt'), '/receipts/456?filter=unbezahlt');
      expect(matrix.canonicalize('/kontakte?tab=suppliers'), '/contacts?tab=suppliers');
    });

    test('test_route_matrix_exposes_a_truthful_boundary', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      expect(matrix.truthfulBoundary('/settings/company'), 'ok');
      expect(matrix.truthfulBoundary('/contacts'), 'ok');
      expect(matrix.truthfulBoundary('/no-such-route'), 'unavailable');
      expect(matrix.fallbackSqlFor('/no-such-route'), isNull);
      expect(matrix.fallbackSqlFor('/contacts'), isNull);
    });
  });
}
