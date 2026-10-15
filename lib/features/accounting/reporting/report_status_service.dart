/// Workspace status states per spec §Report status reflects evidence and
/// unresolved input. Displayed localized; identifiers stay stable.
enum ReportStatusState { unverfugbar, geschatzt, berechnet, geprueft, uebermittelt }

/// Evidence the workspace holds about one report result. Nothing here is
/// inferred: local previews and local files carry no submission receipt.
class ReportStatusEvidence {
  const ReportStatusEvidence({
    required this.sourceComplete,
    required this.calculationSupported,
    required this.explicitlyProvisional,
    required this.unresolvedCount,
    required this.unresolvedSourceIds,
    required this.hasReviewEvidence,
    required this.hasSubmissionReceipt,
  });

  /// No missing source contract or required field.
  final bool sourceComplete;

  /// The calculation has a supported version for the requested period.
  final bool calculationSupported;

  /// The calculation contract explicitly permits a provisional result that
  /// exposes unresolved inputs.
  final bool explicitlyProvisional;

  final int unresolvedCount;

  /// Source record IDs of the unresolved records.
  final List<int> unresolvedSourceIds;

  /// The named review evidence exists.
  final bool hasReviewEvidence;

  /// An external submission receipt or explicit supported confirmation.
  final bool hasSubmissionReceipt;
}

/// Immutable evaluated report status.
class ReportStatus {
  const ReportStatus({
    required this.state,
    required this.unresolvedCount,
    required this.unresolvedSourceIds,
    required this.isSubmitted,
  });

  final ReportStatusState state;
  final int unresolvedCount;
  final List<int> unresolvedSourceIds;

  /// True only with an external receipt or explicit supported confirmation;
  /// `Übermittelt` otherwise never appears.
  final bool isSubmitted;
}

/// Pure evaluator mapping evidence to exactly one workspace status.
class ReportStatusService {
  const ReportStatusService._();

  static ReportStatus evaluate({required ReportStatusEvidence evidence}) {
    if (!evidence.sourceComplete || !evidence.calculationSupported) {
      return ReportStatus(
        state: ReportStatusState.unverfugbar,
        unresolvedCount: evidence.unresolvedCount,
        unresolvedSourceIds: evidence.unresolvedSourceIds,
        isSubmitted: false,
      );
    }
    if (evidence.unresolvedCount > 0) {
      // Geschätzt only when the contract explicitly permits provisional.
      final bool provisional = evidence.explicitlyProvisional;
      return ReportStatus(
        state: provisional ? ReportStatusState.geschatzt : ReportStatusState.unverfugbar,
        unresolvedCount: evidence.unresolvedCount,
        unresolvedSourceIds: evidence.unresolvedSourceIds,
        isSubmitted: false,
      );
    }
    if (evidence.hasSubmissionReceipt) {
      return const ReportStatus(
        state: ReportStatusState.uebermittelt,
        unresolvedCount: 0,
        unresolvedSourceIds: <int>[],
        isSubmitted: true,
      );
    }
    if (evidence.hasReviewEvidence) {
      return const ReportStatus(
        state: ReportStatusState.geprueft,
        unresolvedCount: 0,
        unresolvedSourceIds: <int>[],
        isSubmitted: false,
      );
    }
    return const ReportStatus(
      state: ReportStatusState.berechnet,
      unresolvedCount: 0,
      unresolvedSourceIds: <int>[],
      isSubmitted: false,
    );
  }
}
