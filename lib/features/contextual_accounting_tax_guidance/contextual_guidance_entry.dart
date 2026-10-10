/// Typed content catalog for reviewed accounting/tax explanations.
///
/// Each entry carries a stable ID, the UI route and control/status ID it
/// explains, and the owning capability contract revision it is tied to.
/// Law-dependent entries additionally record primary-source provenance.
enum GuidanceCoverageState { reviewed, missing, reviewNeeded }

/// Primary-source provenance for law-dependent guidance entries.
class GuidanceProvenance {
  const GuidanceProvenance({
    required this.jurisdiction,
    required this.sourceTitle,
    required this.provision,
    required this.sourceVersion,
    required this.retrievalDate,
    required this.applicabilityPeriod,
  });

  final String jurisdiction;
  final String sourceTitle;
  final String provision;
  final String sourceVersion;
  final String retrievalDate;
  final String applicabilityPeriod;
}

/// One reviewed accounting/tax explanation attached to a control or status.
///
/// Visible title/body text always comes from localized resources through the
/// guidance text resolver; this type only holds identifiers, routing,
/// contract linkage, and review provenance.
class ContextualGuidanceEntry {
  const ContextualGuidanceEntry({
    required this.stableId,
    required this.route,
    required this.controlId,
    required this.owningContract,
    required this.contractRevision,
    this.lawDependent = false,
    this.provenance,
  });

  final String stableId;
  final String route;
  final String controlId;
  final String owningContract;
  final String contractRevision;
  final bool lawDependent;
  final GuidanceProvenance? provenance;
}
