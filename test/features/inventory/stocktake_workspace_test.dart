import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/inventory/stocktake_page.dart';
import 'package:openaccounting/features/inventory/stocktake_providers.dart';
import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_repository.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';
import 'package:openaccounting/features/inventory/stocktake_entity.dart';
import 'package:openaccounting/features/inventory/stocktake_repository.dart';
import 'package:openaccounting/features/inventory/stocktake_usecases.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

/// Stocktake workspace: capture, recording, persistence guards, and
/// fail-closed valuation. Covers specs/inventory movement storage, capture
/// and recording, persistence, book-quantity distinction, and valuation.
void main() {
  group('stocktake workspace', () {
    late AppDatabase db;
    late StocktakeRepository repository;
    late StocktakeUseCases useCases;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Inventur GmbH']);
      await db.executor.runInsert('INSERT INTO kategorien (bezeichnung, aktiv) VALUES (?, 1)', <Object?>[
        'Inventur Test',
      ]);
      repository = StocktakeRepository(db.executor);
      useCases = StocktakeUseCases(repository, FeatureModuleService(repository: FeatureModuleRepository(db.executor)));
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> enableInventory() async {
      await FeatureModuleRepository(db.executor)
          .save(FeatureModuleState.defaults().withEnabled(FeatureModuleCatalog.inventory, value: true));
    }

    Future<void> disableInventory() async {
      await db.executor.runUpdate('UPDATE unternehmen SET lagerfuehrung_aktiv = 0', const <Object?>[]);
      await FeatureModuleRepository(db.executor)
          .save(FeatureModuleState.defaults().withEnabled(FeatureModuleCatalog.inventory, value: false));
    }

    Future<int> createArtikel({required String bezeichnung, bool lagerAktiv = true, num bestand = 0}) async {
      final artikel = await db.artikelRepository.create(
        bezeichnung: bezeichnung,
        vkBrutto: 11.9,
        lagerAktiv: lagerAktiv,
        bestandAktuell: bestand,
      );
      return artikel.id;
    }

    Future<num> bestandOf(int id) async => (await db.artikelRepository.findById(id))!.bestandAktuell;

    Future<int> movementCount() async {
      final rows = await db.executor.runSelect('SELECT id FROM inventarbewegungen', const <Object?>[]);
      return rows.length;
    }

    Future<int> journalCount() async {
      final rows = await db.executor.runSelect('SELECT id FROM journal', const <Object?>[]);
      return rows.length;
    }

    test('test_automatic_movement_recorded', () async {
      final id = await createArtikel(bezeichnung: 'Abverkauf', bestand: 50);
      final rechnungen = RechnungenDataSource(db.executor);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Abverkauf', menge: 3, einzelpreis: 10, gesamt: 30, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      final rows = await db.executor.runSelect('SELECT diff FROM inventarbewegungen WHERE artikel_id = ?', <Object?>[
        id,
      ]);
      expect(rows, hasLength(1));
      expect(num.parse(rows.single['diff'].toString()), -3);
    });

    test('test_storno_movement_recorded', () async {
      final id = await createArtikel(bezeichnung: 'Storno', bestand: 50);
      final rechnungen = RechnungenDataSource(db.executor);
      final rechnungId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Storno', menge: 10, einzelpreis: 10, gesamt: 100, artikelId: id),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: rechnungId);
      await rechnungen.stornoRechnung(rechnungId: rechnungId, grund: 'Korrektur');
      final rows = await db.executor.runSelect(
        'SELECT diff FROM inventarbewegungen WHERE artikel_id = ? ORDER BY id',
        <Object?>[id],
      );
      expect(rows.map((row) => num.parse(row['diff'].toString())), containsAll(<num>[-10, 10]));
      expect(await bestandOf(id), 50);
    });

    test('test_incoming_and_document_only_finalization_has_no_automatic_movement', () async {
      final incomingId = await createArtikel(bezeichnung: 'Eingang', bestand: 20);
      final rechnungen = RechnungenDataSource(db.executor);
      final incomingRechnung = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        typ: 'rechnung_eingang',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Eingang', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: incomingId),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: incomingRechnung);
      final angebotId = await rechnungen.createDraftRechnung(
        datum: '2026-03-01',
        typ: 'angebot',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Eingang', menge: 5, einzelpreis: 10, gesamt: 50, artikelId: incomingId),
        ],
      );
      await rechnungen.finalizeRechnung(locale: 'de_DE', rechnungId: angebotId);
      expect(await movementCount(), 0);
      expect(await bestandOf(incomingId), 20);
    });

    test('test_count_snapshots_are_not_movement_rows', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Zaehlen', bestand: 9);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 9);
      await useCases.record(draft.id);
      expect(await movementCount(), 0);
      final positions = await db.executor.runSelect(
        'SELECT menge_gezaehlt FROM inventur_positionen WHERE inventur_id = ?',
        <Object?>[draft.id],
      );
      expect(positions, hasLength(1));
      expect(num.parse(positions.single['menge_gezaehlt'].toString()), 9);
      expect(await bestandOf(id), 9);
    });

    test('test_complete_a_physical_count', () async {
      await enableInventory();
      final first = await createArtikel(bezeichnung: 'Erste Ware', bestand: 12);
      final second = await createArtikel(bezeichnung: 'Zweite Ware', bestand: 3);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      expect(draft.status, StocktakeStatus.entwurf);
      await useCases.setCount(inventurId: draft.id, artikelId: first, menge: 0);
      await useCases.setCount(inventurId: draft.id, artikelId: second, menge: 2.5);
      final recorded = await useCases.record(draft.id);
      expect(recorded.status, StocktakeStatus.erfasst);
      expect(recorded.stichtag, '2026-01-31');
      expect(recorded.erstelltAm, isNotEmpty);
      final counts = <int, num>{
        for (final position in recorded.positionen) position.artikelId: position.mengeGezaehlt!,
      };
      expect(counts[first], 0);
      expect(counts[second], 2.5);
      expect(
        recorded.positionen.map((position) => position.bezeichnungSnapshot),
        containsAll(<String>['Erste Ware', 'Zweite Ware']),
      );
      expect(await bestandOf(first), 12);
      expect(await bestandOf(second), 3);
      expect(await movementCount(), 0);
    });

    test('test_missing_count_cannot_be_recorded', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Offen', bestand: 5);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await expectLater(useCases.record(draft.id), throwsA(isA<StocktakeMissingCountException>()));
      final still = await repository.findById(draft.id);
      expect(still!.status, StocktakeStatus.entwurf);
      expect(still.positionen.single.mengeGezaehlt, isNull);
      final raw = await db.executor.runSelect(
        'SELECT menge_gezaehlt FROM inventur_positionen WHERE inventur_id = ?',
        <Object?>[draft.id],
      );
      expect(raw.single['menge_gezaehlt'], isNull);
      expect(await bestandOf(id), 5);
    });

    test('test_global_inventory_disabled', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Verlauf', bestand: 6);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 6);
      await useCases.record(draft.id);
      await disableInventory();

      await expectLater(useCases.startDraft(stichtag: '2026-02-28'), throwsA(isA<StocktakeUnavailableException>()));
      final history = await useCases.history();
      expect(history, hasLength(1));
      expect(history.single.status, StocktakeStatus.erfasst);
      final tables = await db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('inventuren', 'inventur_positionen')",
        const <Object?>[],
      );
      expect(tables, hasLength(2));
    });

    test('test_no_inventory_enabled_articles_are_available', () async {
      await enableInventory();
      await createArtikel(bezeichnung: 'Dienstleistung', lagerAktiv: false);
      await expectLater(
        useCases.startDraft(stichtag: '2026-01-31'),
        throwsA(isA<StocktakeNoCountableArticlesException>()),
      );
      final rows = await db.executor.runSelect('SELECT id FROM inventuren', const <Object?>[]);
      expect(rows, isEmpty);
    });

    test('test_recorded_count_cannot_be_overwritten', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Fest', bestand: 8);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 8);
      await useCases.record(draft.id);
      await expectLater(
        useCases.setCount(inventurId: draft.id, artikelId: id, menge: 1),
        throwsA(isA<StocktakeImmutableException>()),
      );
      await expectLater(useCases.record(draft.id), throwsA(isA<StocktakeImmutableException>()));
      final stored = await repository.findById(draft.id);
      expect(num.parse(stored!.positionen.single.mengeGezaehlt.toString()), 8);
      expect(stored.stichtag, '2026-01-31');
    });

    test('test_migration_creates_the_declared_stocktake_tables', () async {
      final headerCols = await db.executor.runSelect('PRAGMA table_info(inventuren)', const <Object?>[]);
      expect(<String>{
        for (final row in headerCols) row['name'].toString(),
      }, containsAll(<String>['id', 'stichtag', 'status', 'erstellt_am']));
      final positionCols = await db.executor.runSelect('PRAGMA table_info(inventur_positionen)', const <Object?>[]);
      expect(
        <String>{for (final row in positionCols) row['name'].toString()},
        containsAll(<String>[
          'id',
          'inventur_id',
          'artikel_id',
          'bezeichnung_snapshot',
          'einheit_snapshot',
          'menge_gezaehlt',
        ]),
      );
      final foreignKeys = await db.executor.runSelect(
        'PRAGMA foreign_key_list(inventur_positionen)',
        const <Object?>[],
      );
      expect(foreignKeys.any((row) => row['table'] == 'inventuren'), isTrue);
    });

    test('test_direct_sql_cannot_create_an_empty_recorded_header', () async {
      await expectLater(
        db.executor.runInsert(
          "INSERT INTO inventuren (stichtag, status, erstellt_am) VALUES (?, 'erfasst', ?)",
          <Object?>['2026-01-31', DateTime.now().toUtc().toIso8601String()],
        ),
        throwsA(anything),
      );
      expect(await db.executor.runSelect('SELECT id FROM inventuren', const <Object?>[]), isEmpty);
    });

    test('test_direct_update_or_delete_of_recorded_stocktake_is_rejected', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Schutz', bestand: 2);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 2);
      await useCases.record(draft.id);

      await expectLater(
        db.executor.runUpdate("UPDATE inventuren SET stichtag = '2026-02-01' WHERE id = ?", <Object?>[draft.id]),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM inventuren WHERE id = ?', <Object?>[draft.id]),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runInsert(
          'INSERT INTO inventur_positionen (inventur_id, artikel_id, bezeichnung_snapshot,'
          ' einheit_snapshot, menge_gezaehlt) VALUES (?, ?, ?, ?, ?)',
          <Object?>[draft.id, 999, 'Fremd', 'Stk', 1],
        ),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runUpdate('UPDATE inventur_positionen SET menge_gezaehlt = 5 WHERE inventur_id = ?', <Object?>[
          draft.id,
        ]),
        throwsA(anything),
      );
      await expectLater(
        db.executor.runDelete('DELETE FROM inventur_positionen WHERE inventur_id = ?', <Object?>[draft.id]),
        throwsA(anything),
      );
      final stored = await repository.findById(draft.id);
      expect(stored!.status, StocktakeStatus.erfasst);
      expect(num.parse(stored.positionen.single.mengeGezaehlt.toString()), 2);
    });

    test('test_duplicate_article_position_is_rejected', () async {
      await enableInventory();
      await createArtikel(bezeichnung: 'Doppelt', bestand: 1);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      final artikelId = draft.positionen.single.artikelId;
      await expectLater(
        db.executor.runInsert(
          'INSERT INTO inventur_positionen (inventur_id, artikel_id, bezeichnung_snapshot,'
          ' einheit_snapshot, menge_gezaehlt) VALUES (?, ?, ?, ?, ?)',
          <Object?>[draft.id, artikelId, 'Doppelt', 'Stk', 1],
        ),
        throwsA(anything),
      );
      final stored = await repository.findById(draft.id);
      expect(stored!.positionen, hasLength(1));
    });

    test('test_recorded_quantities_appear_as_physical_counts', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Messbar', bestand: 11);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 7.25);
      final recorded = await useCases.record(draft.id);
      expect(recorded.positionen.single.mengeGezaehlt, 7.25);
      expect(recorded.stichtag, '2026-01-31');
      expect(recorded.erstelltAm, isNotEmpty);
    });

    test('test_current_stock_is_not_substituted_for_historical_quantity', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Aktuell', bestand: 42);
      final draft = await useCases.startDraft(stichtag: '2025-12-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 40);
      final recorded = await useCases.record(draft.id);
      expect(recorded.positionen.single.mengeGezaehlt, 40);
      expect(await bestandOf(id), 42);
      expect(recorded.positionen.single.mengeGezaehlt, isNot(42));
    });

    test('test_count_remains_available_while_valuation_policy_is_unspecified', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Wertlos', bestand: 5);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 5);
      final recorded = await useCases.record(draft.id);
      expect(recorded.positionen.single.mengeGezaehlt, 5);
      await expectLater(useCases.requestValuation(recorded.id), throwsA(isA<StocktakeValuationUnavailableException>()));
      final stored = await repository.findById(recorded.id);
      expect(num.parse(stored!.positionen.single.mengeGezaehlt.toString()), 5);
    });

    test('test_bulk_count_save_rolls_back_after_a_mid_write_failure', () async {
      await enableInventory();
      final int firstId = await createArtikel(bezeichnung: 'Erste Ware', bestand: 5);
      final int secondId = await createArtikel(bezeichnung: 'Zweite Ware', bestand: 8);
      final Stocktake draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: firstId, menge: 5);
      await useCases.setCount(inventurId: draft.id, artikelId: secondId, menge: 8);

      await db.executor.runCustom('''
CREATE TRIGGER fail_second_stocktake_count_update
BEFORE UPDATE OF menge_gezaehlt ON inventur_positionen
WHEN NEW.inventur_id = ${draft.id} AND NEW.artikel_id = $secondId
BEGIN
  SELECT RAISE(ABORT, 'forced mid-write failure');
END
''');

      await expectLater(
        useCases.saveCounts(inventurId: draft.id, counts: <int, num?>{firstId: 10, secondId: 9}, record: true),
        throwsA(anything),
      );

      final Stocktake stored = (await repository.findById(draft.id))!;
      expect(stored.status, StocktakeStatus.entwurf);
      expect(
        <int, num?>{
          for (final StocktakePosition position in stored.positionen) position.artikelId: position.mengeGezaehlt,
        },
        <int, num?>{firstId: 5, secondId: 8},
      );
    });

    testWidgets('test_invalid_count_does_not_change_saved_draft_counts', (WidgetTester tester) async {
      late Stocktake draft;
      final expectedCounts = <int, num>{};
      await tester.runAsync(() async {
        await enableInventory();
        await createArtikel(bezeichnung: 'Erste Ware', bestand: 5);
        await createArtikel(bezeichnung: 'Zweite Ware', bestand: 8);
        draft = await useCases.startDraft(stichtag: '2026-01-31');
        for (var index = 0; index < draft.positionen.length; index++) {
          final position = draft.positionen[index];
          final count = index == 0 ? 5 : 8;
          expectedCounts[position.artikelId] = count;
          await useCases.setCount(inventurId: draft.id, artikelId: position.artikelId, menge: count);
        }
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            stocktakeUseCasesProvider.overrideWithValue(useCases),
            stocktakeEnabledProvider.overrideWith((ref) async => true),
            stocktakeDraftsProvider.overrideWith((ref) async => <Stocktake>[draft]),
            stocktakeHistoryProvider.overrideWith((ref) async => const <Stocktake>[]),
          ],
          child: const MaterialApp(home: StocktakeWorkspacePage()),
        ),
      );
      await tester.pumpAndSettle();
      final Finder firstCount = find.byType(TextField).at(1);
      final Finder secondCount = find.byType(TextField).at(2);
      final Finder saveButton = find.ancestor(
        of: find.byIcon(Icons.save_outlined),
        matching: find.byType(OutlinedButton),
      );
      Future<void> saveAndWait() async {
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }

      Future<void> expectSavedCountsUnchanged() async {
        Stocktake? stored;
        await tester.runAsync(() async => stored = await repository.findById(draft.id));
        for (final position in stored!.positionen) {
          expect(position.mengeGezaehlt, expectedCounts[position.artikelId]);
        }
      }

      await tester.enterText(firstCount, '9');
      await tester.enterText(secondCount, '3x');
      await saveAndWait();
      expect(find.text('Bitte eine gültige gezählte Menge eingeben.'), findsOneWidget);
      await expectSavedCountsUnchanged();

      await tester.enterText(firstCount, '10');
      await tester.enterText(secondCount, '4.1234');
      await saveAndWait();
      await expectSavedCountsUnchanged();

      await tester.enterText(firstCount, '1e9999');
      await tester.enterText(secondCount, '4');
      await saveAndWait();
      expect(find.text('Bitte eine gültige gezählte Menge eingeben.'), findsOneWidget);
      await expectSavedCountsUnchanged();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('test_valuation_request_fails_without_side_effects', () async {
      await enableInventory();
      final id = await createArtikel(bezeichnung: 'Bilanz', bestand: 13);
      final draft = await useCases.startDraft(stichtag: '2026-01-31');
      await useCases.setCount(inventurId: draft.id, artikelId: id, menge: 13);
      final recorded = await useCases.record(draft.id);
      final journalsBefore = await journalCount();
      await expectLater(useCases.requestValuation(recorded.id), throwsA(isA<StocktakeValuationUnavailableException>()));
      expect(await journalCount(), journalsBefore);
      expect(await movementCount(), 0);
      expect(await bestandOf(id), 13);
      expect((await repository.findById(recorded.id))!.positionen.single.mengeGezaehlt, 13);
    });
  });
}
