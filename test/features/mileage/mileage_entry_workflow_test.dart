// ignore_for_file: prefer_single_quotes
import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';
import 'package:openaccounting/features/mileage/mileage_entry_repository.dart';
import 'package:openaccounting/features/mileage/mileage_entry_usecases.dart';

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
      final MileageEntryUseCases postingUseCases = MileageEntryUseCases(repo, postingPort: _RecordingPort());
      await postingUseCases.postTripWithPort(trip.id);
      await expectLater(() => useCases.editTripFacts(trip.id, purpose: 'Neu'), throwsStateError);
      final List<MileageTrip> rows = await repo.listTrips();
      expect(rows.first.purpose, 'Kundenbesuch');
    });

    test('test_calculate_from_an_approved_policy', () {
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
      expect(ineligibleRepository.storePostingCalls, 0);
      expect(untrustedRepository.storePostingCalls, 0);
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
      final _RecordingPort port = _RecordingPort();
      final MileageEntryUseCases wired = MileageEntryUseCases(repo, postingPort: port);
      final String eventId = await wired.postTripWithPort(trip.id);
      expect(eventId.isNotEmpty, isTrue);
      expect(port.calls, 1);
      final MileageTrip kept = (await repo.getById(trip.id))!;
      expect(kept.postingEventId, eventId);
      expect(kept.state, MileageTripState.posted);
    });

    test('test_reject_duplicate_or_incomplete_posting', () async {
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
      final String first = await wired.postTripWithPort(trip.id);
      final String second = await wired.postTripWithPort(trip.id);
      expect(second, first);
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

class _FixedMileageRepository extends MileageEntryRepository {
  _FixedMileageRepository(MileageEntryRepository delegate, this.trip) : super(delegate.executor);

  final MileageTrip trip;
  int storePostingCalls = 0;

  @override
  Future<MileageTrip?> getById(String id) async => id == trip.id ? trip : null;

  @override
  Future<void> storePosting({required String id, required String eventId}) async {
    storePostingCalls++;
  }
}
