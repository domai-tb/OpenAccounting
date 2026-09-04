// failing test for DESIGN §6 — Content Canvas constraints per tasks.md 4.1.
// RED phase: padding responsive 24/16 must FAIL (current AppPage fixed 32),
// cap 720–900 at 1920 and table full width should PASS once impl exists.
// Uses tester.view.physicalSize + pumpWidget, no window_manager.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/design_system/components/app_page.dart';

Widget _wrapAppPage({double maxWidth = 900, EdgeInsetsGeometry? padding, Widget? child}) {
  return MaterialApp(
    home: AppPage(
      maxWidth: maxWidth,
      padding: padding,
      child: child ?? const SizedBox(height: 200, child: Text('content')),
    ),
  );
}

EdgeInsets _effectivePadding(WidgetTester tester) {
  final Padding paddingWidget = tester.widget<Padding>(
    find.descendant(of: find.byType(AppPage), matching: find.byType(Padding)).first,
  );
  final EdgeInsetsGeometry geometry = paddingWidget.padding;
  return geometry.resolve(TextDirection.ltr);
}

Finder _appPageConstrainedBox() {
  return find.descendant(of: find.byType(AppPage), matching: find.byType(ConstrainedBox));
}

void main() {
  group('Content Canvas — DESIGN \u00A76', () {
    testWidgets('test_form_width_constrained_on_ultrawide', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrapAppPage());
      await tester.pumpAndSettle();

      expect(find.byType(Center), findsWidgets, reason: 'AppPage must center constrained content per DESIGN \u00A76');
      final ConstrainedBox box = tester.widget<ConstrainedBox>(_appPageConstrainedBox().first);
      expect(
        box.constraints.maxWidth,
        900,
        reason:
            'Form maxWidth must be 900 (within 720\u2013900) at 1920 per DESIGN \u00A76 \u2014 '
            'ConstrainedBox(maxWidth: 900) centered, not stretched',
      );
      final Size constrainedSize = tester.getSize(_appPageConstrainedBox().first);
      // ConstrainedBox inside Center shrinks to child when child is small,
      // so width is ≤900 (child intrinsic ~163), not stretched to 1920.
      expect(
        constrainedSize.width,
        lessThanOrEqualTo(900),
        reason:
            'Rendered constrained width must be \u2264900 at 1920 \u2014 currently stretched to ${constrainedSize.width}',
      );
      expect(
        box.constraints.maxWidth,
        greaterThanOrEqualTo(720),
        reason: 'Form maxWidth must be \u2265720 per DESIGN \u00A76 range 720\u2013900',
      );

      // Verify with large child that cap is enforced — form content 1500 capped to 900.
      await tester.pumpWidget(_wrapAppPage(child: const SizedBox(width: 1500, height: 200, child: Text('wide'))));
      await tester.pumpAndSettle();
      final Size cappedSize = tester.getSize(_appPageConstrainedBox().first);
      expect(
        cappedSize.width,
        lessThanOrEqualTo(900 + 0.01),
        reason: 'Form with wide child at 1920 must be capped to 900 — got $cappedSize',
      );
    });

    testWidgets('test_page_padding_adapts', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrapAppPage());
      await tester.pumpAndSettle();
      expect(
        _effectivePadding(tester),
        const EdgeInsets.all(AppSpacing.xxl),
        reason: 'Padding at 1920 (\u22651200) must be 32 (AppSpacing.xxl) per DESIGN \u00A76',
      );
      expect(AppSpacing.xxl, 32, reason: 'Token sanity: AppSpacing.xxl must be 32');

      tester.view.physicalSize = const Size(1024, 900);
      await tester.pumpWidget(_wrapAppPage());
      await tester.pumpAndSettle();
      expect(
        _effectivePadding(tester),
        const EdgeInsets.all(AppSpacing.xl),
        reason:
            'Padding at 1024 (900\u20131199 compact) must be 24 (AppSpacing.xl) per DESIGN \u00A76 \u2014 '
            'current AppPage uses fixed 32, should use LayoutBuilder responsive 32/24/16',
      );
      expect(AppSpacing.xl, 24, reason: 'Token sanity: AppSpacing.xl must be 24');

      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpWidget(_wrapAppPage());
      await tester.pumpAndSettle();
      expect(
        _effectivePadding(tester),
        const EdgeInsets.all(AppSpacing.lg),
        reason:
            'Padding at 800 (<900) must be 16 (AppSpacing.lg) per DESIGN \u00A76 \u2014 '
            'current AppPage uses fixed 32, should be 16 on small',
      );
      expect(AppSpacing.lg, 16, reason: 'Token sanity: AppSpacing.lg must be 16');
    });

    testWidgets('test_table_uses_full_width', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Table variant: pass larger maxWidth — must not be capped at 900.
      await tester.pumpWidget(_wrapAppPage(maxWidth: 1600));
      await tester.pumpAndSettle();
      final ConstrainedBox box = tester.widget<ConstrainedBox>(_appPageConstrainedBox().first);
      expect(
        box.constraints.maxWidth,
        greaterThan(900),
        reason:
            'Table variant maxWidth must be >900 (full width) per DESIGN \u00A76 \u2014 '
            'AppPage(maxWidth: 1600) should not cap tables at 900',
      );
      expect(
        box.constraints.maxWidth,
        1600,
        reason: 'AppPage must respect passed maxWidth for tables \u2014 expected 1600',
      );

      // With wide child, table allows up to 1600, not capped at 900.
      await tester.pumpWidget(
        _wrapAppPage(maxWidth: 1600, child: const SizedBox(width: 1500, height: 200, child: Text('wide'))),
      );
      await tester.pumpAndSettle();
      final Size tableSize = tester.getSize(_appPageConstrainedBox().first);
      expect(
        tableSize.width,
        greaterThan(900),
        reason: 'Table with wide child and maxWidth 1600 must be >900 — got $tableSize',
      );
      expect(
        tableSize.width,
        lessThanOrEqualTo(1600 + 64),
        reason: 'Table width must be ≤1600 (+ padding) — got $tableSize',
      );

      // Default form still capped at 900.
      await tester.pumpWidget(_wrapAppPage());
      await tester.pumpAndSettle();
      final ConstrainedBox formBox = tester.widget<ConstrainedBox>(_appPageConstrainedBox().first);
      expect(formBox.constraints.maxWidth, 900, reason: 'Default form must remain capped at 900');
    });
  });
}
