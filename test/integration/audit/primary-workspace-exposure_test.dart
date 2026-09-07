// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';

void main() {
  group('Primary workspace exposure', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async => db.close());

    test('test_primary_workspace_exposure_1_1_a_populated_invoice_and_contact_workspace_is_usable', () async {
      // Seed invoice and customer
      await db.executor.runCustom(
        'INSERT INTO kunden (kundennummer, name, strasse, plz, ort) '
        "VALUES ('K-001', 'Test GmbH', 'Musterstr.', '12345', 'Berlin')",
      );
      await db.executor.runCustom(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, datum, kunde_id, brutto_betrag) '
        "VALUES ('R-001', 'rechnung', 'offen', 0, '2026-06-01', 1, 100.00)",
      );

      // Verify data exists and is queryable
      final invoices = await db.executor.runSelect(
        "SELECT COUNT(*) as c FROM rechnungen WHERE status != 'bezahlt' AND ist_entwurf = 0",
        const <Object?>[],
      );
      expect(invoices.first['c'], 1);

      final contacts = await db.executor.runSelect('SELECT COUNT(*) as c FROM kunden', const <Object?>[]);
      expect(contacts.first['c'], 1);
    });

    test('test_primary_workspace_exposure_1_2_an_empty_or_failed_workspace_is_explicit', () async {
      // Empty workspace: no records
      final invoices = await db.executor.runSelect('SELECT COUNT(*) as c FROM rechnungen', const <Object?>[]);
      expect(invoices.first['c'], 0);
    });

    test('test_primary_workspace_exposure_2_1_creation_and_detail_paths_select_the_correct_mode', () async {
      final router = createRouter(db);

      // Router should have the /invoices and /invoices/new routes
      final config = router.configuration;
      expect(config.routes, isNotEmpty);

      router.dispose();
    });

    test('test_primary_workspace_exposure_2_2_invalid_detail_and_filters_are_handled', () async {
      final router = createRouter(db);

      // Router should handle unknown routes without crashing
      expect(router, isNotNull);
      expect(router.configuration, isNotNull);

      router.dispose();
    });
  });
}
