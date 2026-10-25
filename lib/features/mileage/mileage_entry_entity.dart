/// Mileage trip entity — immutable-after-posting source record.
/// Spec: distance as integer hundredths, unresolved until accepted policy.
typedef MileagePostingRoleSelection = ({int kontoId, int kategorieId});

typedef MileagePostingRoleSettings = ({
  MileagePostingRoleSelection? travelExpense,
  MileagePostingRoleSelection? privateContribution,
});

enum MileageTripState { unresolved, calculated, posted, corrected, voided }

enum MileageTripKind { businessTrip, commuting, eksAllowance, other, unknown }

enum MileageVehicleSource { private, company, unknown }

enum MileageVehicleClass { kraftwagen, otherMotorVehicle, unsupported, unknown }

String mileageTripKindStorageValue(MileageTripKind value) => switch (value) {
  MileageTripKind.businessTrip => 'business_trip',
  MileageTripKind.commuting => 'commuting',
  MileageTripKind.eksAllowance => 'eks_allowance',
  MileageTripKind.other => 'other',
  MileageTripKind.unknown => 'unknown',
};

MileageTripKind mileageTripKindFromStorage(String value) => switch (value) {
  'business_trip' => MileageTripKind.businessTrip,
  'commuting' => MileageTripKind.commuting,
  'eks_allowance' => MileageTripKind.eksAllowance,
  'other' => MileageTripKind.other,
  _ => MileageTripKind.unknown,
};

String mileageVehicleSourceStorageValue(MileageVehicleSource value) => switch (value) {
  MileageVehicleSource.private => 'private',
  MileageVehicleSource.company => 'company',
  MileageVehicleSource.unknown => 'unknown',
};

MileageVehicleSource mileageVehicleSourceFromStorage(String value) => switch (value) {
  'private' => MileageVehicleSource.private,
  'company' => MileageVehicleSource.company,
  _ => MileageVehicleSource.unknown,
};

String mileageVehicleClassStorageValue(MileageVehicleClass value) => switch (value) {
  MileageVehicleClass.kraftwagen => 'kraftwagen',
  MileageVehicleClass.otherMotorVehicle => 'other_motor_vehicle',
  MileageVehicleClass.unsupported => 'unsupported',
  MileageVehicleClass.unknown => 'unknown',
};

MileageVehicleClass mileageVehicleClassFromStorage(String value) => switch (value) {
  'kraftwagen' => MileageVehicleClass.kraftwagen,
  'other_motor_vehicle' => MileageVehicleClass.otherMotorVehicle,
  'unsupported' => MileageVehicleClass.unsupported,
  _ => MileageVehicleClass.unknown,
};

class MileageTrip {
  const MileageTrip({
    required this.id,
    required this.tripDate,
    required this.purpose,
    required this.businessContext,
    required this.distanceHundredthsKm,
    required this.tripKind,
    required this.vehicleSource,
    required this.vehicleClass,
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
  final MileageTripKind tripKind;
  final MileageVehicleSource vehicleSource;
  final MileageVehicleClass vehicleClass;
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

abstract class MileagePostingPort {
  Future<String> postExpense(MileageTrip trip);
}
