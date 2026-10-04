/// Typed Anlage S/G availability use case per income-tax-supporting-reports.
///
/// No accepted form-year, period, classification, or accounting-source
/// contract exists, so every selection returns an unavailable result naming
/// the blockers. The use case never returns numeric fields, never copies
/// other reports, and never touches accounting records.
enum IncomeTaxSchedule { s, g }

/// Blocker reasons for an unavailable S/G supporting report.
enum IncomeTaxBlocker { formContract, periodContract, classification, accountingSource }

class IncomeTaxAvailability {
  const IncomeTaxAvailability({required this.schedule, required this.available, required this.blockers});

  final IncomeTaxSchedule schedule;
  final bool available;
  final List<IncomeTaxBlocker> blockers;
}

class IncomeTaxScheduleAvailabilityUseCase {
  const IncomeTaxScheduleAvailabilityUseCase();

  static const List<IncomeTaxBlocker> missingContracts = <IncomeTaxBlocker>[
    IncomeTaxBlocker.formContract,
    IncomeTaxBlocker.periodContract,
    IncomeTaxBlocker.classification,
    IncomeTaxBlocker.accountingSource,
  ];

  /// Returns the availability for [schedule]. Always unavailable until a
  /// separately accepted contract registers (none exists in this change).
  IncomeTaxAvailability availability(IncomeTaxSchedule schedule) {
    return IncomeTaxAvailability(schedule: schedule, available: false, blockers: missingContracts);
  }

  /// Parses a `schedule=s|g` route value, or null when missing/invalid.
  static IncomeTaxSchedule? parseSchedule(String? value) {
    final String v = (value ?? '').trim().toLowerCase();
    if (v == 's') return IncomeTaxSchedule.s;
    if (v == 'g') return IncomeTaxSchedule.g;
    return null;
  }
}
