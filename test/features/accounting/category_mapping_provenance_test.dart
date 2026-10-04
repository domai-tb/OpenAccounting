import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/datev_entity.dart';
import 'package:openaccounting/features/accounting/datev_service.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';

/// Category mapping provenance: accounting behavior scenarios
/// (accounting-catalog-provenance, accounting delta). All tests start red.
void main() {
  group('Kategorien', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    const manifest = CategoryCatalogManifest(
      sourceReference: 'TEST-SKR03',
      sourceVersion: '2026-test.1',
      reviewApproved: true,
      entries: <CategoryCatalogEntry>[
        CategoryCatalogEntry(
          key: 'TEST-100',
          bezeichnung: 'Katalogkategorie',
          beschreibung: 'Beschreibung',
          kontoSkr03: '8200',
          kontoSkr04: '4200',
          euerZeile: 14,
        ),
      ],
    );

    test('test_accounting_catalog_001_approved_catalog_category_has_traceable_mappings', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final stored = imported.single;
      expect(stored.kontoSkr03, '8200');
      expect(stored.euerZeile, 14);
      expect(stored.catalogEntryKey, 'TEST-100');
      expect(stored.catalogSourceVersion, '2026-test.1');
      expect(stored.mappingStatus, CategoryMappingStatus.catalogVerified);
    });

    test('test_accounting_catalog_002_category_with_skr_mapping', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final stored = imported.single;
      expect(stored.kontoSkr03, '8200');
      expect(stored.kontoSkr04, '4200');
      expect(stored.mappingStatus, CategoryMappingStatus.catalogVerified);
    });

    test('test_accounting_catalog_003_user_defined_category_is_not_described_as_a_standard_mapping', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Eigen', kontoSkr03: '8999');
      expect(created.mappingStatus, isNot(CategoryMappingStatus.catalogVerified));
      expect(created.catalogEntryKey, isNull);
      expect(created.catalogSourceReference, isNull);
    });

    test('test_accounting_catalog_004_unmapped_user_category_remains_explicitly_unmapped', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Ohne Mapping');
      expect(created.mappingStatus, CategoryMappingStatus.unmapped);
      expect(created.kontoSkr03, isNull);
      expect(created.kontoSkr04, isNull);
      expect(created.euerZeile, isNull);
    });

    test('test_accounting_catalog_005_editing_a_catalog_mapping_requires_review', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final edited = await db.kategorienRepository.update(imported.single.id, <String, dynamic>{'euer_zeile': 20});
      expect(edited.mappingStatus, CategoryMappingStatus.reviewRequired);
      expect(edited.catalogSourceVersion, '2026-test.1');
      expect(edited.mappingStatus, isNot(CategoryMappingStatus.catalogVerified));
    });

    test('test_accounting_catalog_006_user_modified_skr_account', () async {
      final imported = await db.kategorienRepository.importApprovedManifest(manifest);
      final edited = await db.kategorienRepository.update(imported.single.id, <String, dynamic>{'konto_skr03': '8999'});
      expect(edited.kontoSkr03, '8999');
      expect(edited.mappingStatus, CategoryMappingStatus.reviewRequired);
    });

    test('test_accounting_catalog_007_legacy_category_values_are_retained_but_untrusted', () async {
      await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, beschreibung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>['Bestand', 'Alt', '8100', '4100', 11, 1],
      );
      final rows = await db.executor.runSelect('SELECT id FROM kategorien LIMIT 1', const []);
      final stored = await db.kategorienRepository.findById((rows.single['id']! as num).toInt());
      expect(stored?.kontoSkr03, '8100');
      expect(stored?.mappingStatus, CategoryMappingStatus.legacyUnverified);
      final visible = await db.kategorienRepository.list();
      expect(visible.map((k) => k.id), contains(stored?.id));
    });

    test('test_accounting_catalog_010_inactive_category', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Inaktiv', aktiv: false);
      final selectable = await db.kategorienRepository.list(onlyActive: true);
      expect(selectable.map((k) => k.id), isNot(contains(created.id)));
      final stored = await db.kategorienRepository.findById(created.id);
      expect(stored, isNotNull);
    });

    test('test_accounting_catalog_011_category_description', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Mit Hinweis', beschreibung: 'Hinweistext');
      final stored = await db.kategorienRepository.findById(created.id);
      expect(stored?.beschreibung, 'Hinweistext');
    });

    test('test_accounting_catalog_014_category_review_is_unavailable_until_its_workspace_is_accepted', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Ungeprüft', kontoSkr03: '8001');
      await expectLater(db.kategorienRepository.reviewMapping(created.id), throwsA(isA<CategoryReviewUnavailable>()));
      final stored = await db.kategorienRepository.findById(created.id);
      expect(stored?.mappingStatus, CategoryMappingStatus.reviewRequired);
    });
  });

  group('EÜR and DATEV disclose or reject category mapping provenance', () {
    late AppDatabase db;
    late EuerService euer;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      euer = EuerService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    const manifest = CategoryCatalogManifest(
      sourceReference: 'TEST-SKR03',
      sourceVersion: '2026-test.1',
      reviewApproved: true,
      entries: <CategoryCatalogEntry>[
        CategoryCatalogEntry(key: 'TEST-EUER-1', bezeichnung: 'Verifiziert', kontoSkr03: '8200', euerZeile: 14),
      ],
    );

    Future<int> addJournal({required int? kategorieId, required String betrag, String datum = '2026-03-10'}) async {
      return db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'EÜR-Test', kategorieId, betrag, 'Einnahme'],
      );
    }

    Future<Kategorie> addUserConfirmed({required int zeile}) async {
      final created = await db.kategorienRepository.create(
        bezeichnung: 'Benutzerdefiniert',
        kontoSkr03: '8999',
        euerZeile: zeile,
      );
      return KategorienRepository(db.executor, categoryWorkspaceAvailable: true).reviewMapping(created.id);
    }

    test('test_accounting_catalog_018_user_configured_output_is_identified', () async {
      final verified = (await db.kategorienRepository.importApprovedManifest(manifest)).single;
      final confirmed = await addUserConfirmed(zeile: 15);
      await addJournal(kategorieId: verified.id, betrag: '100.00');
      await addJournal(kategorieId: confirmed.id, betrag: '50.00');

      final result = await euer.generate(jahr: 2026);

      expect(result.userConfirmedCategoryIds, contains(confirmed.id));
      expect(result.userConfirmedCategoryIds, isNot(contains(verified.id)));
      expect(result.catalogSources['TEST-SKR03'], '2026-test.1');
    });

    test('test_accounting_catalog_019_unresolved_mapping_stops_the_output', () async {
      await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, konto_skr03, euer_zeile, aktiv) VALUES (?, ?, ?, 1)',
        const <Object?>['Altbestand', '8100', 11],
      );
      final cats = await db.executor.runSelect('SELECT id FROM kategorien LIMIT 1', const []);
      final legacyId = (cats.single['id']! as num).toInt();
      final journalId = await addJournal(kategorieId: legacyId, betrag: '100.00');

      await expectLater(
        euer.generate(jahr: 2026),
        throwsA(
          isA<EuerException>()
              .having((e) => e.affectedJournalIds, 'journal IDs', contains(journalId))
              .having((e) => e.affectedCategoryIds, 'category IDs', contains(legacyId)),
        ),
      );
      final exports = await db.executor.runSelect('SELECT id FROM euer_exporte', const []);
      expect(exports, isEmpty, reason: 'no successful report is recorded on failure');
    });

    test('test_accounting_catalog_020_euer_detects_categories_missing_a_report_line', () async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Ohne Zeile', kontoSkr03: '8001');
      final confirmed = await KategorienRepository(
        db.executor,
        categoryWorkspaceAvailable: true,
      ).reviewMapping(created.id);
      // Remove the report line while keeping an eligible status.
      await db.executor.runUpdate('UPDATE kategorien SET euer_zeile = NULL WHERE id = ?', <Object?>[confirmed.id]);
      final journalId = await addJournal(kategorieId: confirmed.id, betrag: '100.00');

      await expectLater(
        euer.generate(jahr: 2026),
        throwsA(
          isA<EuerException>()
              .having((e) => e.affectedJournalIds, 'journal IDs', contains(journalId))
              .having((e) => e.affectedCategoryIds, 'category IDs', contains(confirmed.id)),
        ),
      );
    });

    test('test_accounting_catalog_021_euer_detects_a_missing_category_reference', () async {
      final journalId = await addJournal(kategorieId: null, betrag: '100.00');
      await expectLater(
        euer.generate(jahr: 2026),
        throwsA(isA<EuerException>().having((e) => e.affectedJournalIds, 'journal IDs', contains(journalId))),
      );
    });

    test('test_accounting_catalog_025_user_confirmed_mapping_is_visible_and_recorded', () async {
      final confirmed = await addUserConfirmed(zeile: 16);
      await addJournal(kategorieId: confirmed.id, betrag: '200.00');

      final result = await euer.generate(jahr: 2026);
      expect(result.userConfirmedCategoryIds, contains(confirmed.id));

      final exportId = await euer.persistExport(jahr: 2026, result: result);
      final rows = await db.executor.runSelect(
        'SELECT mapping_provenance_json FROM euer_exporte WHERE id = ?',
        <Object?>[exportId],
      );
      final snapshot = jsonDecode(rows.single['mapping_provenance_json']! as String) as Map<String, Object?>;
      expect(snapshot['version'], 1);
      final resolved = (snapshot['resolved']! as List).cast<Map<String, Object?>>();
      expect(resolved.single['category_id'], confirmed.id);
      expect(resolved.single['mapping_status'], 'user_confirmed');
      expect(resolved.single['category_history_id'], isNotNull);
      expect(snapshot['user_confirmed_category_ids'], contains(confirmed.id));
    });

    test('test_accounting_catalog_048_export_records_persist_the_mapping_provenance_snapshot', () async {
      // Preexisting export rows keep NULL provenance metadata.
      await db.executor.runInsert('INSERT INTO euer_exporte (jahr, summen, status) VALUES (?, ?, ?)', const <Object?>[
        2025,
        '{}',
        'erstellt',
      ]);
      final verified = (await db.kategorienRepository.importApprovedManifest(manifest)).single;
      await addJournal(kategorieId: verified.id, betrag: '300.00');

      final result = await euer.generate(jahr: 2026);
      final exportId = await euer.persistExport(jahr: 2026, result: result);

      final rows = await db.executor.runSelect(
        'SELECT id, mapping_provenance_json FROM euer_exporte ORDER BY id',
        const [],
      );
      expect(rows, hasLength(2));
      expect(rows.first['mapping_provenance_json'], isNull);
      final snapshot = jsonDecode(rows.last['mapping_provenance_json']! as String) as Map<String, Object?>;
      expect(snapshot['version'], 1);
      final resolved = (snapshot['resolved']! as List).cast<Map<String, Object?>>();
      expect(resolved.single['mapping_status'], 'catalog_verified');
      expect(resolved.single['source_reference'], 'TEST-SKR03');
      expect(resolved.single['category_history_id'], isNotNull);
      expect(rows.last['id'], exportId);
    });
  });

  group('DATEV resolves both account slots with provenance', () {
    late AppDatabase db;
    late DatevService datev;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      datev = DatevService(db.executor);
      await db.executor.runInsert(
        'INSERT INTO unternehmen (name, datev_beraternummer, datev_mandantennummer) VALUES (?, ?, ?)',
        const <Object?>['Test Firma', '12345', '678'],
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> addBankKonto({required String nummer}) {
      return db.executor.runInsert('INSERT INTO konten (name, datev_kontonummer) VALUES (?, ?)', <Object?>[
        'Bank',
        nummer,
      ]);
    }

    Future<int> addJournal({required int kategorieId, int? kontoId, String betrag = '119.00'}) {
      return db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable, konto_id) VALUES (?, ?, ?, ?, ?, 0, ?)',
        <Object?>['2026-04-10', 'DATEV-Test', kategorieId, betrag, 'Einnahme', kontoId],
      );
    }

    Future<Kategorie> addVerified({String skr03 = '8400'}) {
      return db.kategorienRepository
          .importApprovedManifest(
            CategoryCatalogManifest(
              sourceReference: 'TEST-SKR03',
              sourceVersion: '2026-test.1',
              reviewApproved: true,
              entries: <CategoryCatalogEntry>[
                CategoryCatalogEntry(key: 'DTV-$skr03', bezeichnung: 'V', kontoSkr03: skr03),
              ],
            ),
          )
          .then((list) => list.single);
    }

    Future<Kategorie> addUserConfirmed({String? skr03 = '8410'}) async {
      final created = await db.kategorienRepository.create(bezeichnung: 'Benutzerdefiniert', kontoSkr03: skr03);
      return KategorienRepository(db.executor, categoryWorkspaceAvailable: true).reviewMapping(created.id);
    }

    test('test_accounting_catalog_012_unmapped_category_does_not_receive_an_invented_account', () async {
      final unmapped = await db.kategorienRepository.create(bezeichnung: 'Ohne Mapping');
      final bankId = await addBankKonto(nummer: '1200');
      final journalId = await addJournal(kategorieId: unmapped.id, kontoId: bankId);
      await expectLater(
        datev.exportCsv(jahr: 2026),
        throwsA(
          isA<DatevException>()
              .having((e) => e.affectedJournalIds, 'journal IDs', contains(journalId))
              .having((e) => e.affectedCategoryIds, 'category IDs', contains(unmapped.id)),
        ),
      );
    });

    test('test_accounting_catalog_013_category_with_missing_skr_mapping', () async {
      final confirmed = await addUserConfirmed(skr03: null);
      final bankId = await addBankKonto(nummer: '1200');
      final journalId = await addJournal(kategorieId: confirmed.id, kontoId: bankId);
      await expectLater(
        datev.exportCsv(jahr: 2026),
        throwsA(
          isA<DatevException>()
              .having((e) => e.unresolvedSlot, 'slot', 'Gegenkonto')
              .having((e) => e.affectedJournalIds, 'journal IDs', contains(journalId))
              .having((e) => e.affectedCategoryIds, 'category IDs', contains(confirmed.id)),
        ),
      );
    });

    test('test_accounting_catalog_022_datev_detects_missing_category_account_mappings', () async {
      final legacyId = await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, konto_skr03, aktiv) VALUES (?, ?, 1)',
        const <Object?>['Altbestand', '8100'],
      );
      final bankId = await addBankKonto(nummer: '1200');
      await addJournal(kategorieId: legacyId, kontoId: bankId);
      await expectLater(
        datev.exportCsv(jahr: 2026),
        throwsA(isA<DatevException>().having((e) => e.affectedCategoryIds, 'category IDs', contains(legacyId))),
      );
      final logs = await db.executor.runSelect('SELECT id FROM datev_export_log', const []);
      expect(logs, isEmpty, reason: 'no fallback account is emitted and nothing is logged');
    });

    test('test_accounting_catalog_023_datev_records_both_account_slot_sources', () async {
      final verified = await addVerified();
      final bankId = await addBankKonto(nummer: '1800');
      final journalId = await addJournal(kategorieId: verified.id, kontoId: bankId);

      final result = await datev.exportDetailed(jahr: 2026);

      expect(result.csv, contains('1800'));
      expect(result.csv, contains('8400'));
      final accounts = (result.slotSnapshots['datev_accounts']! as List).cast<Map<String, Object?>>();
      expect(accounts, hasLength(2));
      final konto = accounts.firstWhere((a) => a['slot'] == 'Konto');
      final gegenkonto = accounts.firstWhere((a) => a['slot'] == 'Gegenkonto');
      expect(konto['journal_id'], journalId);
      expect(konto['account_number'], '1800');
      expect(konto['source'], 'explicit_account');
      expect(gegenkonto['journal_id'], journalId);
      expect(gegenkonto['account_number'], '8400');
      expect(gegenkonto['source'], 'category_mapping');
      expect(gegenkonto['category_id'], verified.id);
      expect(gegenkonto['category_history_id'], isNotNull);
      expect(gegenkonto['mapping_status'], 'catalog_verified');
    });

    test('test_accounting_catalog_024_datev_rejects_an_unresolved_account_slot', () async {
      final verified = await addVerified();
      final journalId = await addJournal(kategorieId: verified.id);
      await expectLater(
        datev.exportCsv(jahr: 2026),
        throwsA(
          isA<DatevException>()
              .having((e) => e.unresolvedSlot, 'slot', 'Konto')
              .having((e) => e.affectedJournalIds, 'journal IDs', contains(journalId)),
        ),
      );
    });

    test('test_accounting_catalog_025_datev_user_confirmed_mapping_is_visible_and_recorded', () async {
      final confirmed = await addUserConfirmed();
      final bankId = await addBankKonto(nummer: '1200');
      final journalId = await addJournal(kategorieId: confirmed.id, kontoId: bankId);

      final result = await datev.exportDetailed(jahr: 2026);

      expect(result.userConfirmedCategoryIds, contains(confirmed.id));
      final previewAccounts = (result.slotSnapshots['datev_accounts']! as List).cast<Map<String, Object?>>();
      expect(previewAccounts.map((a) => a['journal_id']), everyElement(journalId));
      final rows = await db.executor.runSelect(
        'SELECT mapping_provenance_json FROM datev_export_log WHERE id = ?',
        <Object?>[result.exportLogId],
      );
      final snapshot = jsonDecode(rows.single['mapping_provenance_json']! as String) as Map<String, Object?>;
      expect(snapshot['version'], 1);
      expect(snapshot['user_confirmed_category_ids'], contains(confirmed.id));
      final accounts = (snapshot['datev_accounts']! as List).cast<Map<String, Object?>>();
      expect(accounts.any((a) => a['mapping_status'] == 'user_confirmed'), isTrue);
      expect(accounts.any((a) => a['mapping_status'] == 'catalog_verified'), isFalse);
    });

    test('test_accounting_catalog_048_datev_export_records_persist_the_mapping_provenance_snapshot', () async {
      await db.executor.runInsert(
        'INSERT INTO datev_export_log (datum, anzahl_buchungen, status) VALUES (?, ?, ?)',
        const <Object?>['2025-01-01', 0, 'erfolg'],
      );
      final verified = await addVerified();
      final bankId = await addBankKonto(nummer: '1800');
      final journalId = await addJournal(kategorieId: verified.id, kontoId: bankId);

      final result = await datev.exportDetailed(jahr: 2026);

      final rows = await db.executor.runSelect(
        'SELECT id, mapping_provenance_json FROM datev_export_log ORDER BY id',
        const [],
      );
      expect(rows, hasLength(2));
      expect(rows.first['mapping_provenance_json'], isNull);
      final snapshot = jsonDecode(rows.last['mapping_provenance_json']! as String) as Map<String, Object?>;
      expect(snapshot['version'], 1);
      final accounts = (snapshot['datev_accounts']! as List).cast<Map<String, Object?>>();
      expect(accounts, hasLength(2));
      for (final slot in accounts) {
        expect(slot['journal_id'], journalId);
        expect(slot['slot'], isIn(<String>['Konto', 'Gegenkonto']));
        expect(slot['account_number'], isIn(<String>['1800', '8400']));
        expect(slot['source'], isIn(<String>['explicit_account', 'category_mapping']));
      }
      final gegenkonto = accounts.firstWhere((a) => a['slot'] == 'Gegenkonto');
      expect(gegenkonto['category_id'], verified.id);
      expect(gegenkonto['category_history_id'], isNotNull);
      expect(rows.last['id'], result.exportLogId);
    });
  });
}
