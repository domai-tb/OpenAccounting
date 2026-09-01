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
        predicate<Object>((error) => error is StateError && error.message.contains('Dokument ist bereits finalisiert')),
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
      throwsA(predicate<Object>((error) => error is StateError && error.message.contains('Format'))),
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
      'UPDATE rechnungen SET datum = ? WHERE id = ?',
      <Object?>['2026-02-02', draft.id],
    );

    // Assert
    await expectLater(
      invoiceUpdate,
      throwsA(
        predicate<Object>((error) => error is StateError && error.message.contains('Dokument ist bereits finalisiert')),
      ),
    );
    final invoiceRows = await database.executor.runSelect('SELECT datum FROM rechnungen WHERE id = ?', <Object?>[
      draft.id,
    ]);
    expect(invoiceRows.single['datum'], '2026-02-01');

    final Future<void> idUpdate = database.executor.runCustom('UPDATE rechnungen SET id = ? WHERE id = ?', <Object?>[
      draft.id + 1000,
      draft.id,
    ]);
    await expectLater(
      idUpdate,
      throwsA(
        predicate<Object>((error) => error is StateError && error.message.contains('Dokument ist bereits finalisiert')),
      ),
    );

    await database.executor.runCustom('UPDATE rechnungen SET status = ? WHERE id = ?', <Object?>[
      'storniert',
      draft.id,
    ]);
    final statusRows = await database.executor.runSelect('SELECT status FROM rechnungen WHERE id = ?', <Object?>[
      draft.id,
    ]);
    expect(statusRows.single['status'], 'storniert');

    final Future<void> invalidStatusUpdate = database.executor.runCustom(
      'UPDATE rechnungen SET status = ? WHERE id = ?',
      <Object?>['entwurf', draft.id],
    );
    await expectLater(
      invalidStatusUpdate,
      throwsA(
        predicate<Object>((error) => error is StateError && error.message.contains('Dokument ist bereits finalisiert')),
      ),
    );
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
        predicate<Object>((error) => error is StateError && error.message.contains('Dokument ist bereits finalisiert')),
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
    final companyRows = await database.executor.runSelect('SELECT id FROM unternehmen WHERE name = ?', const <Object?>[
      'Test GmbH',
    ]);
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
    await database.executor.runCustom('UPDATE rechnungen SET unternehmen_id = ? WHERE id = ?', <Object?>[
      companyRows.single['id'],
      draft.id,
    ]);
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

  test('uses invoice company for sender snapshot', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "INSERT INTO unternehmen (name, strasse, plz, ort) VALUES ('Other GmbH', 'Andere Straße 1', '10117', 'Berlin')",
    );
    await database.executor.runCustom(
      "INSERT INTO unternehmen (name, strasse, plz, ort) VALUES ('Selected GmbH', 'Gewählte Straße 2', '20095', 'Hamburg')",
    );
    final companyRows = await database.executor.runSelect('SELECT id FROM unternehmen WHERE name = ?', const <Object?>[
      'Selected GmbH',
    ]);
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-03-02',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    await database.executor.runCustom('UPDATE rechnungen SET unternehmen_id = ? WHERE id = ?', <Object?>[
      companyRows.single['id'],
      draft.id,
    ]);

    // Act
    await useCases.finalizeRechnung(rechnungId: draft.id);

    // Assert
    final rows = await database.executor.runSelect('SELECT absender_snapshot FROM rechnungen WHERE id = ?', <Object?>[
      draft.id,
    ]);
    final snapshot = jsonDecode(rows.single['absender_snapshot']! as String) as Map<String, dynamic>;
    expect(snapshot['name'], 'Selected GmbH');
    expect(snapshot['strasse'], 'Gewählte Straße 2');
  });

  test('uses current-year date when latest finalized row was inserted later', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 101 WHERE typ = 'rechnung_ausgang'",
    );
    final rangeRows = await database.executor.runSelect(
      'SELECT id FROM nummernkreise WHERE typ = ? ORDER BY id LIMIT 1',
      const <Object?>['rechnung_ausgang'],
    );
    final rangeId = rangeRows.single['id'];
    await database.executor.runCustom(
      'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id) '
      "VALUES ('RE-260100', 'rechnung', 'offen', '2026-01-01', 0, 'netto', ?)",
      <Object?>[rangeId],
    );
    await database.executor.runCustom(
      'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id) '
      "VALUES ('RE-250100', 'rechnung', 'offen', '2025-12-31', 0, 'netto', ?)",
      <Object?>[rangeId],
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-02-01',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    // Act
    final finalized = await useCases.finalizeRechnung(rechnungId: draft.id);

    // Assert
    expect(finalized.rechnungsnummer, 'RE-260101');
  });

  test('rejects a draft dated before the latest finalized invoice', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 7 WHERE typ = 'rechnung_ausgang'",
    );
    final rangeRows = await database.executor.runSelect(
      'SELECT id FROM nummernkreise WHERE typ = ? ORDER BY id LIMIT 1',
      const <Object?>['rechnung_ausgang'],
    );
    await database.executor.runCustom(
      'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id) '
      "VALUES ('RE-260001', 'rechnung', 'offen', '2026-01-01', 0, 'netto', ?)",
      <Object?>[rangeRows.single['id']],
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2025-12-31',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    // Act / Assert
    await expectLater(
      useCases.finalizeRechnung(rechnungId: draft.id),
      throwsA(predicate<Object>((error) => error is StateError && error.message.contains('vor letzter'))),
    );
  });

  test('rejects malformed or multiple sequence tokens without changing counter', () async {
    for (final format in <String>['RE-{YY####', 'RE-YY####-##']) {
      // Arrange
      final database = AppDatabase.createTestDatabase();
      addTearDown(database.close);
      await database.ensureOpen();
      await database.executor.runCustom(
        'UPDATE nummernkreise SET format = ?, naechste_nummer = 7 WHERE typ = ?',
        <Object?>[format, 'rechnung_ausgang'],
      );
      final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
      final draft = await useCases.createDraftRechnung(
        datum: '2026-01-15',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
      );

      // Act / Assert
      await expectLater(
        useCases.finalizeRechnung(rechnungId: draft.id),
        throwsA(predicate<Object>((error) => error is StateError && error.message.contains('Format'))),
      );
      final rangeRows = await database.executor.runSelect(
        'SELECT naechste_nummer FROM nummernkreise WHERE typ = ?',
        const <Object?>['rechnung_ausgang'],
      );
      expect(rangeRows.single['naechste_nummer'], 7);
    }
  });

  test('rejects finalization when all invoice ranges are inactive', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom("UPDATE nummernkreise SET aktiv = 0 WHERE typ = 'rechnung_ausgang'");
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-01-15',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    // Act / Assert
    await expectLater(
      useCases.finalizeRechnung(rechnungId: draft.id),
      throwsA(predicate<Object>((error) => error is StateError && error.message.contains('Nummernkreis'))),
    );
    final draftRows = await database.executor.runSelect('SELECT ist_entwurf FROM rechnungen WHERE id = ?', <Object?>[
      draft.id,
    ]);
    expect(draftRows.single['ist_entwurf'], 1);
  });

  test('rolls back reserved number when finalization update aborts', () async {
    // Arrange
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();
    await database.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 7 WHERE typ = 'rechnung_ausgang'",
    );
    await database.executor.runCustom('''
CREATE TRIGGER fail_rechnung_finalization BEFORE UPDATE OF rechnungsnummer ON rechnungen
WHEN OLD.ist_entwurf = 1 BEGIN SELECT RAISE(ABORT, 'forced finalization failure'); END
''');
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(database.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-01-15',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );

    // Act / Assert
    await expectLater(
      useCases.finalizeRechnung(rechnungId: draft.id),
      throwsA(predicate<Object>((error) => error.toString().contains('forced finalization failure'))),
    );
    final rangeRows = await database.executor.runSelect(
      'SELECT naechste_nummer FROM nummernkreise WHERE typ = ?',
      const <Object?>['rechnung_ausgang'],
    );
    expect(rangeRows.single['naechste_nummer'], 7);
  });
}
