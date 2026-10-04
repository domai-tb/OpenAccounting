import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_calendar_service.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_repository.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_settings_section.dart';

/// Fiscal-year configuration + shared boundaries (fiscal-year sections 3-4).
void main() {
  group('Fiscal calendar', () {
    late AppDatabase db;
    late FiscalYearRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = FiscalYearRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('test_fiscal_year_calendar_existing_profile_retains_calendar_year_default', () async {
      expect(await repo.getStartMonth(), FiscalYearRepository.defaultStartMonth);
      final FiscalCalendarService january = FiscalCalendarService(startMonth: await repo.getStartMonth());
      final FiscalPeriod year = january.fiscalYearFor(DateTime(2026, 8, 15));
      expect(year.label, '2026');
      expect(year.start, '2026-01-01');
      expect(year.endExclusive, '2027-01-01');
    });

    test('test_fiscal_year_calendar_user_configures_an_alternate_start_month', () async {
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
      await repo.setStartMonth(4);
      expect(await repo.getStartMonth(), 4);
      const FiscalCalendarService april = FiscalCalendarService(startMonth: 4);
      final FiscalPeriod year = april.fiscalYearFor(DateTime(2026, 8, 15));
      expect(year.label, '2026');
      expect(year.start, '2026-04-01');
      expect(year.endExclusive, '2027-04-01');
    });

    test('test_fiscal_year_calendar_invalid_configuration_is_rejected', () async {
      await expectLater(repo.setStartMonth(0), throwsA(isA<FiscalYearException>()));
      await expectLater(repo.setStartMonth(13), throwsA(isA<FiscalYearException>()));
      expect(
        () => const FiscalCalendarService(startMonth: 0).fiscalYearFor(DateTime.parse('2026-02-03')),
        throwsA(isA<FiscalInvalidPeriod>()),
      );
    });

    test('test_fiscal_year_calendar_save_failure_retains_the_persisted_setting', () async {
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
      await repo.setStartMonth(4);
      await expectLater(repo.setStartMonth(13), throwsA(isA<FiscalYearException>()));
      expect(await repo.getStartMonth(), 4);
    });

    test('test_fiscal_year_calendar_date_belongs_to_a_fiscal_year_starting_in_january', () async {
      const FiscalCalendarService service = FiscalCalendarService(startMonth: 1);
      final FiscalPeriod year = service.fiscalYearFor(DateTime(2026, 11, 30));
      expect(year.label, '2026');
      expect(year.start, '2026-01-01');
      expect(year.endExclusive, '2027-01-01');
    });

    test('test_fiscal_year_calendar_date_before_the_configured_start_month', () async {
      const FiscalCalendarService service = FiscalCalendarService(startMonth: 4);
      final FiscalPeriod year = service.fiscalYearFor(DateTime(2026, 2, 15));
      expect(year.label, '2025');
      expect(year.start, '2025-04-01');
      expect(year.endExclusive, '2026-04-01');
    });

    test('test_fiscal_year_calendar_date_on_the_configured_start_month_boundary', () async {
      const FiscalCalendarService service = FiscalCalendarService(startMonth: 4);
      final FiscalPeriod year = service.fiscalYearFor(DateTime.parse('2026-04-01'));
      expect(year.label, '2026');
      expect(year.start, '2026-04-01');
      expect(year.endExclusive, '2027-04-01');
    });

    test('test_fiscal_year_calendar_fiscal_month_and_quarter_follow_the_configured_start', () async {
      const FiscalCalendarService service = FiscalCalendarService(startMonth: 4);
      final FiscalPeriod month = service.fiscalMonth(fiscalYearLabel: 2026, index: 1);
      expect(month.label, '2026-M04');
      expect(month.start, '2026-04-01');
      expect(month.endExclusive, '2026-05-01');
      final FiscalPeriod quarter = service.fiscalQuarter(fiscalYearLabel: 2026, index: 1);
      expect(quarter.label, '2026-Q1');
      expect(quarter.start, '2026-04-01');
      expect(quarter.endExclusive, '2026-07-01');
    });

    test('test_fiscal_year_calendar_invalid_fiscal_month_or_quarter_index_is_rejected', () async {
      const FiscalCalendarService service = FiscalCalendarService(startMonth: 4);
      expect(() => service.fiscalMonth(fiscalYearLabel: 2026, index: 0), throwsA(isA<FiscalInvalidPeriod>()));
      expect(() => service.fiscalMonth(fiscalYearLabel: 2026, index: 13), throwsA(isA<FiscalInvalidPeriod>()));
      expect(() => service.fiscalQuarter(fiscalYearLabel: 2026, index: 0), throwsA(isA<FiscalInvalidPeriod>()));
      expect(() => service.fiscalQuarter(fiscalYearLabel: 2026, index: 5), throwsA(isA<FiscalInvalidPeriod>()));
    });
  });
}

/// Design-system keyboard review for the fiscal-year settings control.
void fiscalYearKeyboardSection() {
  group('Fiscal-year settings keyboard review', () {
    testWidgets('test_fiscal_year_calendar_user_saves_a_setting_with_keyboard_controls', (tester) async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FiscalYearSettingsSection(repository: FiscalYearRepository(db.executor))),
        ),
      );
      await tester.pumpAndSettle();

      final Finder saveButton = find.text('Speichern');
      expect(saveButton, findsOneWidget);
      Focus.of(saveButton.evaluate().single).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('Geschäftsjahr gespeichert'), findsOneWidget);
      expect(await FiscalYearRepository(db.executor).getStartMonth(), 1);
    });

    testWidgets('test_fiscal_year_calendar_save_failure_keeps_the_fiscal_setting_accessible_and_unchanged', (
      tester,
    ) async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Firma')", const <Object?>[]);
      await FiscalYearRepository(db.executor).setStartMonth(4);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FiscalYearSettingsSection(repository: FiscalYearRepository(db.executor))),
        ),
      );
      await tester.pumpAndSettle();
      await db.executor.runCustom('DROP TABLE unternehmen');

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Speichern fehlgeschlagen. Erneut versuchen.'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });
  });
  fiscalYearKeyboardSection();
}
