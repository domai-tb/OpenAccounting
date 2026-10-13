import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

void main() {
  test('creates a draft invoice with positions', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final invoice = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 200),
      ],
    );

    final positions = invoice.positionen;

    expect(invoice.typ, 'rechnung');
    expect(invoice.status, 'entwurf');
    expect(invoice.istEntwurf, isTrue);
    expect(invoice.eingabemodus, 'netto');
    expect(invoice.rechnungsnummer, isNull);
    expect(positions, hasLength(1));
    expect(positions.single.bezeichnung, 'Beratung');
    expect(positions.single.menge, 2);
    expect(positions.single.einzelpreis, 100);
    expect(positions.single.gesamt, 200);
  });

  test('stores the selected customer on a draft invoice', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final int customerId = await database.executor.runInsert(
      'INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)',
      const <Object?>['Test Kunde', 'Musterweg 1', '10115', 'Berlin'],
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final invoice = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      kundeId: customerId,
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    final rows = await database.executor.runSelect('SELECT kunde_id FROM rechnungen WHERE id = ?', <Object?>[
      invoice.id,
    ]);
    expect(rows.single['kunde_id'], customerId);
  });

  test('rejects a position with an inconsistent total', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 201),
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects a position with a blank description', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: '  ', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('accepts unit prices with four decimal places', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    final invoice = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 0.105, gesamt: 0.11),
      ],
    );

    expect(invoice.positionen.single.einzelpreis, 0.105);
    expect(invoice.positionen.single.gesamt, 0.11);
  });

  test('rejects unit prices beyond four decimal places', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 0.10001, gesamt: 0.10),
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('accepts large monetary values with exact cents', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final invoice = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Großauftrag', menge: 1, einzelpreis: 5000000.02, gesamt: 5000000.02),
      ],
    );

    expect(invoice.positionen.single.einzelpreis, 5000000.02);
    expect(invoice.positionen.single.gesamt, 5000000.02);
  });

  test('accepts quantities with three decimal places', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    final invoice = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1.005, einzelpreis: 100, gesamt: 100.50),
      ],
    );

    expect(invoice.positionen.single.menge, 1.005);
  });

  test('rejects quantities beyond three decimal places', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1.0055, einzelpreis: 100, gesamt: 100.55),
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rolls back invoice and positions when a later position cannot be stored', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Gültiger Artikel', menge: 1, einzelpreis: 100, gesamt: 100),
          RechnungPositionItem(
            artikelId: 999,
            bezeichnung: 'Ungültiger Artikel',
            menge: 1,
            einzelpreis: 100,
            gesamt: 100,
          ),
        ],
      ),
      throwsA(predicate<Object>((error) => error.toString().contains('FOREIGN KEY constraint failed'))),
    );

    final invoices = await database.executor.runSelect('SELECT COUNT(*) AS count FROM rechnungen', const <Object?>[]);
    final positions = await database.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungspositionen',
      const <Object?>[],
    );
    expect(invoices.single['count'], 0);
    expect(positions.single['count'], 0);
  });

  test('database rejects invalid ist_entwurf values', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    await expectLater(
      database.executor.runCustom(
        "INSERT INTO rechnungen (typ, datum, ist_entwurf, eingabemodus) VALUES ('rechnung', '2026-08-30', 2, 'netto')",
      ),
      throwsA(isA<Object>()),
    );
  });

  test('database rejects invalid eingabemodus values', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    await expectLater(
      database.executor.runCustom(
        "INSERT INTO rechnungen (typ, datum, ist_entwurf, eingabemodus) VALUES ('rechnung', '2026-08-30', 1, 'ungueltig')",
      ),
      throwsA(isA<Object>()),
    );
  });

  test('test_fixed_discount_tie_across_vat_rates_goes_to_lower_rate', () {
    const List<RechnungPositionItem> centBuckets = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: '7 percent', menge: 1, einzelpreis: 0.01, gesamt: 0.01, ustSatz: 7),
      RechnungPositionItem(bezeichnung: '19 percent', menge: 1, einzelpreis: 0.01, gesamt: 0.01),
    ];
    final VorschauResult exactCase = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: centBuckets,
      rabattBetrag: 0.01,
    );

    expect(exactCase.rabattCents, 1);
    expect(exactCase.nettoCents, 1);
    expect(exactCase.bruttoCents, 1);

    const List<RechnungPositionItem> observableTie = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: '7 percent', menge: 1, einzelpreis: 0.03, gesamt: 0.03, ustSatz: 7),
      RechnungPositionItem(bezeichnung: '19 percent', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
    ];
    final VorschauResult visibleAllocation = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: observableTie,
      rabattBetrag: 0.01,
    );

    // Three-cent buckets make the VAT total reveal which equal-weight rate received the cent.
    expect(visibleAllocation.ustCents, 1);
  });

  test('test_position_discount_applies_before_single_cent_rounding', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(
          bezeichnung: 'Position discount',
          menge: 3,
          einzelpreis: 0.3350,
          gesamt: 0.90,
          rabattProzent: 10,
        ),
      ],
    );

    expect(preview.nettoCents, 90);
  });

  test('test_document_fixed_discount_reduces_pre_tax_subtotal', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Subtotal', menge: 1, einzelpreis: 1000, gesamt: 1000),
      ],
      rabattBetrag: 50,
    );

    expect(preview.nettoCents, 95000);
    expect(preview.rabattCents, 5000);
  });

  test('test_document_discount_fields_cannot_both_be_nonzero', () async {
    final AppDatabase database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    final RechnungenUseCases useCases = RechnungenUseCases(
      RechnungenRepository(RechnungenDataSource(database.executor)),
    );

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-10-11',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Discount', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
        rabattProzent: 1,
        rabattBetrag: 1,
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'conflictingDocumentDiscounts',
        ),
      ),
    );
    final List<Map<String, Object?>> rows = await database.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungen',
      const <Object?>[],
    );
    expect((rows.single['count']! as num).toInt(), 0);
  });

  test('test_excessive_or_conflicting_document_discount_is_rejected', () {
    const List<RechnungPositionItem> positionen = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Subtotal', menge: 1, einzelpreis: 100, gesamt: 100),
    ];

    expect(
      () => VorschauService.calculate(eingabemodus: 'netto', positionen: positionen, rabattBetrag: 100.01),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'excessiveDocumentDiscount',
        ),
      ),
    );
    expect(
      () => VorschauService.calculate(eingabemodus: 'netto', positionen: positionen, rabattBetrag: 1, rabattProzent: 1),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'conflictingDocumentDiscounts',
        ),
      ),
    );
  });
}
