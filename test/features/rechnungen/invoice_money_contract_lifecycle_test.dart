import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

Future<Object?> _capture(Future<Object?> operation) async {
  try {
    await operation;
    return null;
  } catch (error) {
    return error;
  }
}

Future<int> _count(AppDatabase database, String table) async {
  final rows = await database.executor.runSelect('SELECT COUNT(*) AS count FROM $table', const <Object?>[]);
  return (rows.single['count']! as num).toInt();
}

void _expectError(Object? error, String code, {List<String>? fields}) {
  expect(error, isA<InvoiceMoneyValidationException>());
  if (error is InvoiceMoneyValidationException) {
    expect(error.code, code);
    if (fields != null) expect(error.fields, fields);
  }
}

Future<List<Object?>> _counterValues(AppDatabase database) async {
  final rows = await database.executor.runSelect(
    "SELECT typ, naechste_nummer FROM nummernkreise WHERE typ IN ('rechnung_ausgang', 'stornorechnung', 'gutschrift') ORDER BY typ",
    const <Object?>[],
  );
  return rows.map((row) => row['naechste_nummer']).toList(growable: false);
}

void main() {
  test('test_generic_correction_creation_fails_before_side_effects', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final dataSource = RechnungenDataSource(db.executor);
    final beforeInvoices = await _count(db, 'rechnungen');
    final beforePositions = await _count(db, 'rechnungspositionen');
    final beforeCounters = await _counterValues(db);
    final errors = <Object?>[];

    for (final typ in ['gutschrift', 'storno']) {
      const positions = <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ];
      errors
        ..add(await _capture(useCases.createDraftRechnung(datum: '2026-08-30', positionen: positions, typ: typ)))
        ..add(await _capture(useCases.createDokument(typ: typ, datum: '2026-08-30', positionen: positions)))
        ..add(await _capture(dataSource.createDraftRechnung(datum: '2026-08-30', positionen: positions, typ: typ)))
        ..add(await _capture(dataSource.createDokument(typ: typ, datum: '2026-08-30', positionen: positions)));
    }

    for (final error in errors) {
      _expectError(error, 'unsupportedDocumentType');
    }
    expect(await _count(db, 'rechnungen'), beforeInvoices);
    expect(await _count(db, 'rechnungspositionen'), beforePositions);
    expect(await _counterValues(db), beforeCounters);
  });

  test('test_finalize_rejects_altered_headers_before_posting', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    final int customerId = await db.executor.runInsert(
      'INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)',
      const <Object?>['Test Kunde', 'Musterweg 1', '10115', 'Berlin'],
    );
    await db.executor.runCustom("INSERT INTO artikel (bezeichnung, vk_netto, bestand) VALUES ('Widget', 10, 20)");
    final articleRows = await db.executor.runSelect(
      'SELECT id, bestand FROM artikel WHERE bezeichnung = ?',
      const <Object?>['Widget'],
    );
    final int articleId = (articleRows.single['id']! as num).toInt();
    final beforeStock = articleRows.single['bestand'];
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      kundeId: customerId,
      positionen: <RechnungPositionItem>[
        RechnungPositionItem(
          artikelId: articleId,
          bezeichnung: 'Widget',
          menge: 1,
          einzelpreis: 0.15,
          gesamt: 0.15,
          position: 2,
        ),
        RechnungPositionItem(
          artikelId: articleId,
          bezeichnung: 'Widget',
          menge: 1,
          einzelpreis: 0.03,
          gesamt: 0.03,
          position: 1,
        ),
      ],
      rabattBetrag: 0.03,
    );
    await db.executor.runUpdate('UPDATE rechnungen SET brutto_betrag = ? WHERE id = ?', <Object?>['999.00', draft.id]);
    final beforeCounters = await _counterValues(db);
    final beforeJournal = await _count(db, 'journal');
    final beforeReceivables = await _count(db, 'forderungen');
    final beforeMovements = await _count(db, 'inventarbewegungen');

    final error = await _capture(useCases.finalizeRechnung(rechnungId: draft.id, locale: 'de_DE'));
    _expectError(error, 'headerMismatch', fields: const ['brutto_betrag']);

    expect(await _counterValues(db), beforeCounters);
    expect(await _count(db, 'journal'), beforeJournal);
    expect(await _count(db, 'forderungen'), beforeReceivables);
    expect(await _count(db, 'inventarbewegungen'), beforeMovements);
    final invoiceRows = await db.executor.runSelect(
      'SELECT ist_entwurf, status, rechnungsnummer, original_pdf_pfad FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    );
    expect(invoiceRows.single['ist_entwurf'], 1);
    expect(invoiceRows.single['status'], 'entwurf');
    expect(invoiceRows.single['rechnungsnummer'], isNull);
    expect(invoiceRows.single['original_pdf_pfad'], isNull);
    final stockRows = await db.executor.runSelect('SELECT bestand FROM artikel WHERE id = ?', <Object?>[articleId]);
    expect(stockRows.single['bestand'], beforeStock);
  });

  test('test_mismatched_or_unsupported_correction_source_fails_before_side_effects', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final sourceDraft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    await db.executor.runUpdate(
      "UPDATE rechnungen SET netto_betrag = '99.00', ist_entwurf = 0, status = 'offen' WHERE id = ?",
      <Object?>[sourceDraft.id],
    );
    final offerDraft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      typ: 'angebot',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    await db.executor.runUpdate("UPDATE rechnungen SET ist_entwurf = 0, status = 'offen' WHERE id = ?", <Object?>[
      offerDraft.id,
    ]);
    final invoiceId = sourceDraft.id;
    final offerId = offerDraft.id;
    final beforeInvoices = await _count(db, 'rechnungen');
    final beforePositions = await _count(db, 'rechnungspositionen');
    final beforeCounters = await _counterValues(db);

    final creditError = await _capture(useCases.createGutschrift(vonRechnungId: invoiceId));
    final stornoError = await _capture(useCases.stornoRechnung(rechnungId: invoiceId, grund: 'Korrektur'));
    final unsupportedError = await _capture(useCases.stornoRechnung(rechnungId: offerId, grund: 'Nicht erlaubt'));

    _expectError(creditError, 'headerMismatch', fields: const ['netto_betrag']);
    _expectError(stornoError, 'headerMismatch', fields: const ['netto_betrag']);
    _expectError(unsupportedError, 'unsupportedCorrectionSource', fields: const ['typ']);
    expect(await _count(db, 'rechnungen'), beforeInvoices);
    expect(await _count(db, 'rechnungspositionen'), beforePositions);
    expect(await _counterValues(db), beforeCounters);
    final sourceRows = await db.executor.runSelect(
      'SELECT status, netto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    );
    expect(sourceRows.single['status'], 'offen');
    expect(sourceRows.single['netto_betrag'], 99);
  });

  test('test_supported_conversions_preserve_discounted_headers', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'AN-YY####', naechste_nummer = 1 WHERE typ = 'angebot'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'AU-YY####', naechste_nummer = 1 WHERE typ = 'auftrag'",
    );
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final offer = await useCases.createDokument(
      typ: 'angebot',
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
      rabattProzent: 10,
    );
    final finalizedOffer = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: offer.id);
    final order = await useCases.konvertiereDokument(quelleId: finalizedOffer.id, zielTyp: 'auftrag');
    final convertedRows = await db.executor.runSelect(
      'SELECT rabatt_prozent, netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[order.id],
    );

    expect(convertedRows.single['rabatt_prozent'], 10);
    expect(convertedRows.single['netto_betrag'], 90);
    expect(convertedRows.single['ust_betrag'], 17.1);
    expect(convertedRows.single['brutto_betrag'], 107.1);

    await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: order.id);
  });

  test('test_direct_datasource_draft_rejects_unsupported_type_before_side_effects', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final RechnungenDataSource dataSource = RechnungenDataSource(db.executor);
    final int beforeInvoices = await _count(db, 'rechnungen');
    final int beforePositions = await _count(db, 'rechnungspositionen');
    final List<Object?> beforeCounters = await _counterValues(db);

    final Object? error = await _capture(
      dataSource.createDraftRechnung(
        datum: '2026-08-30',
        typ: 'unsupported',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
      ),
    );

    _expectError(error, 'unsupportedDocumentType');
    expect(await _count(db, 'rechnungen'), beforeInvoices);
    expect(await _count(db, 'rechnungspositionen'), beforePositions);
    expect(await _counterValues(db), beforeCounters);
  });

  test('test_finalize_rejects_fractional_cent_header_before_posting', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    final RechnungenDataSource dataSource = RechnungenDataSource(db.executor);
    final RechnungenUseCases useCases = RechnungenUseCases(RechnungenRepository(dataSource));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    await db.executor.runUpdate('UPDATE rechnungen SET netto_betrag = ? WHERE id = ?', <Object?>['100.004', draft.id]);

    final Object? error = await _capture(useCases.finalizeRechnung(rechnungId: draft.id, locale: 'de_DE'));

    _expectError(error, 'headerMismatch', fields: const <String>['netto_betrag']);
    final List<Map<String, Object?>> rows = await db.executor.runSelect(
      'SELECT ist_entwurf, rechnungsnummer FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    );
    expect(rows.single['ist_entwurf'], 1);
    expect(rows.single['rechnungsnummer'], isNull);
  });

  test('test_storno_rejects_negative_or_wrong_sign_source_positions_before_side_effects', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final RechnungenUseCases useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    final finalized = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    await db.executor.runCustom('DROP TRIGGER IF EXISTS protect_rechnungsposition_update');
    final int beforeInvoices = await _count(db, 'rechnungen');
    final int beforePositions = await _count(db, 'rechnungspositionen');
    final List<Object?> beforeCounters = await _counterValues(db);

    Future<void> expectRejected(String column, String field, {required String code, num value = -1}) async {
      await db.executor.runUpdate('UPDATE rechnungspositionen SET $column = ? WHERE rechnung_id = ?', <Object?>[
        value,
        finalized.id,
      ]);
      final Object? error = await _capture(useCases.stornoRechnung(rechnungId: finalized.id, grund: 'Korrektur'));
      _expectError(error, code, fields: <String>[field]);
      expect(await _count(db, 'rechnungen'), beforeInvoices);
      expect(await _count(db, 'rechnungspositionen'), beforePositions);
      expect(await _counterValues(db), beforeCounters);
      final int restoredValue = column == 'menge' ? 1 : 100;
      await db.executor.runUpdate('UPDATE rechnungspositionen SET $column = ? WHERE rechnung_id = ?', <Object?>[
        restoredValue,
        finalized.id,
      ]);
    }

    await expectRejected('menge', 'menge', code: 'negativeInput');
    await expectRejected('einzelpreis', 'einzelpreis', code: 'negativeInput');
    await expectRejected('gesamt', 'gesamt', code: 'negativeInput', value: -100);
  });

  test('test_replacement_draft_preserves_document_discount_and_totals', () async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
    );
    final RechnungenDataSource dataSource = RechnungenDataSource(db.executor);
    final RechnungenUseCases useCases = RechnungenUseCases(RechnungenRepository(dataSource));
    final draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
      rabattProzent: 10,
    );
    final finalized = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    await useCases.stornoRechnung(rechnungId: finalized.id, grund: 'Korrektur');

    final int replacementId = await dataSource.createErsatzRechnung(vonRechnungId: finalized.id);
    final List<Map<String, Object?>> replacement = await db.executor.runSelect(
      'SELECT rabatt_prozent, rabatt_betrag, netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[replacementId],
    );

    expect(num.parse(replacement.single['rabatt_prozent'].toString()), 10);
    expect(num.parse(replacement.single['netto_betrag'].toString()), 90);
    expect(num.parse(replacement.single['ust_betrag'].toString()), 17.1);
    expect(num.parse(replacement.single['brutto_betrag'].toString()), 107.1);
    await useCases.finalizeRechnung(rechnungId: replacementId, locale: 'de_DE');
  });
}
