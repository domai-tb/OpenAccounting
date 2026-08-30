import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/gobd_triggers.dart';

void main() {
  group('GoBD journal protection', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('rejects UPDATE and DELETE for immutable journal rows', () async {
      await db.executor.runCustom(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (1, '2026-01-01', 10, 1, 'Original')",
      );

      final errorMessage = 'GoBD: Dieser Journaleintrag ist unveränderlich';
      await expectLater(
        db.executor.runCustom("UPDATE journal SET beschreibung = 'Geändert' WHERE id = 1"),
        throwsA(predicate<Object>((error) => error.toString().contains(errorMessage))),
      );
      await expectLater(
        db.executor.runCustom('DELETE FROM journal WHERE id = 1'),
        throwsA(predicate<Object>((error) => error.toString().contains(errorMessage))),
      );

      final rows = await db.executor.runSelect('SELECT beschreibung FROM journal WHERE id = 1', const []);
      expect(rows.single['beschreibung'], 'Original');
    });

    test('allows modification of mutable journal rows', () async {
      await db.executor.runCustom(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (2, '2026-01-01', 10, 0, 'Original')",
      );

      await db.executor.runCustom("UPDATE journal SET beschreibung = 'Geändert' WHERE id = 2");
      await db.executor.runCustom('DELETE FROM journal WHERE id = 2');

      final rows = await db.executor.runSelect('SELECT id FROM journal WHERE id = 2', const []);
      expect(rows, isEmpty);
    });

    test('reinstall restores protection after triggers are removed', () async {
      await db.executor.runCustom("INSERT INTO journal (id, datum, betrag, immutable) VALUES (3, '2026-01-01', 10, 1)");
      await GobdTriggers.uninstall(db.executor);
      await db.executor.runCustom('UPDATE journal SET betrag = 11 WHERE id = 3');

      await GobdTriggers.install(db.executor);
      await expectLater(
        db.executor.runCustom('UPDATE journal SET betrag = 12 WHERE id = 3'),
        throwsA(
          predicate<Object>((error) => error.toString().contains('GoBD: Dieser Journaleintrag ist unveränderlich')),
        ),
      );
    });
  });
}
