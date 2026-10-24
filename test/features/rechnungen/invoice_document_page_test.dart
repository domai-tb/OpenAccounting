import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_document_page.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace.dart' show invoiceByIdProvider;
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  testWidgets('finalized_zugferd_sidecar_does_not_claim_pdfa_validity', (WidgetTester tester) async {
    const int invoiceId = 87;
    late Directory profileDirectory;
    late AppDatabase db;
    await tester.runAsync(() async {
      profileDirectory = await Directory.systemTemp.createTemp('invoice_readiness_');
      db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();

      final File sidecar = File('${profileDirectory.path}/pdfs/documents/$invoiceId.zugferd.xml');
      await sidecar.parent.create(recursive: true);
      await sidecar.writeAsString('<rsm:CrossIndustryInvoice/>');
    });
    addTearDown(() async {
      await db.close();
      if (profileDirectory.existsSync()) await profileDirectory.delete(recursive: true);
    });

    final RechnungItem invoice = RechnungItem(
      id: invoiceId,
      rechnungsnummer: 'RE-2026-0087',
      typ: 'rechnung',
      status: 'offen',
      istEntwurf: false,
      eingabemodus: 'netto',
      datum: '2026-10-24',
      ausgabeformat: 'zugferd',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appServicesProvider.overrideWithValue(AppServices(db)),
          invoiceByIdProvider(invoiceId).overrideWith((ref) => invoice),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InvoiceDocumentPage(id: invoiceId),
        ),
      ),
    );
    final Finder readiness = find.text('CII XML present; PDF/A-3b conformance not verified');
    for (int attempt = 0; attempt < 5 && !tester.any(readiness); attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(readiness, findsOneWidget);
    expect(find.text('E-invoice validated'), findsNothing);
  });
}
