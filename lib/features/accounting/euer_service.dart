import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// EÜR Anlage 2025 — 60+ Zeilen 12–107 per spec.
/// Journal direction is read from beleg_typ and kept separate from the
/// category's presentation line. All amounts are aggregated as integer cents.
class EuerException implements Exception {
  const EuerException(
    this.message, [
    this.cause,
    this.affectedJournalIds = const <int>[],
    this.affectedCategoryIds = const <int>[],
  ]);

  final String message;
  final Object? cause;

  /// Journal entries that blocked generation (unresolved mapping input).
  final List<int> affectedJournalIds;

  /// Categories that blocked generation (unresolved mapping input).
  final List<int> affectedCategoryIds;

  @override
  String toString() => 'EuerException: $message';
}

class EuerService {
  EuerService(this.executor, {this.defaultCutoverDatum});

  final QueryExecutor executor;
  final DateTime? defaultCutoverDatum;

  /// Generates the EÜR for [jahr]. Before grouping, every in-scope journal row
  /// is left-joined to its category and its mapping provenance validated:
  /// only `catalog_verified` and explicitly `user_confirmed` mappings may
  /// contribute. A missing category, missing report line, or ineligible
  /// provenance blocks output with the affected journal/category IDs instead
  /// of silently excluding rows. AfA line 33 stays computed from
  /// anlageverzeichnis (journal rows pointing at it are skipped, not failed).
  Future<EuerResult> generate({required int jahr, DateTime? cutoverDatum}) async {
    final String jahrStr = jahr.toString().padLeft(4, '0');

    // 60+ Zeilen — init 12..107 with '0.00' (96 entries).
    final Map<int, String> zeilen = <int, String>{for (int i = 12; i <= 107; i++) i: '0.00'};
    final Map<int, String> hinweise = <int, String>{106: '0.00', 107: '0.00'};

    // LEFT JOIN: unresolved mappings must fail closed, never vanish.
    // beleg_typ is deliberately selected so Gewinn never infers direction
    // from arbitrary EÜR line-number ranges.
    final List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT j.id AS journal_id, j.kategorie_id AS kategorie_id, k.euer_zeile as zeile, '
        'j.betrag as betrag, j.beleg_typ as art, k.mapping_status AS mapping_status, '
        'k.catalog_source_reference AS quelle, k.catalog_source_version AS version '
        'FROM journal j LEFT JOIN kategorien k ON j.kategorie_id = k.id '
        "WHERE strftime('%Y', j.datum) = ?",
        <Object?>[jahrStr],
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EuerException('Buchungen konnten für EÜR nicht gelesen werden', error), stackTrace);
    }
    var einnahmen = 0;
    var ausgaben = 0;
    final List<int> blockedJournals = <int>[];
    final List<int> blockedCategories = <int>[];
    final List<_ResolvedMapping> resolved = <_ResolvedMapping>[];
    for (final Map<String, Object?> r in rows) {
      // Explicit beleg_typ predicate — not string contains. Cash categories
      // Zahlung/Ueberzahlung/Ausbuchung/Eroeffnung never count as revenue.
      // ponytail: whitelist Einnahme/Ausgabe only, explicit exclusion list in BelegTyp.nonRevenue.
      // Non-revenue rows are outside the accepted posting rules and stay skipped.
      final String art = r['art']?.toString().trim().toLowerCase() ?? '';
      final bool isRevenue = art == BelegTyp.einnahme.toLowerCase();
      final bool isExpense = art == BelegTyp.ausgabe.toLowerCase();
      if (!isRevenue && !isExpense) {
        continue;
      }
      final int journalId = (r['journal_id'] as num?)?.toInt() ?? 0;
      final int? kategorieId = (r['kategorie_id'] as num?)?.toInt();
      final String? status = r['mapping_status']?.toString();
      final int? zeile = (r['zeile'] as num?)?.toInt();
      final bool eligible = status == 'catalog_verified' || status == 'user_confirmed';
      if (kategorieId == null || status == null || !eligible || zeile == null || zeile < 12 || zeile > 107) {
        blockedJournals.add(journalId);
        if (kategorieId != null && !blockedCategories.contains(kategorieId)) {
          blockedCategories.add(kategorieId);
        }
        continue;
      }
      if (zeile == 33) {
        continue; // AfA overridden via anlageverzeichnis.
      }
      resolved.add(
        _ResolvedMapping(
          journalId: journalId,
          kategorieId: kategorieId,
          zeile: zeile,
          status: status,
          quelle: r['quelle']?.toString(),
          version: r['version']?.toString(),
        ),
      );
      final String raw = r['betrag']?.toString() ?? '0.00';
      final String formatted = money.formatBetrag(raw);
      final String current = zeilen[zeile] ?? '0.00';
      zeilen[zeile] = money.add(current, formatted);

      if (zeile != 106 && zeile != 107) {
        final int cents = money.toCents(formatted);
        if (isRevenue) {
          einnahmen += cents;
        } else if (isExpense) {
          ausgaben += cents;
        }
      }
    }
    if (blockedJournals.isNotEmpty) {
      throw EuerException(
        'EÜR blockiert: ${blockedJournals.length} Buchungen mit ungeklärtem Kategorie-Mapping '
        '(Journal-IDs: ${blockedJournals.join(', ')}; Kategorie-IDs: ${blockedCategories.join(', ')})',
        null,
        blockedJournals,
        blockedCategories,
      );
    }

    // Zeile 33 — AfA from anlageverzeichnis, not journal.
    int afaCents = 0;
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
    // excluded while rows were classified above. AfA row33 is expense
    // not in journal einnahmen/ausgaben — subtract explicitly.
    final int gewinnCents = einnahmen - ausgaben - afaCents;
    final String gewinn = money.fromCents(gewinnCents);

    // Provenance metadata: user-confirmed ids, catalog sources, and the
    // version-1 snapshot binding every emitted value to its mapping.
    final List<int> userConfirmed = <int>[];
    final Map<String, String> sources = <String, String>{};
    for (final _ResolvedMapping m in resolved) {
      if (m.status == 'user_confirmed' && !userConfirmed.contains(m.kategorieId)) {
        userConfirmed.add(m.kategorieId);
      }
      if (m.status == 'catalog_verified' && m.quelle != null && m.version != null) {
        sources[m.quelle!] = m.version!;
      }
    }
    final Map<int, int> historyIds = await _latestHistoryIds(resolved.map((m) => m.kategorieId).toSet());
    final Map<String, Object?> snapshot = <String, Object?>{
      'version': 1,
      'jahr': jahr,
      'resolved': <Object?>[
        for (final _ResolvedMapping m in resolved)
          <String, Object?>{
            'journal_id': m.journalId,
            'category_id': m.kategorieId,
            'euer_zeile': m.zeile,
            'mapping_status': m.status,
            if (m.quelle != null) 'source_reference': m.quelle,
            if (m.version != null) 'source_version': m.version,
            if (historyIds[m.kategorieId] != null) 'category_history_id': historyIds[m.kategorieId],
          },
      ],
      'user_confirmed_category_ids': userConfirmed,
      'catalog_sources': sources,
    };

    return EuerResult(
      jahr: jahr,
      zeilen: zeilen,
      hinweise: hinweise,
      vorsteuerBetrag: vorsteuer,
      gewinn: gewinn,
      userConfirmedCategoryIds: userConfirmed,
      catalogSources: sources,
      provenanceSnapshot: snapshot,
    );
  }

  /// Persists a generated result to `euer_exporte` with its version-1 mapping
  /// provenance snapshot. Returns the export row id.
  Future<int> persistExport({required int jahr, required EuerResult result, int? unternehmenId}) async {
    await _ensureProvenanceColumn();
    final int? companyId = unternehmenId ?? await _singleUnternehmenId();
    return executor.runInsert(
      'INSERT INTO euer_exporte (jahr, summen, status, unternehmen_id, mapping_provenance_json) VALUES (?, ?, ?, ?, ?)',
      <Object?>[jahr, _summenJson(result), 'erstellt', companyId, _snapshotJson(result)],
    );
  }

  Future<Map<int, int>> _latestHistoryIds(Set<int> categoryIds) async {
    if (categoryIds.isEmpty) return <int, int>{};
    try {
      final placeholders = List.filled(categoryIds.length, '?').join(', ');
      final rows = await executor.runSelect(
        'SELECT kategorie_id, MAX(id) AS hid FROM category_mapping_history '
        'WHERE kategorie_id IN ($placeholders) GROUP BY kategorie_id',
        <Object?>[...categoryIds],
      );
      return <int, int>{for (final r in rows) (r['kategorie_id']! as num).toInt(): (r['hid']! as num).toInt()};
    } catch (_) {
      return <int, int>{};
    }
  }

  Future<void> _ensureProvenanceColumn() async {
    final cols = await executor.runSelect('PRAGMA table_info(euer_exporte)', const <Object?>[]);
    if (!cols.any((c) => c['name'] == 'mapping_provenance_json')) {
      await executor.runCustom('ALTER TABLE euer_exporte ADD COLUMN mapping_provenance_json TEXT');
    }
  }

  Future<int?> _singleUnternehmenId() async {
    try {
      final rows = await executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const <Object?>[]);
      if (rows.isEmpty) return null;
      return (rows.single['id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static String _summenJson(EuerResult result) {
    final entries = <String, String>{};
    for (final e in result.zeilen.entries) {
      if (e.value != '0.00') entries[e.key.toString()] = e.value;
    }
    entries['gewinn'] = result.gewinn;
    entries['vorsteuer'] = result.vorsteuerBetrag;
    return jsonEncode(entries);
  }

  static String _snapshotJson(EuerResult result) => jsonEncode(result.provenanceSnapshot);

  /// Fiscal-year EÜR request for [fiscalYearLabel] with company [startMonth].
  /// The calendar-only calculation cannot serve alternate fiscal years: any
  /// non-January start month fails closed with an unavailable result instead
  /// of relabeling a calendar-year computation. January delegates to the
  /// explicit calendar-year calculation unchanged.
  Future<EuerResult> generateForFiscalYear({
    required int fiscalYearLabel,
    required int startMonth,
    DateTime? cutoverDatum,
  }) async {
    if (startMonth < 1 || startMonth > 12) {
      throw EuerException('EÜR Wirtschaftsjahr $fiscalYearLabel unverfügbar: ungültiger Startmonat');
    }
    if (startMonth != 1) {
      throw EuerException('EÜR Wirtschaftsjahr $fiscalYearLabel unverfügbar: nur Kalenderjahre werden unterstützt');
    }
    return generate(jahr: fiscalYearLabel, cutoverDatum: cutoverDatum);
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

/// One journal row resolved to an eligible category mapping for EÜR output.
class _ResolvedMapping {
  const _ResolvedMapping({
    required this.journalId,
    required this.kategorieId,
    required this.zeile,
    required this.status,
    this.quelle,
    this.version,
  });
  final int journalId;
  final int kategorieId;
  final int zeile;
  final String status;
  final String? quelle;
  final String? version;
}
