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
      );

      expect(trip.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(trip.tripDate, '2026-03-14');
      expect(trip.purpose, 'Kundenbesuch München');
      expect(trip.distanceHundredthsKm, 4525);
      expect(trip.state, MileageTripState.unresolved);
      expect(trip.policyId, isNull);
      expect(trip.calculatedAmount, isNull);
      expect(trip.postingEventId, isNull);

      final List<MileageTrip> rows = await repo.listTrips();
      expect(rows.length, 1);
      expect(rows.first.id, trip.id);
    });

    test('test_reject_invalid_trip_facts', () async {
      await expectLater(
        () => useCases.recordBusinessTrip(
          tripDate: '2026-13-40',
          purpose: '',
          distanceHundredthsKm: 0,
          businessContext: '',
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
      );
      await db.executor.runUpdate(
        "UPDATE mileage_trips SET state = 'posted', posting_event_id = ?, "
        "policy_id = ?, policy_source = ?, policy_version = ?, "
        "policy_effective_from = ?, policy_effective_to = ?, "
        "calculated_amount = ?, calculated_at = ? WHERE id = ?",
        <Object?>[
          'evt-1',
          'test-policy',
          'test',
          'v1',
          '2026-01-01',
          '2026-12-31',
          '12.50',
          '2026-03-14T00:00:00Z',
          trip.id,
        ],
      );
      await expectLater(() => useCases.editTripFacts(trip.id, purpose: 'Neu'), throwsStateError);
      final List<MileageTrip> rows = await repo.listTrips();
      expect(rows.first.purpose, 'Kundenbesuch');
    });

    test('test_calculate_from_an_approved_policy', () {
      expect(useCases.calculateApprovedAmountCents(distanceHundredthsKm: 4525, vehicleClass: 'car'), 1358);
      expect(useCases.calculateApprovedAmountCents(distanceHundredthsKm: 1000, vehicleClass: 'otherMotor'), 200);
      expect(
        () => useCases.calculateApprovedAmountCents(distanceHundredthsKm: 1000, vehicleClass: 'companyCar'),
        throwsArgumentError,
      );
    });

    test('test_keep_an_unresolved_trip_out_of_accounting', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
      );
      await expectLater(
        () => useCases.calculateApprovedAmountCents(distanceHundredthsKm: 1000, vehicleClass: 'companyCar'),
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
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
      );
      const int eksAllowance = (1000 * 10) ~/ 100;
      expect(eksAllowance, 100);
      expect(
        useCases.calculateApprovedAmountCents(distanceHundredthsKm: 1000, vehicleClass: 'car'),
        isNot(eksAllowance),
      );
      final MileageTrip kept = (await repo.getById(trip.id))!;
      expect(kept.state, MileageTripState.unresolved);
      expect(kept.calculatedAmount, isNull);
    });

    test('test_editing_calculated_trip_invalidates_calculation', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
      );
      await useCases.applyApprovedCalculation(trip.id, 'car');
      final MileageTrip edited = await useCases.editTripFacts(trip.id, purpose: 'Neuer Zweck');
      expect(edited.state, MileageTripState.unresolved);
      expect(edited.purpose, 'Neuer Zweck');
      expect(edited.policyId, isNull);
      expect(edited.calculatedAmount, isNull);
      expect(edited.postingEventId, isNull);
    });

    test('test_post_a_confirmed_resolved_mileage_expense', () async {
      final MileageTrip trip = await useCases.recordBusinessTrip(
        tripDate: '2026-03-14',
        purpose: 'Kundenbesuch',
        distanceHundredthsKm: 1000,
        businessContext: 'Projekt',
      );
      await useCases.applyApprovedCalculation(trip.id, 'car');
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
      );
      await useCases.applyApprovedCalculation(trip.id, 'car');
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
