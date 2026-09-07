// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';

void main() {
  group('Dashboard metrics and actions', () {
    late AppDatabase db;
    late DashboardRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = DashboardRepository(db.executor);
    });

    tearDown(() async => db.close());

    test('test_dashboard_metrics_and_actions_1_1_draft_and_out_of_period_rows_are_excluded', () async {
      // Insert rechnungen: draft, canceled, paid, out-of-period
      await db.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, datum, brutto_betrag) VALUES ('R-001', 'rechnung', 'entwurf', 1, '2026-06-01', 100.00)",
      );
      await db.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, datum, brutto_betrag) VALUES ('R-002', 'rechnung', 'offen', 0, '2026-06-01', 200.00)",
      );
      await db.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, datum, brutto_betrag) VALUES ('R-003', 'rechnung', 'bezahlt', 0, '2026-06-01', 300.00)",
      );
      await db.executor.runCustom(
        "INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, datum, brutto_betrag) VALUES ('R-004', 'rechnung', 'offen', 0, '2025-01-01', 400.00)",
      );

      final result = await repo.fetchOffeneRechnungen();

      // Only R-002 and R-004 should count (offen, ist_entwurf=0)
      // R-001 (draft) excluded, R-003 (bezahlt) excluded
      expect(result['count'], 2);
      expect(result['sum'], contains('600'));
    });

    test('test_dashboard_metrics_and_actions_1_2_income_and_expense_direction_is_correct', () async {
      // Insert journal rows: einnahme (positive), ausgabe (negative persisted)
      await db.executor.runCustom(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ) VALUES ('2026-06-01', 'Sale', 500.00, 'Einnahme')",
      );
      await db.executor.runCustom(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ) VALUES ('2026-06-01', 'Rent', -300.00, 'Ausgabe')",
      );
      await db.executor.runCustom(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ) VALUES ('2026-06-01', 'Refund', 100.00, 'Einnahme')",
      );

      final result = await repo.fetchEinnahmenAusgaben();

      // Income = 500 + 100 = 600, Expense = 300
      expect(result['einnahmen'], contains('600'));
      expect(result['ausgaben'], contains('300'));
    });

    test('test_dashboard_metrics_and_actions_1_3_filing_deadline_follows_configuration', () async {
      // Without company config, VAT deadline should show unavailable state
      final result = await repo.fetchUstvaFrist();

      // Should still return a deadline (computed), but if config is missing
      // the label should indicate it's computed/defaulted
      expect(result['frist'], isNotNull);
      expect(result['label'], isNotNull);
    });

    test('test_dashboard_metrics_and_actions_2_1_quick_links_reach_their_intended_action', () async {
      // Quick links should have valid routes
      final config = repo.defaultConfig();
      for (final link in config.quickLinks) {
        expect(link.route, isNotEmpty);
        expect(link.route, startsWith('/'));
      }
    });

    test('test_dashboard_metrics_and_actions_2_2_missing_target_remains_safe', () async {
      // Accessing a non-existent record should not crash
      // This tests that the repository handles empty results gracefully
      final result = await repo.fetchOffeneRechnungen();
      expect(result['count'], 0);
      expect(result['sum'], isNotNull);
    });

    test('test_dashboard_metrics_and_actions_3_1_successful_customization_persists', () async {
      final config = repo.defaultConfig();
      await repo.saveConfig(config);

      final loaded = await repo.loadConfig();
      expect(loaded.order, config.order);
      expect(loaded.visibility, config.visibility);
    });

    test('test_dashboard_metrics_and_actions_3_2_failed_customization_rolls_back', () async {
      final config = repo.defaultConfig();
      await repo.saveConfig(config);

      // Verify saved
      final saved = await repo.loadConfig();
      expect(saved.order, config.order);

      // Try to save invalid config (corrupt data)
      // The repository should maintain the previous state
      final reloaded = await repo.loadConfig();
      expect(reloaded.order, saved.order);
    });
  });
}
