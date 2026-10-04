import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_repository.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_settings_section.dart';

/// Company fiscal-year settings UI (fiscal-year section 6).
void main() {
  group('Company fiscal-year settings', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> pumpSection(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FiscalYearSettingsSection(repository: FiscalYearRepository(db.executor))),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('test_stammdaten_company_settings_display_saved_fiscal_year', (tester) async {
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
      await FiscalYearRepository(db.executor).setStartMonth(7);
      await pumpSection(tester);
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('test_stammdaten_company_settings_reject_an_invalid_update', (tester) async {
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
      await pumpSection(tester);
      await expectLater(FiscalYearRepository(db.executor).setStartMonth(0), throwsA(isA<FiscalYearException>()));
      expect(await FiscalYearRepository(db.executor).getStartMonth(), 1);
    });
  });
}
