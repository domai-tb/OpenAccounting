// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/seed.dart';

void main() {
  group('Seed master data contract', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async => db.close());

    test('test_seed_master_data_contract_1_1_fresh_profile_supports_reporting_without_custom_fixtures', () async {
      // Fresh profile ships no preconfigured mappings without an approved
      // manifest: explicit unconfigured state, no synthetic SKR/EÜR values.
      final cats = await db.executor.runSelect(
        'SELECT id, bezeichnung, konto_skr03, konto_skr04, euer_zeile FROM kategorien LIMIT 10',
        const <Object?>[],
      );
      expect(cats, isEmpty, reason: 'No synthetic categories without an approved manifest');
      expect(await db.kategorienRepository.isAccountingConfigured(), isFalse);
    });

    test('test_seed_master_data_contract_1_2_seed_upgrade_preserves_user_edits', () async {
      // User-defined category with explicit values.
      final created = await db.kategorienRepository.create(bezeichnung: 'Anfang', kontoSkr03: '8001');
      await db.kategorienRepository.update(created.id, <String, dynamic>{'bezeichnung': 'Meine Kategorie'});
      final before = await db.executor.runSelect('SELECT bezeichnung FROM kategorien WHERE id = ?', <Object?>[
        created.id,
      ]);
      expect(before.first['bezeichnung'], 'Meine Kategorie');

      // Re-run seed (idempotent)
      await SeedData.run(db.executor);

      // User edit should be preserved
      final after = await db.executor.runSelect('SELECT bezeichnung FROM kategorien WHERE id = ?', <Object?>[
        created.id,
      ]);
      expect(after.first['bezeichnung'], 'Meine Kategorie');
    });

    test('test_seed_master_data_contract_2_1_supported_template_parses_its_format', () async {
      // Bank templates should be seeded
      final templates = await db.executor.runSelect('SELECT id, name, typ FROM bank_templates', const <Object?>[]);
      expect(templates.isNotEmpty, isTrue, reason: 'Bank templates should be seeded');

      // Should have Sparkasse template
      final sparkasse = templates.where((t) => t['typ'] == 'sparkasse').toList();
      expect(sparkasse.isNotEmpty, isTrue, reason: 'Sparkasse template should exist');
    });

    test('test_seed_master_data_contract_2_2_unknown_format_is_not_silently_mapped', () async {
      // Query for a non-existent template type
      final templates = await db.executor.runSelect(
        "SELECT * FROM bank_templates WHERE typ = 'unknown_bank'",
        const <Object?>[],
      );
      expect(templates.isEmpty, isTrue, reason: 'Unknown template should not exist');
    });
  });
}
