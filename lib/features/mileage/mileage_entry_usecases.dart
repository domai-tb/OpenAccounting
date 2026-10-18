import 'dart:math';

import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';
import 'package:openaccounting/features/mileage/mileage_entry_repository.dart';

/// Posting boundary port — production M2 implementation arrives later.
/// Test doubles prove the exactly-once contract first.
abstract class MileagePostingPort {
  Future<String> postExpense(MileageTrip trip);
}

/// Mileage use-cases — capture only, fail-closed until accepted policy/posting.
/// Never reuses EKS 0.10 rate; unresolved stays out of totals.
class MileageEntryUseCases {
  MileageEntryUseCases(this.repo, {this.postingPort});

  final MileageEntryRepository repo;
  final MileagePostingPort? postingPort;

  Future<MileageTrip> recordBusinessTrip({
    required String tripDate,
    required String purpose,
    required int distanceHundredthsKm,
    required String businessContext,
    required MileageTripKind tripKind,
    required MileageVehicleSource vehicleSource,
    required MileageVehicleClass vehicleClass,
  }) async {
    _requireDate(tripDate);
    _requireText(purpose, 'purpose');
    _requireText(businessContext, 'businessContext');
    if (distanceHundredthsKm < 1 || distanceHundredthsKm > 999999999999) {
      throw ArgumentError('distance out of range');
    }
    final String now = DateTime.now().toUtc().toIso8601String();
    final String id = _newUuidV4();
    final MileageTrip trip = MileageTrip(
      id: id,
      tripDate: tripDate,
      purpose: purpose.trim(),
      businessContext: businessContext.trim(),
      distanceHundredthsKm: distanceHundredthsKm,
      tripKind: tripKind,
      vehicleSource: vehicleSource,
      vehicleClass: vehicleClass,
      state: MileageTripState.unresolved,
      createdAt: now,
      updatedAt: now,
    );
    await repo.insertTrip(trip);
    return trip;
  }

  Future<MileageTrip> editTripFacts(
    String id, {
    String? purpose,
    String? tripDate,
    int? distanceHundredthsKm,
    String? businessContext,
    MileageTripKind? tripKind,
    MileageVehicleSource? vehicleSource,
    MileageVehicleClass? vehicleClass,
  }) async {
    final MileageTrip? current = await repo.getById(id);
    if (current == null) throw StateError('not found');
    if (current.state == MileageTripState.posted ||
        current.state == MileageTripState.corrected ||
        current.state == MileageTripState.voided) {
      throw StateError('posted immutable');
    }
    final String nextPurpose = purpose ?? current.purpose;
    final String nextDate = tripDate ?? current.tripDate;
    final int nextDist = distanceHundredthsKm ?? current.distanceHundredthsKm;
    final String nextContext = businessContext ?? current.businessContext;
    final MileageTripKind nextTripKind = tripKind ?? current.tripKind;
    final MileageVehicleSource nextVehicleSource = vehicleSource ?? current.vehicleSource;
    final MileageVehicleClass nextVehicleClass = vehicleClass ?? current.vehicleClass;
    _requireDate(nextDate);
    _requireText(nextPurpose, 'purpose');
    _requireText(nextContext, 'businessContext');
    if (nextDist < 1 || nextDist > 999999999999) throw ArgumentError('distance out of range');
    if (current.state == MileageTripState.calculated) {
      await repo.demoteCalculatedToUnresolved(
        id: id,
        purpose: nextPurpose.trim(),
        tripDate: nextDate,
        dist: nextDist,
        businessContext: nextContext.trim(),
        tripKind: nextTripKind,
        vehicleSource: nextVehicleSource,
        vehicleClass: nextVehicleClass,
      );
    } else {
      await repo.updateUnresolvedFacts(
        id: id,
        purpose: nextPurpose.trim(),
        tripDate: nextDate,
        dist: nextDist,
        businessContext: nextContext.trim(),
        tripKind: nextTripKind,
        vehicleSource: nextVehicleSource,
        vehicleClass: nextVehicleClass,
      );
    }
    return (await repo.getById(id))!;
  }

  void _requireDate(String raw) {
    final RegExp re = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!re.hasMatch(raw)) throw ArgumentError('invalid date');
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) throw ArgumentError('invalid date');
    final String canon =
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    if (canon != raw) throw ArgumentError('invalid date');
  }

  void _requireText(String raw, String field) {
    if (raw.trim().isEmpty) throw ArgumentError('$field empty');
  }

  /// Posting stays unavailable until the M2 accounting boundary lands.
  /// shortcut: fail-closed stub; test doubles arrive with 3.x.
  Future<void> postTrip(String id) async {
    throw StateError('posting unavailable');
  }

  /// Stores a policy snapshot only for trips that meet the active application policy.
  Future<MileageTrip> calculateTrip(String id) async {
    final MileageTrip? current = await repo.getById(id);
    if (current == null) throw StateError('not found');
    if (current.state != MileageTripState.unresolved) throw StateError('not unresolved');
    if (!_isEligibleForApprovedPolicy(current)) return current;

    final int cents = calculateApprovedAmountCents(
      distanceHundredthsKm: current.distanceHundredthsKm,
      vehicleClass: current.vehicleClass,
    );
    final String now = DateTime.now().toUtc().toIso8601String();
    await repo.storeCalculation(
      id: id,
      policyId: 'DE-private-business-travel/1',
      policySource: 'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71',
      policyVersion: '1',
      policyFrom: '2025-01-01',
      policyTo: '2026-12-31',
      amount: _formatEuroAmount(cents),
      calculatedAt: now,
    );
    return (await repo.getById(id))!;
  }

  bool _isEligibleForApprovedPolicy(MileageTrip trip) {
    return trip.tripKind == MileageTripKind.businessTrip &&
        trip.vehicleSource == MileageVehicleSource.private &&
        (trip.vehicleClass == MileageVehicleClass.kraftwagen ||
            trip.vehicleClass == MileageVehicleClass.otherMotorVehicle) &&
        trip.tripDate.compareTo('2025-01-01') >= 0 &&
        trip.tripDate.compareTo('2026-12-31') <= 0;
  }

  String _formatEuroAmount(int amountCents) =>
      '${amountCents ~/ 100}.${(amountCents % 100).toString().padLeft(2, '0')}';

  /// 3.x wiring: exactly-once posting through the injected port.
  /// Identical retries return the stored event without calling the port again.
  Future<String> postTripWithPort(String id) async {
    final MileageTrip? current = await repo.getById(id);
    if (current == null) throw StateError('not found');
    if (current.postingEventId != null) return current.postingEventId!;
    if (current.state != MileageTripState.calculated) throw StateError('not calculated');
    final MileagePostingPort? port = postingPort;
    if (port == null) throw StateError('posting unavailable');
    final String eventId = await port.postExpense(current);
    if (eventId.trim().isEmpty) throw StateError('empty event');
    await repo.storePosting(id: id, eventId: eventId);
    return eventId;
  }

  /// Approved policy DE-private-business-travel/1: Kraftwagen 30c/km, other motor 20c/km.
  int calculateApprovedAmountCents({required int distanceHundredthsKm, required MileageVehicleClass vehicleClass}) {
    if (distanceHundredthsKm < 1 || distanceHundredthsKm > 999999999999) {
      throw ArgumentError('distance out of range');
    }
    final int rateCentsPerKm = switch (vehicleClass) {
      MileageVehicleClass.kraftwagen => 30,
      MileageVehicleClass.otherMotorVehicle => 20,
      MileageVehicleClass.unsupported || MileageVehicleClass.unknown => throw ArgumentError('unsupported vehicle'),
    };
    return (distanceHundredthsKm * rateCentsPerKm + 50) ~/ 100;
  }
}

String _newUuidV4() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256), growable: false);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes.map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
