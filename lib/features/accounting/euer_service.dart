import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/eur_settlement_reader.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/assets/asset_entity.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';

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
  /// of silently excluding rows. AfA line 33 consumes only complete canonical
  /// asset schedule inputs; legacy values are preserved but never guessed.
  Future<EuerResult> generate({required int jahr, DateTime? cutoverDatum}) async {
    final String jahrStr = jahr.toString().padLeft(4, '0');

    // 60+ Zeilen — init 12..107 with '0.00' (96 entries).
    final Map<int, String> zeilen = <int, String>{for (int i = 12; i <= 107; i++) i: '0.00'};
    final Map<int, String> hinweise = <int, String>{106: '0.00', 107: '0.00'};

    // Cash-basis settlement recognition: when settlement groups attribute
    // amounts to this year, ordinary income/expenses come from settled
    // allocations by settlement date — never from invoice-issue journal
    // dates. Legacy `legacy_unverified` rows fail closed when mixed with
    // settlement data in an in-scope period.
    final EurSettlementTotals? settlementTotals = await _settlementTotalsOrNull(jahr);
    var einnahmen = 0;
    var ausgaben = 0;
    final List<int> blockedJournals = <int>[];
    final List<int> blockedCategories = <int>[];
    final List<_ResolvedMapping> resolved = <_ResolvedMapping>[];
    if (settlementTotals != null) {
      final List<int> legacyIds = await EurSettlementReader.legacyUnverifiedIds(executor, jahr);
      if (legacyIds.isNotEmpty) {
        throw EuerException(
          'EÜR blockiert: ${legacyIds.length} Buchungen ohne geprüfte Doppik '
          '(Journal-IDs: ${legacyIds.join(', ')}) — Abrechnung erst nach Klärung der Altbuchungen möglich',
          null,
          legacyIds,
        );
      }
      for (final MapEntry<int, int> entry in settlementTotals.centsByZeile.entries) {
        zeilen[entry.key] = money.fromCents(entry.value);
      }
      einnahmen = settlementTotals.einnahmenCents;
      ausgaben = settlementTotals.ausgabenCents;
    } else {
      // LEFT JOIN: unresolved mappings must fail closed, never vanish.
      // beleg_typ is deliberately selected so Gewinn never infers direction
      // from arbitrary EÜR line-number ranges.
      // Boundary rows (source_kind set) carry their own settlement-based
      // recognition and stay excluded from legacy invoice-date totals, so an
      // unpaid invoice never counts as received cash here.
      final bool excludeBoundaryRows = await _journalHasSourceColumn();
      final String sourceFilter = excludeBoundaryRows ? ' AND j.source_kind IS NULL' : '';
      final List<Map<String, Object?>> rows;
      try {
        rows = await executor.runSelect(
          'SELECT j.id AS journal_id, j.kategorie_id AS kategorie_id, k.euer_zeile as zeile, '
          'j.betrag as betrag, j.beleg_typ as art, k.mapping_status AS mapping_status, '
          'k.catalog_source_reference AS quelle, k.catalog_source_version AS version '
          'FROM journal j LEFT JOIN kategorien k ON j.kategorie_id = k.id '
          "WHERE strftime('%Y', j.datum) = ?$sourceFilter",
          <Object?>[jahrStr],
        );
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(EuerException('Buchungen konnten für EÜR nicht gelesen werden', error), stackTrace);
      }
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
    } // settlementTotals == null → legacy invoice-date totals above.

    // Zeile 33 — AfA from the asset-register schedule owner, not journal.
    // The canonical schedule is the sole AfA source. Legacy rows fail closed
    // until their inputs are explicitly mapped to the maintained contract.
    int afaCents = 0;
    final List<Map<String, Object?>> afaAssetRefs = <Map<String, Object?>>[];
    try {
      final Set<String> anlageColumns = await _tableColumns('anlageverzeichnis');
      final bool hasCanonical = anlageColumns.contains('kaufpreis_netto');
      final List<String> selectedColumns = <String>[
        'id',
        'bezeichnung',
        'anschaffungskosten',
        'nutzungsdauer',
        'privatanteil',
        'status',
        'anschaffungsdatum',
        for (final String optional in <String>['verkauft_am', 'verkaufsdatum', 'abgangsdatum'])
          if (anlageColumns.contains(optional)) optional,
        if (hasCanonical)
          for (final String canonical in <String>[
            'asset_typ',
            'kaufpreis_netto',
            'nutzungsdauer_jahre',
            'afa_methode',
            'privat_anteil_prozent',
            'kategorie_id',
          ])
            if (anlageColumns.contains(canonical)) canonical,
      ];
      final List<Map<String, Object?>> afaRows = await executor.runSelect(
        'SELECT ${selectedColumns.join(', ')} FROM anlageverzeichnis',
        const <Object?>[],
      );
      const AssetScheduleService scheduleOwner = AssetScheduleService();
      for (final Map<String, Object?> r in afaRows) {
        final String status = (r['status']?.toString() ?? 'aktiv').trim().toLowerCase();
        // ponytail: only 'aktiv' counts — 'inaktiv'/'verkauft' skipped, null treated as aktiv.
        if (status == 'inaktiv' || status == 'verkauft' || status == 'disposed' || status == 'archiviert') {
          continue;
        }
        final FixedAsset asset = _toFixedAsset(r);
        if (!asset.hasCanonicalInputs) {
          throw EuerException(
            'EÜR unvollständig: Anlage ${asset.id} hat unaufgelöste AfA-Eingaben '
            '(kaufpreis_netto/nutzungsdauer_jahre/afa_methode ohne bestätigte Zuordnung)',
          );
        }
        final AssetScheduleRow row = scheduleOwner.computeRow(asset: asset, jahr: jahr);
        if (row.isAvailable) {
          afaCents += money.toCents(row.betrag!);
          afaAssetRefs.add(<String, Object?>{
            'anlage_id': asset.id,
            'jahr': jahr,
            'formel': row.formel,
            'betrag': row.betrag,
          });
          continue;
        }
        final String reason = row.blockierungsgrund ?? '';
        if (reason.startsWith('vor-anschaffung') || reason.startsWith('nutzungsdauer-ueberschritten')) {
          continue;
        }
        throw EuerException('EÜR unvollständig: Anlage ${asset.id} ($reason)');
      }
      zeilen[33] = money.fromCents(afaCents);
    } catch (error, stackTrace) {
      if (error is EuerException) rethrow;
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
    // Statutory timing trace: approved year-boundary rules attributing
    // settlements to this year stay visible on the report.
    final List<Map<String, Object?>> statutoryRules = await EurSettlementReader.timingRulesForYear(executor, jahr);
    final Map<String, Object?> snapshot = <String, Object?>{
      'version': 1,
      'jahr': jahr,
      'afa_assets': afaAssetRefs,
      'settlement_basis': settlementTotals != null,
      'statutory_rules': statutoryRules,
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

  /// Settlement totals when settlement groups attribute amounts to [jahr];
  /// null keeps the legacy invoice-date path (no settlement data yet).
  Future<EurSettlementTotals?> _settlementTotalsOrNull(int jahr) async {
    if (!await EurSettlementReader.hasSettlementData(executor, jahr)) {
      return null;
    }
    return EurSettlementReader.totalsForYear(executor, jahr);
  }

  Future<bool> _journalHasSourceColumn() async {
    try {
      final List<Map<String, Object?>> columns = await executor.runSelect(
        'PRAGMA table_info(journal)',
        const <Object?>[],
      );
      return columns.any((Map<String, Object?> column) => column['name'] == 'source_kind');
    } catch (_) {
      return false;
    }
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

bool _useSoll(int jahr, DateTime? cutoverDatum) {
  if (cutoverDatum == null) {
    return false;
  }
  final DateTime periodStart = DateTime(jahr);
  final DateTime cut = DateTime(cutoverDatum.year, cutoverDatum.month, cutoverDatum.day);
  return !periodStart.isBefore(cut);
}

int? _asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _asTextOrNull(Object? value) {
  if (value == null) return null;
  final String text = value.toString();
  return text.isEmpty ? null : text;
}

/// Maps a canonical asset row to its typed contract inputs for the owner.
FixedAsset _toFixedAsset(Map<String, Object?> row) {
  return FixedAsset(
    id: (row['id'] as num?)?.toInt() ?? 0,
    bezeichnung: row['bezeichnung']?.toString() ?? '',
    assetTyp: AssetTyp.fromDb(row['asset_typ']),
    anschaffungsdatum: row['anschaffungsdatum']?.toString() ?? '',
    kaufpreisNetto: _asTextOrNull(row['kaufpreis_netto']),
    nutzungsdauerJahre: _asIntOrNull(row['nutzungsdauer_jahre']),
    afaMethode: _asTextOrNull(row['afa_methode']),
    privatAnteilProzent: _asTextOrNull(row['privat_anteil_prozent']),
    kategorieId: _asIntOrNull(row['kategorie_id']),
    verkauftAm: _asTextOrNull(row['verkauft_am']),
    status: row['status']?.toString() ?? 'aktiv',
    legacyAnschaffungskosten: _asTextOrNull(row['anschaffungskosten']),
    legacyNutzungsdauer: _asIntOrNull(row['nutzungsdauer']),
    legacyPrivatanteil: _asTextOrNull(row['privatanteil']),
  );
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
