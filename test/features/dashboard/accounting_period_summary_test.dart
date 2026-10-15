import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/reporting/accounting_period_summary_card.dart';
import 'package:openaccounting/features/accounting/reporting/accounting_period_summary_service.dart';
import 'package:openaccounting/features/dashboard/dashboard_period.dart';
import 'package:openaccounting/features/dashboard/dashboard_usecases.dart';

const AccountingPeriodSummaryStrings cardStrings = AccountingPeriodSummaryStrings(
  income: 'Einnahmen',
  expense: 'Ausgaben',
  profit: 'Gewinn',
  margin: 'Marge',
  marginUnavailable: 'Marge n/a',
  period: 'Zeitraum',
  sourceVersion: 'Quellversion',
  unresolvedCount: 'Offene Datensätze',
  unavailable: 'Zeitraster nicht verfügbar',
);

AccountingPeriodSummary buildSummary({int unresolvedCount = 0}) {
  return AccountingPeriodSummary(
    jahr: 2025,
    periodStart: '2025-01-01',
    periodEnd: '2026-01-01',
    incomeCents: 230000,
    expenseCents: 50000,
    profitCents: 180000,
    marginPercent: 180000 / 230000 * 100,
    monthlyTrend: const <AccountingPeriodMonth>[],
    expenseDistribution: const <AccountingPeriodDistribution>[],
    taxDistribution: const <AccountingPeriodDistribution>[],
    sourceVersions: const <String, String>{'euerFormVersion': 'anlage-euer-2025'},
    unresolvedCount: unresolvedCount,
  );
}

void main() {
  group('dashboard annual accounting period summary', () {
    testWidgets('test_summary_widget_uses_the_canonical_annual_result', (WidgetTester tester) async {
      final AccountingPeriodSummary summary = buildSummary();

      await tester.pumpWidget(
        MaterialApp(
          home: AccountingPeriodSummaryCard(strings: cardStrings, summary: summary, unavailableReason: null),
        ),
      );

      // Displays values, year boundaries, source version and unresolved
      // count from the canonical result.
      expect(find.text('Einnahmen'), findsOneWidget);
      expect(find.text('2.300,00'), findsOneWidget);
      expect(find.text('Ausgaben'), findsOneWidget);
      expect(find.text('500,00'), findsOneWidget);
      expect(find.text('Gewinn'), findsOneWidget);
      expect(find.text('1.800,00'), findsOneWidget);
      expect(find.textContaining('2025-01-01'), findsOneWidget);
      expect(find.textContaining('2026-01-01'), findsOneWidget);
      expect(find.textContaining('anlage-euer-2025'), findsOneWidget);
      expect(find.textContaining('0'), findsWidgets);
      // No parallel recalculation: margin comes from the summary value.
      expect(find.textContaining(summary.marginPercent!.toStringAsFixed(1)), findsOneWidget);
    });

    testWidgets('test_summary_dependencies_are_not_approved', (WidgetTester tester) async {
      // Service refuses when the balanced-posting prerequisite is absent.
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runCustom('DROP TABLE settlement_groups', const <Object?>[]);
      final AccountingPeriodSummaryService service = AccountingPeriodSummaryService(db.executor);
      final result = await service.summary(jahr: 2025);
      await db.close();
      expect(result.availability.toString(), contains('unavailable'));

      await tester.pumpWidget(
        MaterialApp(
          home: AccountingPeriodSummaryCard(
            strings: cardStrings,
            summary: null,
            unavailableReason: result.reasonCode,
            unavailablePeriod: '2025',
          ),
        ),
      );

      // Shows the unavailable reason and period; no complete or estimated
      // financial total from a fallback source.
      expect(find.textContaining(cardStrings.unavailable), findsOneWidget);
      expect(find.textContaining(result.reasonCode!), findsOneWidget);
      expect(find.textContaining('2025'), findsWidgets);
      expect(find.text('2.300,00'), findsNothing);
      expect(find.text('1.800,00'), findsNothing);
    });

    testWidgets('test_unsupported_dashboard_summary_period', (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      final AccountingPeriodSummaryService service = AccountingPeriodSummaryService(db.executor);
      final result2026 = await service.summary(jahr: 2026);
      final DashboardUseCase useCase = DashboardUseCase(db.executor);
      final DashboardAnnualKpis? kpis2026 = await useCase.annualSummaryFromReporting(2026);
      await db.close();

      // Unsupported year: no summary and no dashboard KPIs.
      expect(result2026.availability.toString(), contains('unavailable'));
      expect(kpis2026, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: AccountingPeriodSummaryCard(
            strings: cardStrings,
            summary: null,
            unavailableReason: result2026.reasonCode,
            unavailablePeriod: '2026',
          ),
        ),
      );

      // No partial-year or annual value under the wrong period label.
      expect(find.textContaining(cardStrings.unavailable), findsOneWidget);
      expect(find.text('2.300,00'), findsNothing);
      expect(find.text('1.800,00'), findsNothing);
    });

    test('dashboard use case consumes the canonical summary values', () async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, '
        'mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[922, 'Kat', '80015', '40015', 15, 'catalog_verified', 'TEST-EUER', '2025-form.1'],
      );
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2025-03-10', 'Test', 922, '2300.00', 'Einnahme'],
      );

      final AccountingPeriodSummaryService service = AccountingPeriodSummaryService(db.executor);
      final AccountingPeriodSummary summary = (await service.summary(jahr: 2025)).value!;
      final DashboardUseCase useCase = DashboardUseCase(db.executor);
      final DashboardAnnualKpis? kpis = await useCase.annualSummaryFromReporting(2025);
      await db.close();

      // The dashboard KPIs are the canonical summary values, not a second
      // calculation over invoice or journal totals.
      expect(kpis, isNotNull);
      final DashboardAnnualKpis k = kpis!;
      expect(k.year, 2025);
      expect(k.incomeCents, summary.incomeCents);
      expect(k.expenseCents, summary.expenseCents);
      expect(k.profitCents, summary.profitCents);
      expect(k.marginPercent, summary.marginPercent);
    });
  });
}
