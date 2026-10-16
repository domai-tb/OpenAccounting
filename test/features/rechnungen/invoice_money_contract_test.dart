import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

void main() {
  test('line total callers use fixed-point rounding', () {
    expect(VorschauService.lineTotal(quantity: 3, unitPrice: 0.335), 1.01);
  });

  test('test_price_and_quantity_scales_round_trip_through_draft_conversion', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem offer = await useCases.createDraftRechnung(
      datum: '2026-10-11',
      typ: 'angebot',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Scale', menge: 1.234, einzelpreis: 12.3456, gesamt: 15.23),
      ],
    );

    final RechnungItem invoice = await useCases.konvertiereDokument(quelleId: offer.id, zielTyp: 'rechnung');

    expect(invoice.positionen.single.menge, 1.234);
    expect(invoice.positionen.single.einzelpreis, 12.3456);
  });

  test('test_excess_scale_and_negative_inputs_return_typed_validation_error', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final RechnungenUseCases useCases = _useCases(db);

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-10-11',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Scale', menge: 1.0001, einzelpreis: 1, gesamt: 1),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'invalidQuantityScale')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('menge')),
      ),
    );
    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-10-11',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Negative', menge: 1, einzelpreis: -1, gesamt: 1),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'negativeInput')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('einzelpreis')),
      ),
    );
    final List<Map<String, Object?>> documents = await db.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungen',
      const <Object?>[],
    );
    final List<Map<String, Object?>> positions = await db.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungspositionen',
      const <Object?>[],
    );
    expect((documents.single['count']! as num).toInt(), 0);
    expect((positions.single['count']! as num).toInt(), 0);
    expect(
      () => VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Tax', menge: 1, einzelpreis: 1, gesamt: 1, ustSatz: 100.01),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'invalidTaxRate',
        ),
      ),
    );
  });

  test('test_values_beyond_supported_range_return_value_out_of_range', () {
    expect(
      () => VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Too expensive', menge: 1, einzelpreis: 100000000, gesamt: 100000000),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'valueOutOfRange',
        ),
      ),
    );
  });

  test('test_derived_currency_overflow_is_rejected_without_integer_overflow', () {
    expect(
      () => VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Maximum',
            menge: 100,
            einzelpreis: 99999999.9999,
            gesamt: 9999999999.99,
            ustSatz: 100,
          ),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'valueOutOfRange',
        ),
      ),
    );
  });

  test('test_vat_rounds_per_position_before_summing', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'First', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
        RechnungPositionItem(bezeichnung: 'Second', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
        RechnungPositionItem(bezeichnung: 'Third', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
      ],
    );

    expect(preview.nettoCents, 9);
    expect(preview.ustCents, 3);
    expect(preview.bruttoCents, 12);
  });

  test('test_same_rate_discount_tie_uses_persisted_position', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'First', menge: 1, einzelpreis: 0.03, gesamt: 0.03, position: 1),
        RechnungPositionItem(bezeichnung: 'Second', menge: 1, einzelpreis: 0.15, gesamt: 0.15, position: 2),
      ],
      rabattBetrag: 0.03,
    );

    expect(preview.nettoCents, 15);
    expect(preview.ustCents, 2);
    expect(preview.bruttoCents, 17);
  });

  test('test_gross_mode_rounds_net_per_position_before_summing', () {
    const List<RechnungPositionItem> positions = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'First', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
      RechnungPositionItem(bezeichnung: 'Second', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
    ];
    final VorschauResult undiscounted = VorschauService.calculate(eingabemodus: 'brutto', positionen: positions);
    final VorschauResult discounted = VorschauService.calculate(
      eingabemodus: 'brutto',
      positionen: positions,
      rabattBetrag: 0.02,
    );

    expect(undiscounted.nettoCents, 6);
    expect(undiscounted.ustCents, 0);
    expect(undiscounted.bruttoCents, 6);
    expect(discounted.nettoCents, 4);
    expect(discounted.ustCents, 0);
    expect(discounted.bruttoCents, 4);
  });

  test('test_half_cent_line_product_rounds_once_before_vat', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Half cent', menge: 3, einzelpreis: 0.335, gesamt: 1.01),
      ],
    );

    expect(preview.nettoCents, 101);
    expect(preview.ustCents, 19);
    expect(preview.bruttoCents, 120);
  });

  test('test_line_discount_precedes_single_cent_rounding', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(
          bezeichnung: 'Discounted half cent',
          menge: 3,
          einzelpreis: 0.335,
          gesamt: 0.50,
          rabattProzent: 50,
        ),
      ],
    );

    expect(preview.nettoCents, 50);
    expect(preview.ustCents, 10);
    expect(preview.bruttoCents, 60);
  });

  test('test_mismatched_asserted_line_amount_fails_before_insert', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final RechnungenUseCases useCases = _useCases(db);

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-10-11',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Mismatch', menge: 3, einzelpreis: 0.335, gesamt: 1),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'aggregateMismatch',
        ),
      ),
    );
    final List<Map<String, Object?>> rows = await db.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungen',
      const <Object?>[],
    );
    expect((rows.single['count']! as num).toInt(), 0);
  });

  test('test_mixed_rate_percentage_discount_allocates_deterministically', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: '19 percent', menge: 1, einzelpreis: 100, gesamt: 100),
        RechnungPositionItem(bezeichnung: '7 percent', menge: 1, einzelpreis: 50, gesamt: 50, ustSatz: 7),
      ],
      rabattProzent: 10,
    );

    expect(preview.nettoCents, 13500);
    expect(preview.ustCents, 2025);
    expect(preview.bruttoCents, 15525);
  });

  test('test_percentage_discount_rounds_once_before_bucket_allocation', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'netto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: '7 percent', menge: 1, einzelpreis: 0.03, gesamt: 0.03, ustSatz: 7),
        RechnungPositionItem(bezeichnung: '19 percent', menge: 1, einzelpreis: 0.03, gesamt: 0.03),
      ],
      rabattProzent: 10,
    );

    expect(preview.rabattCents, 1);
    expect(preview.nettoCents, 5);
    expect(preview.ustCents, 1);
    expect(preview.bruttoCents, 6);
  });

  test('test_discounted_draft_headers_match_after_reload', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-10-11',
      rabattProzent: 10,
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Discounted', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    final List<Map<String, Object?>> rows = await db.executor.runSelect(
      'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    );

    expect((rows.single['netto_betrag']! as num).toDouble(), 90);
    expect((rows.single['ust_betrag']! as num).toDouble(), 17.1);
    expect((rows.single['brutto_betrag']! as num).toDouble(), 107.1);
  });

  test('test_discount_cannot_exceed_subtotal_or_combine_with_another', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final RechnungenUseCases useCases = _useCases(db);
    const List<RechnungPositionItem> lines = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Subtotal', menge: 1, einzelpreis: 100, gesamt: 100),
    ];

    await expectLater(
      useCases.createDraftRechnung(datum: '2026-10-11', positionen: lines, rabattBetrag: 100.01),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'excessiveDocumentDiscount',
        ),
      ),
    );
    await expectLater(
      useCases.createDraftRechnung(datum: '2026-10-11', positionen: lines, rabattBetrag: 1, rabattProzent: 1),
      throwsA(
        isA<InvoiceMoneyValidationException>().having(
          (InvoiceMoneyValidationException error) => error.code,
          'code',
          'conflictingDocumentDiscounts',
        ),
      ),
    );
    final List<Map<String, Object?>> documents = await db.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungen',
      const <Object?>[],
    );
    final List<Map<String, Object?>> positions = await db.executor.runSelect(
      'SELECT COUNT(*) AS count FROM rechnungspositionen',
      const <Object?>[],
    );
    expect((documents.single['count']! as num).toInt(), 0);
    expect((positions.single['count']! as num).toInt(), 0);
  });

  test('test_line_validation_error_includes_code_field_and_both_indexes', () {
    expect(
      () => VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Valid', menge: 1, einzelpreis: 1, gesamt: 1, position: 3),
          RechnungPositionItem(bezeichnung: 'Invalid', menge: 1.0001, einzelpreis: 1, gesamt: 1, position: 7),
        ],
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'invalidQuantityScale')
            .having((InvoiceMoneyValidationException error) => error.lineIndex, 'lineIndex', 1)
            .having((InvoiceMoneyValidationException error) => error.position, 'position', 7)
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('menge')),
      ),
    );
  });

  test('test_header_mismatch_reports_fields_without_line_metadata', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Invoice money contract');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-10-11',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Header', menge: 1, einzelpreis: 10, gesamt: 10),
      ],
    );
    await db.executor.runUpdate('UPDATE rechnungen SET netto_betrag = ?, ust_betrag = ? WHERE id = ?', <Object?>[
      '9.00',
      '0.50',
      draft.id,
    ]);

    await expectLater(
      useCases.finalizeRechnung(rechnungId: draft.id, locale: 'de_DE'),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'headerMismatch')
            .having(
              (InvoiceMoneyValidationException error) => error.fields,
              'fields',
              containsAll(<String>['netto_betrag', 'ust_betrag']),
            )
            .having((InvoiceMoneyValidationException error) => error.fields.length, 'field count', 2)
            .having((InvoiceMoneyValidationException error) => error.lineIndex, 'lineIndex', isNull)
            .having((InvoiceMoneyValidationException error) => error.position, 'position', isNull),
      ),
    );
  });
  test('test_gross_mode_discount_recalculates_multiple_tax_buckets', () {
    final VorschauResult preview = VorschauService.calculate(
      eingabemodus: 'brutto',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: '19 percent gross', menge: 1, einzelpreis: 119, gesamt: 119),
        RechnungPositionItem(bezeichnung: '7 percent gross', menge: 1, einzelpreis: 53.50, gesamt: 53.50, ustSatz: 7),
      ],
      rabattProzent: 10,
    );

    expect(preview.rabattCents, 1500);
    expect(preview.nettoCents, 13500);
    expect(preview.ustCents, 2025);
    expect(preview.bruttoCents, 15525);
  });
}

RechnungenUseCases _useCases(AppDatabase db) {
  final Directory profile = Directory.systemTemp.createTempSync('invoice-money-fixture-');
  addTearDown(() {
    if (profile.existsSync()) profile.deleteSync(recursive: true);
  });
  return RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: profile.path)));
}
