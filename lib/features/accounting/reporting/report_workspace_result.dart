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
