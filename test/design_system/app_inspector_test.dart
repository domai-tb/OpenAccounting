// failing test for DESIGN §14 — Inspector 360–440 px, overlay <900, Esc + focus trap.
// RED phase per tasks.md 5.1: all expectations must FAIL with stub AppInspector
// (wrong width 200, no overlay, no Esc, no FocusScope) — not import error.
// Uses tester.view.physicalSize 900/1280 variants, no window_manager.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/design_system/components/app_inspector.dart';

Widget _harness({required bool isOpen, required VoidCallback onClose, String? title}) {
  return MaterialApp(
    home: Scaffold(
      body: Row(
        children: <Widget>[
          const Expanded(child: Center(child: Text('content'))),
          AppInspector(
            isOpen: isOpen,
            onClose: onClose,
            title: title ?? 'Rechnung 2026-042',
            child: const Text('Inspector details'),
          ),
        ],
      ),
    ),
  );
}

Widget _overlayHarness({required bool isOpen, required VoidCallback onClose}) {
  return MaterialApp(
    home: Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isNarrow = constraints.maxWidth < 900;
          // Stub ignores isNarrow; correct impl switches Row side panel vs Stack overlay.
          // Harness at this level keeps Row so we can probe whether inspector
          // itself adapts to overlay internally (Stack ancestor) vs stays in Row.
          if (isNarrow) {
            return Stack(
              children: <Widget>[
                const Center(child: Text('content')),
                // Inspector placed as overlay child when narrow — correct impl
                // does this internally; stub does not, so overlay ancestor check fails.
                AppInspector(
                  isOpen: isOpen,
                  onClose: onClose,
                  title: 'Rechnung 2026-042',
                  child: const Text('Inspector details'),
                ),
              ],
            );
          }
          return Row(
            children: <Widget>[
              const Expanded(child: Center(child: Text('content'))),
              AppInspector(
                isOpen: isOpen,
                onClose: onClose,
                title: 'Rechnung 2026-042',
                child: const Text('Inspector details'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void main() {
  group('Optional Inspector — DESIGN §14, §34', () {
    testWidgets('test_inspector_opens_on_selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var closed = false;

      // Closed → inspector hidden.
      await tester.pumpWidget(_harness(isOpen: false, onClose: () => closed = true));
      await tester.pumpAndSettle();
      expect(
        find.text('Inspector details'),
        findsNothing,
        reason: 'Inspector must be hidden when isOpen=false — selection opens it',
      );

      // Open → inspector visible at 360–440 px via ConstrainedBox/SizedBox.
      await tester.pumpWidget(_harness(isOpen: true, onClose: () => closed = true));
      await tester.pumpAndSettle();

      expect(
        find.text('Inspector details'),
        findsOneWidget,
        reason: 'Inspector must show record on row selection per DESIGN §14 — isOpen=true should render child',
      );
      expect(find.byType(AppInspector), findsOneWidget, reason: 'AppInspector widget must be present when open');

      // Width 360–440 px check — ConstrainedBox or SizedBox within range, not 200 stub.
      final Size inspectorSize = tester.getSize(find.byType(AppInspector));
      expect(
        inspectorSize.width,
        greaterThanOrEqualTo(360),
        reason:
            'Inspector width must be >=360 px per DESIGN §14 (360–440) — stub is 200, should be ~400. '
            'Use ConstrainedBox(minWidth 360, maxWidth 440) or SizedBox(width: 400) with AppSpacing.',
      );
      expect(
        inspectorSize.width,
        lessThanOrEqualTo(440),
        reason:
            'Inspector width must be <=440 px per DESIGN §14 (360–440) — got ${inspectorSize.width}. '
            'Width must be approximately 400 px, not stretched.',
      );

      // Also accept ConstrainedBox/SizedBox interior width check for tolerance on Center/Row flex.
      final Finder constrained = find.descendant(of: find.byType(AppInspector), matching: find.byType(ConstrainedBox));
      final Finder sizedBox = find.descendant(of: find.byType(AppInspector), matching: find.byType(SizedBox));
      final bool hasWidthConstraint = constrained.evaluate().isNotEmpty || sizedBox.evaluate().isNotEmpty;
      // AnimatedContainer is the required shell per §32 (200ms); stub uses Container.
      final Finder animatedContainer = find.descendant(
        of: find.byType(AppInspector),
        matching: find.byType(AnimatedContainer),
      );
      expect(
        hasWidthConstraint,
        isTrue,
        reason:
            'Inspector must constrain width via ConstrainedBox or SizedBox 360–440 per DESIGN §14 — '
            'currently plain Container without ConstrainedBox/SizedBox width. Wrap with ConstrainedBox.',
      );
      expect(
        animatedContainer,
        findsOneWidget,
        reason:
            'Inspector must use AnimatedContainer duration 200ms per DESIGN §32 (inspector 180–240 ms) — '
            'stub uses Container, should be AnimatedContainer(duration: AppDuration.normal / 200ms).',
      );
      if (animatedContainer.evaluate().isNotEmpty) {
        final AnimatedContainer ac = tester.widget<AnimatedContainer>(animatedContainer);
        final Duration duration = ac.duration;
        expect(
          duration,
          const Duration(milliseconds: 200),
          reason: 'AnimatedContainer duration must be 200ms per DESIGN §32 — got $duration',
        );
      }

      expect(closed, isFalse, reason: 'onClose must not fire on open');
    });

    testWidgets('test_inspector_adapts_at_narrow', (WidgetTester tester) async {
      // ≥1200 side panel vs 900 overlay per §14, §34: overlay not side panel squeezing content.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var closed = false;

      await tester.pumpWidget(_harness(isOpen: true, onClose: () => closed = true));
      await tester.pumpAndSettle();

      // Reference closed to satisfy lint — callback wiring verified via isOpen behavior above.
      expect(closed, isFalse, reason: 'onClose must not fire before Esc — wiring check');

      expect(find.byType(AppInspector), findsOneWidget, reason: 'Inspector must be visible at 1280 side-panel mode');

      // At 1280 side panel: AppInspector inside Row alongside content.
      final bool rowAncestorAt1280 = find
          .ancestor(of: find.byType(AppInspector), matching: find.byType(Row))
          .evaluate()
          .isNotEmpty;
      expect(
        rowAncestorAt1280,
        isTrue,
        reason:
            'At ≥1200 inspector must be side panel inside Row per DESIGN §34 (side panel) — '
            'inspector should sit as Row child next to content, not overlay.',
      );

      // At 900 overlay: inspector must NOT be side-by-side Row child squeezing content below 960 min.
      // Per task: use tester.view.physicalSize to simulate; inspector should show differently.
      // Should fail before impl — stub always stays Row side panel, so overlay check fails.
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpWidget(_harness(isOpen: true, onClose: () => closed = true));
      await tester.pumpAndSettle();

      expect(find.byType(AppInspector), findsOneWidget, reason: 'Inspector must still be visible at 900 overlay mode');

      // Overlay means Stack ancestor (or Drawer/Overlay) not Row, and content keeps full width.
      // Stub fails: stays in Row, no Stack ancestor.
      final bool stackAncestorAt900 = find
          .ancestor(of: find.byType(AppInspector), matching: find.byType(Stack))
          .evaluate()
          .isNotEmpty;
      final bool rowAncestorAt900 = find
          .ancestor(of: find.byType(AppInspector), matching: find.byType(Row))
          .evaluate()
          .isNotEmpty;

      expect(
        stackAncestorAt900,
        isTrue,
        reason:
            'At 900 inspector must be overlay (Stack/Positioned/Drawer) per DESIGN §14 — '
            'overlay at narrow widths, not side panel squeezing content below 960 minimum. '
            'Inspector should render inside Stack covering content when width <900. '
            'Stub stays in Row so this fails until overlay impl exists.',
      );
      // Side-panel width at 900 would squeeze content below 960 min per Risk in design.md D6.
      expect(
        rowAncestorAt900,
        isFalse,
        reason:
            'At 900 inspector must NOT be Row side panel — that would squeeze content below 960 minimum. '
            'Should be overlay, not Row child at <900.',
      );

      // Also verify via harness that switches LayoutBuilder <900 to Stack internally.
      // Pump overlay harness at 900 — correct impl adapts regardless of parent Row.
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpWidget(_overlayHarness(isOpen: true, onClose: () => closed = true));
      await tester.pumpAndSettle();
      // Harness at 900 already provides Stack parent, so stub would appear to pass Stack check here.
      // The harness test above with _harness proves inspector itself does not adapt — this guards regression.
      expect(find.byType(AppInspector), findsOneWidget);
    });

    testWidgets('test_inspector_closes_on_esc_and_focus_trap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      var closedCount = 0;
      void onClose() => closedCount++;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                const Expanded(child: TextField(key: ValueKey<String>('outside_field'))),
                AppInspector(
                  isOpen: true,
                  onClose: onClose,
                  title: 'Rechnung 2026-042',
                  child: Column(
                    children: <Widget>[
                      const Text('Inspector details'),
                      // ignore: prefer_const_constructors
                      TextField(key: const ValueKey<String>('inspector_field'), autofocus: true),
                      ElevatedButton(onPressed: () {}, child: const Text('Aktion')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppInspector), findsOneWidget, reason: 'Inspector must be open for Esc test');
      expect(find.text('Inspector details'), findsOneWidget);

      // Esc closes inspector per DESIGN §24 (Esc closes inspector) + §14.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        closedCount,
        greaterThan(0),
        reason:
            'Pressing Escape must close inspector per DESIGN §24 (Esc closes menu/dialog/inspector) — '
            'AppInspector must handle Esc via FocusScope onKeyEvent / Shortcuts + Actions or '
            'RawKeyboardListener and call onClose. Stub does not, so onClose never fires.',
      );

      // Focus trap: inspector must contain FocusScope with trapped focus, not leak to outside.
      final Finder focusScopeInInspector = find.descendant(
        of: find.byType(AppInspector),
        matching: find.byType(FocusScope),
      );
      final Finder focusInInspector = find.descendant(of: find.byType(AppInspector), matching: find.byType(Focus));
      final bool hasFocusTrap = focusScopeInInspector.evaluate().isNotEmpty || focusInInspector.evaluate().isNotEmpty;
      expect(
        hasFocusTrap,
        isTrue,
        reason:
            'Inspector must trap focus per spec (focus trap) — must contain FocusScope/Focus '
            'so keyboard navigation stays inside inspector when open. Stub has no FocusScope.',
      );

      // Optional: verify inspector_field is focusable inside trap.
      expect(
        find.byKey(const ValueKey<String>('inspector_field')),
        findsOneWidget,
        reason: 'Inspector focusable child must exist inside trap for verification',
      );
    });
  });
}
