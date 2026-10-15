/// Verified §141 AO bookkeeping-duty evidence for one business.
///
/// All fields are inputs the profile records; nothing here is inferred from
/// transaction totals.
class BookkeepingDutyEvidence {
  const BookkeepingDutyEvidence({
    required this.businessType,
    required this.thresholdBasis,
    required this.measuredAmountCents,
    required this.finanzamtFindingDate,
    required this.noticeDate,
    required this.wirtschaftsjahrStartMonth,
    required this.wirtschaftsjahrStartDay,
  });

  /// `'gewerbebetrieb'` or `'land_und_forstwirtschaft'`; null = unknown.
  final String? businessType;

  /// `'umsatz'` (§19(2) turnover) or `'gewinn'` (profit).
  final String? thresholdBasis;

  final int? measuredAmountCents;

  /// ISO date of the Finanzamt finding; null = no verified evidence.
  final String? finanzamtFindingDate;

  /// ISO date the Finanzamt notice was received; null = no verified evidence.
  final String? noticeDate;

  /// Verified Wirtschaftsjahr boundary of the profile (1-12, 1-31).
  final int wirtschaftsjahrStartMonth;
  final int wirtschaftsjahrStartDay;
}

/// Evaluated §141 duty state for one display date.
class BookkeepingDutyStatus {
  const BookkeepingDutyStatus({
    required this.claimDuty,
    required this.effectiveDate,
    required this.noticeDate,
    required this.reasonCode,
    required this.wirtschaftsjahrBoundary,
  });

  /// True only on/after the evidenced effective date with complete evidence.
  final bool claimDuty;

  /// ISO date the duty starts per §141(2), when derivable from evidence.
  final String? effectiveDate;

  final String? noticeDate;

  /// Typed reason code for the non-warning states; UI maps it to l10n.
  final String? reasonCode;

  /// Evidenced Wirtschaftsjahr boundary 'MM-DD', when evidence is present.
  final String? wirtschaftsjahrBoundary;
}

/// Pure evaluator for the §141 AO bookkeeping-duty warning. Deliberately has
/// no management-GuV activation output: a threshold crossing never toggles
/// the optional GuV preference.
class BookkeepingDutyUseCase {
  const BookkeepingDutyUseCase._();

  /// §141(1) thresholds in cents: turnover > EUR 800,000, profit > EUR 80,000.
  static const int turnoverThresholdCents = 80000000;
  static const int profitThresholdCents = 8000000;

  static BookkeepingDutyStatus evaluate({required BookkeepingDutyEvidence evidence, required String on}) {
    final String boundary =
        '${evidence.wirtschaftsjahrStartMonth.toString().padLeft(2, '0')}-'
        '${evidence.wirtschaftsjahrStartDay.toString().padLeft(2, '0')}';

    final String? type = evidence.businessType;
    if (type != 'gewerbebetrieb' && type != 'land_und_forstwirtschaft') {
      return BookkeepingDutyStatus(
        claimDuty: false,
        effectiveDate: null,
        noticeDate: evidence.noticeDate,
        reasonCode: 'missingBusinessType',
        wirtschaftsjahrBoundary: boundary,
      );
    }
    final String? basis = evidence.thresholdBasis;
    final int? measured = evidence.measuredAmountCents;
    if ((basis != 'umsatz' && basis != 'gewinn') || measured == null) {
      return BookkeepingDutyStatus(
        claimDuty: false,
        effectiveDate: null,
        noticeDate: evidence.noticeDate,
        reasonCode: 'missingThresholdBasis',
        wirtschaftsjahrBoundary: boundary,
      );
    }
    final int threshold = basis == 'umsatz' ? turnoverThresholdCents : profitThresholdCents;
    if (measured <= threshold) {
      return BookkeepingDutyStatus(
        claimDuty: false,
        effectiveDate: null,
        noticeDate: evidence.noticeDate,
        reasonCode: 'thresholdNotExceeded',
        wirtschaftsjahrBoundary: boundary,
      );
    }
    // Threshold crossed: duty still requires verified notice evidence.
    final String? notice = evidence.noticeDate;
    if (notice == null || evidence.finanzamtFindingDate == null) {
      return BookkeepingDutyStatus(
        claimDuty: false,
        effectiveDate: null,
        noticeDate: notice,
        reasonCode: 'missingNoticeEvidence',
        wirtschaftsjahrBoundary: boundary,
      );
    }
    final String effective = _nextWirtschaftsjahrStartAfter(notice, evidence);
    return BookkeepingDutyStatus(
      claimDuty: on.compareTo(effective) >= 0,
      effectiveDate: effective,
      noticeDate: notice,
      reasonCode: on.compareTo(effective) >= 0 ? null : 'beforeEffectiveDate',
      wirtschaftsjahrBoundary: boundary,
    );
  }

  /// §141(2): the duty starts at the beginning of the Wirtschaftsjahr that
  /// begins strictly after the notice date. January 1 is never assumed.
  static String _nextWirtschaftsjahrStartAfter(String noticeDate, BookkeepingDutyEvidence evidence) {
    final DateTime notice = DateTime.parse(noticeDate);
    DateTime candidate = DateTime(notice.year, evidence.wirtschaftsjahrStartMonth, evidence.wirtschaftsjahrStartDay);
    if (!candidate.isAfter(notice)) {
      candidate = DateTime(notice.year + 1, evidence.wirtschaftsjahrStartMonth, evidence.wirtschaftsjahrStartDay);
    }
    final String mm = candidate.month.toString().padLeft(2, '0');
    final String dd = candidate.day.toString().padLeft(2, '0');
    return '${candidate.year}-$mm-$dd';
  }
}
