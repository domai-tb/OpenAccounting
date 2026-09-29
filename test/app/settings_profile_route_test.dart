import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/l10n/l10n.dart';

Future<AppDatabase> _configuredDatabase() async {
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Settings GmbH']);
  return db;
}

Widget _wrapRoute({
  required GoRouter router,
  required AppDatabase db,
  required ProfileManager manager,
  required Locale locale,
}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db), profileManagerProvider.overrideWithValue(manager)],
    child: MaterialApp.router(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

Future<void> _openSettings({
  required WidgetTester tester,
  required GoRouter router,
  required AppDatabase db,
  required ProfileManager manager,
  Locale locale = const Locale('de'),
}) async {
  await tester.pumpWidget(_wrapRoute(router: router, db: db, manager: manager, locale: locale));
  router.go('/settings');
  await tester.pump();
}

void main() {
  testWidgets('test_settings_route_uses_injected_profile_manager', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDatabase();
    final _ScriptedProfileManager manager = _ScriptedProfileManager(profileName: '__settings_injected_profile__');
    final router = createRouter(db);
    addTearDown(db.close);

    await _openSettings(tester: tester, router: router, db: db, manager: manager);
    await tester.pump();

    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.text('__settings_injected_profile__'), findsOneWidget);
    expect(manager.activeProfileCalls, 1);
    expect(manager.listProfilesCalls, 1);
    expect(() => manager.assertUsed(), returnsNormally);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('test_settings_profile_load_timeout_reaches_terminal_error', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDatabase();
    final _ScriptedProfileManager manager = _ScriptedProfileManager(profileName: 'Default', blockLoads: true);
    final router = createRouter(db);
    addTearDown(db.close);

    await _openSettings(tester: tester, router: router, db: db, manager: manager);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.text('Profile konnten nicht geladen werden'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('test_settings_profile_retry_recovers', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDatabase();
    final _ScriptedProfileManager manager = _ScriptedProfileManager(
      profileName: 'Default',
      blockLoads: true,
      recoversOnRetry: true,
    );
    final router = createRouter(db);
    addTearDown(db.close);

    await _openSettings(tester: tester, router: router, db: db, manager: manager);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.text('Profile konnten nicht geladen werden'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(find.text('Profile konnten nicht geladen werden'), findsNothing);
    expect(find.text('Erneut versuchen'), findsNothing);
    expect(find.text('Default'), findsOneWidget);
    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('test_settings_profile_retry_remains_bounded', (WidgetTester tester) async {
    final AppDatabase db = await _configuredDatabase();
    final _ScriptedProfileManager manager = _ScriptedProfileManager(profileName: 'Default', blockLoads: true);
    final router = createRouter(db);
    addTearDown(db.close);

    await _openSettings(tester: tester, router: router, db: db, manager: manager);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(find.text('Profile konnten nicht geladen werden'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(find.text('Profile konnten nicht geladen werden'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('test_settings_profile_error_uses_german_locale', (WidgetTester tester) async {
    final String arb = File('assets/l10n/l10n_de.arb').readAsStringSync();
    expect(arb, contains('"profileLoadError":'));
    final AppDatabase db = await _configuredDatabase();
    final _ScriptedProfileManager manager = _ScriptedProfileManager(profileName: 'Default', blockLoads: true);
    final router = createRouter(db);
    addTearDown(db.close);

    await _openSettings(tester: tester, router: router, db: db, manager: manager, locale: const Locale('de'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.text('Profile konnten nicht geladen werden'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.text('Profiles could not be loaded'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Default'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('test_settings_profile_error_uses_english_locale', (WidgetTester tester) async {
    final String arb = File('assets/l10n/l10n_en.arb').readAsStringSync();
    expect(arb, contains('"profileLoadError":'));
    final AppDatabase db = await _configuredDatabase();
    final _ScriptedProfileManager manager = _ScriptedProfileManager(profileName: 'Default', blockLoads: true);
    final router = createRouter(db);
    addTearDown(db.close);

    await _openSettings(tester: tester, router: router, db: db, manager: manager, locale: const Locale('en'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 250),
    );

    expect(router.state.matchedLocation, '/settings');
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(AppPage), findsOneWidget);
    expect(find.text('Profiles could not be loaded'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Profile konnten nicht geladen werden'), findsNothing);
    expect(find.text('Erneut versuchen'), findsNothing);
    expect(find.text('Default'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  test('test_profile_load_timeout_constant_is_shared_by_initial_and_retry', () {
    final String source = File('lib/core/router/app_router.dart').readAsStringSync();
    expect(RegExp(r'const Duration _profileLoadTimeout = Duration\(seconds: 2\);').allMatches(source), hasLength(1));

    final int loadStart = source.indexOf('Future<_ProfileSnapshot> _loadProfiles()');
    final int reloadStart = source.indexOf('void _reloadProfiles()', loadStart);
    expect(loadStart, greaterThanOrEqualTo(0));
    expect(reloadStart, greaterThan(loadStart));
    final String loadRegion = source.substring(loadStart, reloadStart);
    expect(loadRegion, contains('Future.wait'));
    expect(loadRegion, contains('.timeout(_profileLoadTimeout)'));

    final int reloadEnd = source.indexOf('Future<void> _selectProfile', reloadStart);
    expect(reloadEnd, greaterThan(reloadStart));
    final String reloadRegion = source.substring(reloadStart, reloadEnd);
    expect(reloadRegion, contains('_profiles = _loadProfiles()'));
    expect(reloadRegion, isNot(contains('Duration')));
    expect(reloadRegion, isNot(contains('.timeout')));
  });
}

final class _ScriptedProfileManager extends ProfileManager {
  _ScriptedProfileManager({required this.profileName, this.blockLoads = false, this.recoversOnRetry = false});

  final String profileName;
  final bool blockLoads;
  final bool recoversOnRetry;
  int activeProfileCalls = 0;
  int listProfilesCalls = 0;

  bool _blocks(int calls) => blockLoads && (!recoversOnRetry || calls == 1);

  @override
  Future<String> getActiveProfile() {
    activeProfileCalls++;
    if (_blocks(activeProfileCalls)) return Completer<String>().future;
    return Future<String>.value(profileName);
  }

  @override
  Future<List<String>> listProfiles() {
    listProfilesCalls++;
    if (_blocks(listProfilesCalls)) return Completer<List<String>>().future;
    return Future<List<String>>.value(<String>[profileName]);
  }

  void assertUsed() {
    if (activeProfileCalls == 0 || listProfilesCalls == 0) {
      throw StateError('injected ProfileManager was not used');
    }
  }
}
