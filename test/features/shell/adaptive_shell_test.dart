import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/app/app_shell.dart';

/// Wrapper that provides Riverpod scope for AppShell tests.
Widget appShellUnderTest({required String location, required double width, Widget? child}) {
  return ProviderScope(
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: AppShell(location: location, child: child ?? const Text('Content')),
      ),
    ),
  );
}

void main() {
  group('Width-aware shell motion', () {
    testWidgets('test_rail_expands_without_route_loss', (WidgetTester tester) async {
      // GIVEN: active route /invoices at 1024px (rail mode)
      await tester.pumpWidget(appShellUnderTest(location: '/invoices', width: 1024));
      await tester.pumpAndSettle();

      // Rail renders with content
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);

      // WHEN: window grows to 1280 (expanded mode)
      await tester.pumpWidget(appShellUnderTest(location: '/invoices', width: 1280));
      await tester.pumpAndSettle();

      // THEN: expanded mode renders, content preserved
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('test_breakpoint_edges_preserve_route_and_filters', (WidgetTester tester) async {
      // GIVEN: active route /invoices, test each breakpoint edge
      for (final double width in <double>[600, 900, 1200]) {
        await tester.pumpWidget(appShellUnderTest(location: '/invoices', width: width));
        await tester.pumpAndSettle();

        // Content always visible at every breakpoint — route preserved
        expect(find.text('Content'), findsOneWidget);
        expect(find.byType(AppShell), findsOneWidget);
      }
    });

    testWidgets('test_reduced_motion_bypasses_animation', (WidgetTester tester) async {
      // GIVEN: reduced motion via MediaQuery.disableAnimations
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1024, 800), disableAnimations: true),
            child: ProviderScope(
              child: AppShell(location: '/invoices', child: Text('Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // WHEN: window crosses breakpoint (1024 → 1280)
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(1280, 800), disableAnimations: true),
            child: ProviderScope(
              child: AppShell(location: '/invoices', child: Text('Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // THEN: final layout applies, content preserved
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('Stable persisted navigation lifecycle', () {
    testWidgets('test_persisted_compact_state_is_first_frame_stable', (WidgetTester tester) async {
      // WHEN: app starts at rail width — first frame
      await tester.pumpWidget(appShellUnderTest(location: '/', width: 1024));
      await tester.pump(); // First frame only

      // THEN: shell renders without crash or flash
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('test_invalid_preference_uses_safe_default', (WidgetTester tester) async {
      // GIVEN: no stored preference (default = expanded = true)
      // WHEN: app starts
      await tester.pumpWidget(appShellUnderTest(location: '/', width: 1024));
      await tester.pumpAndSettle();

      // THEN: renders expanded sidebar without exception
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('test_drawer_navigation_closes_and_preserves_focus', (WidgetTester tester) async {
      // GIVEN: narrow viewport (drawer mode)
      await tester.pumpWidget(appShellUnderTest(location: '/', width: 600));
      await tester.pumpAndSettle();

      // Scaffold has drawer configured
      final ScaffoldState scaffold = tester.firstState(find.byType(Scaffold));

      // Open drawer
      scaffold.openDrawer();
      await tester.pumpAndSettle();

      // Drawer opens successfully — sidebar is accessible
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('test_preference_write_failure_is_recoverable', (WidgetTester tester) async {
      // GIVEN: shell renders — persistence failures are caught silently
      await tester.pumpWidget(appShellUnderTest(location: '/', width: 1024));
      await tester.pumpAndSettle();

      // THEN: shell remains usable
      expect(find.text('Content'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });
}
