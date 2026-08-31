import 'dart:convert';

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
    final RechnungItem finalized = await useCases.finalizeRechnung(rechnungId: draft.id);

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
    final RechnungItem finalized = await useCases.finalizeRechnung(rechnungId: draft.id);

    // Act
    final Future<RechnungItem> secondFinalization = useCases.finalizeRechnung(rechnungId: finalized.id);

    // Assert
    await expectLater(
      secondFinalization,
      throwsA(
        predicate<Object>(
          (error) => error is StateError && error.message.toString().contains('Dokument ist bereits finalisiert'),
        ),
      ),
    );
  });

  test('rolls invoice numbering over at year boundary', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 101 WHERE typ = 'rechnung_ausgang'",
    );
    final rangeIdRows = await database.executor.runSelect(
      'SELECT id FROM nummernkreise WHERE typ = ? ORDER BY id LIMIT 1',
      const <Object?>['rechnung_ausgang'],
    );
    final rangeId = rangeIdRows.single['id'];
    await database.executor.runCustom(
      'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id) '
      "VALUES ('RE-250100', 'rechnung', 'offen', '2025-12-31', 0, 'netto', ?)",
      <Object?>[rangeId],
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-01-01',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    // Act
    final RechnungItem finalized = await useCases.finalizeRechnung(rechnungId: draft.id);

    // Assert
    expect(finalized.rechnungsnummer, 'RE-260001');
    final rangeRows = await database.executor.runSelect(
      'SELECT naechste_nummer FROM nummernkreise WHERE typ = ? ORDER BY id LIMIT 1',
      const <Object?>['rechnung_ausgang'],
    );
    expect(rangeRows.single['naechste_nummer'], 2);
  });

  test('rejects number template without sequence token without changing counter', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY', naechste_nummer = 7 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-01-15',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    // Act
    final Future<RechnungItem> finalization = useCases.finalizeRechnung(rechnungId: draft.id);

    // Assert
    await expectLater(
      finalization,
      throwsA(predicate<Object>((error) => error is StateError && error.message.toString().contains('Format'))),
    );
    final draftRows = await database.executor.runSelect(
      'SELECT ist_entwurf, rechnungsnummer FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    );
    expect(draftRows.single['ist_entwurf'], 1);
    expect(draftRows.single['rechnungsnummer'], isNull);
    final rangeRows = await database.executor.runSelect(
      'SELECT naechste_nummer FROM nummernkreise WHERE typ = ? ORDER BY id LIMIT 1',
      const <Object?>['rechnung_ausgang'],
    );
    expect(rangeRows.single['naechste_nummer'], 7);
  });

  test('rejects direct UPDATE of finalized invoice', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-02-01',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    await useCases.finalizeRechnung(rechnungId: draft.id);

    // Act
    final Future<void> invoiceUpdate = database.executor.runCustom(
      'UPDATE rechnungen SET status = ? WHERE id = ?',
      <Object?>['storniert', draft.id],
    );

    // Assert
    await expectLater(
      invoiceUpdate,
      throwsA(
        predicate<Object>(
          (error) => error is StateError && error.message.toString().contains('Dokument ist bereits finalisiert'),
        ),
      ),
    );
    final invoiceRows = await database.executor.runSelect('SELECT status FROM rechnungen WHERE id = ?', <Object?>[
      draft.id,
    ]);
    expect(invoiceRows.single['status'], 'offen');
  });

  test('rejects direct UPDATE of finalized invoice position', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-02-02',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    await useCases.finalizeRechnung(rechnungId: draft.id);

    // Act
    final Future<void> positionUpdate = database.executor.runCustom(
      'UPDATE rechnungspositionen SET menge = ? WHERE rechnung_id = ?',
      <Object?>['2.00', draft.id],
    );

    // Assert
    await expectLater(
      positionUpdate,
      throwsA(
        predicate<Object>(
          (error) => error is StateError && error.message.toString().contains('Dokument ist bereits finalisiert'),
        ),
      ),
    );
    final positionRows = await database.executor.runSelect(
      'SELECT menge FROM rechnungspositionen WHERE rechnung_id = ?',
      <Object?>[draft.id],
    );
    expect(positionRows.single['menge'], 1);
  });

  test('stores sender snapshot and issue timestamp when finalizing', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "INSERT INTO unternehmen (name, strasse, plz, ort) VALUES ('Test GmbH', 'Alte Straße 1', '10115', 'Berlin')",
    );
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-03-01',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    final draftRows = await database.executor.runSelect(
      'SELECT absender_snapshot, ausgegeben_am FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    );
    expect(draftRows.single['absender_snapshot'], isNull);
    expect(draftRows.single['ausgegeben_am'], isNull);

    // Act
    final finalizationStarted = DateTime.now().toUtc();
    await useCases.finalizeRechnung(rechnungId: draft.id);
    final finalizationEnded = DateTime.now().toUtc();
    final finalizedRows = await database.executor.runSelect(
      'SELECT absender_snapshot, ausgegeben_am FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    );
    final originalSnapshot = finalizedRows.single['absender_snapshot'] as String?;
    final issuedAt = finalizedRows.single['ausgegeben_am'] as String?;
    Object? snapshotUpdateError;
    try {
      await database.executor.runCustom('UPDATE rechnungen SET absender_snapshot = ? WHERE id = ?', <Object?>[
        '{"name":"Manipulated GmbH"}',
        draft.id,
      ]);
    } catch (error) {
      snapshotUpdateError = error;
    }
    await database.executor.runCustom(
      "UPDATE unternehmen SET strasse = 'Neue Straße 2', plz = '20095', ort = 'Hamburg' "
      "WHERE name = 'Test GmbH'",
    );
    final rows = await database.executor.runSelect('SELECT absender_snapshot FROM rechnungen WHERE id = ?', <Object?>[
      draft.id,
    ]);
    final unchangedSnapshot = rows.single['absender_snapshot'] as String?;

    // Assert
    expect(
      snapshotUpdateError,
      predicate<Object>(
        (error) => error is StateError && error.message == 'Absender-Snapshot ist nach Finalisierung unveränderlich',
      ),
    );
    expect(originalSnapshot, isNotNull);
    expect(originalSnapshot, isNotEmpty);
    expect(unchangedSnapshot, originalSnapshot);
    final snapshotJson = jsonDecode(originalSnapshot!) as Map<String, dynamic>;
    expect(snapshotJson['name'], 'Test GmbH');
    expect(snapshotJson['strasse'], 'Alte Straße 1');
    expect(snapshotJson['plz'], '10115');
    expect(snapshotJson['ort'], 'Berlin');
    expect(issuedAt, isNotNull);
    expect(issuedAt, isNotEmpty);
    final parsedIssuedAt = DateTime.parse(issuedAt!).toUtc();
    const tolerance = Duration(seconds: 1);
    expect(parsedIssuedAt.isBefore(finalizationStarted.subtract(tolerance)), isFalse);
    expect(parsedIssuedAt.isAfter(finalizationEnded.add(tolerance)), isFalse);
  });
}
