import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_catalog.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_entry.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_help_page.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_texts.dart';
import 'package:openaccounting/l10n/l10n.dart';

Widget _localizedHelpApp() {
  return const ProviderScope(
    child: MaterialApp(
      locale: Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ContextualGuidanceHelpPage(),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(ContextualGuidanceHelpPage)))!;
}

void main() {
  group('Help workspace', () {
    testWidgets('test_help_opens_with_reviewed_contextual_entries', (WidgetTester tester) async {
      // GIVEN: the Help catalog contains reviewed entries.
      final ContextualGuidanceCatalog catalog = ContextualGuidanceCatalog.reviewed();
      expect(catalog.reviewedEntries.length, 15);

      // WHEN: the user opens /help.
      await tester.pumpWidget(_localizedHelpApp());
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);

      // THEN: entries are grouped and displayed with localized names and workflow locations.
      final ContextualGuidanceEntry first = catalog.reviewedEntries.first;
      expect(find.text(guidanceTitle(first, l10n)), findsOneWidget);
      expect(find.text(l10n.guidanceLocationLabel('/reports', 'konten.skrMappingField')), findsOneWidget);

      // AND: opening an entry shows its full reviewed explanation.
      final Finder tile = find.byKey(ValueKey<String>('guidance_entry_${first.stableId}'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(guidanceBody(first, l10n)), findsOneWidget);

      // AND: no static placeholder tile poses as accounting guidance.
      expect(find.text(l10n.localDescription), findsNothing);
    });

    testWidgets('test_search_finds_no_reviewed_entry', (WidgetTester tester) async {
      // GIVEN: no reviewed entry matches the user's query.
      final ContextualGuidanceCatalog catalog = ContextualGuidanceCatalog.reviewed();
      final AppLocalizations german = lookupAppLocalizations(const Locale('de'));
      final AppLocalizations english = lookupAppLocalizations(const Locale('en'));
      expect(catalog.search('XyzKeinThema999', german: german, english: english), isEmpty);

      // WHEN: the user searches Help.
      await tester.pumpWidget(_localizedHelpApp());
      await tester.pumpAndSettle();
      final AppLocalizations l10n = _l10n(tester);
      await tester.enterText(find.byKey(const ValueKey<String>('guidance_search_field')), 'XyzKeinThema999');
      await tester.pumpAndSettle();

      // THEN: the page shows a localized no-results state.
      expect(find.text(l10n.guidanceEmptyResults), findsOneWidget);

      // AND: no unrelated or invented content is shown.
      for (final ContextualGuidanceEntry entry in catalog.reviewedEntries) {
        expect(find.text(guidanceTitle(entry, l10n)), findsNothing);
      }
      expect(find.byKey(const ValueKey<String>('guidance_dialog')), findsNothing);
    });
  });
}
