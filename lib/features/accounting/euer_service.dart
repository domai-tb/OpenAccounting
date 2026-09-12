import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// EÜR Anlage 2025 — 60+ Zeilen 12–107 per spec.
/// Journal direction is read from beleg_typ and kept separate from the
/// category's presentation line. All amounts are aggregated as integer cents.
class EuerException implements Exception {
  const EuerException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'EuerException: $message';
}

class EuerService {
  EuerService(this.executor, {this.defaultCutoverDatum});

  final QueryExecutor executor;
  final DateTime? defaultCutoverDatum;

  Future<EuerResult> generate({required int jahr, DateTime? cutoverDatum}) async {
    final String jahrStr = jahr.toString().padLeft(4, '0');

    // 60+ Zeilen — init 12..107 with '0.00' (96 entries).
    final Map<int, String> zeilen = <int, String>{for (int i = 12; i <= 107; i++) i: '0.00'};
    final Map<int, String> hinweise = <int, String>{106: '0.00', 107: '0.00'};

    // Journal JOIN kategorien — GROUP BY euer_zeile via Dart cents add.
    // beleg_typ is deliberately selected so Gewinn never infers direction
    // from arbitrary EÜR line-number ranges.
    final List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT k.euer_zeile as zeile, j.betrag as betrag, j.beleg_typ as art '
        'FROM journal j JOIN kategorien k ON j.kategorie_id = k.id '
        "WHERE k.euer_zeile IS NOT NULL AND strftime('%Y', j.datum) = ?",
        <Object?>[jahrStr],
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EuerException('Buchungen konnten für EÜR nicht gelesen werden', error), stackTrace);
    }
    var einnahmen = 0;
    var ausgaben = 0;
    for (final Map<String, Object?> r in rows) {
      final int? zeile = (r['zeile'] as num?)?.toInt();
      if (zeile == null) {
        continue;
      }
      if (zeile == 33) {
        continue; // AfA overridden via anlageverzeichnis.
      }
      if (zeile < 12 || zeile > 107) {
        continue;
      }
      final String raw = r['betrag']?.toString() ?? '0.00';
      final String formatted = money.formatBetrag(raw);
      final String current = zeilen[zeile] ?? '0.00';
      zeilen[zeile] = money.add(current, formatted);

      if (zeile != 106 && zeile != 107) {
        final String art = r['art']?.toString().trim().toLowerCase() ?? '';
        final int cents = money.toCents(formatted);
        if (art == 'einnahme') {
          einnahmen += cents;
        } else if (art == 'ausgabe') {
          ausgaben += cents;
        }
      }
    }

    // Zeile 33 — AfA from anlageverzeichnis, not journal.
    try {
      final Set<String> anlageColumns = await _tableColumns('anlageverzeichnis');
      final List<String> selectedColumns = <String>[
        'anschaffungskosten',
        'nutzungsdauer',
        'privatanteil',
        'status',
        'anschaffungsdatum',
        for (final String optional in <String>['verkauft_am', 'verkaufsdatum', 'abgangsdatum'])
          if (anlageColumns.contains(optional)) optional,
      ];
      final List<Map<String, Object?>> afaRows = await executor.runSelect(
        'SELECT ${selectedColumns.join(', ')} FROM anlageverzeichnis',
        const <Object?>[],
      );
      int afaCents = 0;
      for (final Map<String, Object?> r in afaRows) {
        final String status = (r['status']?.toString() ?? 'aktiv').trim().toLowerCase();
        // ponytail: only 'aktiv' counts — 'inaktiv'/'verkauft' skipped, null treated as aktiv.
        if (status == 'inaktiv' || status == 'verkauft' || status == 'disposed') {
          continue;
        }
        final DateTime? acquisitionDate = _parseDate(r['anschaffungsdatum']);
        if (acquisitionDate != null && acquisitionDate.year > jahr) {
          continue;
        }
        final DateTime? disposalDate = _firstDate(r, <String>['verkauft_am', 'verkaufsdatum', 'abgangsdatum']);
        if (disposalDate != null && disposalDate.year < jahr) {
          continue;
        }
        final String kostenRaw = r['anschaffungskosten']?.toString() ?? '0.00';
        final int kostenCents = money.toCents(money.formatBetrag(kostenRaw));
        final int nutzungsdauer = (r['nutzungsdauer'] as num?)?.toInt() ?? 0;
        if (nutzungsdauer <= 0) {
          continue;
        }
        // Linear AfA uses half-up cents, then the annual amount is prorated
        // for the active months when acquisition/disposal occurred this year.
        final int baseCents = _roundHalfUp(kostenCents, nutzungsdauer);
        final String privatRaw = r['privatanteil']?.toString() ?? '0';
        // privatanteil: private-use share 0–100% as decimal string; e.g. '30.00' → 3000.
        final int privatCents = money.toCents(money.formatBetrag(privatRaw));
        // factor scales AfA by business share: (10000 - privatCents) / 10000.
        final int factor = 10000 - privatCents;
        final int clampedFactor = factor < 0 ? 0 : (factor > 10000 ? 10000 : factor);
        final int reduced = _roundHalfUp(baseCents * clampedFactor, 10000);
        final int activeMonths = _activeMonths(
          jahr: jahr,
          acquisitionDate: acquisitionDate,
          disposalDate: disposalDate,
        );
        afaCents += _roundHalfUp(reduced * activeMonths, 12);
      }
      zeilen[33] = money.fromCents(afaCents);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        EuerException('Anlageverzeichnis konnte für AfA nicht gelesen werden', error),
        stackTrace,
      );
    }

    // Hinweis 106/107 — separate map but already summed in zeilen.
    hinweise[106] = zeilen[106] ?? '0.00';
    hinweise[107] = zeilen[107] ?? '0.00';

    // Vorsteuer Soll-Prinzip ab CUTOVER_DATUM.
    final DateTime? effectiveCutover = cutoverDatum ?? defaultCutoverDatum ?? await _configuredCutoverDatum();
    final bool useSoll = _useSoll(jahr, effectiveCutover);
    String vorsteuer = '0.00';
    if (useSoll) {
      try {
        final List<Map<String, Object?>> vRows = await executor.runSelect(
          "SELECT betrag FROM vorsteuer_ansprueche WHERE faelligkeit IS NOT NULL AND strftime('%Y', faelligkeit) = ?",
          <Object?>[jahrStr],
        );
        int sum = 0;
        for (final Map<String, Object?> r in vRows) {
          final String raw = r['betrag']?.toString() ?? '0.00';
          sum += money.toCents(money.formatBetrag(raw));
        }
        // Fallback: if faelligkeit filter yielded 0 but table has rows
        // without date (edge), sum all where substr matches.
        if (sum == 0 && vRows.isEmpty) {
          final List<Map<String, Object?>> allRows = await executor.runSelect(
            'SELECT betrag, faelligkeit FROM vorsteuer_ansprueche',
            const <Object?>[],
          );
          for (final Map<String, Object?> r in allRows) {
            final String? faell = r['faelligkeit'] as String?;
            if (faell != null && faell.startsWith(jahrStr)) {
              final String raw = r['betrag']?.toString() ?? '0.00';
              sum += money.toCents(money.formatBetrag(raw));
            } else if (faell == null) {
              // ponytail: undated anspruch — ignore for year-specific Soll, keeps 0.
            }
          }
        }
        vorsteuer = money.fromCents(sum);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          EuerException('Vorsteueransprüche konnten für EÜR nicht gelesen werden', error),
          stackTrace,
        );
      }
    } else {
      // Zahlungsprinzip: journal.vorsteuer_betrag if column exists.
      try {
        final List<Map<String, Object?>> cols = await executor.runSelect(
          'PRAGMA table_info(journal)',
          const <Object?>[],
        );
        final bool hasVorsteuer = cols.any((Map<String, Object?> c) => c['name'] == 'vorsteuer_betrag');
        if (hasVorsteuer) {
          final List<Map<String, Object?>> vRows = await executor.runSelect(
            'SELECT vorsteuer_betrag as b FROM journal '
            "WHERE vorsteuer_betrag IS NOT NULL AND strftime('%Y', datum) = ?",
            <Object?>[jahrStr],
          );
          int sum = 0;
          for (final Map<String, Object?> r in vRows) {
            final String raw = r['b']?.toString() ?? '0.00';
            sum += money.toCents(money.formatBetrag(raw));
          }
          vorsteuer = money.fromCents(sum);
        } else {
          vorsteuer = '0.00';
        }
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          EuerException('Vorsteuerbuchungen konnten für EÜR nicht gelesen werden', error),
          stackTrace,
        );
      }
    }

    // Gewinn/Verlust follows booking direction; Hinweise 106/107 were
    // excluded while rows were classified above.
    final int gewinnCents = einnahmen - ausgaben;
    final String gewinn = money.fromCents(gewinnCents);

    return EuerResult(jahr: jahr, zeilen: zeilen, hinweise: hinweise, vorsteuerBetrag: vorsteuer, gewinn: gewinn);
  }

  Future<Set<String>> _tableColumns(String table) async {
    final List<Map<String, Object?>> rows = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    return <String>{
      for (final Map<String, Object?> row in rows)
        if (row['name'] is String) row['name']! as String,
    };
  }

  Future<DateTime?> _configuredCutoverDatum() async {
    try {
      final Set<String> columns = await _tableColumns('unternehmen');
      const List<String> candidates = <String>['euer_cutover_datum', 'cutover_datum', 'euer_soll_ab'];
      final String? column = candidates.cast<String?>().firstWhere(
        (String? candidate) => candidate != null && columns.contains(candidate),
        orElse: () => null,
      );
      if (column == null) {
        return null;
      }
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT $column FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      return rows.isEmpty ? null : _parseDate(rows.single[column]);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EuerException('EÜR-Stichtag konnte nicht gelesen werden', error), stackTrace);
    }
  }
}

DateTime? _parseDate(Object? raw) {
  final String text = raw?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
}

DateTime? _firstDate(Map<String, Object?> row, List<String> keys) {
  for (final String key in keys) {
    final DateTime? date = _parseDate(row[key]);
    if (date != null) {
      return date;
    }
  }
  return null;
}

int _activeMonths({required int jahr, DateTime? acquisitionDate, DateTime? disposalDate}) {
  final int start = acquisitionDate?.year == jahr ? acquisitionDate!.month : 1;
  final int end = disposalDate?.year == jahr ? disposalDate!.month : 12;
  return end < start ? 0 : end - start + 1;
}

int _roundHalfUp(int numerator, int denominator) {
  if (denominator <= 0) {
    throw ArgumentError('denominator must be positive');
  }
  if (numerator < 0) {
    return -_roundHalfUp(-numerator, denominator);
  }
  return (numerator + denominator ~/ 2) ~/ denominator;
}

bool _useSoll(int jahr, DateTime? cutoverDatum) {
  if (cutoverDatum == null) {
    return false;
  }
  final DateTime periodStart = DateTime(jahr);
  final DateTime cut = DateTime(cutoverDatum.year, cutoverDatum.month, cutoverDatum.day);
  return !periodStart.isBefore(cut);
}
