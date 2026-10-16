/// Mileage trip entity — immutable-after-posting source record.
/// Spec: distance as integer hundredths, unresolved until accepted policy.
enum MileageTripState { unresolved, calculated, posted, corrected, voided }

class MileageTrip {
  const MileageTrip({
    required this.id,
    required this.tripDate,
    required this.purpose,
    required this.businessContext,
    required this.distanceHundredthsKm,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.policyId,
    this.policySource,
    this.policyVersion,
    this.policyEffectiveFrom,
    this.policyEffectiveTo,
    this.calculatedAmount,
    this.calculatedAt,
    this.postingEventId,
  });

  final String id;
  final String tripDate;
  final String purpose;
  final String businessContext;
  final int distanceHundredthsKm;
  final MileageTripState state;
  final String createdAt;
  final String updatedAt;
  final String? policyId;
  final String? policySource;
  final String? policyVersion;
  final String? policyEffectiveFrom;
  final String? policyEffectiveTo;
  final String? calculatedAmount;
  final String? calculatedAt;
  final String? postingEventId;

  static MileageTripState stateFrom(String raw) {
    return MileageTripState.values.firstWhere(
      (MileageTripState e) => e.name == raw,
      orElse: () => MileageTripState.unresolved,
    );
  }
}
