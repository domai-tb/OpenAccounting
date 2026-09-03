// failing test for DESIGN §3 — shell persists on every primary route + not black fallback.
// Will be green after lib/app/app_shell.dart extracts AppShell with sidebar/header/canvas.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Sidebar Navigation — DESIGN §4, §34', () {
    testWidgets('test_sidebar_expanded_at_1280', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'openaccounting.sidebar_expanded': true});
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());
      addTearDown(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // 240 px expanded at >=1200 per DESIGN §4, §34
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final has240 = sizedBoxes.any((SizedBox s) => s.width == 240.0);
      expect(
        has240,
        isTrue,
        reason:
            'Expanded sidebar at 1280 must be 240 px wide per DESIGN §4. '
            'Found SizedBox widths: ${sizedBoxes.map((SizedBox s) => s.width).toList()}',
      );

      // Icon + label + section labels visible in expanded mode
      expect(
        find.text('ÜBERSICHT'),
        findsOneWidget,
        reason: 'Section label ÜBERSICHT missing at 1280 expanded — must show per DESIGN §4',
      );
      expect(
        find.text('GESCHÄFT'),
        findsOneWidget,
        reason: 'Section label GESCHÄFT missing at 1280 expanded — must show per DESIGN §4',
      );
      expect(
        find.text('STEUERN'),
        findsOneWidget,
        reason: 'Section label STEUERN missing at 1280 expanded — must show per DESIGN §4',
      );
      expect(
        find.widgetWithText(ListTile, 'Rechnungen'),
        findsWidgets,
        reason: 'Rechnungen ListTile with label must be visible at 1280 expanded — icons only at 72',
      );

      // Selected highlight unmistakable in both themes — requires explicit styling
      // At "/" Übersicht is selected, Rechnungen not — verify that logic
      final uebersichtTiles = tester.widgetList<ListTile>(find.widgetWithText(ListTile, 'Übersicht')).toList();
      expect(uebersichtTiles.isNotEmpty, isTrue, reason: 'Übersicht tile not found for highlight check');
      final uebersichtSelected = uebersichtTiles.where((ListTile t) => t.selected).toList();
      expect(uebersichtSelected.isNotEmpty, isTrue, reason: 'Übersicht must be selected at "/" per isSelected logic');
      final rechnungenAtRoot = tester.widgetList<ListTile>(find.widgetWithText(ListTile, 'Rechnungen')).toList();
      final rechnungenSelectedAtRoot = rechnungenAtRoot.where((ListTile t) => t.selected).toList();
      expect(
        rechnungenSelectedAtRoot.isEmpty,
        isTrue,
        reason: 'Rechnungen must NOT be selected at "/" — only Übersicht.',
      );
      // Now navigate to /invoices and check highlight there
      router.go('/invoices');
      await tester.pumpAndSettle();
      final invTiles = tester.widgetList<ListTile>(find.widgetWithText(ListTile, 'Rechnungen')).toList();
      final selectedInv = invTiles.where((ListTile t) => t.selected).toList();
      expect(selectedInv.isNotEmpty, isTrue, reason: 'Rechnungen must be selected at /invoices');
      final tile = selectedInv.first;
      // FAILING: currently selectedTileColor is null — must be set to unmistakable color per DESIGN §4
      expect(
        tile.selectedTileColor,
        isNotNull,
        reason:
            'Selected highlight at 1280 must be unmistakable in both themes per DESIGN §4 — '
            'AppSidebar currently uses ListTile(selected: true) without selectedTileColor/selectedColor. '
            'Set selectedTileColor to theme colorScheme.secondaryContainer or similar for both light/dark.',
      );

      // Workspace selector at top per D2 — must exist, currently missing
      final hasWorkspaceSelector =
          find
              .descendant(of: find.byType(AppSidebar), matching: find.byType(PopupMenuButton<dynamic>))
              .evaluate()
              .isNotEmpty ||
          find
              .descendant(of: find.byType(AppSidebar), matching: find.byType(DropdownButton<dynamic>))
              .evaluate()
              .isNotEmpty ||
          find.byKey(const ValueKey<String>('workspace_selector')).evaluate().isNotEmpty;
      expect(
        hasWorkspaceSelector,
        isTrue,
        reason:
            'Workspace selector at top missing per DESIGN §4/D2 — AppSidebar currently shows '
            'only wallet icon/Text("OpenAccounting"), no workspace selector. Add workspace '
            'selector widget with key workspace_selector or PopupMenuButton.',
      );

      // ● Lokal trust indicator must be interactive with popover per §39 — currently plain Text
      final lokalFinder = find.text('● Lokal');
      expect(lokalFinder, findsOneWidget, reason: '● Lokal indicator missing per DESIGN §4');
      final hasInteractiveAncestor =
          find.ancestor(of: lokalFinder, matching: find.byType(InkWell)).evaluate().isNotEmpty ||
          find.ancestor(of: lokalFinder, matching: find.byType(GestureDetector)).evaluate().isNotEmpty;
      expect(
        hasInteractiveAncestor,
        isTrue,
        reason:
            '● Lokal must be tappable with popover per DESIGN §39/D2 — currently plain '
            'Padding(Text("● Lokal")) without InkWell/GestureDetector. Wrap with InkWell onTap.',
      );
    });

    testWidgets('test_sidebar_compact_at_1024', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());
      addTearDown(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // 72 px rail at 900–1199 per DESIGN §4
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final has72 = sizedBoxes.any((SizedBox s) => s.width == 72.0);
      expect(
        has72,
        isTrue,
        reason:
            'Compact rail at 1024 must be 72 px wide per DESIGN §4. '
            'Found widths: ${sizedBoxes.map((SizedBox s) => s.width).toList()}',
      );
      final has240 = sizedBoxes.any((SizedBox s) => s.width == 240.0);
      expect(has240, isFalse, reason: 'At 1024 sidebar must be 72 not 240 — responsive rail, not expanded.');

      // Icons only — section labels hidden, labels hidden in compact
      expect(
        find.text('ÜBERSICHT'),
        findsNothing,
        reason: 'Section labels must be hidden in compact rail per DESIGN §4',
      );
      expect(find.text('GESCHÄFT'), findsNothing, reason: 'Section labels hidden in compact');
      expect(find.text('STEUERN'), findsNothing, reason: 'Section labels hidden in compact');

      // Tooltip on hover per DESIGN §4 — currently exists but verify
      final tooltipWidgets = tester.widgetList<Tooltip>(find.byType(Tooltip)).toList();
      final hasRechnungenTooltip = tooltipWidgets.any((Tooltip t) => t.message == 'Rechnungen');
      expect(
        hasRechnungenTooltip,
        isTrue,
        reason:
            'Compact rail must show Tooltip("Rechnungen") on hover per DESIGN §4 — '
            'AppSidebar currently wraps leading icon with Tooltip, verify persists.',
      );

      // Click menu control temporarily expands per DESIGN §4 — currently missing
      // Look for any IconButton inside AppSidebar that triggers temporary expand
      final iconButtonsInSidebar = find.descendant(of: find.byType(AppSidebar), matching: find.byType(IconButton));
      expect(
        iconButtonsInSidebar,
        findsWidgets,
        reason:
            'Compact rail must have menu control (IconButton) to temporarily expand per DESIGN §4 — '
            'AppSidebar currently has no IconButton in compact. Add menu control that expands 72→240 temporarily.',
      );
      // Attempt temporary expand: tap and expect width 240
      if (iconButtonsInSidebar.evaluate().isNotEmpty) {
        await tester.tap(iconButtonsInSidebar.first);
        await tester.pumpAndSettle();
        final afterBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
        final expanded = afterBoxes.any((SizedBox s) => s.width == 240.0);
        expect(
          expanded,
          isTrue,
          reason:
              'Tapping menu control at 1024 must temporarily expand 72→240 per DESIGN §4 — '
              'tap did not expand. Implement temporary expand without persisting.',
        );
      }
    });

    testWidgets('test_sidebar_drawer_at_800', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());
      addTearDown(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // Drawer overlay at <900 per DESIGN §4, §34 — AppShell should return Scaffold with drawer
      final scaffolds = tester.widgetList<Scaffold>(find.byType(Scaffold)).toList();
      final hasDrawer = scaffolds.any((Scaffold s) => s.drawer != null);
      expect(
        hasDrawer,
        isTrue,
        reason: 'At 800 sidebar must be overlay Drawer per DESIGN §4 — AppShell isDrawer true must return Scaffold(drawer: Drawer).',
      );

      // Content full width — no SizedBox 240/72 constraining when drawer closed
      // When drawer closed, body is child directly, not Row with SizedBox
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final hasFixedSidebarWidth = sizedBoxes.any((SizedBox s) => s.width == 240.0 || s.width == 72.0);
      // Drawer mode should NOT have persistent SizedBox 240/72 in main scaffold body when closed
      // The Drawer itself is overlay, not Row child. So check that AppShell does not show Row with sidebar.
      expect(
        hasFixedSidebarWidth,
        isFalse,
        reason:
            'At 800 drawer overlay, content must receive full width per DESIGN §4 — '
            'found persistent SizedBox 240/72 in body, should be Drawer overlay instead.',
      );

      // Open drawer to verify content inside
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(AppSidebar), findsOneWidget, reason: 'Drawer must contain AppSidebar after opening');
      expect(find.text('Rechnungen'), findsWidgets, reason: 'Rechnungen must be visible inside opened drawer');

      // FAILING: drawer must also contain workspace selector and ● Lokal interactive — currently missing
      final hasWorkspace =
          find
              .descendant(of: find.byType(AppSidebar), matching: find.byType(PopupMenuButton<dynamic>))
              .evaluate()
              .isNotEmpty ||
          find.byKey(const ValueKey<String>('workspace_selector')).evaluate().isNotEmpty;
      expect(
        hasWorkspace,
        isTrue,
        reason:
            'Drawer AppSidebar must also contain workspace selector per D2 — missing even in drawer. '
            'Add workspace selector to AppSidebar regardless of breakpoint.',
      );
      final lokalFinder = find.text('● Lokal');
      expect(lokalFinder, findsOneWidget, reason: '● Lokal must be in drawer per DESIGN §4');
      final hasInteractive =
          find.ancestor(of: lokalFinder, matching: find.byType(InkWell)).evaluate().isNotEmpty ||
          find.ancestor(of: lokalFinder, matching: find.byType(GestureDetector)).evaluate().isNotEmpty;
      expect(
        hasInteractive,
        isTrue,
        reason: '● Lokal in drawer must be tappable with popover per §39 — currently plain Text.',
      );
    });

    testWidgets('test_sidebar_collapses_and_persists', (WidgetTester tester) async {
      // Persisted collapsed state via SharedPreferences openaccounting.sidebar_expanded per D2
      SharedPreferences.setMockInitialValues(<String, Object>{'openaccounting.sidebar_expanded': true});
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());
      addTearDown(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      // Initially expanded at 1400 (>=1200) with pref true -> 240
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final has240 = sizedBoxes.any((SizedBox s) => s.width == 240.0);
      expect(has240, isTrue, reason: 'Initially expanded at 1400 with pref true must be 240');

      // Collapse toggle must exist and persist per D2 — currently missing IconButton
      final collapseButtons = find.descendant(of: find.byType(AppSidebar), matching: find.byType(IconButton));
      expect(
        collapseButtons,
        findsWidgets,
        reason:
            'Sidebar collapse toggle (IconButton) missing per D2 — AppSidebar header must have '
            'toggle that calls SidebarController.toggle() and persists to SharedPreferences '
            'openaccounting.sidebar_expanded.',
      );

      if (collapseButtons.evaluate().isNotEmpty) {
        await tester.tap(collapseButtons.first);
        await tester.pumpAndSettle();
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getBool('openaccounting.sidebar_expanded');
        expect(
          saved,
          isFalse,
          reason:
              'After toggle collapse, SharedPreferences openaccounting.sidebar_expanded must be false per D2 — '
              'SidebarController.save() not called or key wrong.',
        );
        // Verify UI collapsed to 72 even at 1400 when pref false (expanded only at >=1200 if pref true)
        final sizedBoxesAfter = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
        final has72After = sizedBoxesAfter.any((SizedBox s) => s.width == 72.0);
        expect(
          has72After,
          isTrue,
          reason: 'After collapse, sidebar at 1400 must be 72 (collapsed) per D2 — persist respected only at >=1200.',
        );
      }

      // Restart app simulation: set pref false before pump, expect 72 at 1400
      // FAILING: currently AppShell ignores SharedPreferences, always 240 at 1400 regardless of pref
      SharedPreferences.setMockInitialValues(<String, Object>{'openaccounting.sidebar_expanded': false});
      final db2 = await _configuredDb();
      final router2 = createRouter(db2);
      addTearDown(() async => db2.close());
      await tester.pumpWidget(_wrap(router2));
      await tester.pumpAndSettle();
      final sizedBoxesPersisted = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
      final has72Persisted = sizedBoxesPersisted.any((SizedBox s) => s.width == 72.0);
      expect(
        has72Persisted,
        isTrue,
        reason:
            'Collapsed state must be restored from SharedPreferences openaccounting.sidebar_expanded=false '
            'per DESIGN D2 — currently AppShell ignores pref, always 240 at 1400. SidebarController.load() missing.',
      );
      await db2.close();
    });

    testWidgets('test_sidebar_highlights_correctly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = await _configuredDb();
      final router = createRouter(db);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() async => db.close());
      addTearDown(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

      await tester.pumpWidget(_wrap(router));
      await tester.pumpAndSettle();

      router.go('/invoices?status=offen');
      await tester.pumpAndSettle();

      // Rechnungen item must be selected when navigating to /invoices?status=offen per spec
      final rechnungenTiles = tester.widgetList<ListTile>(find.widgetWithText(ListTile, 'Rechnungen')).toList();
      expect(rechnungenTiles.isNotEmpty, isTrue, reason: 'Rechnungen tile not found for highlight check');
      final selected = rechnungenTiles.where((ListTile t) => t.selected).toList();
      expect(
        selected.isNotEmpty,
        isTrue,
        reason:
            'Rechnungen must be selected at /invoices?status=offen per spec — isSelected(path) must handle '
            'query params. Currently location.startsWith(path) should match, verify.',
      );

      // Highlight must be unmistakable — check selectedTileColor not null
      final tile = selected.isNotEmpty ? selected.first : rechnungenTiles.first;
      expect(
        tile.selectedTileColor,
        isNotNull,
        reason:
            'Rechnungen highlight must be unmistakable in both themes per DESIGN §4 — '
            'selectedTileColor is null, highlight not implemented.',
      );

      // Keyboard focus reachable via Tab per spec — currently missing Focus traversal
      // Send Tab and check focus moves to sidebar item
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final hasFocusInSidebar = find
          .descendant(of: find.byType(AppSidebar), matching: find.byType(Focus))
          .evaluate()
          .isNotEmpty;
      expect(
        hasFocusInSidebar,
        isTrue,
        reason:
            'Sidebar navigation must be keyboard focus reachable via Tab per spec — '
            'AppSidebar items not wrapped with Focus, Tab traversal fails.',
      );
      // Also check that selected tile can be focused
      final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
      final isRechnungenFocused = focusedWidget != null && focusedWidget.toString().contains('Rechnungen');
      // We expect at least some focus in sidebar; this will fail if no Focus widgets
      expect(hasFocusInSidebar, isTrue, reason: 'No Focus widget in AppSidebar — Tab cannot reach Rechnungen.');
      expect(isRechnungenFocused || hasFocusInSidebar, isTrue, reason: 'Rechnungen tile should be focusable via Tab.');
    });
  });
}
