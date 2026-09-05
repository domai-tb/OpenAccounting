import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/journal_entity.dart';
import 'package:openaccounting/features/accounting/journal_repository.dart';

void main() {
  group('Journal Entries + GoBD', () {
    late AppDatabase db;
    late JournalRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = JournalRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('booking creates immutable entry with auto id and GoBD trigger', () async {
      // Arrange: valid kategorien seeded (ids 1..85) + booking data.
      final entry = await repo.create(
        datum: DateTime(2026, 3, 15),
        bezeichnung: 'Testbuchung Einnahme',
        kategorieId: 1,
        betrag: '1234.56',
        art: 'Einnahme',
        kontoSkr03: '8400',
        ustSatzId: 2,
      );

      // Assert: row inserted, auto id, immutable initially 0.
      expect(entry.id, greaterThan(0));
      expect(entry.bezeichnung, 'Testbuchung Einnahme');
      expect(entry.kategorieId, 1);
      expect(entry.betrag, '1234.56');
      expect(entry.art, 'Einnahme');
      expect(entry.immutable, isFalse);
      expect(entry.kontoSkr03, '8400');

      // Verify via raw SQL — immutable flag 0, NUMERIC(12,2) stored exactly.
      final rows = await db.executor.runSelect(
        'SELECT id, datum, beschreibung, kategorie_id, betrag, immutable, '
        'konto_skr03_snapshot, ust_satz_id FROM journal WHERE id = ?',
        <Object?>[entry.id],
      );
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['beschreibung'], 'Testbuchung Einnahme');
      expect(row['kategorie_id'], 1);
      expect((row['betrag'] as num?)?.toStringAsFixed(2), '1234.56');
      expect(row['immutable'], 0);
      expect(row['konto_skr03_snapshot'], '8400');
      expect(row['ust_satz_id'], 2);

      // GoBD triggers exist.
      final triggers = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'protect_journal%'",
        const <Object?>[],
      );
      final names = triggers.map((r) => r['name']?.toString() ?? '').toList();
      expect(names, contains('protect_journal_update'));
      expect(names, contains('protect_journal_delete'));
    });

    test('GoBD: immutable row rejects UPDATE/DELETE, mutable succeeds', () async {
      // Mutable entry should allow UPDATE and DELETE.
      final mutable = await repo.create(
        datum: DateTime(2026, 3, 15),
        bezeichnung: 'Mutable',
        kategorieId: 2,
        betrag: '100.00',
        art: 'Ausgabe',
      );
      await db.executor.runCustom('UPDATE journal SET beschreibung = ? WHERE id = ?', <Object?>[
        'Geändert',
        mutable.id,
      ]);
      final changed = await repo.findById(mutable.id);
      expect(changed!.bezeichnung, 'Geändert');
      await db.executor.runCustom('DELETE FROM journal WHERE id = ?', <Object?>[mutable.id]);
      expect(await repo.findById(mutable.id), isNull);

      // Immutable entry — set immutable=1 then attempt mutation.
      final fixed = await repo.create(
        datum: DateTime(2026, 3, 16),
        bezeichnung: 'Fixed',
        kategorieId: 3,
        betrag: '200.00',
        art: 'Einnahme',
      );
      await db.executor.runCustom('UPDATE journal SET immutable = 1 WHERE id = ?', <Object?>[fixed.id]);

      const msg = 'GoBD: Dieser Journaleintrag ist unveränderlich';
      await expectLater(
        db.executor.runCustom('UPDATE journal SET beschreibung = ? WHERE id = ?', <Object?>['Hack', fixed.id]),
        throwsA(predicate<Object>((e) => e.toString().contains(msg))),
      );
      await expectLater(
        db.executor.runCustom('DELETE FROM journal WHERE id = ?', <Object?>[fixed.id]),
        throwsA(predicate<Object>((e) => e.toString().contains(msg))),
      );

      // Row still there unchanged.
      final still = await repo.findById(fixed.id);
      expect(still, isNotNull);
      expect(still!.bezeichnung, 'Fixed');
    });

    test('missing required fields rejects validation', () async {
      // kategorieId invalid (0) should reject — spec: kategorie_id = NULL.
      await expectLater(
        repo.create(
          datum: DateTime(2026, 3, 15),
          bezeichnung: 'Ohne Kategorie',
          kategorieId: 0,
          betrag: '10.00',
          art: 'Einnahme',
        ),
        throwsA(isA<JournalException>()),
      );

      // betrag empty should reject — spec brutto_betrag = NULL.
      await expectLater(
        repo.create(
          datum: DateTime(2026, 3, 15),
          bezeichnung: 'Ohne Betrag',
          kategorieId: 1,
          betrag: '',
          art: 'Einnahme',
        ),
        throwsA(isA<JournalException>()),
      );

      // bezeichnung blank should reject
      await expectLater(
        repo.create(datum: DateTime(2026, 3, 15), bezeichnung: '   ', kategorieId: 1, betrag: '10.00', art: 'Einnahme'),
        throwsA(isA<JournalException>()),
      );

      // art invalid should reject
      await expectLater(
        repo.create(
          datum: DateTime(2026, 3, 15),
          bezeichnung: 'Falsche Art',
          kategorieId: 1,
          betrag: '10.00',
          art: 'Unbekannt',
        ),
        throwsA(isA<JournalException>()),
      );

      // No rows persisted from failed attempts (only possible successful from previous tests, fresh db per test).
      final all = await repo.list();
      expect(all, isEmpty);
    });

    test('storno creates negative entry linked via storno_von', () async {
      final original = await repo.create(
        datum: DateTime(2026, 1, 10),
        bezeichnung: 'Original',
        kategorieId: 5,
        betrag: '500.00',
        art: 'Einnahme',
      );
      await db.executor.runCustom('UPDATE journal SET immutable = 1 WHERE id = ?', <Object?>[original.id]);

      final storno = await repo.storno(originalId: original.id);

      expect(storno.stornoVon, original.id);
      expect(storno.betrag, '-500.00');
      expect(storno.immutable, isFalse);

      final rows = await db.executor.runSelect('SELECT storno_von, betrag FROM journal WHERE id = ?', <Object?>[
        storno.id,
      ]);
      expect(rows.single['storno_von'], original.id);
      expect((rows.single['betrag'] as num?)?.toStringAsFixed(2), '-500.00');
    });
  });
}
