import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_exception.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';

void main() {
  group('Mahnstufen 4 Levels', () {
    late AppDatabase db;
    late MahnstufenRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MahnstufenRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('fresh DB has 4 standard levels system_stufe=true with gebuehr/zinssatz', () async {
      // Act: list via repository (ensures 4 levels idempotent).
      final levels = await repo.list();
      final system = levels.where((e) => e.systemStufe).toList(growable: false);

      // Assert: exactly 4 system levels with required names.
      expect(system, hasLength(4));
      expect(
        system.map((e) => e.bezeichnung).toList(),
        containsAll(<String>['Mahnung 1', 'Mahnung 2', 'Mahnung 3', 'Letzte Mahnung vor Inkasso']),
      );
      for (final l in system) {
        expect(l.gebuehr, isNotEmpty);
        expect(l.zinssatz, isNotEmpty);
      }
      final m1 = system.firstWhere((e) => e.bezeichnung == 'Mahnung 1');
      expect(m1.gebuehr, '5.00');
      expect(m1.stufe, 1);
      final m4 = system.firstWhere((e) => e.bezeichnung == 'Letzte Mahnung vor Inkasso');
      expect(m4.stufe, 4);
    });

    test('user cannot delete system level -> throws', () async {
      // Arrange: pick a system level.
      final levels = await repo.list();
      final system = levels.firstWhere((e) => e.systemStufe);

      // Act & Assert: delete is rejected with protection message.
      await expectLater(
        repo.delete(system.id),
        throwsA(isA<MahnstufeException>().having((e) => e.message, 'message', contains('Systemstufe'))),
      );
      final after = await repo.getById(system.id);
      expect(after, isNotNull);
    });

    test('edit system level gebuehr 5->10 applies to new mahnungen after edit', () async {
      // Arrange: Mahnung 1 has 5.00 initially.
      final levels = await repo.list();
      final m1 = levels.firstWhere((e) => e.bezeichnung == 'Mahnung 1');
      expect(m1.gebuehr, '5.00');

      // Act: edit gebuehr.
      await repo.update(m1.id, gebuehr: '10.00');
      final updated = await repo.getById(m1.id);

      // Assert: new value persists for future reads (new Mahnungen).
      expect(updated, isNotNull);
      expect(updated!.gebuehr, '10.00');
      final fresh = await repo.list();
      final m1Fresh = fresh.firstWhere((e) => e.id == m1.id);
      expect(m1Fresh.gebuehr, '10.00');
    });

    test('configure level with multiplier true includes prior, false ignores', () async {
      // Arrange: set level 2 to 10.00, level 3 own 5.00 multiplier false.
      final levels = await repo.list();
      final l2 = levels.firstWhere((e) => e.stufe == 2);
      final l3 = levels.firstWhere((e) => e.stufe == 3);
      await repo.update(l2.id, gebuehr: '10.00');
      await repo.update(l3.id, gebuehr: '5.00', multiplier: false);

      // Assert: multiplier false -> only own.
      expect(await repo.effektiveGebuehr(l3.id), '5.00');

      // Act: enable multiplier.
      await repo.update(l3.id, multiplier: true);

      // Assert: includes prior level gebuehr (10 + 5 = 15.00).
      expect(await repo.effektiveGebuehr(l3.id), '15.00');

      // Act: disable again.
      await repo.update(l3.id, multiplier: false);
      expect(await repo.effektiveGebuehr(l3.id), '5.00');
    });

    test('custom level creation appears and is deletable', () async {
      // Act: create custom level beyond 4 system levels.
      final custom = await repo.create(
        stufe: 5,
        bezeichnung: 'Mahnung 4 - Inkasso-Vorbereitung',
        gebuehr: '20.00',
        zinssatz: '8.00',
        tageNachFaelligkeit: 30,
      );

      // Assert: appears in list, not system protected.
      expect(custom.bezeichnung, 'Mahnung 4 - Inkasso-Vorbereitung');
      expect(custom.systemStufe, isFalse);
      final afterCreate = await repo.list();
      expect(afterCreate.any((e) => e.bezeichnung == 'Mahnung 4 - Inkasso-Vorbereitung'), isTrue);

      // Act: delete custom level.
      await repo.delete(custom.id);

      // Assert: removed.
      final afterDelete = await repo.list();
      expect(afterDelete.any((e) => e.id == custom.id), isFalse);
      expect(await repo.getById(custom.id), isNull);
    });
  });
}
