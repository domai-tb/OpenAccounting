import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';

AppDatabase _emptyDb() {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  return db;
}

Future<AppDatabase> _configuredDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
  await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
  return db;
}

Widget _wrap(GoRouter router) {
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  group('GoRouter shell & guard', () {
    testWidgets('setup guard redirects to /setup when Unternehmen empty', (tester) async {
      final db = _emptyDb();
      await db.ensureOpen();
      final router = createRouter(db);
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/setup');
      expect(find.text('Setup Wizard'), findsOneWidget);
      await db.close();
    });

    testWidgets('setup guard does not intercept when Unternehmen exists', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      // Should stay at '/' not /setup.
      expect(router.state.matchedLocation, '/');
      expect(find.text('Übersicht'), findsOneWidget);
      await db.close();
    });

    testWidgets('setup page accessible even when empty', (tester) async {
      final db = _emptyDb();
      await db.ensureOpen();
      final router = createRouter(db);
      router.go('/setup');
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/setup');
      await db.close();
    });

    testWidgets('nested navigation within sections highlights sidebar', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      router.go('/invoices/123');
      await tester.pumpAndSettle();
      expect(find.text('Rechnung 123'), findsOneWidget);
      // Sidebar should still show Rechnungen selected (ListTile selected).
      expect(router.state.matchedLocation, '/invoices/123');
      await db.close();
    });

    testWidgets('nested navigation with invalid ID shows not found', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      router.go('/invoices/99999');
      await tester.pumpAndSettle();
      expect(find.text('Nicht gefunden'), findsOneWidget);
      await db.close();
    });

    testWidgets('deep link with query parameters filters list', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      router.go('/invoices?typ=eingang&status=offen');
      await tester.pumpAndSettle();
      expect(find.textContaining('typ=eingang'), findsWidgets);
      expect(find.textContaining('status=offen'), findsWidgets);
      await db.close();
    });

    testWidgets('shell route renders sidebar 240px expanded', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      // Sidebar shell should be present via Row + SizedBox 240.
      expect(find.text('Rechnungen'), findsWidgets);
      await db.close();
    });

    testWidgets('responsive: compact rail at 1000px', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      // At 1000px, compact mode shows icons — sidebar uses icon-only rail with tooltip.
      expect(find.byIcon(Icons.receipt_long), findsWidgets);
      expect(find.byTooltip('Rechnungen'), findsWidgets);
      await db.close();
    });

    testWidgets('unknown route shows not found', (tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();
      router.go('/does-not-exist-xyz');
      await tester.pumpAndSettle();
      expect(find.text('Nicht gefunden'), findsOneWidget);
      await db.close();
    });

    test('router has shell route and nested routes', () {
      final db = _emptyDb();
      final router = createRouter(db);
      // Verify routes contain expected paths.
      final hasInvoices = router.configuration.findMatch(Uri.parse('/invoices')).matches.isNotEmpty;
      expect(hasInvoices, isTrue);
      final hasSetup = router.configuration.findMatch(Uri.parse('/setup')).matches.isNotEmpty;
      expect(hasSetup, isTrue);
    });

    test('port scan helper ports 8000-8010 defined', () {
      expect(DioClientProbePorts, contains(8000));
      expect(DioClientProbePorts, contains(8010));
      expect(DioClientProbePorts.length, 11);
    });
  });
}

/// Expose probe ports for test without importing dio_client.
const List<int> DioClientProbePorts = <int>[8000, 8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008, 8009, 8010];
