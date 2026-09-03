// failing test for DESIGN §3 — shell persists on every primary route + not black fallback.
// Will be green after lib/app/app_shell.dart extracts AppShell with sidebar/header/canvas.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';

AppDatabase _emptyDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

Future<AppDatabase> _configuredDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.ensureOpen();
  await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
  return db;
}

Widget _wrap(GoRouter router) {
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  group('Desktop Shell Layout — DESIGN §3', () {
    testWidgets('test_shell_renders_on_every_primary_route', (WidgetTester tester) async {
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // Primary routes per spec: '/', '/invoices', '/receipts', '/taxes', '/settings'.
      // Also check '/banking', '/contacts', '/reports', '/help' as shell coverage.
      const routes = <String, String>{
        '/': 'Übersicht',
        '/invoices': 'Rechnungen',
        '/receipts': 'Belege',
        '/taxes': 'Steuern',
        '/settings': 'Einstellungen',
      };

      for (final entry in routes.entries) {
        final path = entry.key;
        final expectedTitle = entry.value;
        router.go(path);
        await tester.pumpAndSettle();

        expect(
          find.byType(AppShell),
          findsOneWidget,
          reason:
              'AppShell missing on $path — shell must persist on every primary '
              'route per DESIGN §3. Verify ShellRoute builder wraps AppShell '
              'and router initialLocation is inside shell.',
        );

        // Sidebar must be present — DESIGN §4 taxonomy ÜBERSICHT/GESCHÄFT/STEUERN.
        expect(
          find.text('Rechnungen'),
          findsWidgets,
          reason:
              'Sidebar item Rechnungen not found on $path — sidebar must be '
              'persistent inside AppShell, not per-page.',
        );

        // Content canvas title — header shows correct page title.
        // Sidebar also contains same label, so at least one widget is enough.
        expect(
          find.text(expectedTitle),
          findsWidgets,
          reason:
              'Expected title "$expectedTitle" not found on $path — header '
              'must show correct page title per spec scenario.',
        );

        // Shell must not be black Container fallback — DESIGN §3.
        final hasBlackContainer = find
            .byWidgetPredicate((Widget w) => w is Container && w.color == Colors.black)
            .evaluate()
            .isNotEmpty;
        expect(
          hasBlackContainer,
          isFalse,
          reason:
              'Black Container fallback found on $path — shell must render '
              'sidebar/header/canvas, not Container(color: Colors.black).',
        );

        // Header presence — every primary page needs header/toolbar per DESIGN §5.
        // Dashboard currently has no AppBar, so this fails until AppPageHeader exists.
        expect(
          find.byType(AppBar),
          findsOneWidget,
          reason:
              'Header AppBar missing on $path — every primary page must have '
              'AppPageHeader/AppBar with title per DESIGN §5. Dashboard/Belege '
              'currently use plain Scaffold without header.',
        );
      }
    });

    testWidgets('test_shell_not_black_fallback', (WidgetTester tester) async {
      final db = _emptyDb();
      await db.ensureOpen();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      expect(
        router.state.matchedLocation,
        '/setup',
        reason: 'Empty unternehmen should redirect to /setup via hasUnternehmen guard',
      );
      expect(
        find.text('Setup Wizard'),
        findsOneWidget,
        reason: 'Setup Wizard text must be visible when redirected to /setup',
      );

      // Setup must be INSIDE shell — currently OUTSIDE ShellRoute, so AppShell missing.
      expect(
        find.byType(AppShell),
        findsOneWidget,
        reason:
            'Setup route /setup must be INSIDE AppShell per DESIGN §3 — currently '
            'is outside ShellRoute (GoRoute /setup above ShellRoute), so shell '
            'is absent and page shows black fallback without sidebar/header. '
            'Move /setup into ShellRoute or wrap SetupPage with AppShell.',
      );

      // Not black fallback.
      final hasBlackContainer = find
          .byWidgetPredicate((Widget w) => w is Container && w.color == Colors.black)
          .evaluate()
          .isNotEmpty;
      expect(
        hasBlackContainer,
        isFalse,
        reason:
            'Setup page must not be black Container fallback — should show sidebar '
            '+ header + constrained canvas, not full-screen black.',
      );

      // Sidebar must be visible even on setup — proves shell wrapping.
      expect(
        find.text('Rechnungen'),
        findsWidgets,
        reason:
            'Sidebar must be visible on /setup inside shell — missing because '
            '/setup is outside ShellRoute. See design.md D4.',
      );

      // Constrained width 720–900 — setup form must be capped per DESIGN §6.
      final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final hasBounded = boxes.any(
        (ConstrainedBox c) => c.constraints.maxWidth >= 720 && c.constraints.maxWidth <= 900,
      );
      expect(
        hasBounded,
        isTrue,
        reason:
            'Setup content must be ConstrainedBox maxWidth 720–900 centered per '
            'DESIGN §6 — currently SetupPage is plain Scaffold Center Text without '
            '720-900 constraint. Add ConstrainedBox(maxWidth: 900) + Center.',
      );
    });
  });
}
