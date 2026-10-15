import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/accounting/reporting/datev_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';
import 'package:openaccounting/l10n/l10n.dart';

Future<GoRouter> _pumpRoute(WidgetTester tester, String location) async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Test GmbH']);
  final GoRouter router = createRouter(db);
  addTearDown(router.dispose);
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: AppScope(
        services: AppServices(db),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  router.go(location);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('test_report_routes_open_a_typed_report_catalog', (WidgetTester tester) async {
    final GoRouter router = await _pumpRoute(tester, '/reports');

    expect(find.byKey(const ValueKey<String>('report-catalog')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('report-catalog-euer')), findsOneWidget);

    router.go('/taxes');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('report-catalog-ustva')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('report-catalog-zm')), findsOneWidget);
  });

  testWidgets('test_report_deep_link_selects_its_typed_owner', (WidgetTester tester) async {
    final GoRouter router = await _pumpRoute(tester, '/taxes?report=zm&month=2025-01');

    expect(router.state.uri.queryParameters['report'], 'zm');
    expect(router.state.uri.queryParameters['month'], '2025-01');
    expect(find.byKey(const ValueKey<String>('report-workspace-zm')), findsOneWidget);
    expect(find.text('2025-01-01 – 2025-02-01'), findsOneWidget);
    expect(find.textContaining('ustg-18a-2026'), findsOneWidget);
  });

  testWidgets('test_missing_or_invalid_report_selection_fails_closed', (WidgetTester tester) async {
    final GoRouter router = await _pumpRoute(tester, '/taxes?report=zm&month=2025-13');

    expect(router.state.uri.queryParameters['month'], '2025-13');
    expect(find.byKey(const ValueKey<String>('report-workspace-invalid')), findsOneWidget);
    expect(find.text('Ungültige Berichtsabfrage'), findsOneWidget);
  });

  testWidgets('test_export_history_deep_link_opens_validated_artifact_history', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
    await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Test GmbH']);
    await db.executor.runCustom(
      "UPDATE unternehmen SET datev_beraternummer = '6512345', datev_mandantennummer = 'M4711'",
      const <Object?>[],
    );
    await db.executor.runInsert('INSERT INTO konten (id, name, datev_kontonummer) VALUES (?, ?, ?)', <Object?>[
      81,
      'Konto 81',
      '4000',
    ]);
    await db.executor.runInsert('INSERT INTO konten (id, name, datev_kontonummer) VALUES (?, ?, ?)', <Object?>[
      82,
      'Konto 82',
      '1200',
    ]);
    await db.executor.runInsert(
      'INSERT INTO journal (id, datum, beschreibung, betrag, beleg_typ, immutable, beleg_nr, '
      'soll_konto_id, haben_konto_id, ust_satz, source_kind) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?)',
      <Object?>[1, '2025-07-15', 'Testbuchung', '1000.00', 'Einnahme', 'RE-1', 81, 82, '19', 'invoice_event'],
    );

    // Real artifact file IO must run outside the FakeAsync test zone.
    final String exportPath = '${Directory.systemTemp.path}/datev_history_127.csv';
    addTearDown(() {
      final File f = File(exportPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    });
    final ReportWorkspaceResult<ReportExportOutcome>? export = await tester.runAsync(
      () => ReportExportUseCase(db.executor).export(
        selection: const ReportSelection.datev(
          month: '2025-07',
          datevConfig: DatevExportConfig(
            sachkontenlaenge: '4',
            chartCode: '03',
            buSchluessel: <String, String>{'19': '1'},
          ),
        ),
        format: 'csv',
        destinationPath: exportPath,
      ),
    );
    expect(export!.availability, ReportAvailability.available);

    final GoRouter router = createRouter(db);
    addTearDown(router.dispose);
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: AppScope(
          services: AppServices(db),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    router.go('/reports?view=history');
    await tester.pumpAndSettle();

    // Deep link preserves the view and opens the validated artifact history
    // instead of an unavailable placeholder.
    expect(router.state.uri.queryParameters['view'], 'history');
    expect(find.byKey(const ValueKey<String>('report-export-history')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('export-history-row-1')), findsOneWidget);
    expect(find.textContaining('datev_history_127.csv'), findsOneWidget);
    expect(find.textContaining('erfolg'), findsOneWidget);
    expect(find.textContaining('ReportExportHistoryUseCase unavailable'), findsNothing);
  });
}
