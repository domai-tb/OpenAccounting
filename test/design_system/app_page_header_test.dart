import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';

void main() {
  group('Page Header — DESIGN §5', () {
    testWidgets('test_header_shows_title_and_primary', (WidgetTester tester) async {
      var primaryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppPageHeader(
              title: 'Rechnungen',
              actions: <Widget>[
                FilledButton(onPressed: () => primaryPressed = true, child: const Text('Neue Rechnung')),
              ],
            ),
          ),
        ),
      );

      final Finder title = find.text('Rechnungen');
      final Finder primaryAction = find.widgetWithText(FilledButton, 'Neue Rechnung');

      expect(title, findsOneWidget);
      expect(primaryAction, findsOneWidget);
      expect(tester.getCenter(primaryAction).dx, greaterThan(tester.getCenter(title).dx));

      await tester.tap(primaryAction);
      expect(primaryPressed, isTrue);
    });

    testWidgets('test_header_primary_action_callback', (WidgetTester tester) async {
      var primaryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            appBar: AppPageHeader(
              title: 'Rechnungen',
              primaryActionLabel: 'Neue Rechnung',
              onPrimaryAction: () => primaryPressed = true,
            ),
          ),
        ),
      );

      final Finder primaryAction = find.widgetWithText(FilledButton, 'Neue Rechnung');

      expect(primaryAction, findsOneWidget);
      await tester.tap(primaryAction);
      expect(primaryPressed, isTrue);
    });

    testWidgets('test_header_filter_toolbar_present', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: AppPageHeader(title: 'Rechnungen')),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(AppBar).evaluate().single, isNotNull);
    });

    testWidgets('test_header_filter_toolbar_can_be_hidden', (WidgetTester tester) async {
      const AppPageHeader header = AppPageHeader(title: 'Rechnung 2026-042', showFilterToolbar: false);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(appBar: header)));

      expect(find.byType(TextField), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.getSize(find.byType(AppBar)).height, header.preferredSize.height);
    });

    testWidgets('test_header_filter_chips_count_and_reset', (WidgetTester tester) async {
      String? removedFilter;
      var resetPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            appBar: AppPageHeader(
              title: 'Rechnungen',
              activeFilters: const <String>['Offen', '2026'],
              resultCount: 42,
              onFilterRemoved: (String filter) => removedFilter = filter,
              onResetFilters: () => resetPressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(FilterChip), findsNWidgets(2));
      expect(find.text('42 Ergebnisse'), findsOneWidget);
      expect(find.text('Filter zurücksetzen'), findsOneWidget);
      expect(find.bySemanticsLabel('Suchen'), findsAtLeastNWidgets(1));
      expect(find.bySemanticsLabel('Filter entfernen: Offen'), findsAtLeastNWidgets(1));

      final Finder firstChip = find.widgetWithText(FilterChip, 'Offen');
      await tester.tap(find.descendant(of: firstChip, matching: find.byIcon(Icons.close)));
      expect(removedFilter, 'Offen');

      await tester.tap(find.text('Filter zurücksetzen'));
      expect(resetPressed, isTrue);
    });

    testWidgets('test_header_preferred_size_matches_subtitle_tabs_and_filters', (WidgetTester tester) async {
      const AppPageHeader header = AppPageHeader(
        title: 'Rechnungen',
        subtitle: 'Entwurf • 1.249,50 €',
        tabs: <Widget>[
          Tab(text: 'Alle'),
          Tab(text: 'Offen'),
        ],
        activeFilters: <String>['Offen'],
        resultCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Scaffold(appBar: header),
        ),
      );

      final AppBar renderedAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(find.byType(TabBar), findsOneWidget);
      expect(renderedAppBar.preferredSize.height, header.preferredSize.height);
      expect(tester.getSize(find.byType(AppBar)).height, header.preferredSize.height);
    });

    testWidgets('test_header_without_primary_shows_subtitle', (WidgetTester tester) async {
      const AppPageHeader header = AppPageHeader(title: 'Rechnungen', subtitle: 'Entwurf • 1.249,50 €');

      await tester.pumpWidget(const MaterialApp(home: Scaffold(appBar: header)));

      expect(find.text('Rechnungen'), findsOneWidget);
      expect(find.text('Entwurf • 1.249,50 €'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      final AppBar renderedAppBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(renderedAppBar.preferredSize.height, header.preferredSize.height);
      expect(tester.getSize(find.byType(AppBar)).height, header.preferredSize.height);
    });
  });
}
