// ignore_for_file: file_names, avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/journal_entity.dart';
import 'package:openaccounting/features/accounting/journal_repository.dart';

void main() {
  group('Journal integrity and snapshots', () {
    late AppDatabase db;
    late JournalRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = JournalRepository(db.executor);

      // Seed kategorien with snapshot fields (clean first)
      await db.executor.runCustom('DELETE FROM journal');
      await db.executor.runCustom('DELETE FROM kategorien');
      await db.executor.runCustom('DELETE FROM ust_saetze');
      await db.executor.runCustom(
        'INSERT INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, typ) '
        "VALUES (1, 'Büromaterial', '6800', '6800', 12, 'Ausgabe')",
      );
      await db.executor.runCustom(
        'INSERT INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, typ) '
        "VALUES (2, 'Umsatzerlöse', '8400', '8400', 1, 'Einnahme')",
      );

      // Seed ust_saetze
      await db.executor.runCustom("INSERT INTO ust_saetze (id, satz, bezeichnung) VALUES (1, 19.0, '19%')");
    });

    tearDown(() async => db.close());

    // ── Task 1: Storno enforces immutable finalized journal rules ──

    test('test_journal_integrity_and_snapshots_1_1_finalized_source_can_be_reversed_once', () async {
      // Create an immutable finalized journal entry
      final JournalEntry original = await repo.create(
        datum: DateTime(2025, 6, 15),
        bezeichnung: 'Büromaterial Nr. 1',
        kategorieId: 1,
        betrag: '150.00',
        art: 'Ausgabe',
      );

      // Mark as immutable (simulating finalization)
      await db.executor.runCustom('UPDATE journal SET immutable = 1 WHERE id = ?', <Object?>[original.id]);
      final JournalEntry finalized = (await repo.findById(original.id))!;

      // Storno should succeed
      final JournalEntry stornoEntry = await repo.storno(originalId: finalized.id);

      // Reversal must be immutable
      expect(stornoEntry.immutable, isTrue, reason: 'Storno entry must be immutable');

      // Reversal must have inverse betrag
      expect(stornoEntry.betrag, startsWith('-'), reason: 'Storno betrag must be negated');

      // Reversal must link to source
      expect(stornoEntry.stornoVon, equals(finalized.id), reason: 'storno_von must point to original');

      // Reversal must share gruppe_id with source
      expect(stornoEntry.gruppeId, equals(finalized.gruppeId), reason: 'gruppe_id must be preserved');

      // Second storno must be rejected
      expect(
        () => repo.storno(originalId: finalized.id),
        throwsA(isA<JournalException>().having((e) => e.message, 'message', contains('bereits storniert'))),
      );
    });

    test('test_journal_integrity_and_snapshots_1_2_mutable_or_already_reversed_source_is_rejected', () async {
      // Create a mutable (non-finalized) entry
      final JournalEntry mutable = await repo.create(
        datum: DateTime(2025, 6, 15),
        bezeichnung: 'Offene Position',
        kategorieId: 1,
        betrag: '100.00',
        art: 'Ausgabe',
      );

      // Storno of mutable entry must be rejected
      expect(
        () => repo.storno(originalId: mutable.id),
        throwsA(isA<JournalException>().having((e) => e.message, 'message', contains('nicht finalisiert'))),
      );

      // Finalize and storno once
      await db.executor.runCustom('UPDATE journal SET immutable = 1 WHERE id = ?', <Object?>[mutable.id]);
      await repo.storno(originalId: mutable.id);

      // Storno of already-reversed entry must be rejected
      expect(
        () => repo.storno(originalId: mutable.id),
        throwsA(isA<JournalException>().having((e) => e.message, 'message', contains('bereits storniert'))),
      );
    });

    // ── Task 3: Journal rows carry audit-stable snapshots ──

    test('test_journal_integrity_and_snapshots_2_1_missing_snapshots_are_resolved', () async {
      // Create entry without explicit snapshot values
      final JournalEntry entry = await repo.create(
        datum: DateTime(2025, 7, 1),
        bezeichnung: 'Testeinkauf',
        kategorieId: 1,
        betrag: '200.00',
        art: 'Ausgabe',
      );

      // Snapshot fields must be resolved from category
      expect(entry.kontoSkr03, equals('6800'), reason: 'konto_skr03 snapshot must be resolved from category');
      expect(entry.kontoSkr04, equals('6800'), reason: 'konto_skr04 snapshot must be resolved from category');
    });

    test('test_journal_integrity_and_snapshots_2_2_historical_read_is_stable_after_master_data_edit', () async {
      // Create entry with resolved snapshots
      final JournalEntry entry = await repo.create(
        datum: DateTime(2025, 7, 1),
        bezeichnung: 'Dauerhafter Eintrag',
        kategorieId: 2,
        betrag: '500.00',
        art: 'Einnahme',
      );

      final String originalKontoSkr03 = entry.kontoSkr03 ?? '';
      final int? originalGruppeId = entry.gruppeId;

      // Edit master data (rename category, change account mapping)
      await db.executor.runCustom(
        "UPDATE kategorien SET bezeichnung = 'Umsatz (geändert)', konto_skr03 = '8000' WHERE id = 2",
      );

      // Re-read journal entry — snapshots must be stable
      final JournalEntry reloaded = (await repo.findById(entry.id))!;
      expect(
        reloaded.kontoSkr03,
        equals(originalKontoSkr03),
        reason: 'konto_skr03 snapshot must not change after master-data edit',
      );
      expect(
        reloaded.gruppeId,
        equals(originalGruppeId),
        reason: 'gruppe_id must remain stable after master-data edit',
      );
    });
  });
}
