import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/custom_template_repository.dart';

/// Custom CSV template management (bank-import section 3).
void main() {
  group('Custom templates', () {
    late AppDatabase db;
    late CustomTemplateRepository repo;

    const mapping = <String, String>{
      'datum': 'Buchungstag',
      'betrag': 'Betrag',
      'verwendungszweck': 'Verwendungszweck',
    };

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = CustomTemplateRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('test_create_custom_template', () async {
      final template = await repo.create(
        name: 'Meine Bank',
        delimiter: ';',
        encoding: 'utf-8',
        dateFormat: 'dd.MM.yyyy',
        fieldMapping: mapping,
      );
      expect(template.typ.startsWith('custom_'), isTrue);
      expect(template.delimiter, ';');
      expect((await repo.listCustom()).map((t) => t.id), contains(template.id));
    });

    test('test_reject_invalid_or_colliding_custom_template', () async {
      await expectLater(
        repo.create(name: '  ', delimiter: ';', encoding: 'utf-8', dateFormat: 'dd.MM.yyyy', fieldMapping: mapping),
        throwsA(isA<CustomTemplateException>()),
      );
      await repo.create(
        name: 'Duplikat',
        delimiter: ';',
        encoding: 'utf-8',
        dateFormat: 'dd.MM.yyyy',
        fieldMapping: mapping,
      );
      await expectLater(
        repo.create(
          name: 'duplikat',
          delimiter: ',',
          encoding: 'utf-8',
          dateFormat: 'yyyy-MM-dd',
          fieldMapping: mapping,
        ),
        throwsA(isA<CustomTemplateException>()),
      );
      await expectLater(
        repo.create(
          name: 'Komma Bank',
          delimiter: '|',
          encoding: 'utf-8',
          dateFormat: 'dd.MM.yyyy',
          fieldMapping: mapping,
        ),
        throwsA(isA<CustomTemplateException>()),
      );
      await expectLater(
        repo.create(
          name: 'Unvollständig',
          delimiter: ';',
          encoding: 'utf-8',
          dateFormat: 'dd.MM.yyyy',
          fieldMapping: const <String, String>{'datum': 'Tag'},
        ),
        throwsA(isA<CustomTemplateException>()),
      );
    });

    test('test_edit_existing_template', () async {
      final created = await repo.create(
        name: 'Alt',
        delimiter: ';',
        encoding: 'utf-8',
        dateFormat: 'dd.MM.yyyy',
        fieldMapping: mapping,
      );
      final edited = await repo.update(created.id, name: 'Neu', delimiter: ',');
      expect(edited.typ, created.typ);
      expect(edited.name, 'Neu');
      expect(edited.delimiter, ',');
    });

    test('test_predefined_templates_are_protected', () async {
      final rows = await db.executor.runSelect(
        "SELECT id FROM bank_templates WHERE typ = 'sparkasse' LIMIT 1",
        const [],
      );
      expect(rows, isNotEmpty);
      final seededId = (rows.single['id']! as num).toInt();
      await expectLater(repo.update(seededId, name: 'Gehackt'), throwsA(isA<CustomTemplateException>()));
      await expectLater(repo.delete(seededId), throwsA(isA<CustomTemplateException>()));
    });
  });
}
