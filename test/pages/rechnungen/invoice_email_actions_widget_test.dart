import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_email_actions.dart';

void main() {
  group('Keep email delivery within application and design boundaries', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets('test_user_sends_from_an_accessible_document_surface', (WidgetTester tester) async {
      int sends = 0;
      await tester.pumpWidget(
        wrap(
          InvoiceEmailActions(
            sendAvailable: true,
            sending: false,
            lastOutcome: InvoiceEmailOutcome.accepted,
            onSend: () => sends++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder button = find.widgetWithText(FilledButton, 'Per E-Mail senden');
      expect(button, findsOneWidget);
      expect(find.text('Vom SMTP-Server angenommen (kein Zustellnachweis).'), findsOneWidget);
      expect(find.byIcon(Icons.send_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(sends, 1);
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        expect(find.bySemanticsLabel('Per E-Mail senden'), findsWidgets);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('test_background_workflow_does_not_send', (WidgetTester tester) async {
      int sends = 0;
      await tester.pumpWidget(
        wrap(InvoiceEmailActions(sendAvailable: true, sending: false, lastOutcome: null, onSend: () => sends++)),
      );
      await tester.pumpAndSettle();
      // Mounting, settling, and rebuilding never submit: only an explicit tap sends.
      await tester.pump(const Duration(seconds: 1));
      expect(sends, 0);
    });

    testWidgets('test_deferred_document_type_shows_no_send_control', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          InvoiceEmailActions(
            sendAvailable: false,
            sending: false,
            lastOutcome: null,
            onSend: () => fail('deferred type must not send'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Versand für diesen Dokumenttyp noch nicht verfügbar.'), findsOneWidget);
    });
  });
}
