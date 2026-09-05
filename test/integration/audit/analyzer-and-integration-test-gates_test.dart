// ignore_for_file: file_names

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';

void main() {
  test('test_analyzer_and_integration_test_gates_1_1_analyzer_gate_passes', () async {
    final ProcessResult result = await Process.run(
      'fvm',
      <String>['flutter', 'analyze'],
      workingDirectory: Directory.current.path,
      runInShell: true,
    );
    final String output = '${result.stdout}\n${result.stderr}';

    expect(result.exitCode, equals(0), reason: 'Pinned flutter analyze must exit zero.\n$output');
    expect(output, contains('No issues found!'), reason: 'Pinned flutter analyze must emit no diagnostics.\n$output');
  });

  test('test_analyzer_and_integration_test_gates_1_2_new_diagnostics_block_acceptance', () async {
    final Directory fixture = await Directory.systemTemp.createTemp('openaccounting-analyzer-gate-');
    addTearDown(() => fixture.delete(recursive: true));
    final File source = File('${fixture.path}/main.dart');
    await source.writeAsString('void main() { final unused = 1; }\n');

    final ProcessResult result = await Process.run(
      'fvm',
      <String>['dart', 'run', 'tool/release_gate.dart', fixture.path],
      workingDirectory: Directory.current.path,
      runInShell: true,
    );
    final String output = '${result.stdout}\n${result.stderr}';

    expect(result.exitCode, isNot(equals(0)), reason: 'A new analyzer diagnostic must block acceptance.\n$output');
    expect(output, contains('unused_local_variable'), reason: 'The gate must report the diagnostic code.\n$output');
    expect(output, contains(source.path), reason: 'The gate must report the diagnostic source location.\n$output');
  });

  testWidgets('test_analyzer_and_integration_test_gates_2_1_route_smoke_tests_prove_reachability', (tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureOpen();
    await db.executor.runInsert('INSERT INTO unternehmen (name, dashboard_config) VALUES (?, ?)', <Object?>[
      'Integration GmbH',
      null,
    ]);
    await db.executor.runInsert(
      'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>['Integration Kunde', 'Teststraße 1', '10115', 'Berlin', 'DE', 'Frau'],
    );

    final ProviderContainer container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    final router = container.read(appRouterProvider);
    addTearDown(container.dispose);
    addTearDown(db.close);

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenAccountingApp()));
    await tester.pumpAndSettle();

    final List<AppRoute> primaryRoutes = AppRoute.values.where((AppRoute route) => route != AppRoute.setup).toList();
    for (final AppRoute route in primaryRoutes) {
      router.go(route.path);
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, route.path, reason: 'Route ${route.path} must be reachable');
      if (route == AppRoute.dashboard) {
        expect(find.text('Offene Rechnungen'), findsOneWidget);
      } else {
        expect(
          find.text('Datenbankabfrage abgeschlossen'),
          findsOneWidget,
          reason: 'Route ${route.path} must query data',
        );
        expect(
          find.textContaining('Datensätze:'),
          findsOneWidget,
          reason: 'Route ${route.path} must expose query results',
        );
      }
    }
  });

  testWidgets('test_analyzer_and_integration_test_gates_2_2_runtime_provider_errors_fail_tests', (tester) async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.ensureOpen();
    await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Integration GmbH']);
    final _ProviderFailureObserver observer = _ProviderFailureObserver();
    final List<String> debugMessages = <String>[];
    final DebugPrintCallback previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        debugMessages.add(message);
      }
    };
    try {
      final ProviderContainer container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        observers: [observer],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const OpenAccountingApp()));
      await tester.pumpAndSettle();

      expect(
        observer.failures,
        isEmpty,
        reason: 'Provider readiness failures must fail this production-composition gate.',
      );
      expect(debugMessages, isEmpty, reason: 'Readiness errors must not be hidden in debug logs.');
      expect(find.text('Fehler beim Laden'), findsNothing);
    } finally {
      debugPrint = previousDebugPrint;
    }
  });
}

final class _ProviderFailureObserver extends ProviderObserver {
  final List<Object> failures = <Object>[];

  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    failures.add(error);
  }
}
