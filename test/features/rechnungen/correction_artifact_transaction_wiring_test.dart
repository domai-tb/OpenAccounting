import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/documents/correction_artifact_writer.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';

Future<int> _finalizedDocument(RechnungenDataSource source, {String typ = 'rechnung'}) async {
  final int id = await source.createDraftRechnung(
    datum: '2026-03-10',
    typ: typ,
    positionen: const <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
    ],
  );
  await source.finalizeRechnung(rechnungId: id, locale: 'de_DE');
  return id;
}

Future<void> _expectReadableArtifact(AppDatabase db, Directory profileDir, int documentId) async {
  final Map<String, Object?> row = (await db.executor.runSelect(
    'SELECT original_pdf_pfad FROM rechnungen WHERE id = ?',
    <Object?>[documentId],
  )).single;
  final String path = row['original_pdf_pfad']! as String;
  final File pdf = File(path);
  expect(pdf.absolute.path, File('${profileDir.path}/pdfs/documents/$documentId.pdf').absolute.path);
  final List<int> bytes = await pdf.readAsBytes();
  expect(bytes, isNotEmpty);
  expect(bytes.take(4).toList(), <int>[0x25, 0x50, 0x44, 0x46]);
}

void main() {
  late AppDatabase db;
  late Directory profileDir;
  late RechnungenDataSource dataSource;

  setUp(() async {
    profileDir = await Directory.systemTemp.createTemp('correction-artifact-wiring-');
    db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
    await db.ensureOpen();
    await _seedBasics(db);
    dataSource = RechnungenDataSource(db.executor, profileDir: profileDir.path);
    addTearDown(() async {
      await db.close();
      if (profileDir.existsSync()) await profileDir.delete(recursive: true);
    });
  });

  test('correction capability requires a profile and rejects writes without one', () async {
    final RechnungenDataSource withoutProfile = RechnungenDataSource(db.executor);
    final RechnungenRepository unavailableRepository = RechnungenRepository(withoutProfile);
    expect(unavailableRepository.correctionArtifactTransactionAvailable, isFalse);

    final int invoiceId = await _finalizedDocument(dataSource);
    final invoice = (await db.executor.runSelect(
      'SELECT original_pdf_pfad, status, storno_datum FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    )).single;
    expect(invoice['original_pdf_pfad'], isNotNull);
    await _expectReadableArtifact(db, profileDir, invoiceId);

    await expectLater(
      withoutProfile.stornoRechnung(rechnungId: invoiceId, grund: 'Korrektur'),
      throwsA(isA<StateError>()),
    );
    await expectLater(withoutProfile.createGutschrift(vonRechnungId: invoiceId), throwsA(isA<StateError>()));

    final sourceAfter = (await db.executor.runSelect(
      'SELECT status, storno_datum FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    )).single;
    expect(sourceAfter['status'], invoice['status']);
    expect(sourceAfter['storno_datum'], isNull);
    expect(
      await db.executor.runSelect('SELECT id FROM rechnungen WHERE storno_von = ?', <Object?>[invoiceId]),
      isEmpty,
    );
    expect(
      await db.executor.runSelect('SELECT id FROM rechnungen WHERE gutschrift_von = ?', <Object?>[invoiceId]),
      isEmpty,
    );
    expect(RechnungenRepository(dataSource).correctionArtifactTransactionAvailable, isTrue);
  });

  test('generic finalization fails closed without an active profile', () async {
    final int invoiceId = await dataSource.createDraftRechnung(
      datum: '2026-03-10',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    final List<Map<String, Object?>> beforeNumbering = await db.executor.runSelect(
      "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang'",
      const <Object?>[],
    );
    final RechnungenDataSource withoutProfile = RechnungenDataSource(db.executor);

    await expectLater(
      withoutProfile.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE'),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('Profil'))),
    );

    final Map<String, Object?> row = (await db.executor.runSelect(
      'SELECT ist_entwurf, rechnungsnummer, original_pdf_pfad FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    )).single;
    expect(row['ist_entwurf'], 1);
    expect(row['rechnungsnummer'], isNull);
    expect(row['original_pdf_pfad'], isNull);
    expect(
      await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang'",
        const <Object?>[],
      ),
      beforeNumbering,
    );
  });

  test('unreadable finalization artifact rolls back document and numbering', () async {
    final int invoiceId = await dataSource.createDraftRechnung(
      datum: '2026-03-10',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
      ],
    );
    final _EmptyCorrectionArtifactWriter writer = _EmptyCorrectionArtifactWriter();
    final RechnungenDataSource failingDataSource = RechnungenDataSource(
      db.executor,
      profileDir: profileDir.path,
      correctionArtifactWriter: writer,
    );
    final List<Map<String, Object?>> beforeNumbering = await db.executor.runSelect(
      "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang'",
      const <Object?>[],
    );

    await expectLater(
      failingDataSource.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE'),
      throwsA(isA<FileSystemException>()),
    );

    expect(writer.committedFile, isNotNull);
    expect(writer.committedFile!.existsSync(), isFalse);
    final Map<String, Object?> row = (await db.executor.runSelect(
      'SELECT ist_entwurf, rechnungsnummer, original_pdf_pfad FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    )).single;
    expect(row['ist_entwurf'], 1);
    expect(row['rechnungsnummer'], isNull);
    expect(row['original_pdf_pfad'], isNull);
    expect(
      await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang'",
        const <Object?>[],
      ),
      beforeNumbering,
    );
  });

  test('failed immediate Lieferschein creation and conversion roll back atomically', () async {
    final _EmptyCorrectionArtifactWriter writer = _EmptyCorrectionArtifactWriter();
    final RechnungenDataSource failingDataSource = RechnungenDataSource(
      db.executor,
      profileDir: profileDir.path,
      correctionArtifactWriter: writer,
    );
    final List<Map<String, Object?>> beforeDeliveryNumbering = await db.executor.runSelect(
      "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'lieferschein'",
      const <Object?>[],
    );

    await expectLater(
      failingDataSource.createDokument(
        typ: 'lieferschein',
        datum: '2026-03-10',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Ware', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(writer.committedFile, isNotNull);
    expect(writer.committedFile!.existsSync(), isFalse);
    expect(
      await db.executor.runSelect("SELECT id FROM rechnungen WHERE typ = 'lieferschein'", const <Object?>[]),
      isEmpty,
    );
    expect(
      await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'lieferschein'",
        const <Object?>[],
      ),
      beforeDeliveryNumbering,
    );

    final int sourceId = await _finalizedDocument(dataSource, typ: 'auftrag');
    final Map<String, Object?> sourceBefore = (await db.executor.runSelect(
      'SELECT konvertiert_zu FROM rechnungen WHERE id = ?',
      <Object?>[sourceId],
    )).single;
    expect(sourceBefore['konvertiert_zu'], isNull);
    writer.committedFile = null;
    final List<Map<String, Object?>> beforeConversionNumbering = await db.executor.runSelect(
      "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'lieferschein'",
      const <Object?>[],
    );

    await expectLater(
      failingDataSource.konvertiereDokument(quelleId: sourceId, zielTyp: 'lieferschein'),
      throwsA(isA<FileSystemException>()),
    );

    expect(writer.committedFile, isNotNull);
    expect(writer.committedFile!.existsSync(), isFalse);
    expect(
      await db.executor.runSelect('SELECT konvertiert_zu FROM rechnungen WHERE id = ?', <Object?>[sourceId]),
      <Map<String, Object?>>[sourceBefore],
    );
    expect(
      await db.executor.runSelect("SELECT id FROM rechnungen WHERE typ = 'lieferschein'", const <Object?>[]),
      isEmpty,
    );
    expect(
      await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'lieferschein'",
        const <Object?>[],
      ),
      beforeConversionNumbering,
    );
  });

  test('Storno and Gutschrift store readable paths returned by the writer', () async {
    final int stornoSourceId = await _finalizedDocument(dataSource);
    final int stornoId = await dataSource.stornoRechnung(rechnungId: stornoSourceId, grund: 'Korrektur');
    await _expectReadableArtifact(db, profileDir, stornoId);

    final int creditSourceId = await _finalizedDocument(dataSource);
    final int creditId = await dataSource.createGutschrift(vonRechnungId: creditSourceId);
    await _expectReadableArtifact(db, profileDir, creditId);
  });

  test('unreadable committed path rolls correction state and artifact back', () async {
    final int invoiceId = await _finalizedDocument(dataSource);
    final _EmptyCorrectionArtifactWriter writer = _EmptyCorrectionArtifactWriter();
    final RechnungenDataSource failingDataSource = RechnungenDataSource(
      db.executor,
      profileDir: profileDir.path,
      correctionArtifactWriter: writer,
    );
    final List<Map<String, Object?>> beforeNumbering = await db.executor.runSelect(
      "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'stornorechnung'",
      const <Object?>[],
    );

    await expectLater(
      failingDataSource.stornoRechnung(rechnungId: invoiceId, grund: 'Korrektur'),
      throwsA(isA<FileSystemException>()),
    );

    expect(writer.committedFile, isNotNull);
    expect(writer.committedFile!.existsSync(), isFalse);
    final sourceAfter = (await db.executor.runSelect(
      'SELECT status, storno_datum FROM rechnungen WHERE id = ?',
      <Object?>[invoiceId],
    )).single;
    expect(sourceAfter['status'], 'offen');
    expect(sourceAfter['storno_datum'], isNull);
    expect(
      await db.executor.runSelect('SELECT id FROM rechnungen WHERE storno_von = ?', <Object?>[invoiceId]),
      isEmpty,
    );
    expect(
      await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'stornorechnung'",
        const <Object?>[],
      ),
      beforeNumbering,
    );
  });

  test('Lieferscheine from creation and conversion finalize with readable artifacts', () async {
    final int directId = await dataSource.createDokument(
      typ: 'lieferschein',
      datum: '2026-03-10',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Lieferposition', menge: 1, einzelpreis: 12, gesamt: 12),
      ],
    );
    final direct = (await db.executor.runSelect(
      'SELECT ist_entwurf, original_pdf_pfad FROM rechnungen WHERE id = ?',
      <Object?>[directId],
    )).single;
    expect(direct['ist_entwurf'], 0);
    expect(direct['original_pdf_pfad'], isNotNull);
    await _expectReadableArtifact(db, profileDir, directId);

    final int orderId = await _finalizedDocument(dataSource, typ: 'auftrag');
    final int convertedId = await dataSource.konvertiereDokument(quelleId: orderId, zielTyp: 'lieferschein');
    final converted = (await db.executor.runSelect(
      'SELECT ist_entwurf, original_pdf_pfad, konvertiert_von FROM rechnungen WHERE id = ?',
      <Object?>[convertedId],
    )).single;
    expect(converted['ist_entwurf'], 0);
    expect(converted['original_pdf_pfad'], isNotNull);
    expect(converted['konvertiert_von'], orderId);
    final sourceLink = (await db.executor.runSelect('SELECT konvertiert_zu FROM rechnungen WHERE id = ?', <Object?>[
      orderId,
    ])).single;
    expect(sourceLink['konvertiert_zu'], convertedId);
    expect(
      await db.executor.runSelect('SELECT id FROM rechnungspositionen WHERE rechnung_id = ?', <Object?>[convertedId]),
      hasLength(1),
    );
    await _expectReadableArtifact(db, profileDir, convertedId);
  });
}

Future<void> _seedBasics(AppDatabase db) async {
  await db.kategorienRepository.create(bezeichnung: 'Korrektur-Kategorie');
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'AU-YY####', naechste_nummer = 1 WHERE typ = 'auftrag'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'LS-YY####', naechste_nummer = 1 WHERE typ = 'lieferschein'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
  );
}

class _EmptyCorrectionArtifactWriter extends CorrectionArtifactWriter {
  _EmptyCorrectionArtifactWriter();

  File? committedFile;

  @override
  Future<File> commitFinalizedArtifact({
    required Directory documentsDir,
    required int documentId,
    required Uint8List pdfBytes,
  }) async {
    documentsDir.createSync(recursive: true);
    committedFile = File('${documentsDir.path}/$documentId.pdf');
    committedFile!.writeAsBytesSync(const <int>[], flush: true);
    return committedFile!;
  }
}
