// ignore_for_file: prefer_single_quotes
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/l10n/l10n.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';
import 'package:openaccounting/features/mileage/mileage_entry_repository.dart';
import 'package:openaccounting/features/mileage/mileage_entry_usecases.dart';
import 'package:openaccounting/features/mileage/mileage_entry_workspace.dart';

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

void main() {
  group('mileage-entry capture', () {
    late AppDatabase db;
    late MileageEntryRepository repo;
    late MileageEntryUseCases useCases;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MileageEntryRepository(db.executor);
      await repo.ensureTablesForTests();
      useCases = MileageEntryUseCases(repo);
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
      await tester.tap(find.byKey(ValueKey<String>('mileage-calculate-${trip.id}')));
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
          home: Scaffold(body: MileageEntryWorkspace(useCases: useCases)),
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
          home: Scaffold(body: MileageEntryWorkspace(useCases: useCases)),
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
          home: Scaffold(body: MileageEntryWorkspace(useCases: useCases)),
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
