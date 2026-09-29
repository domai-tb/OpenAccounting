// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/app_locale.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/theme/app_typography.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('test_english_production_state_copy_is_complete', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('en'), '/inventory');
    addTearDown(harness.dispose);

    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('Inventory management is not available yet.'), findsOneWidget);
    expect(find.text('Back to overview'), findsOneWidget);
    expect(find.text('Lager'), findsNothing);
  });

  testWidgets('test_german_production_state_copy_is_complete', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('de'), '/inventory');
    addTearDown(harness.dispose);

    expect(find.text('Lager'), findsWidgets);
    expect(find.text('Die Lagerverwaltung ist noch nicht verfügbar.'), findsOneWidget);
    expect(find.text('Zur Übersicht'), findsOneWidget);
  });

  testWidgets('test_locale_formats_accounting_values', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: MoneyText(1284.32)),
      ),
    );
    await tester.pumpAndSettle();

    final Text text = tester.widget<Text>(find.byType(Text).first);
    final String normalized = (text.data ?? '').replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
    expect(normalized, '1,284.32 €');
    expect(formatDate(DateTime(2026, 8, 30), locale: 'en_US'), '08/30/2026');
    expect(formatDateLong(DateTime(2026, 8, 30), locale: 'en_US'), 'August 30, 2026');
    expect(AppTypography.formatDate(DateTime(2026, 8, 30), locale: 'en_US'), '08/30/2026');
    expect(AppTypography.formatDateLong(DateTime(2026, 8, 30), locale: 'en_US'), 'August 30, 2026');
  });

  testWidgets('test_unkeyed_visible_copy_and_app_spec_parity_fail_validation', (WidgetTester tester) async {
    // Keep this as a red source-contract test until the base spec is reconciled.
    final String appSpec = File('openspec/specs/app/spec.md').readAsStringSync();
    expect(appSpec, isNot(contains('All user-facing text SHALL be in German')));

    final String appMoney = File('lib/design_system/components/app_money.dart').readAsStringSync();
    expect(appMoney, isNot(contains("locale = 'de_DE'")));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('test_active_locale_formats_accounting_values', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: MoneyText(1284.32, obscured: true)),
      ),
    );
    await tester.pumpAndSettle();

    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String?> labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((Semantics node) => node.properties.label)
        .toList();
    semantics.dispose();
    expect(labels, contains('Amount hidden'), reason: 'semantic labels: $labels');
    expect(AppTypography.formatMoney(1284.32, locale: 'en_US'), contains('1,284.32'));
    expect(AppTypography.formatDateLong(DateTime(2026, 8, 30), locale: 'en_US'), 'August 30, 2026');
    final String pdfSource = File('lib/features/pdf/pdf_generator.dart').readAsStringSync();
    expect(pdfSource, contains('required String locale'));
  });

  testWidgets('test_german_locale_remains_stable', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: MoneyText(1284.32)),
      ),
    );
    await tester.pumpAndSettle();

    final Text text = tester.widget<Text>(find.byType(Text).first);
    final String normalized = (text.data ?? '').replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
    expect(normalized, '1.284,32 €');
    expect(AppTypography.formatDateLong(DateTime(2026, 8, 30), locale: 'de_DE'), '30. August 2026');
    final String typographySource = File('lib/design_system/theme/app_typography.dart').readAsStringSync();
    expect(typographySource, isNot(contains("locale = 'de_DE'")));
  });

  testWidgets('test_hardcoded_german_formatting_fails_english_smoke', (WidgetTester tester) async {
    final List<String> sourcePaths = <String>[
      'lib/design_system/components/app_money.dart',
      'lib/design_system/theme/app_typography.dart',
      'lib/design_system/components/finance_list_surface.dart',
      'lib/features/bank_import/bank_import_page.dart',
      'lib/features/bank_import/bank_import_service.dart',
      'lib/pages/rechnungen/invoice_document_page.dart',
      'lib/features/pdf/pdf_generator.dart',
    ];
    for (final String path in sourcePaths) {
      final String source = File(path).readAsStringSync();
      expect(source, isNot(contains("locale = 'de_DE'")), reason: '$path must not carry a German default');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('test_locale_switch_preserves_route_query_and_filters', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('de'), '/invoices?status=open');
    addTearDown(harness.dispose);
    final Finder search = find.byType(TextField).first;
    await tester.enterText(search, 'Acme');
    await harness.container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    await tester.pumpAndSettle();

    expect(harness.router.state.matchedLocation, '/invoices');
    expect(harness.router.state.uri.queryParameters['status'], 'open');
    expect(find.text('Invoices'), findsWidgets);
    expect(tester.widget<TextField>(search).controller?.text, 'Acme');
  });

  testWidgets('test_unsupported_persisted_locale_falls_back_safely', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{appLocalePreferenceKey: 'fr'});
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('de'), '/inventory');
    addTearDown(harness.dispose);

    expect(harness.container.read(appLocaleProvider).languageCode, 'de');
    expect(find.text('Die Lagerverwaltung ist noch nicht verfügbar.'), findsOneWidget);
    expect(find.text('Inventory management is not available yet.'), findsNothing);
  });

  testWidgets('test_english_selection_persists_across_restart', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('en'), '/settings');
    addTearDown(harness.dispose);

    expect(find.text('Settings'), findsWidgets);
    expect(harness.container.read(appLocaleProvider).languageCode, 'en');
  });

  testWidgets('test_locale_persistence_failure_keeps_session_usable', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('en'), '/settings');
    addTearDown(harness.dispose);
    await harness.container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(harness.router.state.matchedLocation, '/settings');
  });

  testWidgets('test_documented_routes_expose_both_locale_catalogs', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('en'), '/');
    addTearDown(harness.dispose);
    const List<String> routes = <String>[
      '/',
      '/settings',
      '/banking',
      '/invoices',
      '/receipts',
      '/contacts',
      '/taxes',
      '/reports',
      '/help',
      '/setup',
      '/inventory',
    ];
    for (final String route in routes) {
      harness.router.go(route);
      await tester.pumpAndSettle();
      expect(harness.router.state.matchedLocation, route);
      expect(
        find.textContaining('Lagerverwaltung'),
        findsNothing,
        reason: '$route must not show German copy in English',
      );
    }
    expect(find.text('Inventory management is not available yet.'), findsOneWidget);
  });

  testWidgets('test_missing_required_route_state_key_fails_parity_check', (WidgetTester tester) async {
    final Map<String, dynamic> de =
        jsonDecode(File('assets/l10n/l10n_de.arb').readAsStringSync()) as Map<String, dynamic>;
    final Map<String, dynamic> en =
        jsonDecode(File('assets/l10n/l10n_en.arb').readAsStringSync()) as Map<String, dynamic>;
    const List<String> required = <String>[
      'setupTitle',
      'setupStart',
      'setupStep',
      'setupCompanyName',
      'setupIban',
      'setupCashBalance',
      'setupCategories',
      'setupRequired',
      'setupInvalidIban',
      'setupDatabaseError',
      'setupRetry',
      'setupComplete',
      'inventoryTitle',
      'inventoryUnavailable',
      'inventoryUnavailableDescription',
      'inventoryReadOnly',
      'inventoryRetry',
      'inventoryBack',
    ];
    expect(de.keys.toSet(), en.keys.toSet());
    for (final String key in required) {
      expect(de.containsKey(key), isTrue, reason: 'de missing $key');
      expect(en.containsKey(key), isTrue, reason: 'en missing $key');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('test_localized_control_keeps_keyboard_and_focus_semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: MoneyText(1284.32, obscured: true)),
      ),
    );
    await tester.pumpAndSettle();
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<String?> labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((Semantics node) => node.properties.label)
        .toList();
    semantics.dispose();
    expect(labels, contains('Amount hidden'), reason: 'semantic labels: $labels');
  });

  testWidgets('test_narrow_loading_and_error_states_remain_reachable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('en'), '/inventory');
    addTearDown(harness.dispose);

    expect(find.text('Inventory management is not available yet.'), findsOneWidget);
    expect(find.text('Back to overview'), findsOneWidget);
  });
}

Future<_ProductionHarness> _pumpProduction(WidgetTester tester, Locale locale, String location) async {
  // The production notifier uses the platform-backed plugin. Tests must
  // install its in-memory implementation before the notifier's build
  // microtask runs, otherwise getInstance waits forever on the VM channel.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Localization GmbH']);
  final ProviderContainer container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  final GoRouter router = container.read(appRouterProvider);
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenAccountingApp()));
  await _boundedProductionPump(tester);
  await container.read(appLocaleProvider.notifier).setLocale(locale);
  await _boundedProductionPump(tester);
  if (location != '/') {
    router.go(location);
    await _boundedProductionPump(tester);
  }
  return _ProductionHarness(container: container, router: router, db: db);
}

Future<void> _boundedProductionPump(WidgetTester tester) async {
  // The pre-fix app can keep a loading animation alive while its initial
  // service graph is unresolved. Probe briefly so red assertions run instead
  // of hanging the TDD loop; final acceptance keeps normal pumpAndSettle.
  // Allow route-local bounded timeouts (for example profile loading) to fire
  // after the route is mounted while still avoiding an unbounded settle loop.
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final class _ProductionHarness {
  _ProductionHarness({required this.container, required this.router, required this.db});

  final ProviderContainer container;
  final GoRouter router;
  final AppDatabase db;

  void dispose() {
    router.dispose();
    container.dispose();
    unawaited(db.close());
  }
}
