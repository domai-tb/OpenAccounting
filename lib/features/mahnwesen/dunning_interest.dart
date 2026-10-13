import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/mahnwesen/mahnungen_exception.dart';

/// One configured stage rate: absolute calendar-day offset from the invoice
/// due date plus the configured annual percentage rate (`zinssatz`).
class DunningStageRate {
  const DunningStageRate({required this.stufe, required this.daysAfterDue, required this.annualRate});

  final int stufe;
  final int daysAfterDue;
  final String annualRate;
}

/// One posted settlement reducing principal, effective on its date before
/// that date's interest accrual.
class DunningSettlement {
  const DunningSettlement({required this.effectiveDate, required this.appliedCents});

  final String effectiveDate;
  final int appliedCents;
}

/// One maximal run of consecutive accrual days sharing rate and principal.
class DunningInterestSegment {
  const DunningInterestSegment({
    required this.von,
    required this.bis,
    required this.tage,
    required this.stufe,
    required this.zinssatz,
    required this.principalCents,
  });

  final String von;
  final String bis;
  final int tage;
  final int stufe;
  final String zinssatz;
  final int principalCents;
}

class DunningInterestResult {
  const DunningInterestResult({required this.segments, required this.totalCents});

  final List<DunningInterestSegment> segments;
  final int totalCents;

  String get total => money.fromCents(totalCents);
}

/// Deterministic late-payment interest on settled open principal.
///
/// No interest accrues before the first stage's absolute threshold. Each
/// overdue calendar day through the as-of date uses the annual rate of the
/// highest stage whose threshold is on or before that day; rate changes apply
/// prospectively. Settlements reduce principal starting on their effective
/// date; full settlement stops accrual on that date. Fees and prior interest
/// never enter principal (no compounding). Exact decimal daily amounts use a
/// 365-day year and round once to cents, half-up; no floating point, no
/// per-day rounding.
class DunningInterest {
  const DunningInterest._();

  static const int _daysPerYear = 365;
  static const int _hundredthsPerUnit = 100;

  static DunningInterestResult calculate({
    required String dueDate,
    required List<DunningStageRate> stages,
    required int initialPrincipalCents,
    required List<DunningSettlement> settlements,
    required String asOf,
  }) {
    final String due = _dateOnly(dueDate);
    final String end = _dateOnly(asOf);
    if (stages.isEmpty) {
      throw const MahnungException('Keine Mahnstufen konfiguriert');
    }
    if (initialPrincipalCents < 0) {
      throw const MahnungException('Offener Saldo darf nicht negativ sein');
    }
    final List<DunningStageRate> ordered = List<DunningStageRate>.from(stages)
      ..sort((DunningStageRate a, DunningStageRate b) => a.daysAfterDue.compareTo(b.daysAfterDue));
    final DateTime dueDay = _parseDay(due);
    final DateTime endDay = _parseDay(end);
    final DateTime firstThreshold = dueDay.add(Duration(days: ordered.first.daysAfterDue));
    if (endDay.isBefore(firstThreshold) || initialPrincipalCents <= 0) {
      return const DunningInterestResult(segments: <DunningInterestSegment>[], totalCents: 0);
    }
    final List<DunningSettlement> orderedSettlements = List<DunningSettlement>.from(settlements)
      ..sort((DunningSettlement a, DunningSettlement b) => a.effectiveDate.compareTo(b.effectiveDate));
    for (final DunningSettlement settlement in orderedSettlements) {
      _parseDay(_dateOnly(settlement.effectiveDate));
      if (settlement.appliedCents < 0) {
        throw const MahnungException('Ausgleichsbetrag darf nicht negativ sein');
      }
    }

    var numerator = BigInt.zero;
    final List<DunningInterestSegment> segments = <DunningInterestSegment>[];
    DateTime day = firstThreshold;
    while (!day.isAfter(endDay)) {
      final String dayStr = _toDateString(day);
      final DunningStageRate stage = _stageForDay(ordered, dueDay, day);
      final int rateHundredths = _rateHundredths(stage.annualRate);
      var principal = initialPrincipalCents;
      for (final DunningSettlement settlement in orderedSettlements) {
        if (_dateOnly(settlement.effectiveDate).compareTo(dayStr) <= 0) {
          principal -= settlement.appliedCents;
        }
      }
      if (principal > 0 && rateHundredths > 0) {
        numerator += BigInt.from(principal) * BigInt.from(rateHundredths);
        _appendSegment(segments, dayStr: dayStr, stage: stage, principalCents: principal);
      }
      day = day.add(const Duration(days: 1));
    }
    // cents = sum(principal * rateHundredths) / (100 * 100 * 365), half-up once.
    final BigInt divisor = BigInt.from(_hundredthsPerUnit * _hundredthsPerUnit * _daysPerYear);
    final int totalCents = ((numerator + divisor ~/ BigInt.from(2)) ~/ divisor).toInt();
    return DunningInterestResult(segments: segments, totalCents: totalCents);
  }

  static void _appendSegment(
    List<DunningInterestSegment> segments, {
    required String dayStr,
    required DunningStageRate stage,
    required int principalCents,
  }) {
    if (segments.isNotEmpty) {
      final DunningInterestSegment last = segments.last;
      if (last.stufe == stage.stufe && last.zinssatz == stage.annualRate && last.principalCents == principalCents) {
        segments[segments.length - 1] = DunningInterestSegment(
          von: last.von,
          bis: dayStr,
          tage: last.tage + 1,
          stufe: last.stufe,
          zinssatz: last.zinssatz,
          principalCents: last.principalCents,
        );
        return;
      }
    }
    segments.add(
      DunningInterestSegment(
        von: dayStr,
        bis: dayStr,
        tage: 1,
        stufe: stage.stufe,
        zinssatz: stage.annualRate,
        principalCents: principalCents,
      ),
    );
  }

  static DunningStageRate _stageForDay(List<DunningStageRate> ordered, DateTime dueDay, DateTime day) {
    DunningStageRate current = ordered.first;
    for (final DunningStageRate stage in ordered) {
      final DateTime threshold = dueDay.add(Duration(days: stage.daysAfterDue));
      if (!threshold.isAfter(day)) {
        current = stage;
      } else {
        break;
      }
    }
    return current;
  }

  static int _rateHundredths(String raw) {
    try {
      final int hundredths = money.parseScaled(raw, scale: 2, field: 'Zinssatz', roundExcess: true);
      if (hundredths < 0) {
        throw const MahnungException('Zinssatz darf nicht negativ sein');
      }
      return hundredths;
    } on money.MoneyParseException catch (error) {
      throw MahnungException('Zinssatz ungültig: ${error.message}');
    }
  }

  static String _dateOnly(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;

  static DateTime _parseDay(String day) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw MahnungException('Datum ungültig: $day (JJJJ-MM-TT erwartet)');
    }
    final List<String> parts = day.split('-');
    final DateTime parsed = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    if (_toDateString(parsed) != day) {
      throw MahnungException('Datum ungültig: $day (kein Kalendertag)');
    }
    return parsed;
  }

  static String _toDateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
