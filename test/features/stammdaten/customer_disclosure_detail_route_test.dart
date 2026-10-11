import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/master_data_pages.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/customer_disclosure_export_action.dart';

class _RouteFileSelector extends FileSelectorPlatform {
  _RouteFileSelector(this.destination, {this.failure});

  final String destination;
  final PlatformException? failure;
  bool called = false;

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    called = true;
    final PlatformException? error = failure;
    if (error != null) throw error;
    return FileSaveLocation(destination);
  }
}

Future<AppDatabase> _configuredDatabase(String profileDir) async {
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir);
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Test GmbH']);
  return db;
}

Future<int> _seedCustomer(AppDatabase db) {
  return db.executor.runInsert(
    'INSERT INTO kunden (kundennummer, debitor_nr, anrede, name, strasse, plz, ort, land) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    const <Object?>['K-042', 'D-042', 'Herr', 'Kunde AG', 'Musterstraße 1', '10115', 'Berlin', 'DE'],
  );
}

Widget _wrapRoute(GoRouter router, AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: AppScope(
      services: AppServices(db),
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
}

Future<({int customerId, GoRouter router})> _openCustomerRoute(
  WidgetTester tester,
  _RouteFileSelector fileSelector,
  Directory root,
) async {
  final Directory profileDir = Directory('${root.path}/profile')..createSync();
  addTearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });
  final AppDatabase db = (await tester.runAsync(() => _configuredDatabase(profileDir.path)))!;
  addTearDown(db.close);
  final int customerId = (await tester.runAsync(() => _seedCustomer(db)))!;
  final FileSelectorPlatform originalFileSelector = FileSelectorPlatform.instance;
  FileSelectorPlatform.instance = fileSelector;
  addTearDown(() {
    FileSelectorPlatform.instance = originalFileSelector;
  });
  final GoRouter router = GoRouter(
    initialLocation: '/contacts/$customerId?kind=customer',
    routes: <RouteBase>[
      GoRoute(
        path: '/contacts/:id',
        builder: (BuildContext context, GoRouterState state) => ContactRecordView(id: state.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(_wrapRoute(router, db));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  return (customerId: customerId, router: router);
}

void main() {
  testWidgets('test_customer_data_disclosure_export_042_customer_detail_invokes_the_scoped_export_service', (
    WidgetTester tester,
  ) async {
    final Directory root = Directory.systemTemp.createTempSync('disclosure_route_042_');
    final String destination = '${root.path}/customer.zip';
    final _RouteFileSelector fileSelector = _RouteFileSelector(destination);
    final ({int customerId, GoRouter router}) env = await _openCustomerRoute(tester, fileSelector, root);

    expect(env.router.state.uri.path, '/contacts/${env.customerId}');
    expect(find.text('D-042 · Kunde AG'), findsOneWidget);

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(ContactRecordView)))!;
    final Finder exportAction = find.text(l10n.customerDisclosureExportAction);
    expect(exportAction, findsOneWidget);
    await tester.ensureVisible(exportAction);
    expect(find.byType(CustomerDisclosureExportButton), findsOneWidget);
    final CustomerDisclosureExportButton exportButton = tester.widget(find.byType(CustomerDisclosureExportButton));
    expect(exportButton.selectDestination, isNotNull);
    final CustomerDisclosureExportController controller = exportButton.controller;
    FileSelectorPlatform.instance = fileSelector;
    await tester.tap(exportAction);
    await tester.pumpAndSettle();

    expect(find.text(l10n.customerDisclosureExportScopeTitle), findsOneWidget);
    expect(find.text(l10n.actionCancel), findsOneWidget);

    await tester.tap(find.text(l10n.customerDisclosureExportConfirm));
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 50 &&
          (controller.status == CustomerDisclosureFlowStatus.idle ||
              controller.status == CustomerDisclosureFlowStatus.confirming ||
              controller.status == CustomerDisclosureFlowStatus.exporting);
      attempt++
    ) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text(l10n.customerDisclosureExportScopeTitle), findsNothing);
    expect(fileSelector.called, isTrue);
    expect(File(destination).existsSync(), isTrue);
    expect(find.text(l10n.customerDisclosureExportComplete), findsOneWidget);
    expect(env.router.state.uri.path, '/contacts/${env.customerId}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_customer_data_disclosure_export_043_picker_failure_is_announced_without_creating_archive', (
    WidgetTester tester,
  ) async {
    final Directory root = Directory.systemTemp.createTempSync('disclosure_route_043_');
    final String destination = '${root.path}/customer.zip';
    final _RouteFileSelector fileSelector = _RouteFileSelector(
      destination,
      failure: PlatformException(code: 'picker_failed'),
    );
    final ({int customerId, GoRouter router}) env = await _openCustomerRoute(tester, fileSelector, root);
    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(ContactRecordView)))!;
    final CustomerDisclosureExportButton exportButton = tester.widget(find.byType(CustomerDisclosureExportButton));
    expect(exportButton.selectDestination, isNotNull);

    FileSelectorPlatform.instance = fileSelector;
    await tester.tap(find.text(l10n.customerDisclosureExportAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.customerDisclosureExportConfirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n.customerDisclosureExportScopeTitle), findsNothing);
    for (var attempt = 0; attempt < 20 && !fileSelector.called; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(fileSelector.called, isTrue);
    expect(find.text(l10n.customerDisclosureExportFailed), findsOneWidget);
    expect(find.text(l10n.customerDisclosureExportCancelled), findsNothing);
    expect(File(destination).existsSync(), isFalse);
    expect(env.router.state.uri.path, '/contacts/${env.customerId}');
    expect(tester.takeException(), isNull);
  });
}
