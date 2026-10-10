// ignore_for_file: avoid_redundant_argument_values

import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/app_locale.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/skeleton.dart';
import 'package:openaccounting/design_system/theme/app_typography.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../features/pdf/pdf_test_helpers.dart';

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
    expect(formatMoney(1284.32, locale: 'en_US'), '1,284.32 €');
    expect(AppTypography.formatDate(DateTime(2026, 8, 30), locale: 'en_US'), '08/30/2026');
    expect(AppTypography.formatDateLong(DateTime(2026, 8, 30), locale: 'en_US'), 'August 30, 2026');
    expect(AppTypography.formatMoney(1284.32, locale: 'en_US'), contains('1,284.32'));

    // MoneyText renders the German locale as well.
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: MoneyText(1284.32)),
      ),
    );
    await tester.pumpAndSettle();
    final Text germanText = tester.widget<Text>(find.byType(Text).first);
    final String germanNormalized = (germanText.data ?? '').replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
    expect(germanNormalized, '1.284,32 €');
  });

  testWidgets('test_unkeyed_visible_copy_and_app_spec_parity_fail_validation', (WidgetTester tester) async {
    // Keep this as a red source-contract test until the base spec is reconciled.
    final String appSpec = File('openspec/specs/app/spec.md').readAsStringSync();
    expect(appSpec, isNot(contains('All user-facing text SHALL be in German')));

    final String appMoney = File('lib/design_system/components/app_money.dart').readAsStringSync();
    expect(appMoney, isNot(contains("locale = 'de_DE'")));

    // Scenario "Unkeyed visible copy fails validation": a touched production
    // widget that introduces a visible string without an ARB key must fail
    // validation with the source location and the literal needing a key.
    final List<String> injected = _scanSource(
      'lib/injected/touched_widget.dart',
      "class TouchedWidget {\n  final String hint = 'Bitte Daten laden und prüfen';\n}\n",
      _catalogValues(),
    );
    expect(
      injected,
      contains('lib/injected/touched_widget.dart:2: missing key for visible literal "Bitte Daten laden und prüfen"'),
      reason: 'unkeyed visible copy must fail with source location: $injected',
    );

    // The curated production scope — documented-route surfaces this change
    // touches — must hold no unkeyed visible literals: everything visible is
    // a value in one of the ARB catalogs or an explicitly exempted
    // non-visible data literal (format patterns, persisted defaults, machine
    // keywords; see _nonVisibleDataLiterals).
    final List<String> unkeyed = _findUnkeyedVisibleLiterals(_visibleCopyScanPaths, _catalogValues());
    expect(unkeyed, isEmpty, reason: 'unkeyed visible literals:\n${unkeyed.join('\n')}');

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
    expect(formatMoney(1284.32, locale: 'en_US'), '1,284.32 €');
    expect(formatMoney(1284.32, locale: 'de_DE'), '1.284,32 €');
    expect(formatDate(DateTime(2026, 8, 30), locale: 'en_US'), '08/30/2026');
    expect(formatDateLong(DateTime(2026, 8, 30), locale: 'de_DE'), '30. August 2026');
    expect(AppTypography.formatDate(DateTime(2026, 8, 30), locale: 'en_US'), '08/30/2026');

    // MoneyText renders in both locales.
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: MoneyText(1284.32)),
      ),
    );
    await tester.pumpAndSettle();
    final Text germanMoney = tester.widget<Text>(find.byType(Text).first);
    final String germanMoneyNormalized = (germanMoney.data ?? '').replaceAll('\u00A0', ' ').replaceAll('\u202F', ' ');
    expect(germanMoneyNormalized, '1.284,32 €');

    final String pdfSource = File('lib/features/pdf/pdf_generator.dart').readAsStringSync();
    expect(pdfSource, contains('required String locale'));

    // PDF acceptance: the same document data through the production finalize
    // boundary in de_DE and en_US, with extracted text compared per locale.
    final Directory pdfProfile = Directory.systemTemp.createTempSync('locale-pdf-acceptance-');
    addTearDown(() {
      pdfProfile.deleteSync(recursive: true);
    });
    final AppDatabase pdfDb = AppDatabase.createTestDatabase(profileDir: pdfProfile.path);
    addTearDown(pdfDb.close);
    await pdfDb.ensureOpen();
    await pdfDb.kategorienRepository.create(bezeichnung: 'Finalisierung');
    await pdfDb.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final RechnungenUseCases useCases = RechnungenUseCases(
      RechnungenRepository(RechnungenDataSource(pdfDb.executor, profileDir: pdfProfile.path)),
    );
    const List<RechnungPositionItem> positions = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Website-Design', menge: 2, einzelpreis: 500, gesamt: 1000),
    ];
    final RechnungItem draftDe = await useCases.createDraftRechnung(datum: '2026-08-30', positionen: positions);
    final RechnungItem draftEn = await useCases.createDraftRechnung(datum: '2026-08-30', positionen: positions);
    final RechnungItem finalizedDe = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draftDe.id);
    final RechnungItem finalizedEn = await useCases.finalizeRechnung(locale: 'en_US', rechnungId: draftEn.id);
    final String deText = parsePdf(File(finalizedDe.originalPdfPath!).readAsBytesSync()).visibleText;
    final String enText = parsePdf(File(finalizedEn.originalPdfPath!).readAsBytesSync()).visibleText;
    expect(deText, contains('Rechnung'));
    expect(deText, contains('30.08.2026'));
    expect(deText, contains('1.190,00'));
    expect(deText, contains('Gesamtbetrag'));
    expect(deText, isNot(contains('08/30/2026')));
    expect(enText, contains('Invoice'));
    expect(enText, contains('08/30/2026'));
    expect(enText, contains('1,190.00'));
    expect(enText, contains('Total amount'));
    expect(enText, isNot(contains('30.08.2026')));
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

    // Omitted locale propagation is rejected by the shared formatter contract.
    expect(() => formatMoney(1.0), throwsArgumentError);
    expect(() => formatMoney(1.0, locale: ''), throwsArgumentError);
    expect(() => formatDate(DateTime(2026, 8, 30)), throwsArgumentError);
    expect(() => formatDateLong(DateTime(2026, 8, 30)), throwsArgumentError);
    expect(() => AppTypography.formatMoney(1.0), throwsArgumentError);
    expect(() => AppTypography.formatDate(DateTime(2026, 8, 30)), throwsArgumentError);
    expect(() => AppTypography.formatDateLong(DateTime(2026, 8, 30)), throwsArgumentError);

    // Invoice/document rendering propagates its active locale explicitly.
    final String invoiceDoc = File('lib/pages/rechnungen/invoice_document_page.dart').readAsStringSync();
    expect(invoiceDoc, contains('locale: locale'));

    // Machine-readable ISO/DATEV formatters stay outside the locale boundary.
    final String bankService = File('lib/features/bank_import/bank_import_service.dart').readAsStringSync();
    final String bankPage = File('lib/features/bank_import/bank_import_page.dart').readAsStringSync();
    for (final String source in <String>[bankService, bankPage]) {
      expect(source, isNot(contains('DateFormat(')), reason: 'bank import keeps machine-readable dates');
      expect(source, contains("padLeft(2, '0')"), reason: 'bank import keeps the ISO date helpers');
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
    final _ProductionHarness harness = await _pumpProduction(tester, const Locale('de'), '/settings');
    addTearDown(harness.dispose);
    expect(find.text('Einstellungen'), findsWidgets);

    // Spec scenario: "the preference store rejects the write". Swap in a store
    // that refuses every mutation after the session has warmed its instance.
    final _RejectingPreferenceStore store = _RejectingPreferenceStore();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    await harness.container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
    await tester.pumpAndSettle();

    expect(store.rejectedWrites, greaterThan(0), reason: 'the locale write must actually reach the rejecting store');
    expect(harness.container.read(appLocaleProvider).languageCode, 'en');
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Einstellungen'), findsNothing);
    expect(harness.router.state.matchedLocation, '/settings');
  });

  testWidgets('test_documented_routes_expose_both_locale_catalogs', (WidgetTester tester) async {
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

    // Per-route localized title fixtures: (English, German).
    const Map<String, List<String>> routeTitles = <String, List<String>>{
      '/': <String>['Overview', 'Übersicht'],
      '/settings': <String>['Settings', 'Einstellungen'],
      '/banking': <String>['Banking', 'Bank & Zahlungen'],
      '/invoices': <String>['Invoices', 'Rechnungen'],
      '/receipts': <String>['Receipts', 'Belege'],
      '/contacts': <String>['Contacts', 'Kontakte'],
      '/taxes': <String>['Taxes', 'Steuern'],
      '/reports': <String>['Reports', 'Auswertungen'],
      '/help': <String>['Help', 'Hilfe'],
      '/setup': <String>['Setup wizard', 'Setup Wizard'],
      '/inventory': <String>['Inventory', 'Lager'],
    };

    // English pass: every documented route through the real router, no German copy.
    final _ProductionHarness en = await _pumpProduction(tester, const Locale('en'), '/');
    addTearDown(en.dispose);
    for (final String route in routes) {
      en.router.go(route);
      await tester.pumpAndSettle();
      expect(en.router.state.matchedLocation, route);
      expect(
        find.text(routeTitles[route]!.first),
        findsWidgets,
        reason: '$route must expose its localized English title',
      );
      for (final String german in _germanLeakPhrases) {
        expect(
          find.textContaining(german),
          findsNothing,
          reason: '$route must not show German copy "$german" in English',
        );
      }
    }

    // assertInventoryUnavailableState / assertInventoryReadOnlyState / assertInventoryRetryAction (English).
    en.router.go('/inventory');
    await tester.pumpAndSettle();
    expect(find.text('Inventory management is not available yet.'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(en.router.state.matchedLocation, '/inventory');

    // assertSetupWizardCompletionState / assertSetupWizardFailureState (English).
    await _driveWizardToAbschluss(tester, en, continueLabel: 'Continue', completionHeading: 'Setup complete');
    expect(find.text('Setup complete'), findsWidgets);
    await en.db.close();
    await tester.tap(find.widgetWithText(FilledButton, 'Setup complete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The profile could not be saved.'), findsOneWidget);
    en.dispose();

    // German pass: the same routes and states resolve to the German catalog.
    final _ProductionHarness de = await _pumpProduction(tester, const Locale('de'), '/');
    addTearDown(de.dispose);
    for (final String route in routes) {
      de.router.go(route);
      await tester.pumpAndSettle();
      expect(de.router.state.matchedLocation, route);
      expect(
        find.text(routeTitles[route]!.last),
        findsWidgets,
        reason: '$route must expose its localized German title',
      );
      for (final String english in _englishLeakPhrases) {
        expect(
          find.textContaining(english),
          findsNothing,
          reason: '$route must not show English copy "$english" in German',
        );
      }
    }

    de.router.go('/inventory');
    await tester.pumpAndSettle();
    expect(find.text('Die Lagerverwaltung ist noch nicht verfügbar.'), findsOneWidget);
    expect(find.text('Nur lesen'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Erneut versuchen'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(de.router.state.matchedLocation, '/inventory');

    await _driveWizardToAbschluss(tester, de, continueLabel: 'Weiter', completionHeading: 'Einrichtung abgeschlossen');
    expect(find.text('Einrichtung abgeschlossen'), findsWidgets);
    await de.db.close();
    await tester.tap(find.widgetWithText(FilledButton, 'Einrichtung abgeschlossen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Das Profil konnte nicht gespeichert werden.'), findsOneWidget);
    de.dispose();
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
    expect(_parityFindings(de, en, required), isEmpty);

    // Negative path: a key present in de but absent in en must fail with the
    // locale and the missing key named (spec scenario "Missing required
    // route-state key fails parity check").
    final Map<String, dynamic> enMissingSetupTitle = Map<String, dynamic>.from(en)..remove('setupTitle');
    final List<String> findings = _parityFindings(de, enMissingSetupTitle, required);
    expect(findings, isNotEmpty);
    expect(findings.join('\n'), contains('en missing key: setupTitle'));
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

    // Production navigation destination in English, activated with Enter.
    final _ProductionHarness en = await _exerciseSidebarKeyboard(
      tester,
      locale: const Locale('en'),
      destinationLabel: 'Invoices',
      path: '/invoices',
      key: LogicalKeyboardKey.enter,
    );
    en.dispose();

    // The same contract in German, activated with Space.
    await _exerciseSidebarKeyboard(
      tester,
      locale: const Locale('de'),
      destinationLabel: 'Belege',
      path: '/receipts',
      key: LogicalKeyboardKey.space,
    );
  });

  testWidgets('test_narrow_loading_and_error_states_remain_reachable', (WidgetTester tester) async {
    final _ProductionHarness harness = await _pumpProduction(
      tester,
      const Locale('en'),
      '/inventory',
      viewport: const Size(320, 900),
    );
    addTearDown(harness.dispose);

    // The inventory boundary copy fits the documented narrow viewport.
    expect(find.text('Inventory management is not available yet.'), findsOneWidget);
    expect(find.text('Back to overview'), findsOneWidget);
    _expectOnScreen(tester, find.text('Inventory management is not available yet.'));
    _expectOnScreen(tester, find.text('Back to overview'));

    // A documented list route walks loading -> empty -> data -> error at 320 px.
    // go() lands on the router a frame before the destination builds; pump one
    // frame at a time so the loading state is observed before the query settles.
    harness.router.go('/contacts');
    bool sawLoading = false;
    for (int i = 0; i < 12 && !sawLoading; i++) {
      await tester.pump();
      sawLoading = find.byType(SkeletonBox).evaluate().isNotEmpty;
    }
    expect(sawLoading, isTrue, reason: 'loading state renders skeletons');
    await tester.pumpAndSettle();

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create customer'), findsOneWidget);
    expect(find.byTooltip('Create customer'), findsOneWidget);
    _expectOnScreen(tester, find.text('No entries yet'));
    _expectOnScreen(tester, find.widgetWithText(FilledButton, 'Create customer'));

    await harness.db.executor.runInsert(
      'INSERT INTO kunden (anrede, name, strasse, plz, ort, land, kundennummer) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>['Herr', 'Ada Lovelace', 'Main Street 1', '10115', 'Berlin', 'DE', 'KD-0001'],
    );
    await tester.enterText(find.byType(TextField).first, 'Ada');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ada Lovelace'), findsOneWidget);
    _expectOnScreen(tester, find.textContaining('Ada Lovelace'));

    // Filtered empty state keeps its reset path.
    await tester.enterText(find.byType(TextField).first, 'zzz-no-match');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('No entries yet'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ada Lovelace'), findsOneWidget);

    // Error state through a failing reload after the database closes.
    await harness.db.close();
    await tester.enterText(find.byType(TextField).first, 'zzz-retry');
    await tester.pumpAndSettle();
    expect(find.text('Data unavailable'), findsOneWidget);
    expect(find.text('The data could not be loaded. Please retry.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    _expectOnScreen(tester, find.text('Data unavailable'));
    _expectOnScreen(tester, find.widgetWithText(FilledButton, 'Retry'));

    // The error action stays reachable by keyboard and semantics.
    final SemanticsHandle semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Retry'), findsOneWidget);
    semantics.dispose();
    final FocusNode retryFocus = Focus.of(tester.element(find.text('Retry')));
    retryFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(retryFocus.hasFocus, isTrue, reason: 'the error action must be visibly focusable');
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue, reason: 'Enter must activate Retry');
    await tester.pumpAndSettle();
    expect(find.text('Data unavailable'), findsOneWidget, reason: 'Retry keeps the route mounted with the error state');
  });
}

Future<void> _driveWizardToAbschluss(
  WidgetTester tester,
  _ProductionHarness harness, {
  required String continueLabel,
  required String completionHeading,
}) async {
  harness.router.go('/setup');
  await tester.pumpAndSettle();
  // Stammdaten: company name is required.
  await tester.enterText(find.byType(TextField).at(0), 'Lokalisierung GmbH');
  await tester.tap(find.widgetWithText(FilledButton, continueLabel));
  await tester.pumpAndSettle();
  // Konten: a valid IBAN is required, cash balance defaults to 0.00.
  await tester.enterText(find.byType(TextField).at(0), 'DE89370400440532013000');
  await tester.tap(find.widgetWithText(FilledButton, continueLabel));
  await tester.pumpAndSettle();
  // Kategorien: the first category chip is preselected.
  await tester.tap(find.widgetWithText(FilledButton, continueLabel));
  await tester.pumpAndSettle();
  expect(find.text(completionHeading), findsWidgets);
}

Future<_ProductionHarness> _pumpProduction(
  WidgetTester tester,
  Locale locale,
  String location, {
  Size viewport = const Size(1400, 900),
}) async {
  // The production notifier uses the platform-backed plugin. Tests must
  // install its in-memory implementation before the notifier's build
  // microtask runs, otherwise getInstance waits forever on the VM channel.
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Localization GmbH']);
  final ProviderContainer container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  final GoRouter router = container.read(appRouterProvider);
  tester.view.physicalSize = viewport;
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

/// Mounts the production app at [locale], focuses the sidebar destination
/// labeled [destinationLabel], activates it with [key], and asserts the spec
/// contract: localized name, role and selected state through semantics,
/// Enter/Space activation, and visible focus retained across navigation.
Future<_ProductionHarness> _exerciseSidebarKeyboard(
  WidgetTester tester, {
  required Locale locale,
  required String destinationLabel,
  required String path,
  required LogicalKeyboardKey key,
}) async {
  final _ProductionHarness harness = await _pumpProduction(tester, locale, '/');
  addTearDown(harness.dispose);
  final SemanticsHandle semantics = tester.ensureSemantics();
  // The semantics tree is rebuilt on the next frame after the handle is
  // installed; node lookups below need that frame.
  await tester.pumpAndSettle();

  final Finder tile = find.widgetWithText(ListTile, destinationLabel);
  expect(tile, findsOneWidget, reason: 'sidebar must expose $destinationLabel');

  final Finder destinationSemantics = find.ancestor(
    of: tile,
    matching: find.byWidgetPredicate(
      (Widget widget) => widget is Semantics && widget.properties.label == destinationLabel,
    ),
  );
  expect(destinationSemantics, findsOneWidget, reason: 'semantics label the destination');
  final Semantics semanticsNode = tester.widget<Semantics>(destinationSemantics);
  expect(semanticsNode.properties.label, destinationLabel, reason: 'semantics announce the localized name');
  expect(semanticsNode.properties.button, isTrue, reason: 'destination exposes its button role');
  expect(semanticsNode.properties.selected, isFalse, reason: 'destination starts unselected');

  final FocusNode focus = Focus.of(tester.element(tile));
  focus.requestFocus();
  await tester.pumpAndSettle();
  expect(focus.hasFocus, isTrue, reason: 'focused destination keeps a visible focus indicator');
  expect(tester.binding.focusManager.primaryFocus, focus);

  expect(await tester.sendKeyEvent(key), isTrue, reason: '$key must activate the destination');
  await tester.pumpAndSettle();
  expect(harness.router.state.matchedLocation, path, reason: 'activation navigates to $path');

  final Finder selectedTile = find.widgetWithText(ListTile, destinationLabel);
  expect(tester.widget<ListTile>(selectedTile).selected, isTrue, reason: 'activated destination is selected');
  final Finder selectedSemanticsFinder = find.ancestor(
    of: selectedTile,
    matching: find.byWidgetPredicate(
      (Widget widget) => widget is Semantics && widget.properties.label == destinationLabel,
    ),
  );
  final Semantics selectedSemantics = tester.widget<Semantics>(selectedSemanticsFinder);
  expect(selectedSemantics.properties.label, destinationLabel);
  expect(selectedSemantics.properties.button, isTrue);
  expect(selectedSemantics.properties.selected, isTrue, reason: 'selected state is announced through semantics');
  expect(focus.hasFocus, isTrue, reason: 'focus survives activation');

  semantics.dispose();
  return harness;
}

/// Asserts [finder] lies fully inside the logical viewport — no clipped text.
void _expectOnScreen(WidgetTester tester, Finder finder) {
  final Size logical = tester.view.physicalSize / tester.view.devicePixelRatio;
  final Rect bounds = Offset.zero & logical;
  final Rect rect = tester.getRect(finder);
  expect(
    rect.left >= bounds.left && rect.top >= bounds.top && rect.right <= bounds.right && rect.bottom <= bounds.bottom,
    isTrue,
    reason: '$finder at $rect must stay within the narrow viewport $bounds',
  );
}

/// German phrases that must never appear while English is active on the
/// documented routes (spec: "never expose an unrelated hardcoded German
/// literal when English is active"). Sourced from the pre-localization audit
/// of each route's visible copy.
const List<String> _germanLeakPhrases = <String>[
  'Lagerverwaltung',
  'Datei wählen',
  'Keine Warnungen',
  'Einstellungen',
  'Keine Fristen',
  'Keine Mahnungen',
  'Keine Zahlungen',
  'Neue Rechnung',
  'UStVA fällig',
  'Zahlungseingänge',
  'Überfällige Rechnungen',
  'Artikel (nicht verfügbar)',
  'Filter zurücksetzen',
];

/// English phrases that must never appear while German is active on the
/// documented routes (German is the primary locale; no English leakage).
const List<String> _englishLeakPhrases = <String>[
  'Inventory management',
  'No entries yet',
  'Data could not be loaded',
  'No matches',
  'Back to overview',
  'Reset filters',
];

/// Curated production scope for the unkeyed-visible-copy check: every
/// documented-route surface this change touches for visible copy.
const List<String> _visibleCopyScanPaths = <String>[
  'lib/core/localization.dart',
  'lib/core/router/app_router.dart',
  'lib/design_system/components/app_money.dart',
  'lib/design_system/components/app_page_header.dart',
  'lib/design_system/components/app_sidebar.dart',
  'lib/design_system/components/finance_list_surface.dart',
  'lib/design_system/theme/app_typography.dart',
  'lib/features/bank_import/bank_import_page.dart',
  'lib/features/bank_import/bank_import_service.dart',
  'lib/features/dashboard/dashboard_entity.dart',
  'lib/features/dashboard/dashboard_page.dart',
  'lib/features/dashboard/dashboard_repository.dart',
  'lib/features/dashboard/dashboard_widgets.dart',
  'lib/features/pdf/pdf_generator.dart',
  'lib/features/setup/wizard_page.dart',
  'lib/features/setup/wizard_service.dart',
  'lib/pages/rechnungen/invoice_document_page.dart',
];

/// Non-visible literals excluded from the unkeyed-visible-copy scan, each
/// category justified: format patterns and font family names are machine
/// inputs; `Meine Firma`/`Giro`/`Kasse`/`Standard` are persisted fallback
/// data written to records; the remaining entries are machine-parsed XML/CSV
/// tokens, console diagnostic metadata, and debug-only tags.
const Set<String> _nonVisibleDataLiterals = <String>{
  'MM/dd/yyyy',
  'MMMM d, yyyy',
  'd. MMMM yyyy',
  'Inter',
  'Meine Firma',
  'Giro',
  'Kasse',
  'Standard',
  'BkToCstmrStmt',
  'BkToStmRpt',
  'BkToCstmr',
  'Dt',
  'BookgDt',
  'ValDt',
  'verwendungszweck ',
  'OpenAccounting route data',
  'widget ',
};

final RegExp _literalPattern = RegExp(r"'([^'\n]*)'");
final RegExp _codePrefixPattern = RegExp(
  r'^(lib/|assets/|package:|test/|/|SELECT|INSERT|UPDATE|DELETE|WHERE|GROUP|ORDER|PRAGMA|ALTER|CREATE|DROP|ON |AND |OR |flutter\.|openaccounting\.|http|#|RE-)',
);
final RegExp _sqlLinePattern = RegExp(r'\b(SELECT|WHERE|BETWEEN|COALESCE|VALUES|INSERT|UPDATE|CASE|FROM)\b');
final RegExp _ibanPattern = RegExp(r'^[A-Z]{2}\d');
final RegExp _lowercasePhrasePattern = RegExp('^[a-z_][a-z0-9_]* [a-z_(]');
final RegExp _identifierListPattern = RegExp('^[a-z_][a-z0-9_]*, ');

/// All non-metadata string values from both ARB catalogs.
Set<String> _catalogValues() {
  final Map<String, dynamic> de =
      json.decode(File('assets/l10n/l10n_de.arb').readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic> en =
      json.decode(File('assets/l10n/l10n_en.arb').readAsStringSync()) as Map<String, dynamic>;
  return <String>{
    for (final MapEntry<String, dynamic> entry in de.entries)
      if (entry.value is String && !entry.key.startsWith('@')) entry.value as String,
    for (final MapEntry<String, dynamic> entry in en.entries)
      if (entry.value is String && !entry.key.startsWith('@')) entry.value as String,
  };
}

/// Scans one source file's text for visible string literals that are neither
/// present in the ARB catalogs nor exempted. Returns one finding per literal:
/// `<path>:<line>: missing key for visible literal "<literal>"`.
List<String> _scanSource(String path, String source, Set<String> catalogValues) {
  final List<String> findings = <String>[];
  final List<String> lines = source.split('\n');
  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    // Debug output, throws, and SQL statements are not production-visible UI.
    if (line.contains('debugPrint(') || line.contains('throw ') || line.contains('ArgumentError')) continue;
    if (line.contains('StateError') || _sqlLinePattern.hasMatch(line)) continue;
    for (final Match match in _literalPattern.allMatches(line)) {
      final String literal = match.group(1)!;
      final String value = literal.split(r'$').first;
      if (value.trim().isEmpty) continue;
      // Interpolation residue, placeholder templates, and format patterns.
      if (value.contains('{') || value.contains('}') || value.contains('%')) continue;
      if (_codePrefixPattern.hasMatch(value)) continue;
      // Parameterized SQL and column-list fragments.
      if (value.contains('?') || _identifierListPattern.hasMatch(value)) continue;
      if (!value.contains(RegExp('[a-z]'))) continue;
      // Structure heuristic: visible copy has a space or starts uppercase;
      // lowercase machine phrases (CSV keywords, log words) are skipped.
      final bool visibleShape =
          value.contains(' ') || (value.startsWith(RegExp('[A-Z]')) && value.contains(RegExp('[a-z]')));
      if (!visibleShape) continue;
      if (_lowercasePhrasePattern.hasMatch(value)) continue;
      if (_ibanPattern.hasMatch(value)) continue;
      if (catalogValues.contains(value)) continue;
      if (_nonVisibleDataLiterals.contains(value)) continue;
      findings.add('$path:${i + 1}: missing key for visible literal "$value"');
    }
  }
  return findings;
}

/// Runs [_scanSource] over every file in [paths].
List<String> _findUnkeyedVisibleLiterals(List<String> paths, Set<String> catalogValues) {
  final List<String> findings = <String>[];
  for (final String path in paths) {
    findings.addAll(_scanSource(path, File(path).readAsStringSync(), catalogValues));
  }
  return findings;
}

/// Reports locale/key problems for the ARB catalogs and required-key list.
List<String> _parityFindings(Map<String, dynamic> de, Map<String, dynamic> en, List<String> required) {
  final List<String> findings = <String>[];
  final Set<String> deKeys = de.keys.toSet();
  final Set<String> enKeys = en.keys.toSet();
  if (deKeys != enKeys) {
    for (final String key in deKeys.difference(enKeys)) {
      findings.add('en missing key: $key');
    }
    for (final String key in enKeys.difference(deKeys)) {
      findings.add('de missing key: $key');
    }
  }
  for (final String key in required) {
    if (!de.containsKey(key)) {
      findings.add('de missing required key: $key');
    }
    if (!en.containsKey(key)) {
      findings.add('en missing required key: $key');
    }
  }
  return findings;
}

/// A preference store that refuses every mutation, standing in for the spec
/// scenario where the locale preference write is rejected at runtime.
final class _RejectingPreferenceStore extends SharedPreferencesStorePlatform {
  int rejectedWrites = 0;

  @override
  Future<Map<String, Object>> getAll() async => <String, Object>{};

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    rejectedWrites++;
    throw StateError('preference write rejected by test store');
  }

  @override
  Future<bool> remove(String key) async => false;

  @override
  Future<bool> clear() async => false;
}

final class _ProductionHarness {
  _ProductionHarness({required this.container, required this.router, required this.db});

  final ProviderContainer container;
  final GoRouter router;
  final AppDatabase db;

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    router.dispose();
    container.dispose();
    unawaited(db.close());
  }
}
