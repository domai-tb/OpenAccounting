import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

import 'pdf_test_helpers.dart';

void main() {
  test('PdfCompanySnapshot supports public const construction', () {
    const company = PdfCompanySnapshot(name: 'Const Studio');

    expect(company.name, 'Const Studio');
  });

  test('PdfDocumentSnapshot supports public const construction', () {
    const document = PdfDocumentSnapshot(
      documentType: PdfDocumentType.rechnung,
      template: PdfTemplate.standard,
      documentNumber: 'CONST-001',
      company: PdfCompanySnapshot(name: 'Const Studio'),
      customer: PdfCustomerSnapshot(name: 'Const Customer'),
      positions: <PdfPositionSnapshot>[
        PdfPositionSnapshot(
          description: 'Const position',
          quantity: 1,
          unitPrice: 1,
          netAmount: 1,
          taxRate: 19,
          taxAmount: 0.19,
          grossAmount: 1.19,
        ),
      ],
      totals: PdfTotalsSnapshot(netAmount: 1, taxAmount: 0.19, grossAmount: 1.19),
    );

    expect(document.documentNumber, 'CONST-001');
  });

  test('collection-bearing snapshot construction defensively copies inputs', () {
    const position = PdfPositionSnapshot(
      description: 'Copied position',
      quantity: 1,
      unitPrice: 1,
      netAmount: 1,
      taxRate: 19,
      taxAmount: 0.19,
      grossAmount: 1.19,
    );
    final positions = <PdfPositionSnapshot>[position];
    final document = PdfDocumentSnapshot.from(
      documentType: PdfDocumentType.rechnung,
      template: PdfTemplate.standard,
      documentNumber: 'COPY-001',
      company: const PdfCompanySnapshot(name: 'Copy Studio'),
      customer: const PdfCustomerSnapshot(name: 'Copy Customer'),
      positions: positions,
      totals: const PdfTotalsSnapshot(netAmount: 1, taxAmount: 0.19, grossAmount: 1.19),
    );
    positions.clear();

    final logoBytes = <int>[1];
    final company = PdfCompanySnapshot.from(name: 'Bytes Studio', logoBytes: logoBytes);
    logoBytes[0] = 2;

    expect(document.positions, hasLength(1));
    expect(() => document.positions.add(position), throwsUnsupportedError);
    expect(company.logoBytes, [1]);
    expect(() => company.logoBytes!.add(2), throwsUnsupportedError);
  });

  test('PDF parser handles names before page operators', () {
    final parsedPdf = parseUncompressedPdf(uncompressedPdf(latin1.encode('BT /F1 12 Tf (Hallo) Tj ET')));

    expect(parsedPdf.visibleText, contains('Hallo'));
    expect(parsedPdf.containsOperator('Tf'), isTrue);
  });

  test('PDF parser maps the WinAnsi Euro byte', () {
    final stream = <int>[...latin1.encode('BT /F1 12 Tf (1.190,00 '), 0x80, ...latin1.encode(') Tj ET')];
    final parsedPdf = parseUncompressedPdf(uncompressedPdf(stream));

    expect(parsedPdf.visibleText, contains('1.190,00 €'));
  });

  test('Rechnung PDF contains PDF signature', () async {
    final pdfBytes = await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE');

    expect(latin1.decode(pdfBytes.sublist(0, 5)), '%PDF-');
  });

  test('Rechnung PDF contains company header', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE'));

    expect(
      parsedPdf.visibleText,
      allOf(contains('Muster Studio'), contains('Musterstraße 1'), contains('10115 Berlin')),
    );
  });

  test('Rechnung PDF contains Rechnung label and number', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE'));

    expect(parsedPdf.visibleText, allOf(contains('Rechnung'), contains('RE-2026-001')));
  });

  test('Rechnung PDF contains position content', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE'));

    expect(parsedPdf.visibleText, allOf(contains('Website-Design'), contains('2,00')));
  });

  test('Rechnung PDF contains customer address and German date', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE'));

    expect(
      parsedPdf.visibleText,
      allOf(contains('Beispiel GmbH'), contains('Kundenweg 2'), contains('20095 Hamburg'), contains('30.08.2026')),
    );
  });

  test('Rechnung PDF contains full Standard monetary columns', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE'));

    expect(
      parsedPdf.visibleText,
      allOf(
        contains('Pos.'),
        contains('Beschreibung'),
        contains('Menge'),
        contains('Einzelpreis'),
        contains('Rabatt'),
        contains('Netto'),
      ),
    );
    expect(
      parsedPdf.visibleText,
      allOf(
        contains('USt-Satz'),
        contains('USt'),
        contains('Brutto'),
        contains('1.000,00 €'),
        contains('19,00 %'),
        contains('190,00 €'),
      ),
    );
  });

  test('Rechnung generation leaves snapshot values unchanged', () async {
    final snapshot = rechnungSnapshot();
    final positions = snapshot.positions;

    await const PdfGenerator().generate(snapshot, locale: 'de_DE');

    expect(snapshot.positions, same(positions));
    expect(snapshot.documentNumber, 'RE-2026-001');
    expect(snapshot.totals.grossAmount, 1190);
  });

  test('Rechnung PDF contains German-formatted total', () async {
    final parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(rechnungSnapshot(), locale: 'de_DE'));

    expect(parsedPdf.visibleText, allOf(contains('Gesamtbetrag'), contains('1.190,00 €')));
  });
  test('test_discounted_invoice_pdf_shows_discount_and_subtotal', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'PDF-Kategorie');

    final Directory profileDir = await Directory.systemTemp.createTemp('invoice-money-pdf-');
    addTearDown(() async {
      if (profileDir.existsSync()) await profileDir.delete(recursive: true);
    });

    final RechnungenDataSource dataSource = RechnungenDataSource(db.executor);
    final RechnungenUseCases useCases = RechnungenUseCases(RechnungenRepository(dataSource));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-10-11',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Discounted invoice', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
      rabattProzent: 10,
    );

    final int invoiceId = await dataSource.finalizeRechnung(
      rechnungId: draft.id,
      profileDir: profileDir,
      locale: 'de_DE',
    );
    final rows = await db.executor.runSelect('SELECT original_pdf_pfad FROM rechnungen WHERE id = ?', <Object?>[
      invoiceId,
    ]);
    final String pdfPath = rows.single['original_pdf_pfad']!.toString();
    final ParsedPdf parsedPdf = parseUncompressedPdf(await File(pdfPath).readAsBytes());

    expect(
      parsedPdf.visibleText,
      allOf(
        contains('Zwischensumme'),
        contains('100,00 €'),
        contains('Rabatt'),
        contains('10,00 €'),
        contains('90,00 €'),
        contains('17,10 €'),
        contains('107,10 €'),
      ),
    );
  });
  test('test_pdf_line_discount_uses_single_rounding_boundary', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'PDF-Kategorie');

    final Directory profileDir = await Directory.systemTemp.createTemp('invoice-money-pdf-');
    addTearDown(() async {
      if (profileDir.existsSync()) await profileDir.delete(recursive: true);
    });

    final RechnungenDataSource dataSource = RechnungenDataSource(db.executor);
    final RechnungenUseCases useCases = RechnungenUseCases(RechnungenRepository(dataSource));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-10-11',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(
          bezeichnung: 'Discounted half-cent line',
          menge: 3,
          einzelpreis: 0.335,
          gesamt: 0.50,
          rabattProzent: 50,
        ),
      ],
    );

    final int invoiceId = await dataSource.finalizeRechnung(
      rechnungId: draft.id,
      profileDir: profileDir,
      locale: 'de_DE',
    );
    final rows = await db.executor.runSelect('SELECT original_pdf_pfad FROM rechnungen WHERE id = ?', <Object?>[
      invoiceId,
    ]);
    final String pdfPath = rows.single['original_pdf_pfad']!.toString();
    final ParsedPdf parsedPdf = parseUncompressedPdf(await File(pdfPath).readAsBytes());

    expect(parsedPdf.visibleText, contains('0,50 €'));
    expect(parsedPdf.visibleText, contains('0,60 €'));
    expect(parsedPdf.visibleText, isNot(contains('0,51 €')));
    expect(parsedPdf.visibleText, isNot(contains('0,61 €')));
  });

  test('test_gross_mode_storno_snapshot_renders_signed_source_line_amounts', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'PDF-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );

    final RechnungenDataSource dataSource = RechnungenDataSource(db.executor);
    final RechnungenUseCases useCases = RechnungenUseCases(RechnungenRepository(dataSource));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-10-12',
      eingabemodus: 'brutto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 119, gesamt: 119),
      ],
    );
    final finalized = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final storno = await useCases.stornoRechnung(rechnungId: finalized.id, grund: 'Korrektur');
    final rows = await db.executor.runSelect(
      'SELECT eingabemodus, netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[storno.id],
    );

    expect(rows.single['eingabemodus'], 'brutto');
    expect(rows.single['netto_betrag'], -100);
    expect(rows.single['ust_betrag'], -19);
    expect(rows.single['brutto_betrag'], -119);

    final num netAmount = rows.single['netto_betrag']! as num;
    final num taxAmount = rows.single['ust_betrag']! as num;
    final num grossAmount = rows.single['brutto_betrag']! as num;
    final RechnungPositionItem stornoPosition = storno.positionen.single;
    final PdfDocumentSnapshot baseSnapshot = rechnungSnapshot();
    final PdfDocumentSnapshot snapshot = PdfDocumentSnapshot.from(
      documentType: PdfDocumentType.storno,
      template: baseSnapshot.template,
      documentNumber: 'ST-2026-001',
      documentDate: DateTime(2026, 10, 12),
      company: baseSnapshot.company,
      customer: baseSnapshot.customer,
      positions: <PdfPositionSnapshot>[
        PdfPositionSnapshot(
          description: stornoPosition.bezeichnung,
          quantity: stornoPosition.menge.abs(),
          unitPrice: stornoPosition.einzelpreis.abs(),
          netAmount: netAmount,
          taxRate: stornoPosition.ustSatz,
          taxAmount: taxAmount,
          grossAmount: grossAmount,
        ),
      ],
      totals: PdfTotalsSnapshot(netAmount: netAmount, taxAmount: taxAmount, grossAmount: grossAmount),
    );
    final ParsedPdf parsedPdf = parseUncompressedPdf(await const PdfGenerator().generate(snapshot, locale: 'de_DE'));

    expect(parsedPdf.visibleText, contains('Beratung 1,00 119,00 € -100,00 € 19,00 % -19,00 € -119,00 €'));
  });
}
