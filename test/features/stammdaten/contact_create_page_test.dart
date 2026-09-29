import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/pages/stammdaten/contact_create_page.dart';

void main() {
  testWidgets('rejects malformed contact email before saving', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ContactCreatePage()));

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Anna Müller');
    await tester.enterText(fields.at(2), 'Hauptstraße 1');
    await tester.enterText(fields.at(3), '10115');
    await tester.enterText(fields.at(4), 'Berlin');
    await tester.enterText(fields.at(5), '@');
    await tester.tap(find.text('Kontakt speichern'));
    await tester.pump();

    expect(find.text('Bitte eine gültige E-Mail-Adresse eingeben'), findsOneWidget);
  });
}
