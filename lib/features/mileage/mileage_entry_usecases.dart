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
  }) async {
    _requireDate(tripDate);
    _requireText(purpose, 'purpose');
    _requireText(businessContext, 'businessContext');
    if (distanceHundredthsKm < 1 || distanceHundredthsKm > 999999999999) {
      throw ArgumentError('distance out of range');
    }
    final String now = DateTime.now().toUtc().toIso8601String();
    final String id = '${DateTime.now().toUtc().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
    final MileageTrip trip = MileageTrip(
      id: id,
      tripDate: tripDate,
      purpose: purpose.trim(),
      businessContext: businessContext.trim(),
      distanceHundredthsKm: distanceHundredthsKm,
      state: MileageTripState.unresolved,
      createdAt: now,
      updatedAt: now,
    );
    await repo.insertTrip(trip);
    return trip;
  }

  Future<MileageTrip> editTripFacts(String id, {String? purpose, String? tripDate, int? distanceHundredthsKm}) async {
    final MileageTrip? current = await repo.getById(id);
    if (current == null) throw StateError('not found');
    if (current.state != MileageTripState.unresolved) throw StateError('posted immutable');
    final String nextPurpose = purpose ?? current.purpose;
    final String nextDate = tripDate ?? current.tripDate;
    final int nextDist = distanceHundredthsKm ?? current.distanceHundredthsKm;
    _requireDate(nextDate);
    _requireText(nextPurpose, 'purpose');
    if (nextDist < 1 || nextDist > 999999999999) throw ArgumentError('distance out of range');
    await repo.updateUnresolvedFacts(id: id, purpose: nextPurpose.trim(), tripDate: nextDate, dist: nextDist);
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

  /// M1 persistence: atomically store the approved snapshot on unresolved-to-calculated.
  Future<MileageTrip> applyApprovedCalculation(String id, String vehicleClass) async {
    final MileageTrip? current = await repo.getById(id);
    if (current == null) throw StateError('not found');
    if (current.state != MileageTripState.unresolved) throw StateError('not unresolved');
    final int cents = calculateApprovedAmountCents(
      distanceHundredthsKm: current.distanceHundredthsKm,
      vehicleClass: vehicleClass,
    );
    final String now = DateTime.now().toUtc().toIso8601String();
    await repo.storeCalculation(
      id: id,
      policyId: 'DE-private-business-travel/1',
      policySource: 'EStH-R4.12-LStH-A25',
      policyVersion: '1',
      policyFrom: '2025-01-01',
      policyTo: '2026-12-31',
      amount: (cents / 100).toStringAsFixed(2),
      calculatedAt: now,
    );
    return (await repo.getById(id))!;
  }

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

  /// Approved policy DE-private-business-travel/1: car 30c/km, other motor 20c/km, half-up per trip.
  /// shortcut: vehicle eligibility param only; full facts validated at record time.
  int calculateApprovedAmountCents({required int distanceHundredthsKm, required String vehicleClass}) {
    if (distanceHundredthsKm < 1 || distanceHundredthsKm > 999999999999) throw ArgumentError('distance out of range');
    final int rate;
    if (vehicleClass == 'car') {
      rate = 30;
    } else if (vehicleClass == 'otherMotor') {
      rate = 20;
    } else {
      throw ArgumentError('unsupported vehicle');
    }
    return (distanceHundredthsKm * rate + 50) ~/ 100;
  }
}
