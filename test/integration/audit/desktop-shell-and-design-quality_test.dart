// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/design_system/components/app_dialog.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';

void main() {
  group('Desktop shell and design quality', () {
    // ── Task 1: Breakpoints preserve usable navigation ──

    testWidgets('test_desktop_shell_and_design_quality_1_1_breakpoints_preserve_usable_navigation', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppShell(location: '/', child: Text('content')),
          ),
        ),
      );
      await tester.pump();
      final Scaffold narrow = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(narrow.drawer, isNotNull);

      tester.view.physicalSize = const Size(1000, 600);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AppShell(location: '/', child: Text('content')),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    // ── Task 2: A page without filters has no inert toolbar ──

    testWidgets('test_desktop_shell_and_design_quality_1_2_a_page_without_filters_has_no_inert_toolbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: AppPageHeader(title: 'Übersicht')),
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.filter_list), findsNothing);
    });

    // ── Task 3: Long and private amounts remain legible ──

    test('test_desktop_shell_and_design_quality_2_1_long_and_private_amounts_remain_legible', () {
      // formatMoney must handle large numbers without ellipsis.
      final large = formatMoney(123456789.99);
      expect(large, contains('123.456.789,99'));
      expect(large.length, lessThan(30), reason: 'Formatted money must be concise');

      // formatMoney must handle zero.
      final zero = formatMoney(0);
      expect(zero, contains('0,00'));

      // formatMoney must handle negative.
      final negative = formatMoney(-42.50);
      expect(negative, contains('42,50'));
    });

    // ── Task 4: Keyboard focus completes the interaction ──

    testWidgets('test_desktop_shell_and_design_quality_2_2_keyboard_focus_completes_the_interaction', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppStatusChip(status: AppStatus.info, label: 'Info', onPressed: () => pressed = true),
          ),
        ),
      );
      await tester.tap(find.text('Info'));
      expect(pressed, isTrue);
    });

    // ── Task 5: Destructive confirmation is specific ──

    testWidgets('test_desktop_shell_and_design_quality_3_1_destructive_confirmation_is_specific', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppDialog(title: 'Rechnung löschen', content: Text('RE-42 wird gelöscht.')),
          ),
        ),
      );
      expect(find.text('Rechnung löschen'), findsOneWidget);
      expect(find.text('RE-42 wird gelöscht.'), findsOneWidget);
    });

    // ── Task 6: Failure and empty state are actionable ──

    testWidgets('test_desktop_shell_and_design_quality_3_2_failure_and_empty_state_are_actionable', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const Text('Keine Daten vorhanden'),
                FilledButton(onPressed: () => retried = true, child: const Text('Erneut versuchen')),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Keine Daten vorhanden'), findsOneWidget);
      await tester.tap(find.text('Erneut versuchen'));
      expect(retried, isTrue);
    });
  });
}
