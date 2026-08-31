import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

void main() {
  test('finalizes a draft invoice with a year-based number and preserves positions', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 200),
      ],
    );

    // Act
    final dynamic dynamicUseCases = useCases;
    // ignore: avoid_dynamic_calls
    final RechnungItem finalized = await dynamicUseCases.finalizeRechnung(rechnungId: draft.id);

    // Assert
    expect(finalized.rechnungsnummer, 'RE-260001');
    expect(finalized.istEntwurf, isFalse);
    expect(finalized.positionen, hasLength(1));
    expect(finalized.positionen.single.bezeichnung, 'Beratung');
    expect(finalized.positionen.single.menge, 2);
    expect(finalized.positionen.single.einzelpreis, 100);
    expect(finalized.positionen.single.gesamt, 200);
  });

  test('rejects finalizing an already finalized invoice', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    final dynamic dynamicUseCases = useCases;
    // ignore: avoid_dynamic_calls
    final RechnungItem finalized = await dynamicUseCases.finalizeRechnung(rechnungId: draft.id);

    // Act
    // ignore: avoid_dynamic_calls
    final Future<Object?> secondFinalization = dynamicUseCases.finalizeRechnung(rechnungId: finalized.id);

    // Assert
    await expectLater(
      secondFinalization,
      throwsA(predicate<Object>((error) => error.toString().contains('Dokument ist bereits finalisiert'))),
    );
  });
}
