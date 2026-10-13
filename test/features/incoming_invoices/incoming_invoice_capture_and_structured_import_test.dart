import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/incoming_invoices/incoming_invoice_capture_page.dart';
import 'package:openaccounting/features/receipts/receipt_inbox_page.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  testWidgets('test_save_a_manually_reviewed_pdf_as_an_incoming_draft', (WidgetTester tester) async {
    final _CaptureFixture fixture = await _createFixture(tester, withSupplier: true);
    addTearDown(() => tester.runAsync(fixture.close));
    await _mount(tester, fixture, '/receipts/inbox');

    await tester.tap(find.text('manuell-geprueft.pdf'));
    await tester.pump();
    await tester.tap(find.text('Quelle ansehen').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('receipt_create_incoming_invoice')),
      findsOneWidget,
      reason: 'visible text: ${tester.widgetList<Text>(find.byType(Text)).map((Text widget) => widget.data).toList()}',
    );
    await tester.tap(find.byKey(const ValueKey<String>('receipt_create_incoming_invoice')));
    await _pumpLoad(tester);
    expect(find.byKey(const ValueKey<String>('incoming_invoice_pdf_preview')), findsNothing);
    expect(find.byKey(const ValueKey<String>('incoming_invoice_source_number')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('incoming_invoice_supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lieferant').last);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_source_number')), 'L-42');
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_date')), '2026-10-10');
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_due_date')), '2026-11-10');
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_line_0_description')), 'Beratung');
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_line_0_quantity')), '2');
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_line_0_price')), '10.00');
    await tester.enterText(find.byKey(const ValueKey<String>('incoming_invoice_line_0_vat')), '19');
    await tester.tap(find.byKey(const ValueKey<String>('incoming_invoice_save')));
    await _pumpLoad(tester);

    final List<Map<String, Object?>> invoices = await _runAsync(
      tester,
      () => fixture.db.executor.runSelect('SELECT * FROM rechnungen WHERE beleg_id = ?', <Object?>[fixture.belegId]),
    );
    expect(invoices, hasLength(1));
    expect(invoices.single['typ'], 'rechnung_eingang');
    expect(invoices.single['ist_entwurf'], 1);
    expect(invoices.single['rechnungsnummer'], isNull);
    expect(invoices.single['fremd_rechnungsnummer'], 'L-42');
    expect(invoices.single['datum'], '2026-10-10');
    expect(invoices.single['faelligkeit'], '2026-11-10');
    expect(invoices.single['lieferant_id'], fixture.supplierId);
    expect(invoices.single['beleg_id'], fixture.belegId);
    expect(
      await _runAsync(
        tester,
        () => fixture.db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[
          invoices.single['id'],
        ]),
      ),
      isEmpty,
    );
    final Map<String, Object?> receipt = (await _runAsync(
      tester,
      () => fixture.db.executor.runSelect('SELECT sha256, status FROM belege WHERE id = ?', <Object?>[fixture.belegId]),
    )).single;
    expect(receipt['sha256'], fixture.sourceHash);
    expect(receipt['status'], startsWith('geprueft'));
  });

  testWidgets('test_confirm_structured_fields_into_an_incoming_draft', (WidgetTester tester) async {
    final _CaptureFixture fixture = await _createFixture(
      tester,
      withSupplier: true,
      filename: 'rechnung.xml',
      sourceBytes: Uint8List.fromList(utf8.encode(_supportedInvoice)),
    );
    addTearDown(() => tester.runAsync(fixture.close));
    await _mount(tester, fixture, '/receipts/${fixture.belegId}/capture');

    expect(find.text('RE-2026-42'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('incoming_invoice_save')));
    await tester.pump();
    expect(find.text('Wählen Sie vor dem Speichern einen Lieferanten aus.'), findsOneWidget);
    expect(
      await _runAsync(
        tester,
        () => fixture.db.executor.runSelect('SELECT id FROM rechnungen WHERE beleg_id = ?', <Object?>[fixture.belegId]),
      ),
      isEmpty,
    );

    await tester.tap(find.byKey(const ValueKey<String>('incoming_invoice_supplier')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lieferant').last);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('incoming_invoice_source_number')),
      'RE-2026-42-korrigiert',
    );
    expect(find.text('Quellenwert: RE-2026-42'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('incoming_invoice_save')));
    await _pumpLoad(tester);

    final List<Map<String, Object?>> invoices = await _runAsync(
      tester,
      () => fixture.db.executor.runSelect('SELECT * FROM rechnungen WHERE beleg_id = ?', <Object?>[fixture.belegId]),
    );
    expect(invoices, hasLength(1));
    expect(invoices.single['fremd_rechnungsnummer'], 'RE-2026-42-korrigiert');
    expect(invoices.single['datum'], '2026-10-10');
    expect(invoices.single['faelligkeit'], '2026-10-24');
    final List<Map<String, Object?>> positions = await _runAsync(
      tester,
      () => fixture.db.executor.runSelect(
        'SELECT bezeichnung, menge, einzelpreis, ust_satz FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[invoices.single['id']],
      ),
    );
    expect(positions.single['bezeichnung'], 'Beratung');
    expect(positions.single['menge'], 2);
    expect(positions.single['einzelpreis'], 10);
    expect(positions.single['ust_satz'], 19);
  });

  testWidgets('test_missing_supplier_prevents_draft_creation', (WidgetTester tester) async {
    final _CaptureFixture fixture = await _createFixture(tester, withSupplier: false);
    addTearDown(() => tester.runAsync(fixture.close));
    await _mount(tester, fixture, '/receipts/${fixture.belegId}/capture');

    await tester.tap(find.byKey(const ValueKey<String>('incoming_invoice_save')));
    await tester.pump();

    expect(find.text('Wählen Sie vor dem Speichern einen Lieferanten aus.'), findsOneWidget);
    expect(
      await _runAsync(
        tester,
        () => fixture.db.executor.runSelect('SELECT id FROM rechnungen WHERE beleg_id = ?', <Object?>[fixture.belegId]),
      ),
      isEmpty,
    );
  });

  testWidgets('test_unconfirmed_suggestions_do_not_create_a_draft', (WidgetTester tester) async {
    final _CaptureFixture fixture = await _createFixture(
      tester,
      withSupplier: true,
      filename: 'rechnung.xml',
      sourceBytes: Uint8List.fromList(utf8.encode(_supportedInvoice)),
    );
    addTearDown(() => tester.runAsync(fixture.close));
    await _mount(tester, fixture, '/receipts/${fixture.belegId}/capture');

    expect(find.byKey(const ValueKey<String>('incoming_invoice_source_number')), findsOneWidget);
    expect(find.text('RE-2026-42'), findsOneWidget);
    expect(
      await _runAsync(
        tester,
        () => fixture.db.executor.runSelect('SELECT id FROM rechnungen WHERE beleg_id = ?', <Object?>[fixture.belegId]),
      ),
      isEmpty,
    );
  });
}

Future<_CaptureFixture> _createFixture(
  WidgetTester tester, {
  required bool withSupplier,
  String filename = 'manuell-geprueft.pdf',
  Uint8List? sourceBytes,
}) async {
  return (await tester.runAsync(
    () => _CaptureFixture.create(withSupplier: withSupplier, filename: filename, sourceBytes: sourceBytes),
  ))!;
}

Future<T> _runAsync<T extends Object>(WidgetTester tester, Future<T> Function() callback) async =>
    (await tester.runAsync(callback))!;

const String _supportedInvoice = '''
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
  xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
  xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0</cbc:CustomizationID>
  <cbc:ID>RE-2026-42</cbc:ID><cbc:IssueDate>2026-10-10</cbc:IssueDate>
  <cbc:DueDate>2026-10-24</cbc:DueDate><cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty><cac:Party><cac:PartyName><cbc:Name>Beispiel GmbH</cbc:Name></cac:PartyName></cac:Party></cac:AccountingSupplierParty>
  <cac:InvoiceLine><cbc:InvoicedQuantity>2</cbc:InvoicedQuantity><cbc:LineExtensionAmount>20.00</cbc:LineExtensionAmount>
    <cac:Item><cbc:Name>Beratung</cbc:Name><cac:ClassifiedTaxCategory><cbc:Percent>19</cbc:Percent></cac:ClassifiedTaxCategory></cac:Item>
    <cac:Price><cbc:PriceAmount>10.00</cbc:PriceAmount></cac:Price>
  </cac:InvoiceLine>
  <cac:TaxTotal><cbc:TaxAmount>3.80</cbc:TaxAmount><cac:TaxSubtotal><cbc:TaxableAmount>20.00</cbc:TaxableAmount></cac:TaxSubtotal></cac:TaxTotal>
  <cac:LegalMonetaryTotal><cbc:TaxExclusiveAmount>20.00</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount>23.80</cbc:TaxInclusiveAmount><cbc:PayableAmount>23.80</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
</Invoice>
''';

Future<void> _mount(WidgetTester tester, _CaptureFixture fixture, String initialLocation) async {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/receipts/inbox',
        builder: (BuildContext context, GoRouterState state) =>
            AppScope(services: fixture.services, child: const ReceiptInboxPage()),
      ),
      GoRoute(
        path: '/receipts/:id/capture',
        builder: (BuildContext context, GoRouterState state) => AppScope(
          services: fixture.services,
          child: IncomingInvoiceCapturePage(belegId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(path: '/invoices/:id', builder: (BuildContext context, GoRouterState state) => const Text('Saved draft')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(fixture.db)],
      child: MaterialApp.router(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await _pumpLoad(tester);
}

Future<void> _pumpLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

class _CaptureFixture {
  _CaptureFixture({
    required this.profile,
    required this.db,
    required this.services,
    required this.belegId,
    required this.sourceHash,
    this.supplierId,
  });

  final Directory profile;
  final AppDatabase db;
  final AppServices services;
  final int belegId;
  final String sourceHash;
  final int? supplierId;

  static Future<_CaptureFixture> create({
    required bool withSupplier,
    String filename = 'manuell-geprueft.pdf',
    Uint8List? sourceBytes,
  }) async {
    final Directory profile = await Directory.systemTemp.createTemp('incoming-invoice-workspace-');
    final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profile.path);
    await db.ensureOpen();
    final AppServices services = AppServices(db);
    final int? supplierId = withSupplier
        ? (await services.lieferanten.create(name: 'Lieferant', strasse: 'Weg 1', plz: '10115', ort: 'Berlin')).id
        : null;
    final int belegId = await services.receipts.importReceipt(
      bytes: sourceBytes ?? await _pdfBytes(),
      filename: filename,
    );
    await services.receipts.markReviewed(belegId: belegId);
    final List<Map<String, Object?>> rows = await db.executor.runSelect(
      'SELECT sha256 FROM belege WHERE id = ?',
      <Object?>[belegId],
    );
    return _CaptureFixture(
      profile: profile,
      db: db,
      services: services,
      belegId: belegId,
      sourceHash: rows.single['sha256']!.toString(),
      supplierId: supplierId,
    );
  }

  Future<void> close() async {
    await db.close();
    await profile.delete(recursive: true);
  }
}

Future<Uint8List> _pdfBytes() async {
  final pw.Document document = pw.Document();
  document.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Text('Original invoice'))));
  return Uint8List.fromList(await document.save());
}
