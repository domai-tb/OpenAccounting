// ignore_for_file: prefer_single_quotes
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/l10n/l10n.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';
import 'package:openaccounting/features/mileage/mileage_entry_repository.dart';
import 'package:openaccounting/features/mileage/mileage_entry_usecases.dart';
import 'package:openaccounting/features/mileage/mileage_entry_workspace.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';

class _FailingListMileageEntryRepository extends MileageEntryRepository {
  _FailingListMileageEntryRepository(super.executor);

  bool failNextList = false;

  @override
  Future<List<MileageTrip>> listTrips() async {
    if (failNextList) {
      failNextList = false;
      throw StateError('trip list refresh failed');
    }
    return super.listTrips();
  }
}

class _FailOnceMileageEntryRepository extends MileageEntryRepository {
  _FailOnceMileageEntryRepository(super.executor);

  bool failNextApply = true;

  @override
  Future<void> applyCorrection(String correctionId) async {
    if (failNextApply) {
      failNextApply = false;
      throw StateError('simulated correction apply failure');
    }
    await super.applyCorrection(correctionId);
  }
}

class _GatedUndoPreparationRepository extends MileageEntryRepository {
  _GatedUndoPreparationRepository(super.executor);

  final Completer<void> preparationStarted = Completer<void>();
  final Completer<void> releasePreparation = Completer<void>();
  final Completer<void> preparationFinished = Completer<void>();
  bool correctionApplicationAttempted = false;

  @override
  Future<void> prepareUndoCorrection({
    required String sourceTripId,
    required String correctionId,
    required String reason,
  }) async {
    preparationStarted.complete();
    await releasePreparation.future;
    await super.prepareUndoCorrection(sourceTripId: sourceTripId, correctionId: correctionId, reason: reason);
    preparationFinished.complete();
  }

  @override
  Future<void> applyCorrection(String correctionId) async {
    correctionApplicationAttempted = true;
    await super.applyCorrection(correctionId);
  }
}

void main() {
  group('mileage-entry capture', () {
    late AppDatabase db;
    late MileageEntryRepository repo;
    late MileageEntryUseCases useCases;
    late AppServices appServices;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MileageEntryRepository(db.executor);
      await repo.ensureTablesForTests();
      useCases = MileageEntryUseCases(repo);
      appServices = AppServices(db);
    });
    tearDown(() async => db.close());

    Future<int> insertCategory({required String label, required String art, required int euerLine}) async {
      final int categoryId = await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, art, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status, '
        'catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[label, art, '700$euerLine', '400$euerLine', euerLine, 'catalog_verified', 'TEST-MILEAGE', '1'],
      );
      await db.executor.runInsert(
        'INSERT INTO category_mapping_history (kategorie_id, geaendert_am, aktion, vorher_mapping_json, '
        'nachher_mapping_json, katalog_quelle, katalog_version) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          categoryId,
          DateTime.now().toUtc().toIso8601String(),
          'catalog_import',
          null,
          '{"mapping_status":"catalog_verified","euer_zeile":$euerLine}',
          'TEST-MILEAGE',
          '1',
        ],
      );
      return categoryId;
    }

    Future<void> configureMileagePostingRoles() async {
      final int expenseKontoId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Mileage travel expense', 'Sachkonto'],
      );
      final int contributionKontoId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Mileage private contribution', 'Sachkonto'],
      );
      final int expenseCategoryId = await insertCategory(label: 'Mileage expense', art: 'ausgabe', euerLine: 71);
      final int contributionCategoryId = await insertCategory(
        label: 'Mileage private contribution',
        art: 'einnahme',
        euerLine: 107,
      );
      await PostingGroupService(db.executor).configureMileagePostingRoles(
        travelExpenseKontoId: expenseKontoId,
        travelExpenseKategorieId: expenseCategoryId,
        privateContributionKontoId: contributionKontoId,
        privateContributionKategorieId: contributionCategoryId,
      );
    }

    test('test_record_a_business_trip', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch München',
        distanceHundredthsKm: 4525,
        businessContext: 'Projekt Alpha, Fahrzeug privat',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );

      expect(trip.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(trip.tripDate, '2026-03-14');
      expect(trip.purpose, 'Kundenbesuch München');
      expect(trip.distanceHundredthsKm, 4525);
      expect(trip.tripKind, MileageTripKind.businessTrip);
      expect(trip.vehicleSource, MileageVehicleSource.private);
      expect(trip.vehicleClass, MileageVehicleClass.kraftwagen);
      expect(trip.state, MileageTripState.unresolved);
      expect(trip.policyId, isNull);
      expect(trip.calculatedAmount, isNull);
      expect(trip.postingEventId, isNull);

      final List<MileageTrip> rows = await repo.listTrips();
      expect(rows.length, 1);
      expect(rows.single.id, trip.id);
      expect(rows.single.distanceHundredthsKm, 4525);
      expect(rows.single.tripKind, MileageTripKind.businessTrip);
      expect(rows.single.vehicleSource, MileageVehicleSource.private);
      expect(rows.single.vehicleClass, MileageVehicleClass.kraftwagen);
    });

    test('test_reject_invalid_trip_facts', () async {
      await expectLater(
        () => useCases.recordBusinessTrip(
          tripDate: '2026-13-40',
          purpose: '',
          distanceHundredthsKm: 0,
          businessContext: '',
          tripKind: MileageTripKind.businessTrip,
          vehicleSource: MileageVehicleSource.private,
          vehicleClass: MileageVehicleClass.kraftwagen,
        ),
        throwsArgumentError,
      );
      expect(await repo.listTrips(), isEmpty);
    });

    test('test_preserve_posted_source_facts', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(trip.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(trip.id);
      await expectLater(() => useCases.editTripFacts(trip.id, purpose: 'Neu'), throwsStateError);
      final List<MileageTrip> rows = await repo.listTrips();
      expect(rows.first.purpose, 'Kundenbesuch');
    });

    test('test_prepare_replacement_correction_without_accounting_changes', () async {
      final MileageTrip source = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(source.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(source.id);

      final MileageTrip postedBefore = (await repo.getById(source.id))!;
      final int journalCountBefore =
          ((await db.executor.runSelect('SELECT COUNT(*) AS count FROM journal WHERE source_kind = ?', const <Object?>[
                    'mileage_trip',
                  ])).single['count']!
                  as num)
              .toInt();
      final ({String correctionId, MileageTrip replacementTrip}) prepared = await useCases.prepareReplacementCorrection(
        sourceTripId: source.id,
        reason: 'Korrektur der Strecke',
        tripDate: '2026-03-15',
        purpose: 'Korrigierter Kundenbesuch',
        distanceHundredthsKm: 1200,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );

      expect(prepared.replacementTrip.id, isNot(source.id));
      expect(prepared.replacementTrip.tripDate, '2026-03-15');
      expect(prepared.replacementTrip.purpose, 'Korrigierter Kundenbesuch');
      expect(prepared.replacementTrip.distanceHundredthsKm, 1200);
      expect(prepared.replacementTrip.state, MileageTripState.unresolved);
      expect(prepared.replacementTrip.policyId, isNull);
      expect(prepared.replacementTrip.calculatedAmount, isNull);
      expect(prepared.replacementTrip.postingEventId, isNull);

      final MileageTrip postedAfter = (await repo.getById(source.id))!;
      expect(postedAfter.tripDate, postedBefore.tripDate);
      expect(postedAfter.purpose, postedBefore.purpose);
      expect(postedAfter.distanceHundredthsKm, postedBefore.distanceHundredthsKm);
      expect(postedAfter.state, MileageTripState.posted);
      expect(postedAfter.postingEventId, postedBefore.postingEventId);

      final List<Map<String, Object?>> corrections = await db.executor.runSelect(
        'SELECT id, kind, replacement_trip_id, reason, state, accounting_correction_id, applied_at '
        'FROM mileage_trip_corrections WHERE trip_id = ?',
        <Object?>[source.id],
      );
      expect(corrections, hasLength(1));
      expect(corrections.single['id'], prepared.correctionId);
      expect(corrections.single['kind'], 'replace');
      expect(corrections.single['replacement_trip_id'], prepared.replacementTrip.id);
      expect(corrections.single['reason'], 'Korrektur der Strecke');
      expect(corrections.single['state'], 'draft');
      expect(corrections.single['accounting_correction_id'], isNull);
      expect(corrections.single['applied_at'], isNull);

      final int journalCountAfter =
          ((await db.executor.runSelect('SELECT COUNT(*) AS count FROM journal WHERE source_kind = ?', const <Object?>[
                    'mileage_trip',
                  ])).single['count']!
                  as num)
              .toInt();
      expect(journalCountAfter, journalCountBefore);
      final List<Map<String, Object?>> replacementLegs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
        <Object?>['mileage_trip', prepared.replacementTrip.id],
      );
      expect(replacementLegs, isEmpty);

      final MileageTrip unresolved = await useCases.recordBusinessTrip(
        tripDate: '2026-03-16',
        purpose: 'Nicht gebuchte Fahrt',
        distanceHundredthsKm: 500,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await expectLater(
        () => useCases.prepareReplacementCorrection(
          sourceTripId: unresolved.id,
          reason: 'Nicht zulässig',
          tripDate: '2026-03-17',
          purpose: 'Ersatzfahrt',
          distanceHundredthsKm: 600,
          businessContext: 'Projekt',
          tripKind: MileageTripKind.businessTrip,
          vehicleSource: MileageVehicleSource.private,
          vehicleClass: MileageVehicleClass.kraftwagen,
        ),
        throwsStateError,
      );
    });

    test('test_correction_apply_rejects_unprepared_replacement_without_mutation', () async {
      final MileageTrip source = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(source.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(source.id);
      final ({String correctionId, MileageTrip replacementTrip}) prepared = await useCases.prepareReplacementCorrection(
        sourceTripId: source.id,
        reason: 'Korrektur der Strecke',
        tripDate: '2026-03-15',
        purpose: 'Korrigierter Kundenbesuch',
        distanceHundredthsKm: 1200,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      final List<Map<String, Object?>> tripsBefore = await db.executor.runSelect(
        'SELECT * FROM mileage_trips ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> correctionsBefore = await db.executor.runSelect(
        'SELECT * FROM mileage_trip_corrections ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> journalBefore = await db.executor.runSelect(
        'SELECT * FROM journal ORDER BY id',
        const <Object?>[],
      );

      await expectLater(() => useCases.applyCorrection(prepared.correctionId), throwsA(isA<Exception>()));

      expect(await db.executor.runSelect('SELECT * FROM mileage_trips ORDER BY id', const <Object?>[]), tripsBefore);
      expect(
        await db.executor.runSelect('SELECT * FROM mileage_trip_corrections ORDER BY id', const <Object?>[]),
        correctionsBefore,
      );
      expect(await db.executor.runSelect('SELECT * FROM journal ORDER BY id', const <Object?>[]), journalBefore);
      expect((await repo.getById(source.id))!.state, MileageTripState.posted);
      expect((await repo.getById(prepared.replacementTrip.id))!.state, MileageTripState.unresolved);
    });

    test(
      'test_apply_accepted_replacement_correction_atomically_persists_business_date_without_legacy_backfill',
      () async {
        final MileageTrip source = await useCases.recordBusinessTrip(
          tripDate: '2026-03-14',
          purpose: 'Kundenbesuch',
          distanceHundredthsKm: 1000,
          businessContext: 'Projekt',
          tripKind: MileageTripKind.businessTrip,
          vehicleSource: MileageVehicleSource.private,
          vehicleClass: MileageVehicleClass.kraftwagen,
        );
        await useCases.calculateTrip(source.id);
        await configureMileagePostingRoles();
        await useCases.postTrip(source.id);
        final ({String correctionId, MileageTrip replacementTrip}) prepared = await useCases
            .prepareReplacementCorrection(
              sourceTripId: source.id,
              reason: 'Korrektur der Strecke',
              tripDate: '2026-03-15',
              purpose: 'Korrigierter Kundenbesuch',
              distanceHundredthsKm: 1200,
              businessContext: 'Projekt',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            );
        await useCases.calculateTrip(prepared.replacementTrip.id);

        final DateTime appliedAt = DateTime.utc(2026, 12, 31, 23, 30);
        final String expectedBusinessDate = appliedAt.toLocal().toIso8601String().substring(0, 10);
        repo = MileageEntryRepository(db.executor, now: () => appliedAt);
        useCases = MileageEntryUseCases(repo);
        await useCases.applyCorrection(prepared.correctionId);

        final List<Map<String, Object?>> correctionRows = await db.executor.runSelect(
          'SELECT state, applied_at, applied_business_date FROM mileage_trip_corrections WHERE id = ?',
          <Object?>[prepared.correctionId],
        );
        expect(correctionRows.single['state'], 'applied');
        expect(correctionRows.single['applied_at'], appliedAt.toUtc().toIso8601String());
        expect(correctionRows.single['applied_business_date'], expectedBusinessDate);
        final List<Map<String, Object?>> journalRows = await db.executor.runSelect(
          'SELECT datum FROM journal WHERE source_kind = ? AND source_id = ?',
          <Object?>['mileage_correction', prepared.correctionId],
        );
        expect(journalRows, isNotEmpty);
        expect(journalRows.map((Map<String, Object?> row) => row['datum']), everyElement(expectedBusinessDate));
        await useCases.applyCorrection(prepared.correctionId);
        expect(
          (await db.executor.runSelect(
            'SELECT applied_business_date FROM mileage_trip_corrections WHERE id = ?',
            <Object?>[prepared.correctionId],
          )).single['applied_business_date'],
          expectedBusinessDate,
        );
      },
    );

    test('test_apply_accepted_replacement_correction_atomically', () async {
      final MileageTrip source = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(source.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(source.id);
      final List<Map<String, Object?>> sourceBeforeRows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        <Object?>[source.id],
      );
      final List<Map<String, Object?>> originalLegsBefore = await db.executor.runSelect(
        'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', source.id],
      );
      final ({String correctionId, MileageTrip replacementTrip}) prepared = await useCases.prepareReplacementCorrection(
        sourceTripId: source.id,
        reason: 'Korrektur der Strecke',
        tripDate: '2026-03-15',
        purpose: 'Korrigierter Kundenbesuch',
        distanceHundredthsKm: 1200,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(prepared.replacementTrip.id);

      await useCases.applyCorrection(prepared.correctionId);

      final List<Map<String, Object?>> sourceAfterRows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        <Object?>[source.id],
      );
      expect(sourceAfterRows.single['trip_date'], sourceBeforeRows.single['trip_date']);
      expect(sourceAfterRows.single['purpose'], sourceBeforeRows.single['purpose']);
      expect(sourceAfterRows.single['business_context'], sourceBeforeRows.single['business_context']);
      expect(sourceAfterRows.single['distance_hundredths_km'], sourceBeforeRows.single['distance_hundredths_km']);
      expect(sourceAfterRows.single['calculated_amount'], sourceBeforeRows.single['calculated_amount']);
      expect(sourceAfterRows.single['posting_event_id'], sourceBeforeRows.single['posting_event_id']);
      expect(sourceAfterRows.single['state'], 'corrected');

      final List<Map<String, Object?>> corrections = await db.executor.runSelect(
        'SELECT state, accounting_correction_id, replacement_trip_id FROM mileage_trip_corrections WHERE id = ?',
        <Object?>[prepared.correctionId],
      );
      final String eventId = corrections.single['accounting_correction_id']! as String;
      final MileageTrip replacementAfter = (await repo.getById(prepared.replacementTrip.id))!;
      expect(replacementAfter.state, MileageTripState.posted);
      expect(replacementAfter.postingEventId, eventId);
      expect(corrections.single, <String, Object?>{
        'state': 'applied',
        'accounting_correction_id': eventId,
        'replacement_trip_id': prepared.replacementTrip.id,
      });
      final List<Map<String, Object?>> originalLegsAfter = await db.executor.runSelect(
        'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', source.id],
      );
      expect(originalLegsAfter, originalLegsBefore);

      final List<Map<String, Object?>> correctionLegs = await db.executor.runSelect(
        'SELECT id, gruppe_id, source_kind, source_id, reversal_of_group_id, soll, haben, ust_satz_id, '
        'ust_satz, vorsteuer_betrag FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_correction', prepared.correctionId],
      );
      expect(correctionLegs, hasLength(4));
      expect(correctionLegs.map((Map<String, Object?> row) => row['source_kind']), everyElement('mileage_correction'));
      expect(correctionLegs.map((Map<String, Object?> row) => row['source_id']), everyElement(prepared.correctionId));
      expect(correctionLegs.map((Map<String, Object?> row) => row['gruppe_id']).toSet(), hasLength(1));
      expect(correctionLegs.where((Map<String, Object?> row) => row['reversal_of_group_id'] != null), hasLength(2));
      expect(
        correctionLegs,
        everyElement(
          predicate<Map<String, Object?>>(
            (Map<String, Object?> row) =>
                row['ust_satz_id'] == null && row['ust_satz'] == null && row['vorsteuer_betrag'] == null,
          ),
        ),
      );
      final int debitCents = correctionLegs.fold<int>(
        0,
        (int sum, Map<String, Object?> row) => sum + ((row['soll']! as num) * 100).round(),
      );
      final int creditCents = correctionLegs.fold<int>(
        0,
        (int sum, Map<String, Object?> row) => sum + ((row['haben']! as num) * 100).round(),
      );
      expect(debitCents, creditCents);

      final int journalCountBeforeRetry =
          ((await db.executor.runSelect('SELECT COUNT(*) AS count FROM journal', const <Object?>[])).single['count']!
                  as num)
              .toInt();
      await useCases.applyCorrection(prepared.correctionId);
      expect(
        (await db.executor.runSelect(
          'SELECT accounting_correction_id FROM mileage_trip_corrections WHERE id = ?',
          <Object?>[prepared.correctionId],
        )).single['accounting_correction_id'],
        eventId,
      );
      final int journalCountAfterRetry =
          ((await db.executor.runSelect('SELECT COUNT(*) AS count FROM journal', const <Object?>[])).single['count']!
                  as num)
              .toInt();
      expect(journalCountAfterRetry, journalCountBeforeRetry);
    });

    test('test_undo_posted_trip_through_correction', () async {
      final MileageTrip source = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(source.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(source.id);
      final List<Map<String, Object?>> sourceBeforeRows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        <Object?>[source.id],
      );
      final String correctionId = await useCases.prepareUndoCorrection(
        sourceTripId: source.id,
        reason: 'Trip entered twice',
      );
      final List<Map<String, Object?>> originalLegsBefore = await db.executor.runSelect(
        'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', source.id],
      );

      await useCases.applyCorrection(correctionId);

      final List<Map<String, Object?>> sourceAfterRows = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        <Object?>[source.id],
      );
      expect(sourceAfterRows.single['trip_date'], sourceBeforeRows.single['trip_date']);
      expect(sourceAfterRows.single['purpose'], sourceBeforeRows.single['purpose']);
      expect(sourceAfterRows.single['business_context'], sourceBeforeRows.single['business_context']);
      expect(sourceAfterRows.single['distance_hundredths_km'], sourceBeforeRows.single['distance_hundredths_km']);
      expect(sourceAfterRows.single['posting_event_id'], sourceBeforeRows.single['posting_event_id']);
      expect(sourceAfterRows.single['state'], 'voided');
      expect((await repo.getById(source.id))!.postingEventId, sourceBeforeRows.single['posting_event_id']);
      expect(
        await db.executor.runSelect(
          'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
          <Object?>['mileage_trip', source.id],
        ),
        originalLegsBefore,
      );
      final List<Map<String, Object?>> corrections = await db.executor.runSelect(
        'SELECT state, accounting_correction_id, replacement_trip_id FROM mileage_trip_corrections WHERE id = ?',
        <Object?>[correctionId],
      );
      final String eventId = corrections.single['accounting_correction_id']! as String;
      expect(corrections.single, <String, Object?>{
        'state': 'applied',
        'accounting_correction_id': eventId,
        'replacement_trip_id': null,
      });
      final List<Map<String, Object?>> correctionLegs = await db.executor.runSelect(
        'SELECT id, gruppe_id, source_id, reversal_of_group_id, soll, haben FROM journal '
        'WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_correction', correctionId],
      );
      expect(correctionLegs, hasLength(2));
      expect(correctionLegs.map((Map<String, Object?> row) => row['reversal_of_group_id'] != null), everyElement(true));
      expect(correctionLegs.map((Map<String, Object?> row) => row['gruppe_id']).toSet(), hasLength(1));
      await useCases.applyCorrection(correctionId);
      expect(
        (await db.executor.runSelect(
          'SELECT accounting_correction_id FROM mileage_trip_corrections WHERE id = ?',
          <Object?>[correctionId],
        )).single['accounting_correction_id'],
        eventId,
      );
      final List<Map<String, Object?>> correctionLegsAfterRetry = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
        <Object?>['mileage_correction', correctionId],
      );
      expect(correctionLegsAfterRetry, hasLength(2));
    });

    test('test_failed_or_repeated_correction_is_safe', () async {
      final MileageTrip source = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(source.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(source.id);
      final ({String correctionId, MileageTrip replacementTrip}) prepared = await useCases.prepareReplacementCorrection(
        sourceTripId: source.id,
        reason: 'Korrektur der Strecke',
        tripDate: '2026-03-15',
        purpose: 'Korrigierter Kundenbesuch',
        distanceHundredthsKm: 1200,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(prepared.replacementTrip.id);
      await db.executor.runCustom('''
CREATE TRIGGER test_abort_mileage_source_correction
BEFORE UPDATE ON mileage_trips
WHEN OLD.id = '${source.id}' AND NEW.state = 'corrected'
BEGIN
  SELECT RAISE(ABORT, 'forced correction rollback');
END''');
      final List<Map<String, Object?>> tripsBefore = await db.executor.runSelect(
        'SELECT * FROM mileage_trips ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> correctionsBefore = await db.executor.runSelect(
        'SELECT * FROM mileage_trip_corrections ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> journalBefore = await db.executor.runSelect(
        'SELECT * FROM journal ORDER BY id',
        const <Object?>[],
      );

      await expectLater(() => useCases.applyCorrection(prepared.correctionId), throwsA(isA<Exception>()));
      expect(await db.executor.runSelect('SELECT * FROM mileage_trips ORDER BY id', const <Object?>[]), tripsBefore);
      expect(
        await db.executor.runSelect('SELECT * FROM mileage_trip_corrections ORDER BY id', const <Object?>[]),
        correctionsBefore,
      );
      expect(await db.executor.runSelect('SELECT * FROM journal ORDER BY id', const <Object?>[]), journalBefore);

      await db.executor.runCustom('DROP TRIGGER test_abort_mileage_source_correction');
      await useCases.applyCorrection(prepared.correctionId);
      final String eventId =
          (await db.executor.runSelect(
                'SELECT accounting_correction_id FROM mileage_trip_corrections WHERE id = ?',
                <Object?>[prepared.correctionId],
              )).single['accounting_correction_id']!
              as String;
      await useCases.applyCorrection(prepared.correctionId);
      expect(
        (await db.executor.runSelect(
          'SELECT accounting_correction_id FROM mileage_trip_corrections WHERE id = ?',
          <Object?>[prepared.correctionId],
        )).single['accounting_correction_id'],
        eventId,
      );
      expect(
        await db.executor
            .runSelect('SELECT COUNT(*) AS count FROM journal WHERE source_kind = ? AND source_id = ?', <Object?>[
              'mileage_correction',
              prepared.correctionId,
            ])
            .then((List<Map<String, Object?>> rows) => (rows.single['count']! as num).toInt()),
        4,
      );
    });

    test('test_calculate_from_an_approved_policy', () async {
      expect(
        useCases.calculateApprovedAmountCents(distanceHundredthsKm: 4525, vehicleClass: MileageVehicleClass.kraftwagen),
        1358,
      );
      expect(
        useCases.calculateApprovedAmountCents(
          distanceHundredthsKm: 1000,
          vehicleClass: MileageVehicleClass.otherMotorVehicle,
        ),
        200,
      );
      expect(
        useCases.calculateApprovedAmountCents(distanceHundredthsKm: 4, vehicleClass: MileageVehicleClass.kraftwagen),
        1,
      );
      expect(
        useCases.calculateApprovedAmountCents(distanceHundredthsKm: 5, vehicleClass: MileageVehicleClass.kraftwagen),
        2,
      );
      expect(
        () => useCases.calculateApprovedAmountCents(
          distanceHundredthsKm: 1000,
          vehicleClass: MileageVehicleClass.unsupported,
        ),
        throwsArgumentError,
      );

      final List<({String date, MileageVehicleClass vehicleClass, num amount})> boundaryCases =
          <({String date, MileageVehicleClass vehicleClass, num amount})>[
            (date: '2025-01-01', vehicleClass: MileageVehicleClass.kraftwagen, amount: 3.0),
            (date: '2026-12-31', vehicleClass: MileageVehicleClass.otherMotorVehicle, amount: 2.0),
          ];
      for (final fact in boundaryCases) {
        final MileageTrip trip = await useCases.recordBusinessTrip(
          tripDate: fact.date,
          purpose: 'Kundenbesuch',
          distanceHundredthsKm: 1000,
          businessContext: 'Projekt',
          tripKind: MileageTripKind.businessTrip,
          vehicleSource: MileageVehicleSource.private,
          vehicleClass: fact.vehicleClass,
        );
        final MileageTrip calculated = await useCases.calculateTrip(trip.id);
        expect(calculated.state, MileageTripState.calculated);
        expect(num.parse(calculated.calculatedAmount!), fact.amount);
        expect(calculated.policyId, 'DE-private-business-travel/1');
        expect(calculated.policyVersion, '1');
        expect(calculated.policyEffectiveFrom, '2025-01-01');
        expect(calculated.policyEffectiveTo, '2026-12-31');
        expect(calculated.calculatedAt, isNotNull);
      }

      final List<
        ({String date, MileageTripKind tripKind, MileageVehicleSource vehicleSource, MileageVehicleClass vehicleClass})
      >
      excludedFacts =
          <
            ({
              String date,
              MileageTripKind tripKind,
              MileageVehicleSource vehicleSource,
              MileageVehicleClass vehicleClass,
            })
          >[
            (
              date: '2024-12-31',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2027-01-01',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.commuting,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.eksAllowance,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.other,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.unknown,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.company,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.unknown,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.unsupported,
            ),
            (
              date: '2026-03-14',
              tripKind: MileageTripKind.businessTrip,
              vehicleSource: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.unknown,
            ),
          ];
      for (final fact in excludedFacts) {
        final MileageTrip trip = await useCases.recordBusinessTrip(
          tripDate: fact.date,
          purpose: 'Fahrt',
          distanceHundredthsKm: 1000,
          businessContext: 'Projekt',
          tripKind: fact.tripKind,
          vehicleSource: fact.vehicleSource,
          vehicleClass: fact.vehicleClass,
        );
        final MileageTrip result = await useCases.calculateTrip(trip.id);
        expect(result.state, MileageTripState.unresolved);
        expect(result.policyId, isNull);
        expect(result.policySource, isNull);
        expect(result.policyVersion, isNull);
        expect(result.policyEffectiveFrom, isNull);
        expect(result.policyEffectiveTo, isNull);
        expect(result.calculatedAmount, isNull);
        expect(result.calculatedAt, isNull);
        expect(result.postingEventId, isNull);
      }
    });

    test('test_keep_an_unresolved_trip_out_of_accounting', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await expectLater(
        () => useCases.calculateApprovedAmountCents(
          distanceHundredthsKm: 1000,
          vehicleClass: MileageVehicleClass.unsupported,
        ),
        throwsArgumentError,
      );
      await expectLater(() => useCases.postTrip(trip.id), throwsStateError);
      final MileageTrip kept = (await repo.getById(trip.id))!;
      expect(kept.state, MileageTripState.unresolved);
      expect(kept.policyId, isNull);
      expect(kept.calculatedAmount, isNull);
      expect(kept.postingEventId, isNull);
    });

    test('test_do_not_treat_the_eks_allowance_as_the_general_deduction', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'EKS-Fahrt',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.eksAllowance,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      const int eksAllowance = (1000 * 10) ~/ 100;
      expect(eksAllowance, 100);
      await useCases.calculateTrip(trip.id);
      expect(
        useCases.calculateApprovedAmountCents(distanceHundredthsKm: 1000, vehicleClass: MileageVehicleClass.kraftwagen),
        isNot(eksAllowance),
      );
      final MileageTrip kept = (await repo.getById(trip.id))!;
      expect(kept.state, MileageTripState.unresolved);
      expect(kept.calculatedAmount, isNull);
    });

    test('test_keep_ineligible_trips_unresolved', () async {
      final List<
        ({String tripDate, MileageTripKind kind, MileageVehicleSource source, MileageVehicleClass vehicleClass})
      >
      ineligibleFacts =
          <({String tripDate, MileageTripKind kind, MileageVehicleSource source, MileageVehicleClass vehicleClass})>[
            (
              tripDate: '2026-03-14',
              kind: MileageTripKind.commuting,
              source: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              tripDate: '2026-03-14',
              kind: MileageTripKind.other,
              source: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              tripDate: '2026-03-14',
              kind: MileageTripKind.businessTrip,
              source: MileageVehicleSource.company,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
            (
              tripDate: '2026-03-14',
              kind: MileageTripKind.businessTrip,
              source: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.unsupported,
            ),
            (
              tripDate: '2026-03-14',
              kind: MileageTripKind.unknown,
              source: MileageVehicleSource.unknown,
              vehicleClass: MileageVehicleClass.unknown,
            ),
            (
              tripDate: '2027-01-01',
              kind: MileageTripKind.businessTrip,
              source: MileageVehicleSource.private,
              vehicleClass: MileageVehicleClass.kraftwagen,
            ),
          ];

      for (final fact in ineligibleFacts) {
        final MileageTrip trip = await useCases.recordBusinessTrip(
          tripDate: fact.tripDate,
          purpose: 'Fahrt ${fact.tripDate}',
          distanceHundredthsKm: 1000,
          businessContext: 'Projekt',
          tripKind: fact.kind,
          vehicleSource: fact.source,
          vehicleClass: fact.vehicleClass,
        );
        final MileageTrip result = await useCases.calculateTrip(trip.id);
        expect(result.state, MileageTripState.unresolved);
        expect(result.policyId, isNull);
        expect(result.calculatedAmount, isNull);
        expect(result.postingEventId, isNull);
      }
    });

    test('test_editing_calculated_trip_invalidates_calculation', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(trip.id);
      final MileageTrip edited = await useCases.editTripFacts(trip.id, purpose: 'Neuer Zweck');
      expect(edited.state, MileageTripState.unresolved);
      expect(edited.purpose, 'Neuer Zweck');
      expect(edited.policyId, isNull);
      expect(edited.calculatedAmount, isNull);
      expect(edited.postingEventId, isNull);
    });

    test('test_posting_rejects_ineligible_or_untrusted_calculation_snapshot', () async {
      MileageTrip calculatedTrip({required String id, required MileageTripKind tripKind, required String policyId}) {
        return MileageTrip(
          id: id,
          tripDate: '2026-03-14',
          purpose: 'Kundenbesuch',
          businessContext: 'Projekt',
          distanceHundredthsKm: 1000,
          tripKind: tripKind,
          vehicleSource: MileageVehicleSource.private,
          vehicleClass: MileageVehicleClass.kraftwagen,
          state: MileageTripState.calculated,
          createdAt: '2026-03-14T12:00:00Z',
          updatedAt: '2026-03-14T12:00:00Z',
          policyId: policyId,
          policySource: 'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71',
          policyVersion: '1',
          policyEffectiveFrom: '2025-01-01',
          policyEffectiveTo: '2026-12-31',
          calculatedAmount: '3.00',
          calculatedAt: '2026-03-14T12:00:00Z',
        );
      }

      final _RecordingPort postingPort = _RecordingPort();
      final _FixedMileageRepository ineligibleRepository = _FixedMileageRepository(
        repo,
        calculatedTrip(
          id: 'ineligible-trip',
          tripKind: MileageTripKind.commuting,
          policyId: 'DE-private-business-travel/1',
        ),
      );
      final MileageEntryUseCases ineligibleUseCases = MileageEntryUseCases(
        ineligibleRepository,
        postingPort: postingPort,
      );
      await expectLater(() => ineligibleUseCases.postTripWithPort('ineligible-trip'), throwsStateError);

      final _FixedMileageRepository untrustedRepository = _FixedMileageRepository(
        repo,
        calculatedTrip(
          id: 'untrusted-policy-trip',
          tripKind: MileageTripKind.businessTrip,
          policyId: 'unapproved-policy',
        ),
      );
      final MileageEntryUseCases untrustedUseCases = MileageEntryUseCases(
        untrustedRepository,
        postingPort: postingPort,
      );
      await expectLater(() => untrustedUseCases.postTripWithPort('untrusted-policy-trip'), throwsStateError);
      expect(postingPort.calls, 0);
    });

    test('test_post_a_confirmed_resolved_mileage_expense', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(trip.id);
      await configureMileagePostingRoles();
      await useCases.postTrip(trip.id);
      final MileageTrip kept = (await repo.getById(trip.id))!;
      expect(kept.postingEventId, isNotEmpty);
      expect(kept.state, MileageTripState.posted);
    });

    test('test_production_posting_commits_journal_and_trip_reference', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(trip.id);
      await configureMileagePostingRoles();

      await useCases.postTrip(trip.id);

      final MileageTrip posted = (await repo.getById(trip.id))!;
      expect(posted.state, MileageTripState.posted);
      expect(posted.postingEventId, isNotNull);
      final List<Map<String, Object?>> legs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', trip.id],
      );
      expect(legs, hasLength(2));
    });

    test('test_production_posting_retry_returns_existing_group', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(trip.id);
      await configureMileagePostingRoles();

      await useCases.postTrip(trip.id);
      final String firstEventId = (await repo.getById(trip.id))!.postingEventId!;
      await useCases.postTrip(trip.id);

      final MileageTrip replayed = (await repo.getById(trip.id))!;
      expect(replayed.postingEventId, firstEventId);
      final List<Map<String, Object?>> legs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', trip.id],
      );
      expect(legs, hasLength(2));
    });

    test('test_fake_posting_port_rejects_an_incomplete_trip', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(trip.id);
      final _RecordingPort port = _RecordingPort();
      final MileageEntryUseCases wired = MileageEntryUseCases(repo, postingPort: port);
      final String eventId = await wired.postTripWithPort(trip.id);
      expect(eventId, isNotEmpty);
      expect(port.calls, 1);

      final MileageTrip bare = await useCases.recordBusinessTrip(
        tripDate: '2026-03-15',
        purpose: 'Ohne Kalkulation',
        distanceHundredthsKm: 500,
        businessContext: 'Projekt',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await expectLater(() => wired.postTripWithPort(bare.id), throwsStateError);
      expect(port.calls, 1);
    });

    testWidgets('test_mileage_form_is_keyboard_operable_and_localized', (tester) async {
      Future<void> pumpWorkspace(Locale locale) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AppScope(
                services: AppServices(db),
                child: BankImportPage(routeUri: Uri.parse('/banking?view=mileage')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> selectFirstOptionWithKeyboard(String key, String label) async {
        final Finder field = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(label), findsWidgets);
      }

      await pumpWorkspace(const Locale('en'));
      expect(find.text('Business mileage'), findsOneWidget);
      expect(find.text('Trip date'), findsOneWidget);
      expect(find.text('Purpose'), findsOneWidget);
      expect(find.text('Distance (km)'), findsOneWidget);
      expect(find.text('Business context'), findsOneWidget);
      expect(find.text('Trip kind'), findsOneWidget);
      expect(find.text('Vehicle source'), findsOneWidget);
      expect(find.text('Vehicle class'), findsOneWidget);

      final Finder dateField = find.byKey(const ValueKey<String>('mileage-trip-date'));
      await tester.ensureVisible(dateField);
      await tester.tap(dateField);
      await tester.enterText(dateField, '2026-10-18');
      final FocusNode? dateFocus = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(equals(dateFocus)));

      await tester.enterText(find.byKey(const ValueKey<String>('mileage-purpose')), 'Client visit');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-distance')), '12.34');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-business-context')), 'Project Alpha');
      await selectFirstOptionWithKeyboard('mileage-trip-kind', 'Business trip');
      await selectFirstOptionWithKeyboard('mileage-vehicle-source', 'Private');
      await selectFirstOptionWithKeyboard('mileage-vehicle-class', 'Car (Kraftwagen)');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final MileageTrip recorded = (await repo.listTrips()).single;
      expect(recorded.purpose, 'Client visit');
      expect(recorded.distanceHundredthsKm, 1234);
      expect(recorded.tripKind, MileageTripKind.businessTrip);
      expect(recorded.vehicleSource, MileageVehicleSource.private);
      expect(recorded.vehicleClass, MileageVehicleClass.kraftwagen);
      expect(recorded.state, MileageTripState.unresolved);

      await tester.tap(find.byKey(ValueKey<String>('mileage-edit-${recorded.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-purpose')), 'Updated client visit');
      final Finder editSaveButton = find.byKey(const ValueKey<String>('mileage-save'));
      await tester.ensureVisible(editSaveButton);
      await tester.pumpAndSettle();
      await tester.tap(editSaveButton);
      await tester.pumpAndSettle();
      final MileageTrip edited = (await repo.getById(recorded.id))!;
      expect(edited.purpose, 'Updated client visit');
      expect(edited.distanceHundredthsKm, 1234);
      expect(edited.state, MileageTripState.unresolved);

      await pumpWorkspace(const Locale('de'));
      await tester.tap(find.byKey(const ValueKey<String>('mileage-new-trip')));
      await tester.pumpAndSettle();
      expect(find.text('Geschäftliche Fahrten'), findsOneWidget);
      expect(find.text('Fahrtdatum'), findsOneWidget);
      expect(find.text('Fahrtart'), findsOneWidget);
      expect(find.text('Fahrzeugquelle'), findsOneWidget);
      expect(find.text('Fahrzeugklasse'), findsOneWidget);
      final Finder invalidSaveButton = find.byKey(const ValueKey<String>('mileage-save'));
      await tester.ensureVisible(invalidSaveButton);
      await tester.pumpAndSettle();
      await tester.tap(invalidSaveButton);
      await tester.pumpAndSettle();
      expect(find.text('Datum im Format JJJJ-MM-TT eingeben.'), findsOneWidget);
    });

    testWidgets('test_posting_is_unavailable_without_each_prerequisite', (tester) async {
      final _DelegatingRecordingPort postingPort = _DelegatingRecordingPort(repo);
      final AppServices services = _MileageTestAppServices(db, MileageEntryUseCases(repo, postingPort: postingPort));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppScope(
              services: services,
              child: BankImportPage(routeUri: Uri.parse('/banking?view=mileage')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> selectOption(String key, String label) async {
        final Finder field = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      Future<void> saveTrip({required String date, required String purpose, required String kind}) async {
        await tester.enterText(find.byKey(const ValueKey<String>('mileage-trip-date')), date);
        await tester.enterText(find.byKey(const ValueKey<String>('mileage-purpose')), purpose);
        await tester.enterText(find.byKey(const ValueKey<String>('mileage-distance')), '10.00');
        await tester.enterText(find.byKey(const ValueKey<String>('mileage-business-context')), 'Project Alpha');
        await selectOption('mileage-trip-kind', kind);
        await selectOption('mileage-vehicle-source', 'Private');
        await selectOption('mileage-vehicle-class', 'Car (Kraftwagen)');
        final Finder saveButton = find.byKey(const ValueKey<String>('mileage-save'));
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();
      }

      await saveTrip(date: '2026-10-18', purpose: 'Commute', kind: 'Commuting');
      MileageTrip trip = (await repo.listTrips()).single;
      expect(trip.state, MileageTripState.unresolved);
      await tester.tap(find.byKey(ValueKey<String>('mileage-calculate-${trip.id}')));
      await tester.pumpAndSettle();
      trip = (await repo.getById(trip.id))!;
      expect(trip.state, MileageTripState.unresolved);
      expect(trip.policyId, isNull);
      expect(
        find.text('This trip is not eligible under the current mileage policy and remains unresolved.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(find.byKey(ValueKey<String>('mileage-post-${trip.id}'))).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey<String>('mileage-new-trip')));
      await tester.pumpAndSettle();
      await saveTrip(date: '2026-10-17', purpose: 'Customer visit', kind: 'Business trip');
      trip = (await repo.listTrips()).firstWhere((MileageTrip value) => value.purpose == 'Customer visit');
      final Finder calculateTripButton = find.byKey(ValueKey<String>('mileage-calculate-${trip.id}'));
      await tester.scrollUntilVisible(
        calculateTripButton,
        120,
        scrollable: find.descendant(of: find.byType(MileageEntryWorkspace), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(calculateTripButton);
      await tester.pumpAndSettle();
      trip = (await repo.getById(trip.id))!;
      expect(trip.state, MileageTripState.calculated);
      expect(trip.calculatedAmount, isNotNull);
      final Finder postButton = find.byKey(ValueKey<String>('mileage-post-${trip.id}'));
      expect(postButton, findsOneWidget);
      expect(tester.widget<FilledButton>(postButton).onPressed, isNotNull);
      await tester.ensureVisible(postButton);
      await tester.pumpAndSettle();
      await tester.tap(postButton);
      await tester.pumpAndSettle();
      expect(postingPort.tripIds, <String>[trip.id]);
      expect(postingPort.completedTripIds, <String>[trip.id]);
      expect(
        find.text('Posting is unavailable. Check account roles and ensure the trip date is open.'),
        findsOneWidget,
      );
      trip = (await repo.getById(trip.id))!;
      expect(trip.state, MileageTripState.calculated);
      expect(trip.postingEventId, isNull);

      await configureMileagePostingRoles();
      await db.executor.runInsert(
        'INSERT INTO mileage_posting_period_closures (closed_from, closed_through, closed_at) VALUES (?, ?, ?)',
        <Object?>['2026-10-17', '2026-10-17', '2026-10-18T00:00:00.000Z'],
      );
      final Finder closedPeriodPostButton = find.byKey(ValueKey<String>('mileage-post-${trip.id}'));
      await tester.ensureVisible(closedPeriodPostButton);
      await tester.pumpAndSettle();
      await tester.tap(closedPeriodPostButton);
      await tester.pumpAndSettle();
      expect(postingPort.tripIds, <String>[trip.id, trip.id]);
      expect(postingPort.completedTripIds, <String>[trip.id, trip.id]);
      expect(
        find.text('Posting is unavailable. Check account roles and ensure the trip date is open.'),
        findsOneWidget,
      );
      trip = (await repo.getById(trip.id))!;
      expect(trip.state, MileageTripState.calculated);
      expect(trip.postingEventId, isNull);
      final List<Map<String, Object?>> journalRows = await db.executor.runSelect(
        "SELECT id FROM journal WHERE source_kind = 'mileage_trip' AND source_id = ?",
        <Object?>[trip.id],
      );
      expect(journalRows, isEmpty);
    });

    test('rejects whole-kilometer overflow before converting to hundredths', () {
      expect(parseMileageDistanceHundredthsKm('9999999999.99'), 999999999999);
      expect(parseMileageDistanceHundredthsKm('10000000000'), isNull);
      expect(parseMileageDistanceHundredthsKm('184467440737095517'), isNull);
    });

    testWidgets('test_new_trip_requires_explicit_eligibility_selections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MileageEntryWorkspace(
              useCases: useCases,
              bankAccounts: appServices.bankAccounts,
              categoryWorkspace: appServices.categoryWorkspace,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<MileageTripKind>>(find.byKey(const ValueKey<String>('mileage-trip-kind')))
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<MileageVehicleSource>>(
              find.byKey(const ValueKey<String>('mileage-vehicle-source')),
            )
            .initialValue,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<MileageVehicleClass>>(
              find.byKey(const ValueKey<String>('mileage-vehicle-class')),
            )
            .initialValue,
        isNull,
      );

      await tester.enterText(find.byKey(const ValueKey<String>('mileage-trip-date')), '2026-10-18');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-purpose')), 'Client visit');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-distance')), '10.00');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-business-context')), 'Project Alpha');
      final Finder saveButton = find.byKey(const ValueKey<String>('mileage-save'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(await repo.listTrips(), isEmpty);
      expect(find.byKey(const ValueKey<String>('mileage-save')), findsOneWidget);
    });

    testWidgets('test_mileage_trip_list_is_searchable_and_filterable', (tester) async {
      final MileageTrip calculated = await useCases.recordBusinessTrip(
        tripDate: '2026-10-18',
        purpose: 'Client visit',
        distanceHundredthsKm: 1000,
        businessContext: 'Project Alpha',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      final MileageTrip unresolved = await useCases.recordBusinessTrip(
        tripDate: '2026-10-17',
        purpose: 'Office travel',
        distanceHundredthsKm: 2000,
        businessContext: 'Project Beta',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(calculated.id);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MileageEntryWorkspace(
              useCases: useCases,
              bankAccounts: appServices.bankAccounts,
              categoryWorkspace: appServices.categoryWorkspace,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder search = find.byKey(const ValueKey<String>('mileage-search'));
      final Finder workspaceScrollable = find
          .descendant(of: find.byType(MileageEntryWorkspace), matching: find.byType(Scrollable))
          .first;
      Future<void> reveal(Finder target, {double delta = 400}) async {
        await tester.scrollUntilVisible(target, delta, scrollable: workspaceScrollable);
        await tester.pumpAndSettle();
      }

      await reveal(search);
      await tester.enterText(search, 'client');
      await tester.pumpAndSettle();
      final Finder calculatedEdit = find.byKey(ValueKey<String>('mileage-edit-${calculated.id}'));
      final Finder unresolvedEdit = find.byKey(ValueKey<String>('mileage-edit-${unresolved.id}'));
      await reveal(calculatedEdit);
      expect(calculatedEdit, findsOneWidget);
      expect(unresolvedEdit, findsNothing);

      await reveal(search, delta: -400);
      await tester.enterText(search, 'no matching trip');
      await tester.pumpAndSettle();
      final Finder noMatches = find.text('No matches for this search');
      await reveal(noMatches);
      expect(noMatches, findsOneWidget);

      await reveal(search, delta: -400);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      final Finder stateFilter = find.byKey(const ValueKey<String>('mileage-state-filter'));
      await reveal(stateFilter);
      await tester.tap(stateFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calculated').last);
      await tester.pumpAndSettle();
      await reveal(calculatedEdit);
      expect(calculatedEdit, findsOneWidget);
      expect(unresolvedEdit, findsNothing);

      final Finder resetFilter = find.byKey(const ValueKey<String>('mileage-filter-reset'));
      await reveal(resetFilter, delta: -400);
      await tester.tap(resetFilter);
      await tester.pumpAndSettle();
      await reveal(calculatedEdit);
      expect(calculatedEdit, findsOneWidget);
      await reveal(unresolvedEdit);
      expect(unresolvedEdit, findsOneWidget);
    });

    testWidgets('committed mileage actions remain successful when list refresh fails', (tester) async {
      final _FailingListMileageEntryRepository failingRepo = _FailingListMileageEntryRepository(db.executor);
      await failingRepo.ensureTablesForTests();
      repo = failingRepo;
      useCases = MileageEntryUseCases(failingRepo);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MileageEntryWorkspace(
              useCases: useCases,
              bankAccounts: appServices.bankAccounts,
              categoryWorkspace: appServices.categoryWorkspace,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> selectOption(String key, String label) async {
        final Finder field = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await tester.enterText(find.byKey(const ValueKey<String>('mileage-trip-date')), '2026-10-18');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-purpose')), 'Client visit');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-distance')), '10.00');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-business-context')), 'Project Alpha');
      await selectOption('mileage-trip-kind', 'Business trip');
      await selectOption('mileage-vehicle-source', 'Private');
      await selectOption('mileage-vehicle-class', 'Car (Kraftwagen)');

      failingRepo.failNextList = true;
      final Finder saveButton = find.byKey(const ValueKey<String>('mileage-save'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('Trip saved.'), findsOneWidget);
      expect(find.text('The trip could not be saved. Check its details and try again.'), findsNothing);
      expect(find.text('Client visit'), findsOneWidget);

      MileageTrip trip = (await failingRepo.listTrips()).single;
      expect(trip.state, MileageTripState.unresolved);

      failingRepo.failNextList = true;
      final Finder calculateButton = find.byKey(ValueKey<String>('mileage-calculate-${trip.id}'));
      await tester.ensureVisible(calculateButton);
      await tester.pumpAndSettle();
      await tester.tap(calculateButton);
      await tester.pumpAndSettle();
      expect(find.text('The eligible amount was calculated.'), findsOneWidget);
      expect(find.text('The trip could not be calculated. It remains unchanged.'), findsNothing);
      trip = (await failingRepo.getById(trip.id))!;
      expect(trip.state, MileageTripState.calculated);

      await configureMileagePostingRoles();
      failingRepo.failNextList = true;
      final Finder postButton = find.byKey(ValueKey<String>('mileage-post-${trip.id}'));
      await tester.ensureVisible(postButton);
      await tester.pumpAndSettle();
      await tester.tap(postButton);
      await tester.pumpAndSettle();
      expect(find.text('The mileage expense was posted.'), findsOneWidget);
      expect(find.text('Posting is unavailable. Check account roles and ensure the trip date is open.'), findsNothing);
      trip = (await failingRepo.getById(trip.id))!;
      expect(trip.state, MileageTripState.posted);
      expect(find.text('Posted'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(ValueKey<String>('mileage-edit-${trip.id}'))).onPressed, isNull);
      expect(tester.widget<FilledButton>(find.byKey(ValueKey<String>('mileage-post-${trip.id}'))).onPressed, isNull);
      await useCases.postTrip(trip.id);
      final List<Map<String, Object?>> firstPostingRows = await db.executor.runSelect(
        "SELECT id FROM journal WHERE source_kind = 'mileage_trip' AND source_id = ?",
        <Object?>[trip.id],
      );
      expect(firstPostingRows, hasLength(2));

      final List<Map<String, Object?>> retryPostingRows = await db.executor.runSelect(
        "SELECT id FROM journal WHERE source_kind = 'mileage_trip' AND source_id = ?",
        <Object?>[trip.id],
      );
      expect(retryPostingRows, hasLength(2));
    });

    testWidgets('posted mileage corrections are accessible in both locales and preserve source facts', (tester) async {
      await configureMileagePostingRoles();

      Future<MileageTrip> createPostedTrip({required String tripDate, required String purpose}) async {
        final MileageTrip trip = await useCases.recordBusinessTrip(
          tripDate: tripDate,
          purpose: purpose,
          distanceHundredthsKm: 1000,
          businessContext: 'Original project',
          tripKind: MileageTripKind.businessTrip,
          vehicleSource: MileageVehicleSource.private,
          vehicleClass: MileageVehicleClass.kraftwagen,
        );
        await useCases.calculateTrip(trip.id);
        await useCases.postTrip(trip.id);
        return trip;
      }

      final MileageTrip correctSource = await createPostedTrip(
        tripDate: '2026-03-14',
        purpose: 'Original customer visit',
      );
      final MileageTrip undoSource = await createPostedTrip(
        tripDate: '2026-03-15',
        purpose: 'Duplicate customer visit',
      );
      final List<Map<String, Object?>> sourceBefore = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        <Object?>[correctSource.id],
      );
      final List<Map<String, Object?>> originalJournal = await db.executor.runSelect(
        'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', correctSource.id],
      );
      final _FailOnceMileageEntryRepository correctionRepo = _FailOnceMileageEntryRepository(db.executor);
      final MileageEntryUseCases correctionUseCases = MileageEntryUseCases(correctionRepo);

      Future<void> pumpWorkspace(Locale locale, {MileageEntryUseCases? workspaceUseCases}) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MileageEntryWorkspace(
                useCases: workspaceUseCases ?? useCases,
                bankAccounts: appServices.bankAccounts,
                categoryWorkspace: appServices.categoryWorkspace,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWorkspace(const Locale('en'), workspaceUseCases: correctionUseCases);
      expect(find.byType(MileageEntryWorkspace), findsOneWidget);
      final Finder workspaceScrollable = find
          .descendant(of: find.byType(MileageEntryWorkspace), matching: find.byType(Scrollable))
          .first;
      Future<void> reveal(Finder target) async {
        await tester.scrollUntilVisible(target, 400, scrollable: workspaceScrollable);
        await tester.pumpAndSettle();
      }

      final Finder correctButton = find.byKey(ValueKey<String>('mileage-correct-${correctSource.id}'));
      final Finder undoButton = find.byKey(ValueKey<String>('mileage-undo-${undoSource.id}'));
      await reveal(correctButton);
      await reveal(undoButton);
      expect(correctButton, findsOneWidget);
      expect(undoButton, findsOneWidget);
      expect(find.descendant(of: correctButton, matching: find.text('Correct trip')), findsOneWidget);
      expect(find.descendant(of: undoButton, matching: find.text('Undo trip')), findsOneWidget);

      await tester.ensureVisible(correctButton);
      await tester.tap(correctButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-purpose')), 'Corrected customer visit');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-distance')), '12.50');
      await tester.enterText(find.byKey(const ValueKey<String>('mileage-business-context')), 'Corrected project');
      await tester.enterText(
        find.byKey(const ValueKey<String>('mileage-correction-reason')),
        'The original distance was entered incorrectly',
      );
      final Finder saveButton = find.byKey(const ValueKey<String>('mileage-save'));
      await reveal(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      final Map<String, Object?> pendingCorrection = (await db.executor.runSelect(
        "SELECT id, replacement_trip_id FROM mileage_trip_corrections WHERE trip_id = ? AND kind = 'replace'",
        <Object?>[correctSource.id],
      )).single;
      final String replacementTripId = '${pendingCorrection['replacement_trip_id']}';
      final Finder applyButton = find.byKey(ValueKey<String>('mileage-apply-correction-$replacementTripId'));
      final Finder postButton = find.byKey(ValueKey<String>('mileage-post-$replacementTripId'));
      await reveal(applyButton);
      expect(find.text('Corrected customer visit'), findsOneWidget);
      expect(postButton, findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpWorkspace(const Locale('en'), workspaceUseCases: correctionUseCases);
      await reveal(applyButton);
      expect(applyButton, findsOneWidget);
      expect(postButton, findsNothing);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('original trip and posting remain unchanged'), findsOneWidget);
      await tester.tap(find.text('Apply correction').last);
      await tester.pumpAndSettle();
      expect(find.text('Correction unavailable. Check account roles and trip date, then retry.'), findsOneWidget);
      expect(
        (await db.executor.runSelect('SELECT state FROM mileage_trip_corrections WHERE id = ?', <Object?>[
          pendingCorrection['id'],
        ])).single['state'],
        'draft',
      );
      expect(
        await db.executor.runSelect('SELECT id FROM journal WHERE source_kind = ? AND source_id = ?', <Object?>[
          'mileage_correction',
          pendingCorrection['id'],
        ]),
        isEmpty,
      );

      await reveal(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply correction').last);
      await tester.pumpAndSettle();

      final List<Map<String, Object?>> sourceAfter = await db.executor.runSelect(
        'SELECT * FROM mileage_trips WHERE id = ?',
        <Object?>[correctSource.id],
      );
      expect(sourceAfter.single['trip_date'], sourceBefore.single['trip_date']);
      expect(sourceAfter.single['purpose'], sourceBefore.single['purpose']);
      expect(sourceAfter.single['business_context'], sourceBefore.single['business_context']);
      expect(sourceAfter.single['distance_hundredths_km'], sourceBefore.single['distance_hundredths_km']);
      expect(sourceAfter.single['trip_kind'], sourceBefore.single['trip_kind']);
      expect(sourceAfter.single['vehicle_source'], sourceBefore.single['vehicle_source']);
      expect(sourceAfter.single['vehicle_class'], sourceBefore.single['vehicle_class']);
      expect(sourceAfter.single['calculated_amount'], sourceBefore.single['calculated_amount']);
      expect(sourceAfter.single['posting_event_id'], sourceBefore.single['posting_event_id']);
      expect(sourceAfter.single['state'], 'corrected');
      expect(
        await db.executor.runSelect(
          'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
          <Object?>['mileage_trip', correctSource.id],
        ),
        originalJournal,
      );
      final Map<String, Object?> correction = (await db.executor.runSelect(
        'SELECT id, state, replacement_trip_id FROM mileage_trip_corrections WHERE trip_id = ? AND kind = ?',
        <Object?>[correctSource.id, 'replace'],
      )).single;
      expect(correction['state'], 'applied');
      expect(
        (await db.executor.runSelect(
          'SELECT state, purpose, distance_hundredths_km, trip_kind, vehicle_source, vehicle_class '
          'FROM mileage_trips WHERE id = ?',
          <Object?>[correction['replacement_trip_id']],
        )).single,
        <String, Object?>{
          'state': 'posted',
          'purpose': 'Corrected customer visit',
          'distance_hundredths_km': 1250,
          'trip_kind': 'business_trip',
          'vehicle_source': 'private',
          'vehicle_class': 'kraftwagen',
        },
      );
      expect(
        await db.executor.runSelect('SELECT id FROM journal WHERE source_kind = ? AND source_id = ?', <Object?>[
          'mileage_correction',
          correction['id'],
        ]),
        hasLength(4),
      );

      await pumpWorkspace(const Locale('de'), workspaceUseCases: correctionUseCases);
      final Finder localizedCorrection = find.byKey(
        ValueKey<String>('mileage-correct-${correction['replacement_trip_id']}'),
      );
      final Finder localizedUndo = find.byKey(ValueKey<String>('mileage-undo-${undoSource.id}'));
      await reveal(localizedCorrection);
      await reveal(localizedUndo);
      expect(find.descendant(of: localizedCorrection, matching: find.text('Fahrt korrigieren')), findsOneWidget);
      expect(find.descendant(of: localizedUndo, matching: find.text('Fahrt rückgängig machen')), findsOneWidget);
      await tester.tap(localizedUndo);
      await tester.pumpAndSettle();
      expect(find.text('Korrekturgrund'), findsOneWidget);
      expect(find.text('Fahrt wirklich rückgängig machen?'), findsOneWidget);
      await tester.enterText(
        find.byKey(ValueKey<String>('mileage-undo-reason-${undoSource.id}')),
        'Fahrt doppelt erfasst',
      );
      await tester.tap(find.text('Fahrt rückgängig machen').last);
      await tester.pumpAndSettle();

      final Map<String, Object?> undone = (await db.executor.runSelect(
        'SELECT trip_date, purpose, business_context, distance_hundredths_km, trip_kind, vehicle_source, vehicle_class, '
        'posting_event_id, state '
        'FROM mileage_trips WHERE id = ?',
        <Object?>[undoSource.id],
      )).single;
      expect(undone['trip_date'], undoSource.tripDate);
      expect(undone['purpose'], undoSource.purpose);
      expect(undone['business_context'], undoSource.businessContext);
      expect(undone['distance_hundredths_km'], undoSource.distanceHundredthsKm);
      expect(undone['trip_kind'], mileageTripKindStorageValue(undoSource.tripKind));
      expect(undone['vehicle_source'], mileageVehicleSourceStorageValue(undoSource.vehicleSource));
      expect(undone['vehicle_class'], mileageVehicleClassStorageValue(undoSource.vehicleClass));
      expect(undone['posting_event_id'], isNotEmpty);
      expect(undone['state'], 'voided');
      final Map<String, Object?> undoCorrection = (await db.executor.runSelect(
        'SELECT id, state, reason FROM mileage_trip_corrections WHERE trip_id = ? AND kind = ?',
        <Object?>[undoSource.id, 'void'],
      )).single;
      expect(undoCorrection['state'], 'applied');
      expect(undoCorrection['reason'], 'Fahrt doppelt erfasst');
      expect(
        await db.executor.runSelect(
          'SELECT id, reversal_of_group_id FROM journal WHERE source_kind = ? AND source_id = ?',
          <Object?>['mileage_correction', undoCorrection['id']],
        ),
        hasLength(2),
      );
    });

    testWidgets('undo preparation locks actions and ignores completion after workspace disposal', (tester) async {
      await configureMileagePostingRoles();
      final MileageTrip source = await useCases.recordBusinessTrip(
        tripDate: '2026-03-16',
        purpose: 'Undo busy state test',
        distanceHundredthsKm: 1000,
        businessContext: 'Undo busy project',
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      await useCases.calculateTrip(source.id);
      await useCases.postTrip(source.id);

      final _GatedUndoPreparationRepository gatedRepo = _GatedUndoPreparationRepository(db.executor);
      final MileageEntryUseCases gatedUseCases = MileageEntryUseCases(gatedRepo);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MileageEntryWorkspace(
              useCases: gatedUseCases,
              bankAccounts: appServices.bankAccounts,
              categoryWorkspace: appServices.categoryWorkspace,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder scrollable = find
          .descendant(of: find.byType(MileageEntryWorkspace), matching: find.byType(Scrollable))
          .first;
      final Finder undoButton = find.byKey(ValueKey<String>('mileage-undo-${source.id}'));
      await tester.scrollUntilVisible(undoButton, 400, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(undoButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ValueKey<String>('mileage-undo-reason-${source.id}')), 'Duplicate entry');
      await tester.tap(find.text('Undo trip').last);
      await tester.pumpAndSettle();

      expect(gatedRepo.preparationStarted.isCompleted, isTrue);
      expect(tester.widget<OutlinedButton>(undoButton).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      gatedRepo.releasePreparation.complete();
      await gatedRepo.preparationFinished.future;
      await tester.pump();
      expect(gatedRepo.correctionApplicationAttempted, isFalse);
      final Map<String, Object?> pendingUndo = (await db.executor.runSelect(
        'SELECT state FROM mileage_trip_corrections WHERE trip_id = ? AND kind = ?',
        <Object?>[source.id, 'void'],
      )).single;
      expect(pendingUndo['state'], 'draft');
      expect(tester.takeException(), isNull);
    });

    testWidgets('mileage posting role settings save explicit eligible pairs through production route', (tester) async {
      final AppServices services = AppServices(db);
      final BankAccount expenseAccount = await services.bankAccounts.create(
        name: 'Mileage travel ledger',
        kontoart: 'Sachkonto',
      );
      final BankAccount contributionAccount = await services.bankAccounts.create(
        name: 'Mileage contribution ledger',
        kontoart: 'Sachkonto',
      );
      await services.bankAccounts.create(name: 'Ordinary bank account', kontoart: 'Girokonto');
      final int expenseCategoryId = await insertCategory(label: 'Mileage expense', art: 'ausgabe', euerLine: 71);
      final int contributionCategoryId = await insertCategory(
        label: 'Mileage private contribution',
        art: 'einnahme',
        euerLine: 107,
      );
      await insertCategory(label: 'Unrelated category', art: 'ausgabe', euerLine: 70);
      final List<Map<String, Object?>> companyRows = await db.executor.runSelect(
        'SELECT id FROM unternehmen LIMIT 1',
        const <Object?>[],
      );
      if (companyRows.isEmpty) {
        await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', const <Object?>['Test GmbH']);
      }
      final router = createRouter(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: AppScope(
            services: services,
            child: MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/banking?view=mileage');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/banking');
      expect(router.routeInformationProvider.value.uri.queryParameters['view'], 'mileage');

      final Finder settingsToggle = find.byKey(const ValueKey<String>('mileage-role-settings-toggle'));
      await tester.tap(settingsToggle);
      await tester.pumpAndSettle();

      final Finder saveButton = find.byKey(const ValueKey<String>('mileage-role-save'));
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

      Future<void> choose(String key, String label) async {
        final Finder field = find.byKey(ValueKey<String>(key));
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      final Finder expenseAccountField = find.byKey(const ValueKey<String>('mileage-role-expense-account'));
      await tester.ensureVisible(expenseAccountField);
      await tester.tap(expenseAccountField);
      await tester.pumpAndSettle();
      expect(find.text('Ordinary bank account'), findsNothing);
      await tester.tap(find.text('Mileage travel ledger').last);
      await tester.pumpAndSettle();

      await choose('mileage-role-expense-category', 'Mileage expense');
      await choose('mileage-role-contribution-account', 'Mileage contribution ledger');

      final Finder contributionCategoryField = find.byKey(const ValueKey<String>('mileage-role-contribution-category'));
      await tester.ensureVisible(contributionCategoryField);
      await tester.tap(contributionCategoryField);
      await tester.pumpAndSettle();
      expect(find.text('Unrelated category'), findsNothing);
      await tester.tap(find.text('Mileage private contribution').last);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Mileage posting roles saved.'), findsOneWidget);
      final MileagePostingRoleSettings settings = await useCases.loadPostingRoleSettings();
      expect(settings.travelExpense, (kontoId: expenseAccount.id, kategorieId: expenseCategoryId));
      expect(settings.privateContribution, (kontoId: contributionAccount.id, kategorieId: contributionCategoryId));
    });
  });
}

class _RecordingPort implements MileagePostingPort {
  int calls = 0;

  @override
  Future<String> postExpense(MileageTrip trip) async {
    calls++;
    return 'evt-${trip.id}';
  }
}

class _DelegatingRecordingPort implements MileagePostingPort {
  _DelegatingRecordingPort(this.delegate);

  final MileagePostingPort delegate;
  final List<String> tripIds = <String>[];
  final List<String> completedTripIds = <String>[];
  @override
  Future<String> postExpense(MileageTrip trip) async {
    tripIds.add(trip.id);
    try {
      return await delegate.postExpense(trip);
    } finally {
      completedTripIds.add(trip.id);
    }
  }
}

class _MileageTestAppServices extends AppServices {
  _MileageTestAppServices(super.db, this._mileageEntry);

  final MileageEntryUseCases _mileageEntry;

  @override
  MileageEntryUseCases get mileageEntry => _mileageEntry;
}

class _FixedMileageRepository extends MileageEntryRepository {
  _FixedMileageRepository(MileageEntryRepository delegate, this.trip) : super(delegate.executor);

  final MileageTrip trip;

  @override
  Future<MileageTrip?> getById(String id) async => id == trip.id ? trip : null;
}
