import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/router/master_data_routes.dart';

/// Canonical route inventory with the asset register (delta spec, group 6).
void main() {
  group('Fixed asset register workspace — routes', () {
    test('test_every_canonical_route_has_a_useful_surface', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final MasterDataRouteTarget? target = matrix.ownerOf('/assets');

      expect(target, isNotNull);
      expect(target!.owner, MasterDataOwner.assets);
      expect(target.title, 'Anlagen');
      expect(target.primaryActionLabel, 'Anlage hinzufügen');
      expect(matrix.canonicalPaths, contains('/assets'));
    });

    test('test_database_outage_is_not_an_empty_route', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      final MasterDataUnavailable outage = matrix.unavailable('/assets?jahr=2025&status=aktiv');

      expect(outage.route, '/assets?jahr=2025&status=aktiv');
      expect(outage.state, 'unavailable');
      expect(outage.state, isNot('empty'));
      expect(outage.state, isNot('setup'));
    });

    test('test_alias_matrix_preserves_deep_links', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();

      expect(matrix.canonicalize('/anlagen?jahr=2025&status=aktiv'), '/assets?jahr=2025&status=aktiv');
      expect(matrix.canonicalize('/anlagen'), '/assets');
      expect(matrix.canonicalize('/rechnungen/123?status=offen&seite=2'), '/invoices/123?status=offen&seite=2');
      expect(matrix.canonicalize('/belege/456?filter=unbezahlt'), '/receipts/456?filter=unbezahlt');
    });

    test('test_route_matrix_exposes_a_truthful_boundary', () {
      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();

      expect(matrix.truthfulBoundary('/assets'), 'ok');
      expect(matrix.fallbackSqlFor('/assets'), isNull);
      expect(matrix.truthfulBoundary('/no-such-route'), 'unavailable');
      expect(matrix.fallbackSqlFor('/no-such-route'), isNull);
    });
  });
}
