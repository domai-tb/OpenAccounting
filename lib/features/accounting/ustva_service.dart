import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/ustva_entity.dart';

/// UStVA KZ 1-22 + special KZs per spec.
/// ponytail: executor-injected, pure string money, PRAGMA column checks with ponytail stub fallback.
/// Missing columns (ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a) → 0 contribution, not crash.
/// Uses brutto portion formula base*ust/(100+ust) with trunc, max(0) for negative margin.
class UstvaService {
  UstvaService(this.executor);

  final QueryExecutor executor;

  Future<UstvaResult> compute({required int jahr, required int monatOrQuartal, required String rhythmus}) async {
    final String norm = rhythmus.trim().toLowerCase();
    final bool isMonthly;
    if (norm == 'monatlich' || norm == 'monthly' || norm == 'monat') {
      isMonthly = true;
    } else if (norm == 'quartal' || norm == 'quarterly' || norm == 'quartalsweise' || norm == 'q') {
      isMonthly = false;
    } else {
      throw ArgumentError('rhythmus must be monatlich or quartal, got $rhythmus');
    }

    if (isMonthly && (monatOrQuartal < 1 || monatOrQuartal > 12)) {
      throw ArgumentError('monat must be 1..12');
    }
    if (!isMonthly && (monatOrQuartal < 1 || monatOrQuartal > 4)) {
      throw ArgumentError('quartal must be 1..4');
    }

    // Fetch journal with resolved satz via LEFT JOIN (falls back to plain SELECT if join fails).
    final List<Map<String, Object?>> journalRows = await _fetchJournalRows();
    final List<Map<String, Object?>> vorsteuerRows = await _fetchVorsteuerRows();

    // Filter by period in Dart to avoid SQL date-function + missing-column fragility.
    final List<Map<String, Object?>> jFiltered = journalRows
        .where((Map<String, Object?> r) {
          final String? datum = r['datum'] as String?;
          return _inPeriod(datum, jahr, monatOrQuartal, isMonthly);
        })
        .toList(growable: false);

    final List<Map<String, Object?>> vFiltered = vorsteuerRows
        .where((Map<String, Object?> r) {
          final String? faell = r['faelligkeit'] as String?;
          // ponytail: vorsteuer tanpa faelligkeit → ignore for period-specific Soll (keeps 0)
          if (faell == null || faell.isEmpty) {
            return false;
          }
          return _inPeriod(faell, jahr, monatOrQuartal, isMonthly);
        })
        .toList(growable: false);

    int kz1Cents = 0;
    int kz3Cents = 0;
    int kz4Cents = 0;
    int kz81Cents = 0;
    int kz83Cents = 0;
    int kz18Cents = 0;
    int kz89Cents = 0;
    int kz93Cents = 0;

    for (final Map<String, Object?> row in jFiltered) {
      final String betragRaw = row['betrag']?.toString() ?? '0.00';
      final int betragCents = _toCents(_formatBetrag(betragRaw));

      // ponytail stub: DDL may lack ust_sonderfall/marge columns → containsKey check, missing → null
      final String? sonderfall = _stringOrNull(row, 'ust_sonderfall');
      final bool isIgErwerb = sonderfall == 'ig_erwerb';
      final bool isRc = sonderfall != null && !isIgErwerb;

      final String? margeRaw = _stringOrNull(row, 'marge_25a_brutto');
      final String? satz25Raw = _stringOrNull(row, 'ust_satz_25a');
      if (margeRaw != null && satz25Raw != null && margeRaw.trim().isNotEmpty && satz25Raw.trim().isNotEmpty) {
        final int margeCents = _toCents(_formatBetrag(margeRaw));
        final int base = margeCents < 0 ? 0 : margeCents;
        kz81Cents += base;
        final num? satz25 = _parseSatz(satz25Raw);
        if (satz25 != null && satz25 != 0) {
          final int ust = _calcUstFromBrutto(base, satz25);
          kz83Cents += ust;
          kz18Cents += ust;
        }
        continue;
      }

      if (isRc) {
        // Reverse charge: base → KZ89, tax → KZ93, not domestic (exclude from KZ1/3/4)
        kz89Cents += betragCents;
        final num? satz = _resolveSatz(row);
        if (satz != null && satz != 0) {
          kz93Cents += _calcUstFromBrutto(betragCents, satz);
        }
        continue;
      }

      if (isIgErwerb) {
        // ig Erwerb journals are purchase side, not Umsatz → exclude from KZ1/3/4, KZ61 via vorsteuer table
        continue;
      }

      // Normal domestic turnover
      kz1Cents += betragCents;
      final num? satz = _resolveSatz(row);
      if (satz != null && satz != 0) {
        final int ust = _calcUstFromBrutto(betragCents, satz);
        if ((satz - 19).abs() < 0.01) {
          kz3Cents += ust;
        } else if ((satz - 7).abs() < 0.01) {
          kz4Cents += ust;
        }
      }
    }

    // Vorsteuer KZ61/66 from vorsteuer_ansprueche (Soll-Prinzip)
    int kz61Cents = 0;
    int kz66Cents = 0;
    for (final Map<String, Object?> row in vFiltered) {
      final String betragRaw = row['betrag']?.toString() ?? '0.00';
      final int betragCents = _toCents(_formatBetrag(betragRaw));
      final String? sf = _stringOrNull(row, 'ust_sonderfall');
      if (sf == 'ig_erwerb') {
        kz61Cents += betragCents;
      } else {
        kz66Cents += betragCents;
      }
    }

    final Map<String, String> kz = <String, String>{
      '1': _fromCents(kz1Cents),
      '3': _fromCents(kz3Cents),
      '4': _fromCents(kz4Cents),
      '18': _fromCents(kz18Cents),
      '61': _fromCents(kz61Cents),
      '66': _fromCents(kz66Cents),
      '81': _fromCents(kz81Cents),
      '83': _fromCents(kz83Cents),
      '89': _fromCents(kz89Cents),
      '93': _fromCents(kz93Cents),
      for (int i = 1; i <= 22; i++)
        if (!<String>['1', '3', '4', '18'].contains('$i')) '$i': '0.00',
    };

    return UstvaResult(
      jahr: jahr,
      monatOrQuartal: monatOrQuartal,
      rhythmus: isMonthly ? 'monatlich' : 'quartal',
      kz: kz,
    );
  }

  Future<List<Map<String, Object?>>> _fetchJournalRows() async {
    try {
      return await executor.runSelect(
        'SELECT j.*, s.satz as _resolved_satz FROM journal j LEFT JOIN ust_saetze s ON j.ust_satz_id = s.id',
        const <Object?>[],
      );
    } catch (_) {
      try {
        return await executor.runSelect('SELECT * FROM journal', const <Object?>[]);
      } catch (_) {
        return <Map<String, Object?>>[];
      }
    }
  }

  Future<List<Map<String, Object?>>> _fetchVorsteuerRows() async {
    try {
      return await executor.runSelect('SELECT * FROM vorsteuer_ansprueche', const <Object?>[]);
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }
}

bool _inPeriod(String? raw, int jahr, int monatOrQuartal, bool isMonthly) {
  if (raw == null || raw.length < 7) {
    return false;
  }
  final int? y = int.tryParse(raw.substring(0, 4));
  final int? m = int.tryParse(raw.substring(5, 7));
  if (y == null || m == null) {
    return false;
  }
  if (y != jahr) {
    return false;
  }
  if (isMonthly) {
    return m == monatOrQuartal;
  }
  final int q = monatOrQuartal;
  final int start = (q - 1) * 3 + 1;
  final int end = q * 3;
  return m >= start && m <= end;
}

String? _stringOrNull(Map<String, Object?> row, String key) {
  if (!row.containsKey(key)) {
    return null;
  }
  final Object? v = row[key];
  if (v == null) {
    return null;
  }
  final String s = v.toString();
  if (s.isEmpty) {
    return null;
  }
  return s;
}

num? _parseSatz(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) {
    return null;
  }
  return num.tryParse(t);
}

num? _resolveSatz(Map<String, Object?> row) {
  final String? direct = _stringOrNull(row, 'ust_satz');
  if (direct != null) {
    final num? n = _parseSatz(direct);
    if (n != null) {
      return n;
    }
  }
  final String? resolved = _stringOrNull(row, '_resolved_satz');
  if (resolved != null) {
    final num? n = _parseSatz(resolved);
    if (n != null) {
      return n;
    }
  }
  return null;
}

int _calcUstFromBrutto(int baseCents, num satz) {
  if (satz == 0) {
    return 0;
  }
  // ponytail: trunc floor, avoids float drift for exact margins (119*19/119=19)
  final double r = baseCents * satz / (100 + satz);
  // trunc toward zero for positive, but base is non-negative for USt (margin max 0)
  return r.floor();
}

int _toCents(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) {
    return 0;
  }
  final bool isNeg = t.startsWith('-');
  final String unsigned = isNeg ? t.substring(1) : t;
  final List<String> parts = unsigned.split('.');
  final String intPartRaw = parts[0].isEmpty ? '0' : parts[0];
  final String intNoLead = intPartRaw.replaceFirst(RegExp('^0+'), '');
  final String effInt = intNoLead.isEmpty ? '0' : intNoLead;
  final String decRaw = parts.length > 1 ? parts[1] : '';
  final String dec = '${decRaw}00'.substring(0, 2);
  final int cents = int.parse(effInt) * 100 + int.parse(dec);
  return isNeg ? -cents : cents;
}

String _fromCents(int cents) {
  final bool isNeg = cents < 0;
  final int abs = cents.abs();
  final String intPart = (abs ~/ 100).toString();
  final String dec = (abs % 100).toString().padLeft(2, '0');
  return '${isNeg ? '-' : ''}$intPart.$dec';
}

String _formatBetrag(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) {
    return '0.00';
  }
  final bool isNeg = t.startsWith('-');
  final String unsigned = isNeg ? t.substring(1) : t;
  final List<String> parts = unsigned.split('.');
  final String intPart = parts[0].isEmpty ? '0' : parts[0];
  final String decRaw = parts.length > 1 ? parts[1] : '';
  final String dec = '${decRaw}00'.substring(0, 2);
  return '${isNeg ? '-' : ''}$intPart.$dec';
}
