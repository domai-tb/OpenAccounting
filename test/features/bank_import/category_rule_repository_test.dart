import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/category_rule_repository.dart';

/// Auto-filter rule CRUD + matching (bank-import section 2).
void main() {
  group('Category rules', () {
    late AppDatabase db;
    late CategoryRuleRepository repo;
    late int kategorieId;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = CategoryRuleRepository(db.executor);
      kategorieId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Regelkat', 1)",
        const <Object?>[],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('test_create_filter_rule', () async {
      final rule = await repo.create(pattern: 'Amazon', kategorieId: kategorieId, prioritaet: 10);
      expect(rule.pattern, 'Amazon');
      expect(rule.kategorieId, kategorieId);
      expect((await repo.match('AMAZON Marketplace'))?.id, rule.id);
    });

    test('test_reject_an_invalid_filter_rule', () async {
      await expectLater(repo.create(pattern: '   ', kategorieId: kategorieId), throwsA(isA<CategoryRuleException>()));
      await expectLater(repo.create(pattern: 'Netto', kategorieId: 99999), throwsA(isA<CategoryRuleException>()));
      expect(await repo.list(), isEmpty);
    });

    test('test_equal_priority_rules_use_rule_id_order', () async {
      final first = await repo.create(pattern: 'Shop', kategorieId: kategorieId, prioritaet: 5);
      await repo.create(pattern: 'Shop', kategorieId: kategorieId, prioritaet: 5);
      expect((await repo.match('my Shop order'))?.id, first.id);
    });

    test('test_edit_and_prioritize_a_rule', () async {
      final low = await repo.create(pattern: 'Markt', kategorieId: kategorieId, prioritaet: 1);
      final high = await repo.create(pattern: 'Markt', kategorieId: kategorieId, prioritaet: 1);
      await repo.update(high.id, prioritaet: 50);
      expect((await repo.match('Supermarkt'))?.id, high.id);
      expect((await repo.findById(low.id))?.prioritaet, 1);
    });

    test('test_delete_filter_rule', () async {
      final rule = await repo.create(pattern: 'Tanken', kategorieId: kategorieId);
      expect((await repo.match('Tanken Aral'))?.id, rule.id);
      await repo.delete(rule.id);
      expect(await repo.match('Tanken Aral'), isNull);
      expect(await repo.findById(rule.id), isNull);
    });
  });
}
