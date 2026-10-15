import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';

/// Availability of a report workspace result.
enum ReportAvailability { available, unavailable, invalidSelection }

/// Typed workspace result: one availability state; when available, the
/// immutable typed report value. Pages render this and never query tables.
class ReportWorkspaceResult<T> {
  const ReportWorkspaceResult.available(T this.value) : availability = ReportAvailability.available, reasonCode = null;
  const ReportWorkspaceResult.unavailable(this.reasonCode)
    : availability = ReportAvailability.unavailable,
      value = null;
  const ReportWorkspaceResult.invalidSelection(this.reasonCode)
    : availability = ReportAvailability.invalidSelection,
      value = null;

  final ReportAvailability availability;

  /// Typed reason code; UI maps it to a localized message.
  final String? reasonCode;

  final T? value;
}

/// Immutable EÜR preview: resolved line amounts plus the recorded form and
/// source versions.
class EuerPreview {
  const EuerPreview({
    required this.jahr,
    required this.formVersion,
    required this.zeilen,
    required this.sourceVersions,
    required this.hinweise,
    required this.vorsteuerBetrag,
    required this.gewinn,
    required this.sourceCoverageComplete,
  });

  final int jahr;
  final String formVersion;
  final Map<int, String> zeilen;

  /// Catalog source reference → version for verified mappings in this result.
  final Map<String, String> sourceVersions;

  /// Hinweiszeilen (106/107) without Gewinn impact.
  final Map<int, String> hinweise;

  /// Vorsteuer per Soll-Prinzip ab CUTOVER_DATUM, else Zahlungsprinzip.
  final String vorsteuerBetrag;

  /// Gewinn (positive) / Verlust (negative string).
  final String gewinn;

  /// True when generation succeeded: no unresolved mapping input blocked the
  /// result, so source coverage is complete (blocked input throws instead).
  final bool sourceCoverageComplete;

  /// Betrag für Zeile oder '0.00'.
  String zeile(int n) => zeilen[n] ?? '0.00';
}

/// Typed owner for `/reports?report=euer&year=YYYY` (design.md route table).
/// shortcut: only the accepted 2025 form exists; add a per-year form-mapping
/// registry when a later form contract is accepted.
class EuerReportUseCase {
  EuerReportUseCase(this.executor) : _service = EuerService(executor);

  final QueryExecutor executor;
  final EuerService _service;

  static const String supportedFormVersion = 'anlage-euer-2025';

  Future<ReportWorkspaceResult<EuerPreview>> preview({required int jahr}) async {
    if (jahr != 2025) {
      return const ReportWorkspaceResult<EuerPreview>.unavailable('unsupportedFormYear');
    }
    try {
      final EuerResult result = await _service.generate(jahr: jahr);
      return ReportWorkspaceResult<EuerPreview>.available(
        EuerPreview(
          jahr: jahr,
          formVersion: supportedFormVersion,
          zeilen: result.zeilen,
          sourceVersions: result.catalogSources,
          hinweise: result.hinweise,
          vorsteuerBetrag: result.vorsteuerBetrag,
          gewinn: result.gewinn,
          sourceCoverageComplete: true,
        ),
      );
    } on EuerException catch (e) {
      return ReportWorkspaceResult<EuerPreview>.unavailable('sourceUnavailable: ${e.message}');
    }
  }
}
