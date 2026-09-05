import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/theme/app_colors.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';

void main() {
  group('Semantic Accounting Colors — DESIGN §43 §44', () {
    testWidgets('test_status_chip_semantic', (WidgetTester tester) async {
      // Überfällig chip must use AccountingColors.overdue (not colorScheme.error)
      // and pair color with icon+text (never color alone).
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppStatusChip(status: AppStatus.overdue, label: 'Überfällig'),
          ),
        ),
      );

      expect(find.text('Überfällig'), findsOneWidget, reason: 'chip must show text label');
      expect(find.byIcon(Icons.error), findsOneWidget, reason: 'chip must show icon with text');

      final BuildContext ctx = tester.element(find.byType(AppStatusChip));
      final Color resolved = AppStatusChip.statusColor(ctx, AppStatus.overdue);
      expect(resolved, AccountingColors.light.overdue, reason: 'must use AccountingColors.overdue light');
      expect(
        resolved,
        isNot(Theme.of(ctx).colorScheme.error),
        reason: 'must not overload colorScheme.error for overdue',
      );

      // Also verify paid uses AccountingColors.paid with check icon.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: AppStatusChip(status: AppStatus.paid, label: 'Bezahlt'),
          ),
        ),
      );
      expect(find.text('Bezahlt'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final BuildContext ctx2 = tester.element(find.byType(AppStatusChip));
      expect(
        AppStatusChip.statusColor(ctx2, AppStatus.paid),
        AccountingColors.light.paid,
        reason: 'paid must use AccountingColors.paid',
      );
    });

    testWidgets('test_hover_state_differs_dark', (WidgetTester tester) async {
      // Hover background must differ between light and dark (distinct tokens
      // #F1F3F6 vs #1D2129 per §44).
      const Color base = Color(0xFFDC2626); // overdue light base
      final Color lightHover = AppStatusChip.backgroundForStates(
        <WidgetState>{WidgetState.hovered},
        base,
        Brightness.light,
      );
      final Color darkHover = AppStatusChip.backgroundForStates(
        <WidgetState>{WidgetState.hovered},
        base,
        Brightness.dark,
      );
      expect(lightHover, isNot(darkHover), reason: 'hover must differ in dark theme');

      // Verify all §44 states produce distinct colors.
      final Color def = AppStatusChip.backgroundForStates(<WidgetState>{}, base, Brightness.light);
      final Color pressed = AppStatusChip.backgroundForStates(
        <WidgetState>{WidgetState.pressed},
        base,
        Brightness.light,
      );
      final Color focused = AppStatusChip.backgroundForStates(
        <WidgetState>{WidgetState.focused},
        base,
        Brightness.light,
      );
      final Color selected = AppStatusChip.backgroundForStates(
        <WidgetState>{WidgetState.selected},
        base,
        Brightness.light,
      );
      final Color disabled = AppStatusChip.backgroundForStates(
        <WidgetState>{WidgetState.disabled},
        base,
        Brightness.light,
      );
      final Set<Color> distinct = <Color>{def, lightHover, pressed, focused, selected, disabled};
      expect(distinct.length, 6, reason: 'default/hover/pressed/focused/selected/disabled must be distinct per §44');

      // Also verify widget renders hover state without crash in dark theme.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: AppStatusChip(status: AppStatus.overdue, label: 'Überfällig'),
          ),
        ),
      );
      expect(find.text('Überfällig'), findsOneWidget);
      final BuildContext darkCtx = tester.element(find.byType(AppStatusChip));
      expect(Theme.of(darkCtx).brightness, Brightness.dark);
      expect(
        AppStatusChip.statusColor(darkCtx, AppStatus.overdue),
        AccountingColors.dark.overdue,
        reason: 'dark must use AccountingColors.dark.overdue',
      );
      expect(
        AppStatusChip.statusColor(darkCtx, AppStatus.overdue),
        isNot(AccountingColors.light.overdue),
        reason: 'light/dark values must be distinct',
      );
    });

    testWidgets('test_missing_extension_fallback', (WidgetTester tester) async {
      // Missing ThemeExtension must fall back safely (no throw) to neutral.
      bool threw = false;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: const Scaffold(
              body: AppStatusChip(status: AppStatus.overdue, label: 'Überfällig'),
            ),
          ),
        );
      } catch (_) {
        threw = true;
      }
      expect(threw, isFalse, reason: 'missing extension must not throw');
      expect(find.text('Überfällig'), findsOneWidget, reason: 'chip must still render with fallback');
      expect(find.byIcon(Icons.error), findsOneWidget, reason: 'icon must still show with fallback');

      final BuildContext ctx = tester.element(find.byType(AppStatusChip));
      final Color fallback = AppStatusChip.statusColor(ctx, AppStatus.overdue);
      expect(fallback, AccountingColors.light.overdue, reason: 'fallback must be AccountingColors.light value');
      // Disabled state also must not throw.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: const Scaffold(
            body: AppStatusChip(status: AppStatus.draft, label: 'Entwurf', enabled: false),
          ),
        ),
      );
      expect(find.text('Entwurf'), findsOneWidget);
    });
  });
}
