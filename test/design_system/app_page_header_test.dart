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

    testWidgets('test_header_filter_toolbar_present', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: AppPageHeader(title: 'Rechnungen')),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(AppBar).evaluate().single, isNotNull);
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
