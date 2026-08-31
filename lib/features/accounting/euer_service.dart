import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/euer_entity.dart';

/// EÜR Anlage 2025 — 60+ Zeilen 12–107 per spec.
/// ponytail: pure string-cent helpers, no double, map-init covers 60+ Zeilen without 60 repetitive branches.
/// ponytail: global executor lock ceiling — per-call if throughput matters.
class EuerService {
  EuerService(this.executor);

  final QueryExecutor executor;

  Future<EuerResult> generate({required int jahr, DateTime? cutoverDatum}) async {
    final String jahrStr = jahr.toString().padLeft(4, '0');

    // 60+ Zeilen — init 12..107 with '0.00' (96 entries).
    final Map<int, String> zeilen = <int, String>{for (int i = 12; i <= 107; i++) i: '0.00'};
    final Map<int, String> hinweise = <int, String>{106: '0.00', 107: '0.00'};

    // Journal JOIN kategorien — GROUP BY euer_zeile via Dart cents add.
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT k.euer_zeile as zeile, j.betrag as betrag '
      'FROM journal j JOIN kategorien k ON j.kategorie_id = k.id '
      "WHERE k.euer_zeile IS NOT NULL AND strftime('%Y', j.datum) = ?",
      <Object?>[jahrStr],
    );
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
      final String formatted = _formatBetrag(raw);
      final String current = zeilen[zeile] ?? '0.00';
      zeilen[zeile] = _add(current, formatted);
    }

    // Zeile 33 — AfA from anlageverzeichnis, not journal.
    try {
      final List<Map<String, Object?>> afaRows = await executor.runSelect(
        'SELECT anschaffungskosten, nutzungsdauer, privatanteil, status, anschaffungsdatum '
        'FROM anlageverzeichnis',
        const <Object?>[],
      );
      int afaCents = 0;
      for (final Map<String, Object?> r in afaRows) {
        final String? statusRaw = r['status'] as String?;
        final String status = (statusRaw ?? 'aktiv').toLowerCase();
        // ponytail: only 'aktiv' counts — 'inaktiv'/'verkauft' skipped, null treated as aktiv.
        if (status == 'inaktiv' || status == 'verkauft' || status == 'in_active') {
          continue;
        }
        // Optional date filter: skip assets acquired after jahr.
        final String? datumRaw = r['anschaffungsdatum'] as String?;
        if (datumRaw != null && datumRaw.length >= 4) {
          final int? anschaffJahr = int.tryParse(datumRaw.substring(0, 4));
          if (anschaffJahr != null && anschaffJahr > jahr) {
            continue;
          }
        }
        final String kostenRaw = r['anschaffungskosten']?.toString() ?? '0.00';
        final int kostenCents = _toCents(_formatBetrag(kostenRaw));
        final int nutzungsdauer = (r['nutzungsdauer'] as num?)?.toInt() ?? 0;
        if (nutzungsdauer <= 0) {
          continue;
        }
        // Linear AfA: kosten / nutzungsdauer, trunc.
        final int baseCents = kostenCents ~/ nutzungsdauer;
        final String privatRaw = r['privatanteil']?.toString() ?? '0';
        final int privatCents = _toCents(_formatBetrag(privatRaw));
        // privatCents is percent*100 (30.00 -> 3000). Factor (10000 - privat)/10000.
        final int factor = 10000 - privatCents;
        final int clampedFactor = factor < 0 ? 0 : (factor > 10000 ? 10000 : factor);
        final int reduced = (baseCents * clampedFactor) ~/ 10000;
        afaCents += reduced;
      }
      zeilen[33] = _fromCents(afaCents);
    } catch (_) {
      // ponytail: anlageverzeichnis missing — keep 0.00.
      zeilen[33] = zeilen[33] ?? '0.00';
    }

    // Hinweis 106/107 — separate map but already summed in zeilen.
    hinweise[106] = zeilen[106] ?? '0.00';
    hinweise[107] = zeilen[107] ?? '0.00';

    // Vorsteuer Soll-Prinzip ab CUTOVER_DATUM.
    final bool useSoll = _useSoll(jahr, cutoverDatum);
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
          sum += _toCents(_formatBetrag(raw));
        }
        // Fallback: if faelligkeit filter yielded 0 but table has rows without date (edge), sum all where substr matches.
        if (sum == 0 && vRows.isEmpty) {
          final List<Map<String, Object?>> allRows = await executor.runSelect(
            'SELECT betrag, faelligkeit FROM vorsteuer_ansprueche',
            const <Object?>[],
          );
          for (final Map<String, Object?> r in allRows) {
            final String? faell = r['faelligkeit'] as String?;
            if (faell != null && faell.startsWith(jahrStr)) {
              final String raw = r['betrag']?.toString() ?? '0.00';
              sum += _toCents(_formatBetrag(raw));
            } else if (faell == null) {
              // ponytail: undated anspruch — ignore for year-specific Soll, keeps 0.
            }
          }
        }
        vorsteuer = _fromCents(sum);
      } catch (_) {
        vorsteuer = '0.00';
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
            "SELECT vorsteuer_betrag as b FROM journal WHERE vorsteuer_betrag IS NOT NULL AND strftime('%Y', datum) = ?",
            <Object?>[jahrStr],
          );
          int sum = 0;
          for (final Map<String, Object?> r in vRows) {
            final String raw = r['b']?.toString() ?? '0.00';
            sum += _toCents(_formatBetrag(raw));
          }
          vorsteuer = _fromCents(sum);
        } else {
          vorsteuer = '0.00';
        }
      } catch (_) {
        vorsteuer = '0.00';
      }
    }

    // Gewinn/Verlust: Einnahmen (<25) minus Ausgaben (>=25), Hinweis 106/107 excluded.
    int einnahmen = 0;
    int ausgaben = 0;
    for (final MapEntry<int, String> e in zeilen.entries) {
      final int z = e.key;
      if (z == 106 || z == 107) {
        continue;
      }
      final int cents = _toCents(e.value);
      if (z < 25) {
        einnahmen += cents;
      } else {
        ausgaben += cents;
      }
    }
    final int gewinnCents = einnahmen - ausgaben;
    final String gewinn = _fromCents(gewinnCents);

    return EuerResult(jahr: jahr, zeilen: zeilen, hinweise: hinweise, vorsteuerBetrag: vorsteuer, gewinn: gewinn);
  }
}

bool _useSoll(int jahr, DateTime? cutoverDatum) {
  if (cutoverDatum == null) {
    return true;
  }
  final DateTime periodStart = DateTime(jahr);
  final DateTime cut = DateTime(cutoverDatum.year, cutoverDatum.month, cutoverDatum.day);
  return !periodStart.isBefore(cut);
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

String _add(String a, String b) {
  return _fromCents(_toCents(a) + _toCents(b));
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
