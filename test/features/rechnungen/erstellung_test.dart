import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

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

  test('rejects monetary values with more than two decimal places', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 0.105, gesamt: 0.11),
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

  test('rejects quantities with more than two decimal places', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));

    await expectLater(
      useCases.createDraftRechnung(
        datum: '2026-08-30',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1.005, einzelpreis: 100, gesamt: 100.50),
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
}
