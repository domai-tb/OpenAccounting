import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_catalog.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_entry.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_help_button.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_help_page.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_texts.dart';
import 'package:openaccounting/l10n/l10n.dart';

Widget _localizedApp(Widget home) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
}

void main() {
  group('Supported accounting and tax controls have reviewed context guidance', () {
    testWidgets('test_user_opens_guidance_for_a_supported_field', (WidgetTester tester) async {
      // GIVEN: a field references a reviewed guidance entry.
      final ContextualGuidanceCatalog catalog = ContextualGuidanceCatalog.reviewed();
      final ContextualGuidanceEntry? entry = catalog.forControl('konten.skrMappingField');
      expect(entry, isNotNull);

      // WHEN: the user activates its labeled help affordance.
      await tester.pumpWidget(_localizedApp(const ContextGuidanceButton(controlId: 'konten.skrMappingField')));
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);
      await tester.tap(find.text(l10n.guidanceExplainAction));
      await tester.pumpAndSettle();

      // THEN: the localized explanation identifies what the field means and what workflow it affects.
      expect(find.text(guidanceBody(entry!, l10n)), findsOneWidget);

      // AND: the explanation remains tied to its owning capability contract revision.
      expect(find.text(l10n.guidanceContractLabel(entry.owningContract, entry.contractRevision)), findsOneWidget);
    });

    testWidgets('test_field_has_no_approved_explanation', (WidgetTester tester) async {
      // GIVEN: a supported control has no reviewed catalog entry.
      final ContextualGuidanceCatalog catalog = ContextualGuidanceCatalog.reviewed();
      expect(catalog.forControl('konten.unbekanntesFeld'), isNull);
      expect(catalog.coverageStateForControl('konten.unbekanntesFeld'), GuidanceCoverageState.missing);

      // WHEN: the control is rendered.
      await tester.pumpWidget(_localizedApp(const ContextGuidanceButton(controlId: 'konten.unbekanntesFeld')));
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);

      // THEN: no help affordance, missing-help warning, guessed guidance, or unrelated link is shown.
      expect(find.text(l10n.guidanceExplainAction), findsNothing);
      expect(find.byKey(const ValueKey<String>('guidance_dialog')), findsNothing);

      // AND: a review-needed entry also renders no affordance but stays in the maintainer inventory.
      final ContextualGuidanceCatalog pending = ContextualGuidanceCatalog(
        entries: catalog.entries,
        reviewNeeded: const <String>{'accounting.category.skr-mapping'},
      );
      expect(pending.forControl('konten.skrMappingField'), isNull);
      expect(pending.coverageStateForControl('konten.skrMappingField'), GuidanceCoverageState.reviewNeeded);
      await tester.pumpWidget(
        _localizedApp(ContextGuidanceButton(controlId: 'konten.skrMappingField', catalog: pending)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.guidanceExplainAction), findsNothing);
    });

    testWidgets('test_unsupported_tax_behavior_is_discussed', (WidgetTester tester) async {
      // GIVEN: a field relates to a tax behavior the application has not fully accepted.
      final ContextualGuidanceCatalog catalog = ContextualGuidanceCatalog.reviewed();
      final ContextualGuidanceEntry? entry = catalog.forControl('tax.special25aField');
      expect(entry, isNotNull);

      // WHEN: its explanation is displayed.
      await tester.pumpWidget(_localizedApp(const ContextGuidanceButton(controlId: 'tax.special25aField')));
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);
      await tester.tap(find.text(l10n.guidanceExplainAction));
      await tester.pumpAndSettle();

      // THEN: the text states that the behavior is unavailable or unresolved.
      final String body = guidanceBody(entry!, l10n);
      expect(body, contains('nicht verfügbar'));
      expect(find.text(body), findsOneWidget);

      // AND: it does not advise which tax treatment to choose; it disclaims tax advice.
      expect(find.text(l10n.guidanceNoAdviceNote), findsOneWidget);
    });
  });

  group('Help provides a searchable glossary for contextual entries', () {
    testWidgets('test_search_and_open_a_help_entry', (WidgetTester tester) async {
      // GIVEN: the user is in Help with reviewed guidance entries available.
      await tester.pumpWidget(_localizedApp(const ContextualGuidanceHelpPage()));
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);

      // WHEN: they search a German term and open a result.
      await tester.enterText(find.byKey(const ValueKey<String>('guidance_search_field')), 'Storno');
      await tester.pumpAndSettle();
      final Finder result = find.byKey(const ValueKey<String>('guidance_entry_accounting.journal.storno'));
      expect(result, findsOneWidget);
      expect(find.byKey(const ValueKey<String>('guidance_entry_accounting.category.skr-mapping')), findsNothing);
      await tester.tap(result);
      await tester.pumpAndSettle();

      // THEN: Help shows the matching localized explanation with field/workflow references.
      final ContextualGuidanceCatalog catalog = ContextualGuidanceCatalog.reviewed();
      final ContextualGuidanceEntry entry = catalog.byId('accounting.journal.storno')!;
      expect(find.text(guidanceBody(entry, l10n)), findsOneWidget);
      expect(find.text(l10n.guidanceLocationLabel('/reports', 'journal.stornoAction')), findsWidgets);

      // AND: the same content entry is returned by its contextual field affordance.
      await tester.tap(find.text(l10n.actionClose));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_localizedApp(const ContextGuidanceButton(controlId: 'journal.stornoAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.guidanceExplainAction));
      await tester.pumpAndSettle();
      expect(find.text(guidanceBody(entry, l10n)), findsOneWidget);
    });

    testWidgets('test_no_glossary_result_is_available', (WidgetTester tester) async {
      // GIVEN: the search has no reviewed entry matching the active locale terms.
      await tester.pumpWidget(_localizedApp(const ContextualGuidanceHelpPage()));
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);

      // WHEN: the user searches the glossary.
      await tester.enterText(find.byKey(const ValueKey<String>('guidance_search_field')), 'XyzKeinThema999');
      await tester.pumpAndSettle();

      // THEN: Help shows a localized empty state and does not fabricate a definition.
      expect(find.text(l10n.guidanceEmptyResults), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('guidance_dialog')), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('Context guidance follows the desktop design schema', () {
    testWidgets('test_guidance_is_reachable_without_a_pointer', (WidgetTester tester) async {
      // GIVEN: keyboard focus is within an accounting form.
      await tester.pumpWidget(_localizedApp(const ContextGuidanceButton(controlId: 'konten.skrMappingField')));
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);
      final Finder affordance = find.text(l10n.guidanceExplainAction);
      Focus.of(tester.element(affordance)).requestFocus();
      await tester.pump();
      expect(Focus.of(tester.element(affordance)).hasFocus, isTrue);

      // WHEN: the user navigates to and activates the contextual explanation control.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // THEN: the explanation opens with keyboard interaction.
      expect(find.byKey(const ValueKey<String>('guidance_dialog')), findsOneWidget);

      // AND: it closes with keyboard interaction and focus returns to the help control.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('guidance_dialog')), findsNothing);
      expect(Focus.of(tester.element(affordance)).hasFocus, isTrue);
    });
  });
}
