// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_output_format.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

import 'e_invoice_test_fixtures.dart'
    show
        eInvoiceTestService,
        invalidEInvoiceTestOfflineXmlValidation,
        unavailableEInvoiceTestOfflineXmlValidation,
        validSnapshot;

void main() {
  group('Invoice output format selection and state', () {
    Widget wrap(Widget child, {Locale locale = const Locale('de')}) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets('zugferd_customer_preference_preselects_zugferd', (WidgetTester tester) async {
      // The landed customer preference only supplies the draft default.
      expect(defaultOutputFormat(zugferdAktiv: true), EInvoiceOutputFormat.zugferd);

      await tester.pumpWidget(
        wrap(
          InvoiceOutputFormatSelector(
            selected: defaultOutputFormat(zugferdAktiv: true),
            readiness: EInvoiceReadiness.notValidated,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ZUGFeRD'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('XRechnung'), findsOneWidget);
      final SegmentedButton<EInvoiceOutputFormat> segments = tester.widget(
        find.byType(SegmentedButton<EInvoiceOutputFormat>),
      );
      expect(segments.selected, <EInvoiceOutputFormat>{EInvoiceOutputFormat.zugferd});
    });

    testWidgets('disabled_zugferd_preference_preselects_pdf', (WidgetTester tester) async {
      expect(defaultOutputFormat(zugferdAktiv: false), EInvoiceOutputFormat.pdf);

      await tester.pumpWidget(
        wrap(
          InvoiceOutputFormatSelector(
            selected: defaultOutputFormat(zugferdAktiv: false),
            readiness: EInvoiceReadiness.notValidated,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SegmentedButton<EInvoiceOutputFormat> segments = tester.widget(
        find.byType(SegmentedButton<EInvoiceOutputFormat>),
      );
      expect(segments.selected, <EInvoiceOutputFormat>{EInvoiceOutputFormat.pdf});
      // Every alternative stays available beside the default.
      expect(find.text('ZUGFeRD'), findsOneWidget);
      expect(find.text('XRechnung'), findsOneWidget);
    });

    testWidgets('per_invoice_choice_overrides_default_without_changing_customer', (WidgetTester tester) async {
      EInvoiceOutputFormat? chosen;
      await tester.pumpWidget(
        wrap(
          InvoiceOutputFormatSelector(
            selected: EInvoiceOutputFormat.pdf,
            readiness: EInvoiceReadiness.notValidated,
            onChanged: (EInvoiceOutputFormat value) => chosen = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('XRechnung'));
      await tester.pump();

      // The per-invoice override is a local selection callback; the widget
      // owns no customer write path, so the saved preference cannot change.
      expect(chosen, EInvoiceOutputFormat.xrechnung);
    });

    testWidgets('shows_all_formats_selection_and_readiness_with_text', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          InvoiceOutputFormatSelector(
            selected: EInvoiceOutputFormat.zugferd,
            readiness: EInvoiceReadiness.invalid,
            isDraft: false,
            exportAvailable: true,
            onExport: () {},
            diagnostics: const <EInvoiceDiagnostic>[
              EInvoiceDiagnostic(
                ruleId: 'buyer.street',
                messageDe: 'Pflichtfeld fehlt: buyer.street',
                messageEn: 'Required field is missing: buyer.street',
                route: 'rechnungen',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ausgabeformat'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('ZUGFeRD'), findsOneWidget);
      expect(find.text('XRechnung'), findsOneWidget);
      // Readiness is text plus icon, never color-only.
      expect(find.text('E-Rechnung fehlerhaft – Details prüfen'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      expect(find.textContaining('buyer.street'), findsOneWidget);
      expect(find.text('XRechnung exportieren'), findsOneWidget);
    });

    testWidgets('offline_validator_results_show_localized_readiness_and_diagnostics', (WidgetTester tester) async {
      final EInvoiceService service = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: unavailableEInvoiceTestOfflineXmlValidation,
      );
      late EInvoiceExportValidationException failure;
      try {
        await service.xrechnungXml(validSnapshot(buyerReference: 'LEITWEG-123'));
        fail('Unavailable offline validation must not return XML.');
      } on EInvoiceExportValidationException catch (error) {
        failure = error;
      }
      final List<EInvoiceDiagnostic> diagnostics = failure.result.diagnostics;
      final EInvoiceReadiness readiness = service.readiness(failure.result);

      InvoiceOutputFormatSelector selector(EInvoiceReadiness state, List<EInvoiceDiagnostic> messages) =>
          InvoiceOutputFormatSelector(
            selected: EInvoiceOutputFormat.xrechnung,
            readiness: state,
            isDraft: false,
            exportAvailable: true,
            diagnostics: messages,
          );

      await tester.pumpWidget(wrap(selector(readiness, diagnostics)));
      await tester.pumpAndSettle();
      expect(find.text('Prüfung nicht verfügbar'), findsOneWidget);
      expect(
        find.textContaining('Die Offline-Prüfung ist nicht verfügbar. Es wurde kein E-Rechnungsartefakt ausgegeben.'),
        findsOneWidget,
      );
      expect(find.textContaining('The Java runtime is not available.'), findsNothing);

      await tester.pumpWidget(wrap(selector(readiness, diagnostics), locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Validation unavailable'), findsOneWidget);
      expect(
        find.textContaining('Offline validation is unavailable. No e-invoice artifact was produced.'),
        findsOneWidget,
      );
      expect(find.textContaining('The Java runtime is not available.'), findsNothing);

      final EInvoiceService invalidService = EInvoiceService(
        bundle: eInvoiceTestService.bundle,
        offlineXmlValidation: invalidEInvoiceTestOfflineXmlValidation,
      );
      late EInvoiceExportValidationException invalidFailure;
      try {
        await invalidService.xrechnungXml(validSnapshot(buyerReference: 'LEITWEG-123'));
        fail('Invalid offline validation must not return XML.');
      } on EInvoiceExportValidationException catch (error) {
        invalidFailure = error;
      }
      expect(invalidService.readiness(invalidFailure.result), EInvoiceReadiness.invalid);
      await tester.pumpWidget(
        wrap(selector(EInvoiceReadiness.invalid, invalidFailure.result.diagnostics), locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('E-invoice invalid – check details'), findsOneWidget);
      expect(find.textContaining('Offline validation rejected the e-invoice XML.'), findsOneWidget);
      expect(find.textContaining('Die XML-Datei verletzt die Schemastruktur.'), findsNothing);
    });

    testWidgets('restores_persisted_xrechnung_selection_after_reopen', (WidgetTester tester) async {
      // Reopened finalized invoice: persisted xrechnung restored read-only,
      // export not yet validated.
      await tester.pumpWidget(
        wrap(
          const InvoiceOutputFormatSelector(
            selected: EInvoiceOutputFormat.xrechnung,
            readiness: EInvoiceReadiness.notValidated,
            isDraft: false,
            exportAvailable: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SegmentedButton<EInvoiceOutputFormat> segments = tester.widget(
        find.byType(SegmentedButton<EInvoiceOutputFormat>),
      );
      expect(segments.selected, <EInvoiceOutputFormat>{EInvoiceOutputFormat.xrechnung});
      expect(segments.onSelectionChanged, isNull);
      expect(find.text('Noch nicht geprüft'), findsOneWidget);
      expect(find.text('XRechnung exportieren'), findsOneWidget);
    });

    testWidgets('exposes_keyboard_reachable_localized_export_and_error_details', (WidgetTester tester) async {
      var exports = 0;
      await tester.pumpWidget(
        wrap(
          InvoiceOutputFormatSelector(
            selected: EInvoiceOutputFormat.xrechnung,
            readiness: EInvoiceReadiness.invalid,
            isDraft: false,
            exportAvailable: true,
            onExport: () => exports++,
            diagnostics: const <EInvoiceDiagnostic>[
              EInvoiceDiagnostic(
                ruleId: 'buyerReference',
                messageDe: 'Käuferreferenz (z. B. Leitweg-ID) fehlt für den XRechnung-Export',
                messageEn: 'Buyer reference (e.g. Leitweg ID) is missing for XRechnung export',
                route: 'rechnungen',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder exportButton = find.byKey(const ValueKey<String>('e_invoice_export_xrechnung'));
      expect(exportButton, findsOneWidget);
      // Keyboard traversal reaches the export action in order.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.tap(exportButton);
      await tester.pump();
      expect(exports, 1);
      expect(find.textContaining('buyerReference'), findsOneWidget);
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        expect(find.bySemanticsLabel('XRechnung exportieren'), findsWidgets);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('hides_or_disables_export_for_draft_invoice', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const InvoiceOutputFormatSelector(
            selected: EInvoiceOutputFormat.pdf,
            readiness: EInvoiceReadiness.notValidated,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('e_invoice_export_xrechnung')), findsNothing);
      // The UI never implies that an e-invoice artifact exists for a draft.
      expect(find.text('Export erst nach Finalisierung verfügbar'), findsOneWidget);
      expect(find.text('E-Rechnung geprüft und gültig'), findsNothing);
    });

    testWidgets('reopened_legacy_invoice_shows_pdf_without_customer_inference', (WidgetTester tester) async {
      // Legacy rows carry no saved format; readers resolve to PDF without
      // consulting the customer's current ZUGFeRD setting.
      expect(resolveFinalizedOutputFormat(null), EInvoiceOutputFormat.pdf);
      final RechnungItem legacy = RechnungItem(
        id: 7,
        rechnungsnummer: 'RE-2025-0001',
        typ: 'rechnung',
        status: 'offen',
        istEntwurf: false,
        eingabemodus: 'netto',
        datum: '2025-11-01',
        // ignore: avoid_redundant_argument_values
        ausgabeformat: null,
        positionen: const <RechnungPositionItem>[],
      );
      expect(legacy.effektivesAusgabeformat, 'pdf');

      await tester.pumpWidget(
        wrap(
          InvoiceOutputFormatSelector(
            selected: parseEInvoiceOutputFormat(legacy.ausgabeformat),
            readiness: EInvoiceReadiness.valid,
            isDraft: false,
            exportAvailable: true,
            onExport: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SegmentedButton<EInvoiceOutputFormat> segments = tester.widget(
        find.byType(SegmentedButton<EInvoiceOutputFormat>),
      );
      expect(segments.selected, <EInvoiceOutputFormat>{EInvoiceOutputFormat.pdf});
    });
  });
}
