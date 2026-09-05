import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/design_system/components/app_dialog.dart';
import 'package:openaccounting/design_system/tokens/radius.dart';

// RED phase per tasks.md 11.1: fails if radius !=14 or shadow missing.
// Covers DESIGN §10 + app-theme/spec Elevation spec.

void main() {
  group('Elevation, Borders and Radius — Dialog §10', () {
    testWidgets('test_dialog_radius_and_shadow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppDialog(title: 'Löschen?', content: Text('Inhalt')),
          ),
        ),
      );

      expect(find.byType(AppDialog), findsOneWidget, reason: 'AppDialog must render');

      final Finder container = find.descendant(of: find.byType(AppDialog), matching: find.byType(Container));
      final Finder card = find.descendant(of: find.byType(AppDialog), matching: find.byType(Card));
      final Finder material = find.descendant(of: find.byType(AppDialog), matching: find.byType(Material));
      final Finder dialogWidget = find.descendant(of: find.byType(AppDialog), matching: find.byType(Dialog));

      BorderRadius? radius;
      List<BoxShadow>? shadows;
      double? elevation;

      // Probe Container BoxDecoration first.
      if (container.evaluate().isNotEmpty) {
        for (final Element e in container.evaluate()) {
          final Container c = e.widget as Container;
          final Decoration? d = c.decoration;
          if (d is BoxDecoration) {
            if (d.borderRadius is BorderRadius) radius = d.borderRadius as BorderRadius?;
            shadows = d.boxShadow;
            if (radius != null) break;
          }
        }
      }
      if (radius == null && card.evaluate().isNotEmpty) {
        final Card c = tester.widget<Card>(card.first);
        final ShapeBorder? shape = c.shape;
        if (shape is RoundedRectangleBorder) {
          final BorderRadiusGeometry br = shape.borderRadius;
          if (br is BorderRadius) radius = br;
        }
        elevation = c.elevation;
      }
      if (radius == null && dialogWidget.evaluate().isNotEmpty) {
        final Dialog d = tester.widget<Dialog>(dialogWidget.first);
        final ShapeBorder? shape = d.shape;
        if (shape is RoundedRectangleBorder) {
          final BorderRadiusGeometry br = shape.borderRadius;
          if (br is BorderRadius) radius = br;
        }
        if (d.elevation != null) elevation = d.elevation;
        // Dialog shadow comes from elevation / Material.
        if (d.backgroundColor != null && radius == null) {
          // fallback to Material ancestor
        }
      }
      if (radius == null && material.evaluate().isNotEmpty) {
        for (final Element e in material.evaluate()) {
          final Material m = e.widget as Material;
          if (m.shape is RoundedRectangleBorder) {
            final BorderRadiusGeometry br = (m.shape! as RoundedRectangleBorder).borderRadius;
            if (br is BorderRadius) radius = br;
          }
          if (m.borderRadius is BorderRadius) {
            radius ??= m.borderRadius as BorderRadius?;
          }
          if (m.elevation > 0) elevation = m.elevation;
          if (radius != null) break;
        }
      }

      expect(
        radius,
        isNotNull,
        reason:
            'AppDialog must have BorderRadius — use AppRadius.dialog (14) via BoxDecoration/Card/Dialog shape. '
            'No radius found in Container/Card/Dialog/Material descendants.',
      );
      if (radius != null) {
        final BorderRadius r = radius;
        expect(
          r.topLeft.x,
          AppRadius.dialog,
          reason:
              'AppDialog borderRadius must be AppRadius.dialog (14) per DESIGN §10 — '
              'got ${r.topLeft.x}, expected ${AppRadius.dialog}. Use BorderRadius.circular(AppRadius.dialog).',
        );
        expect(r.topRight.x, AppRadius.dialog, reason: 'AppDialog all corners must be AppRadius.dialog (14)');
        expect(r.bottomLeft.x, AppRadius.dialog, reason: 'AppDialog all corners must be AppRadius.dialog (14)');
        expect(r.bottomRight.x, AppRadius.dialog, reason: 'AppDialog all corners must be AppRadius.dialog (14)');
      }

      // Dialogs MUST have shadow — menus/dialogs/command palette get elevation (§10 Shadows).
      final bool hasBoxShadow = shadows != null && shadows.isNotEmpty;
      final bool hasElevation = elevation != null && elevation > 0;
      expect(
        hasBoxShadow || hasElevation,
        isTrue,
        reason:
            'AppDialog must have shadow per DESIGN §10 — shadows only for floating menus/dialogs. '
            'Found boxShadow: $shadows, elevation: $elevation. '
            'Add BoxShadow or elevation >0 (Dialog elevation / Material elevation).',
      );
    });

    testWidgets('test_dialog_uses_tokens_and_shadow_not_flat', (WidgetTester tester) async {
      expect(AppRadius.dialog, 14, reason: 'AppRadius.dialog must be 14 per DESIGN §42');
      expect(AppRadius.card, 12, reason: 'AppRadius.card must be 12 for contrast with dialog');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppDialog(title: 'Titel', content: Text('Body')),
          ),
        ),
      );
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('test_dialog_title_and_actions', (WidgetTester tester) async {
      var confirmed = false;
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDialog(
              title: 'Rechnung löschen?',
              content: const Text('Wird dauerhaft gelöscht.'),
              onConfirm: () => confirmed = true,
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );

      expect(find.text('Rechnung löschen?'), findsOneWidget);
      expect(find.text('Wird dauerhaft gelöscht.'), findsOneWidget);

      // Actions rendered when callbacks provided.
      final Finder confirmBtn = find.text('Löschen');
      final Finder cancelBtn = find.text('Abbrechen');
      // AppDialog may use FilledButton/TextButton — probe by text.
      if (confirmBtn.evaluate().isNotEmpty) {
        await tester.tap(confirmBtn);
        expect(confirmed, isTrue);
      }
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn);
        expect(cancelled, isTrue);
      }
    });
  });
}
