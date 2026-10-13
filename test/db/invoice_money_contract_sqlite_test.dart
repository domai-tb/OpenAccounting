import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

void main() {
  late AppDatabase database;
  late RechnungenDataSource dataSource;

  setUp(() async {
    database = AppDatabase.createTestDatabase();
    await database.ensureOpen();
    dataSource = RechnungenDataSource(database.executor);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> savePosition({required num unitPrice, required num quantity, required num total, int? articleId}) {
    return dataSource.createDraftRechnung(
      datum: '2026-10-11',
      positionen: <RechnungPositionItem>[
        RechnungPositionItem(
          artikelId: articleId,
          bezeichnung: 'Precision test',
          menge: quantity,
          einzelpreis: unitPrice,
          gesamt: total,
          ustSatz: 0,
        ),
      ],
    );
  }

  Future<int> invoiceCount() async {
    final List<Map<String, Object?>> rows = await database.executor.runSelect(
      'SELECT COUNT(*) AS row_count FROM rechnungen',
      const <Object?>[],
    );
    return int.parse(rows.first['row_count'].toString());
  }

  String asFixed(Object? value, int fractionDigits) => num.parse(value.toString()).toStringAsFixed(fractionDigits);

  test('test_invoice_price_and_quantity_retain_precision_in_sqlite', () async {
    final int invoiceId = await savePosition(unitPrice: 12.3456, quantity: 1.234, total: 15.23);
    final List<Map<String, Object?>> positions = await dataSource.findPositionenByRechnungId(invoiceId);
    final Map<String, Object?> position = positions.single;

    expect(asFixed(position['einzelpreis'], 4), '12.3456');
    expect(asFixed(position['menge'], 3), '1.234');

    final List<Map<String, Object?>> columns = await database.executor.runSelect(
      'PRAGMA table_info(rechnungspositionen)',
      const <Object?>[],
    );
    final Map<String, String> declaredTypes = <String, String>{
      for (final Map<String, Object?> column in columns) column['name'].toString(): column['type'].toString(),
    };
    expect(declaredTypes['einzelpreis'], 'NUMERIC(12,4)');
    expect(declaredTypes['menge'], 'NUMERIC(12,3)');
  });

  test('test_money_column_precision_round_trips_exact_cents', () async {
    final int invoiceId = await savePosition(unitPrice: 1234567.8912, quantity: 100, total: 123456789.12);
    final List<Map<String, Object?>> header = await database.executor.runSelect(
      'SELECT netto_betrag, brutto_betrag, ust_betrag FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    );
    final List<Map<String, Object?>> positions = await dataSource.findPositionenByRechnungId(invoiceId);

    expect(asFixed(header.single['netto_betrag'], 2), '123456789.12');
    expect(asFixed(header.single['brutto_betrag'], 2), '123456789.12');
    expect(asFixed(header.single['ust_betrag'], 2), '0.00');
    expect(asFixed(positions.single['gesamt'], 2), '123456789.12');
  });

  test('test_money_overflow_is_rejected_before_sqlite_write', () async {
    await expectLater(
      dataSource.createDraftRechnung(
        datum: '2026-10-11',
        positionen: const <RechnungPositionItem>[],
        rabattBetrag: 10000000000.01,
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'valueOutOfRange')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('rabattBetrag')),
      ),
    );

    expect(await invoiceCount(), 0);
  });

  test('test_article_price_product_calculates_exact_cents', () async {
    final article = await database.artikelRepository.create(
      bezeichnung: 'Precision article',
      vkNetto: 2.9412,
      vkEingabe: 'netto',
      ustSatz: 0,
    );

    final int invoiceId = await savePosition(
      articleId: article.id,
      unitPrice: article.vkNetto,
      quantity: 100,
      total: 294.12,
    );
    final List<Map<String, Object?>> positions = await dataSource.findPositionenByRechnungId(invoiceId);

    expect(asFixed(positions.single['einzelpreis'], 4), '2.9412');
    expect(asFixed(positions.single['gesamt'], 2), '294.12');
  });

  test('test_zero_article_price_round_trips_without_artifact', () async {
    final article = await database.artikelRepository.create(
      bezeichnung: 'Free article',
      vkNetto: 0,
      vkEingabe: 'netto',
      ustSatz: 0,
    );

    final int invoiceId = await savePosition(articleId: article.id, unitPrice: 0, quantity: 100, total: 0);
    final List<Map<String, Object?>> positions = await dataSource.findPositionenByRechnungId(invoiceId);

    expect(asFixed(article.vkNetto, 4), '0.0000');
    expect(asFixed(positions.single['einzelpreis'], 4), '0.0000');
    expect(asFixed(positions.single['gesamt'], 2), '0.00');
  });

  test('test_excess_price_or_quantity_scale_is_rejected_before_sqlite_write', () async {
    await expectLater(
      savePosition(unitPrice: 12.34567, quantity: 1, total: 12.35),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'invalidMoneyScale')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('einzelpreis')),
      ),
    );
    expect(await invoiceCount(), 0);

    await expectLater(
      savePosition(unitPrice: 12.3456, quantity: 1.2345, total: 15.23),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'invalidQuantityScale')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('menge')),
      ),
    );
    expect(await invoiceCount(), 0);
  });

  test('test_invoice_values_beyond_supported_range_are_rejected_before_sqlite_write', () async {
    await expectLater(
      savePosition(unitPrice: 100000000, quantity: 1, total: 100000000),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'valueOutOfRange')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('einzelpreis')),
      ),
    );
    expect(await invoiceCount(), 0);

    await expectLater(
      savePosition(unitPrice: 0, quantity: 1000000000, total: 0),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'valueOutOfRange')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('menge')),
      ),
    );
    expect(await invoiceCount(), 0);
  });

  test('test_sqlite_numeric_declaration_does_not_round_overflow', () async {
    await database.executor.runCustom('INSERT INTO konten (id, name, saldo) VALUES (?, ?, ?)', <Object?>[
      1,
      'Numeric affinity',
      '10000000000.01',
    ]);
    final List<Map<String, Object?>> stored = await database.executor.runSelect(
      'SELECT saldo, typeof(saldo) AS storage_type FROM konten WHERE id = ?',
      const <Object?>[1],
    );
    expect(asFixed(stored.single['saldo'], 2), '10000000000.01');
    expect(stored.single['storage_type'], 'real');

    await expectLater(
      dataSource.createDraftRechnung(
        datum: '2026-10-11',
        positionen: const <RechnungPositionItem>[],
        rabattBetrag: 10000000000.01,
      ),
      throwsA(
        isA<InvoiceMoneyValidationException>()
            .having((InvoiceMoneyValidationException error) => error.code, 'code', 'valueOutOfRange')
            .having((InvoiceMoneyValidationException error) => error.fields, 'fields', contains('rabattBetrag')),
      ),
    );
    expect(await invoiceCount(), 0);
  });
}
