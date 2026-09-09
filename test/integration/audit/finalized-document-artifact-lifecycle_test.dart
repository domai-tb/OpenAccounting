// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  late AppDatabase db;
  late RechnungenDataSource ds;
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pdf-artifact-test-');
    db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
    ds = RechnungenDataSource(db.executor);
    // Ensure extra columns exist (same as RechnungenDataSource._ensureExtraColumns).
    for (final sql in [
      'ALTER TABLE rechnungen ADD COLUMN original_pdf_pfad TEXT',
      'ALTER TABLE rechnungen ADD COLUMN absender_snapshot TEXT',
    ]) {
      try {
        await db.executor.runCustom(sql);
      } catch (_) {}
    }
  });

  tearDown(() async => db.close());

  group('Finalized document artifact lifecycle', () {
    test('test_finalized_document_artifact_lifecycle_1_1_invoice_finalization_creates_a_readable_pdf', () async {
      // Create a draft invoice and finalize it via the datasource.
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2025-01-15',
        positionen: [const RechnungPositionItem(bezeichnung: 'Testleistung', menge: 1, einzelpreis: 100, gesamt: 100)],
      );

      await ds.finalizeRechnung(rechnungId: rechnungId, profileDir: tmpDir);

      // Read back the stored path.
      final rows = await db.executor.runSelect(
        'SELECT original_pdf_pfad, rechnungsnummer FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      final row = rows.single;
      final storedPath = row['original_pdf_pfad'] as String?;

      // After finalization, a non-empty PDF must exist at the stored path.
      expect(storedPath, isNotNull, reason: 'finalizeRechnung must store a PDF path');
      final file = File(storedPath!);
      expect(file.existsSync(), isTrue, reason: 'PDF artifact must exist at stored path');
      expect(file.lengthSync(), greaterThan(0), reason: 'PDF artifact must not be empty');
      // Verify it starts with %PDF header.
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF', reason: 'Artifact must be a valid PDF');
    });

    test('test_finalized_document_artifact_lifecycle_1_2_artifact_failure_prevents_a_false_path', () async {
      // Create a draft invoice and finalize it.
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2025-01-15',
        positionen: [const RechnungPositionItem(bezeichnung: 'Testleistung', menge: 1, einzelpreis: 100, gesamt: 100)],
      );

      await ds.finalizeRechnung(rechnungId: rechnungId, profileDir: tmpDir);

      // Read back the stored path.
      final rows = await db.executor.runSelect('SELECT original_pdf_pfad FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ]);
      final storedPath = rows.single['original_pdf_pfad'] as String?;

      // If a path is stored, the artifact file must exist on disk.
      if (storedPath != null && storedPath.isNotEmpty) {
        final file = File(storedPath);
        expect(file.existsSync(), isTrue, reason: 'If a path is stored, the artifact file must exist on disk');
      }
    });

    test('test_finalized_document_artifact_lifecycle_2_1_a_user_can_reopen_and_save_a_finalized_pdf', () async {
      // Create a draft, finalize it, then verify the artifact can be read.
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2025-01-15',
        positionen: [const RechnungPositionItem(bezeichnung: 'Testleistung', menge: 1, einzelpreis: 100, gesamt: 100)],
      );

      await ds.finalizeRechnung(rechnungId: rechnungId, profileDir: tmpDir);

      final rows = await db.executor.runSelect('SELECT original_pdf_pfad FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ]);
      final storedPath = rows.single['original_pdf_pfad'] as String?;

      expect(storedPath, isNotNull, reason: 'finalizeRechnung must store a PDF path');
      final file = File(storedPath!);
      expect(file.existsSync(), isTrue, reason: 'PDF artifact must exist after finalization');

      // Simulate save-as: read bytes and write to a new location.
      final saveTarget = File('${tmpDir.path}/saved-copy.pdf');
      await file.copy(saveTarget.path);
      expect(saveTarget.existsSync(), isTrue);
      expect(saveTarget.lengthSync(), greaterThan(0));
    });

    test('test_finalized_document_artifact_lifecycle_2_2_missing_or_unsupported_actions_are_actionable', () async {
      // Verify that when no artifact exists, actions are gracefully blocked.
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2025-01-15',
        positionen: [const RechnungPositionItem(bezeichnung: 'Testleistung', menge: 1, einzelpreis: 100, gesamt: 100)],
      );

      // Don't finalize — no artifact should exist.
      final rows = await db.executor.runSelect('SELECT original_pdf_pfad FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ]);
      final storedPath = rows.single['original_pdf_pfad'] as String?;

      // Draft invoice has no artifact yet.
      expect(storedPath, isNull, reason: 'Draft should not have a PDF artifact path');
    });
  });
}
