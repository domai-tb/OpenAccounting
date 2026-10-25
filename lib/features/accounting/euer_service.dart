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

    final _MileageEuerTotals mileage = await _mileageTotalsForYear(jahr);
    zeilen[71] = money.add(zeilen[71] ?? '0.00', money.fromCents(mileage.expenseCents));
    zeilen[107] = money.add(zeilen[107] ?? '0.00', money.fromCents(mileage.contributionCents));
    ausgaben += mileage.expenseCents;

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
      'mileage_sources': mileage.reportSnapshots,
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
  /// Mileage postings have no cash settlement date. Their once-only EÜR
  /// recognition is tied to trip_date in both report modes, using only the
  /// immutable v25 per-leg category snapshots.
  Future<_MileageEuerTotals> _mileageTotalsForYear(int jahr) async {
    final String start = '${jahr.toString().padLeft(4, '0')}-01-01';
    final String end = '${(jahr + 1).toString().padLeft(4, '0')}-01-01';
    final List<Map<String, Object?>> trips = await executor.runSelect(
      'SELECT id, trip_date, state, posting_event_id FROM mileage_trips WHERE trip_date >= ? AND trip_date < ? ORDER BY trip_date, id',
      <Object?>[start, end],
    );
    final List<Map<String, Object?>> journalSources = await executor.runSelect(
      'SELECT DISTINCT source_id FROM journal WHERE source_kind = ? AND datum >= ? AND datum < ? ORDER BY source_id',
      <Object?>['mileage_trip', start, end],
    );
    if (journalSources.any(
      (Map<String, Object?> row) => row['source_id'] == null || row['source_id'].toString().trim().isEmpty,
    )) {
      throw const EuerException('EÜR blockiert: Mileage-Journalquelle ohne Fahrten-UUID');
    }
    final List<Map<String, Object?>> appliedReplacements = await executor.runSelect(
      'SELECT replacement_trip_id FROM mileage_trip_corrections WHERE kind = ? AND state = ?',
      const <Object?>['replace', 'applied'],
    );
    final Set<String> replacementTripIds = <String>{
      for (final Map<String, Object?> row in appliedReplacements)
        if (row['replacement_trip_id'] != null) row['replacement_trip_id'].toString(),
    };
    final List<Map<String, Object?>> correctionSources = await executor.runSelect(
      'SELECT DISTINCT source_id FROM journal WHERE source_kind = ? AND datum >= ? AND datum < ? ORDER BY source_id',
      <Object?>['mileage_correction', start, end],
    );
    final List<Map<String, Object?>> appliedCorrections = await executor.runSelect(
      'SELECT id AS source_id, applied_at, applied_business_date FROM mileage_trip_corrections '
      'WHERE state = ? ORDER BY id',
      <Object?>['applied'],
    );
    if (correctionSources.any(
      (Map<String, Object?> row) => row['source_id'] == null || row['source_id'].toString().trim().isEmpty,
    )) {
      throw const EuerException('EÜR blockiert: Mileage-Korrekturquelle ohne UUID');
    }
    final Set<String> correctionIds = <String>{
      for (final Map<String, Object?> row in correctionSources) row['source_id'].toString(),
    };
    for (final Map<String, Object?> row in appliedCorrections) {
      final String correctionId = row['source_id']?.toString() ?? '';
      final DateTime? appliedAt = DateTime.tryParse(row['applied_at']?.toString() ?? '');
      final String? appliedBusinessDate = _validatedMileageCorrectionDate(row['applied_business_date'], correctionId);
      if (correctionId.trim().isEmpty) {
        throw const EuerException('EÜR blockiert: Mileage-Korrekturquelle ohne UUID');
      }
      if (appliedAt == null || !appliedAt.isUtc) {
        throw const EuerException('EÜR blockiert: Mileage-Korrekturquelle ohne gültigen UTC-Zeitpunkt');
      }
      final List<Map<String, Object?>> correctionJournalDates = await executor.runSelect(
        'SELECT datum FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_correction', correctionId],
      );
      if (correctionJournalDates.isEmpty && appliedBusinessDate == null) {
        throw EuerException('EÜR blockiert: Mileage-Korrektur $correctionId hat kein bekanntes Buchungsdatum');
      }
      if (appliedBusinessDate != null && int.parse(appliedBusinessDate.substring(0, 4)) == jahr) {
        correctionIds.add(correctionId);
      }
      for (final Map<String, Object?> journalDateRow in correctionJournalDates) {
        final String? journalDate = _validatedMileageCorrectionDate(journalDateRow['datum'], correctionId);
        if (journalDate == null) {
          throw EuerException('EÜR blockiert: Mileage-Korrektur $correctionId hat ein unbekanntes Buchungsdatum');
        }
        if (int.parse(journalDate.substring(0, 4)) == jahr) correctionIds.add(correctionId);
      }
    }
    final Set<String> sourceIds = <String>{
      for (final Map<String, Object?> trip in trips)
        if ((trip['state'] == 'posted' || trip['state'] == 'corrected' || trip['state'] == 'voided') &&
            !replacementTripIds.contains(trip['id'].toString()))
          trip['id'].toString(),
      for (final Map<String, Object?> source in journalSources) source['source_id'].toString(),
    };
    var expensesCents = 0;
    var contributionCents = 0;
    final List<Map<String, Object?>> reportSnapshots = <Map<String, Object?>>[];
    for (final String tripId in sourceIds) {
      final List<Map<String, Object?>> tripRows = await executor.runSelect(
        'SELECT id, trip_date, state, posting_event_id, calculated_amount FROM mileage_trips WHERE id = ? LIMIT 1',
        <Object?>[tripId],
      );
      if (tripRows.isEmpty) throw EuerException('EÜR blockiert: Mileage-Quelle $tripId hat keine Fahrt');
      final Map<String, Object?> trip = tripRows.single;
      final String tripDate = trip['trip_date']?.toString() ?? '';
      if ((trip['state'] != 'posted' && trip['state'] != 'corrected' && trip['state'] != 'voided') ||
          (trip['posting_event_id']?.toString().trim().isNotEmpty ?? false) == false) {
        throw EuerException('EÜR blockiert: Mileage-Quelle $tripId ist nicht atomar gebucht');
      }
      if (tripDate.compareTo(start) < 0 || tripDate.compareTo(end) >= 0) {
        throw EuerException('EÜR blockiert: Mileage-Journalquelle $tripId liegt außerhalb des Fahrtdatums');
      }
      if (trip['state'] == 'corrected' || trip['state'] == 'voided') {
        final String expectedKind = trip['state'] == 'corrected' ? 'replace' : 'void';
        final List<Map<String, Object?>> terminalCorrections = await executor.runSelect(
          'SELECT id FROM mileage_trip_corrections WHERE trip_id = ? AND kind = ? AND state = ? '
          'AND accounting_correction_id = id LIMIT 1',
          <Object?>[tripId, expectedKind, 'applied'],
        );
        if (terminalCorrections.length != 1) {
          throw EuerException('EÜR blockiert: Mileage-Quelle $tripId hat keine angewendete Korrektur');
        }
      }
      final List<Map<String, Object?>> legs = await executor.runSelect(
        'SELECT id, datum, kategorie_id, betrag, beleg_typ, konto_id, soll, haben, soll_konto_id, haben_konto_id, '
        'gruppe_id, legacy_unverified, immutable, source_kind, source_id, mileage_role_snapshot, '
        'mileage_kategorie_id_snapshot, mileage_kategorie_name_snapshot, mileage_kategorie_art_snapshot, '
        'mileage_euer_zeile_snapshot, mileage_kategorie_skr03_snapshot, mileage_kategorie_skr04_snapshot, '
        'mileage_mapping_status_snapshot, mileage_mapping_source_reference_snapshot, '
        'mileage_mapping_source_version_snapshot, mileage_mapping_history_id_snapshot '
        'FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>['mileage_trip', tripId],
      );
      if (legs.length != 2) {
        throw EuerException('EÜR blockiert: Mileage-Quelle $tripId hat keine vollständige Zweiergruppe');
      }
      final String eventId = trip['posting_event_id'].toString();
      final int rootId = ((legs.first['gruppe_id'] as num?) ?? 0).toInt();
      if (rootId <= 0) {
        throw EuerException('EÜR blockiert: Mileage-Quelle $tripId hat keinen vollständigen Snapshot');
      }
      final Map<String, Map<String, Object?>> byRole = <String, Map<String, Object?>>{};
      var debitCents = 0;
      var creditCents = 0;
      final int expectedTripCents = _mileageEurCents(trip['calculated_amount'], tripId);
      for (final Map<String, Object?> leg in legs) {
        final int id = (leg['id'] as num?)?.toInt() ?? 0;
        final int groupId = (leg['gruppe_id'] as num?)?.toInt() ?? 0;
        final String role = leg['mileage_role_snapshot']?.toString() ?? '';
        final int rowDebit = money.toCents(money.formatBetrag((leg['soll'] ?? 0).toString()));
        final int rowCredit = money.toCents(money.formatBetrag((leg['haben'] ?? 0).toString()));
        if (id <= 0 ||
            groupId != rootId ||
            (id == rootId) != (groupId == id) ||
            leg['datum'] != tripDate ||
            leg['beleg_typ'] != 'Ausgabe' ||
            leg['source_kind'] != 'mileage_trip' ||
            leg['source_id'] != tripId ||
            (leg['immutable'] as num?)?.toInt() != 1 ||
            (leg['legacy_unverified'] as num?)?.toInt() != 0 ||
            rowDebit < 0 ||
            rowCredit < 0 ||
            (rowDebit == 0) == (rowCredit == 0) ||
            byRole.containsKey(role) ||
            (role != 'travel_expense' && role != 'private_contribution') ||
            !_mileageSnapshotIsComplete(leg)) {
          throw EuerException(
            'EÜR blockiert: Mileage-Quelle $tripId enthält einen fehlerhaften oder veränderlichen Snapshot',
          );
        }
        byRole[role] = leg;
        debitCents += rowDebit;
        creditCents += rowCredit;
      }
      final Map<String, Object?>? expense = byRole['travel_expense'];
      final Map<String, Object?>? contribution = byRole['private_contribution'];
      if (expense == null ||
          contribution == null ||
          (expense['id'] as num?)?.toInt() != rootId ||
          debitCents != expectedTripCents ||
          creditCents != expectedTripCents ||
          money.toCents(money.formatBetrag((expense['soll'] ?? 0).toString())) != expectedTripCents ||
          money.toCents(money.formatBetrag((expense['haben'] ?? 0).toString())) != 0 ||
          money.toCents(money.formatBetrag((contribution['soll'] ?? 0).toString())) != 0 ||
          money.toCents(money.formatBetrag((contribution['haben'] ?? 0).toString())) != expectedTripCents ||
          (expense['soll_konto_id'] as num?)?.toInt() != (expense['konto_id'] as num?)?.toInt() ||
          expense['haben_konto_id'] != null ||
          (contribution['haben_konto_id'] as num?)?.toInt() != (contribution['konto_id'] as num?)?.toInt() ||
          contribution['soll_konto_id'] != null ||
          (expense['mileage_euer_zeile_snapshot'] as num?)?.toInt() != 71 ||
          (contribution['mileage_euer_zeile_snapshot'] as num?)?.toInt() != 107 ||
          money.toCents(money.formatBetrag((expense['betrag'] ?? 0).toString())) != expectedTripCents ||
          money.toCents(money.formatBetrag((contribution['betrag'] ?? 0).toString())) != -expectedTripCents) {
        throw EuerException('EÜR blockiert: Mileage-Quelle $tripId ist unvollständig oder unausgeglichen');
      }
      final List<Map<String, Object?>> settlements = await executor.runSelect(
        'SELECT id FROM settlement_groups WHERE source_kind = ? AND source_id = ? LIMIT 1',
        <Object?>['mileage_trip', tripId],
      );
      if (settlements.isNotEmpty) {
        throw EuerException('EÜR blockiert: Mileage-Quelle $tripId wurde zusätzlich als Zahlung erfasst');
      }
      expensesCents += expectedTripCents;
      contributionCents += expectedTripCents;
      final List<Map<String, Object?>> legSnapshots = <Map<String, Object?>>[
        for (final Map<String, Object?> leg in <Map<String, Object?>>[expense, contribution])
          <String, Object?>{
            'journal_id': leg['id'],
            'role': leg['mileage_role_snapshot'],
            'category_id': leg['mileage_kategorie_id_snapshot'],
            'category_label': leg['mileage_kategorie_name_snapshot'],
            'category_art': leg['mileage_kategorie_art_snapshot'],
            'euer_line': leg['mileage_euer_zeile_snapshot'],
            'konto_skr03': leg['mileage_kategorie_skr03_snapshot'],
            'konto_skr04': leg['mileage_kategorie_skr04_snapshot'],
            'mapping_status': leg['mileage_mapping_status_snapshot'],
            'mapping_source_reference': leg['mileage_mapping_source_reference_snapshot'],
            'mapping_source_version': leg['mileage_mapping_source_version_snapshot'],
            'mapping_history_id': leg['mileage_mapping_history_id_snapshot'],
          },
      ];
      reportSnapshots.add(<String, Object?>{
        'trip_id': tripId,
        'trip_date': tripDate,
        'event_id': eventId,
        'amount_cents': expectedTripCents,
        'legs': legSnapshots,
      });
    }
    for (final String correctionId in correctionIds) {
      final _MileageEuerTotals correctionTotals = await _mileageCorrectionTotalsForEvent(correctionId, start, end);
      expensesCents += correctionTotals.expenseCents;
      contributionCents += correctionTotals.contributionCents;
      reportSnapshots.addAll(correctionTotals.reportSnapshots);
    }
    return _MileageEuerTotals(
      expenseCents: expensesCents,
      contributionCents: contributionCents,
      reportSnapshots: reportSnapshots,
    );
  }

  Future<_MileageEuerTotals> _mileageCorrectionTotalsForEvent(String correctionId, String start, String end) async {
    final List<Map<String, Object?>> corrections = await executor.runSelect(
      'SELECT c.id, c.trip_id, c.kind, c.replacement_trip_id, c.state, c.accounting_correction_id, c.applied_at, '
      'c.applied_business_date, source.state AS source_state, source.posting_event_id AS source_event, '
      'source.calculated_amount AS source_amount, replacement.state AS replacement_state, '
      'replacement.posting_event_id AS replacement_event, replacement.calculated_amount AS replacement_amount '
      'FROM mileage_trip_corrections c JOIN mileage_trips source ON source.id = c.trip_id '
      'LEFT JOIN mileage_trips replacement ON replacement.id = c.replacement_trip_id WHERE c.id = ?',
      <Object?>[correctionId],
    );
    if (corrections.length != 1) throw const EuerException('EÜR blockiert: Mileage-Korrektur fehlt');
    final Map<String, Object?> correction = corrections.single;
    final bool replace = correction['kind'] == 'replace';
    final String expectedSourceState = replace ? 'corrected' : 'voided';
    final String appliedAt = correction['applied_at']?.toString() ?? '';
    final DateTime? appliedAtInstant = DateTime.tryParse(appliedAt);
    final String? appliedBusinessDate = _validatedMileageCorrectionDate(
      correction['applied_business_date'],
      correctionId,
    );
    final List<Map<String, Object?>> dateRows = await executor.runSelect(
      'SELECT DISTINCT datum FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY datum',
      <Object?>['mileage_correction', correctionId],
    );
    final Set<String> correctionDates = <String>{};
    for (final Map<String, Object?> dateRow in dateRows) {
      final String? journalDate = _validatedMileageCorrectionDate(dateRow['datum'], correctionId);
      if (journalDate == null) {
        throw EuerException('EÜR blockiert: Mileage-Korrektur $correctionId hat ein unbekanntes Buchungsdatum');
      }
      correctionDates.add(journalDate);
    }
    final String date = correctionDates.length == 1
        ? correctionDates.single
        : correctionDates.isEmpty
        ? appliedBusinessDate ?? ''
        : '';
    if (correction['state'] != 'applied' ||
        correction['accounting_correction_id'] != correctionId ||
        appliedAtInstant == null ||
        !appliedAtInstant.isUtc ||
        date.length != 10 ||
        DateTime.tryParse(date) == null ||
        appliedBusinessDate != null && appliedBusinessDate != date ||
        date.compareTo(start) < 0 ||
        date.compareTo(end) >= 0 ||
        correction['source_state'] != expectedSourceState ||
        (correction['source_event']?.toString().trim().isNotEmpty ?? false) == false ||
        (!replace && correction['replacement_trip_id'] != null) ||
        (replace && (correction['replacement_state'] != 'posted' || correction['replacement_event'] != correctionId))) {
      throw const EuerException('EÜR blockiert: Mileage-Korrektur ist nicht atomar angewendet');
    }
    final String tripId = correction['trip_id']?.toString() ?? '';
    final String sourceEvent = correction['source_event']?.toString() ?? '';
    final List<Map<String, Object?>> originalTripRows = await executor.runSelect(
      'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
      <Object?>['mileage_trip', tripId],
    );
    final List<Map<String, Object?>> originalRows = originalTripRows.isNotEmpty
        ? originalTripRows
        : await executor.runSelect(
            'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? AND reversal_of_group_id IS NULL ORDER BY id',
            <Object?>['mileage_correction', sourceEvent],
          );
    if (originalRows.length != 2) {
      throw const EuerException('EÜR blockiert: Mileage-Korrektur hat keine vollständige Ursprungsbuchung');
    }
    final int originalRoot = (originalRows.first['gruppe_id'] as num?)?.toInt() ?? 0;
    final int originalAmount = _mileageEurCents(correction['source_amount'], correctionId);
    if (originalRoot <= 0) throw const EuerException('EÜR blockiert: Mileage-Ursprungsgruppe fehlt');
    final Map<String, Map<String, Object?>> originalByRole = <String, Map<String, Object?>>{};
    for (final Map<String, Object?> row in originalRows) {
      final String role = row['mileage_role_snapshot']?.toString() ?? '';
      final int debit = money.toCents(money.formatBetrag((row['soll'] ?? 0).toString()));
      final int credit = money.toCents(money.formatBetrag((row['haben'] ?? 0).toString()));
      final int signedAmount = money.toCents(money.formatBetrag((row['betrag'] ?? 0).toString()));
      final bool sourceLegIsValid = role == 'travel_expense'
          ? debit == originalAmount && credit == 0 && signedAmount == originalAmount
          : debit == 0 && credit == originalAmount && signedAmount == -originalAmount;
      if ((role != 'travel_expense' && role != 'private_contribution') ||
          !sourceLegIsValid ||
          originalByRole.containsKey(role) ||
          (row['gruppe_id'] as num?)?.toInt() != originalRoot ||
          (row['immutable'] as num?)?.toInt() != 1 ||
          (row['legacy_unverified'] as num?)?.toInt() != 0 ||
          !_mileageSnapshotIsComplete(row)) {
        throw const EuerException('EÜR blockiert: Mileage-Ursprungsbuchung hat ungültige Snapshots');
      }
      originalByRole[role] = row;
    }
    if (originalByRole.length != 2) {
      throw const EuerException('EÜR blockiert: Mileage-Ursprungsbuchung fehlt eine Rolle');
    }

    final List<Map<String, Object?>> legs = await executor.runSelect(
      'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
      <Object?>['mileage_correction', correctionId],
    );
    final int expectedCount = replace ? 4 : 2;
    if (legs.length != expectedCount) throw const EuerException('EÜR blockiert: Mileage-Korrekturgruppe unvollständig');
    final int groupId = (legs.first['gruppe_id'] as num?)?.toInt() ?? 0;
    final Map<String, Map<String, Object?>> reversalByRole = <String, Map<String, Object?>>{};
    final Map<String, Map<String, Object?>> replacementByRole = <String, Map<String, Object?>>{};
    var totalDebit = 0;
    var totalCredit = 0;
    var expenseCents = 0;
    var contributionCents = 0;
    for (final Map<String, Object?> row in legs) {
      final String role = row['mileage_role_snapshot']?.toString() ?? '';
      final bool reversal = row['reversal_of_group_id'] != null;
      final Map<String, Map<String, Object?>> byRole = reversal ? reversalByRole : replacementByRole;
      final int debit = money.toCents(money.formatBetrag((row['soll'] ?? 0).toString()));
      final int credit = money.toCents(money.formatBetrag((row['haben'] ?? 0).toString()));
      if ((role != 'travel_expense' && role != 'private_contribution') ||
          byRole.containsKey(role) ||
          (row['gruppe_id'] as num?)?.toInt() != groupId ||
          groupId <= 0 ||
          row['source_kind'] != 'mileage_correction' ||
          row['source_id'] != correctionId ||
          row['datum'] != date ||
          row['beleg_typ'] != 'Ausgabe' ||
          (row['immutable'] as num?)?.toInt() != 1 ||
          (row['legacy_unverified'] as num?)?.toInt() != 0 ||
          row['ust_satz_id'] != null ||
          row['ust_satz'] != null ||
          row['ust_sonderfall'] != null ||
          row['vorsteuer_betrag'] != null ||
          row['marge_25a_brutto'] != null ||
          row['ust_satz_25a'] != null ||
          debit < 0 ||
          credit < 0 ||
          (debit == 0) == (credit == 0) ||
          !_mileageSnapshotIsComplete(row)) {
        throw const EuerException('EÜR blockiert: Mileage-Korrekturgruppe enthält eine ungültige Buchungszeile');
      }
      byRole[role] = row;
      totalDebit += debit;
      totalCredit += credit;
      if (role == 'travel_expense') expenseCents += debit - credit;
      if (role == 'private_contribution') contributionCents += credit - debit;
    }
    if (reversalByRole.length != 2 ||
        (reversalByRole['travel_expense']?['id'] as num?)?.toInt() != groupId ||
        totalDebit != totalCredit ||
        (replace && replacementByRole.length != 2) ||
        (!replace && replacementByRole.isNotEmpty)) {
      throw const EuerException('EÜR blockiert: Mileage-Korrekturgruppe ist unausgeglichen');
    }
    const List<String> snapshotColumns = <String>[
      'mileage_role_snapshot',
      'mileage_kategorie_id_snapshot',
      'mileage_kategorie_name_snapshot',
      'mileage_kategorie_art_snapshot',
      'mileage_euer_zeile_snapshot',
      'mileage_kategorie_skr03_snapshot',
      'mileage_kategorie_skr04_snapshot',
      'mileage_mapping_status_snapshot',
      'mileage_mapping_source_reference_snapshot',
      'mileage_mapping_source_version_snapshot',
      'mileage_mapping_history_id_snapshot',
    ];
    for (final String role in <String>['travel_expense', 'private_contribution']) {
      final Map<String, Object?> original = originalByRole[role]!;
      final Map<String, Object?> reversal = reversalByRole[role]!;
      final int originalDebit = money.toCents(money.formatBetrag((original['soll'] ?? 0).toString()));
      final int originalCredit = money.toCents(money.formatBetrag((original['haben'] ?? 0).toString()));
      final int originalSigned = money.toCents(money.formatBetrag((original['betrag'] ?? 0).toString()));
      if ((reversal['reversal_of_group_id'] as num?)?.toInt() != originalRoot ||
          reversal['konto_id'] != original['konto_id'] ||
          reversal['kategorie_id'] != original['kategorie_id'] ||
          money.toCents(money.formatBetrag((reversal['soll'] ?? 0).toString())) != originalCredit ||
          money.toCents(money.formatBetrag((reversal['haben'] ?? 0).toString())) != originalDebit ||
          money.toCents(money.formatBetrag((reversal['betrag'] ?? 0).toString())) != -originalSigned ||
          snapshotColumns.any((String column) => reversal[column] != original[column])) {
        throw const EuerException('EÜR blockiert: Mileage-Umkehrbuchung weicht von der Ursprungsbuchung ab');
      }
    }
    if (replace) {
      final int amount = _mileageEurCents(correction['replacement_amount'], correctionId);
      final Map<String, Object?> expense = replacementByRole['travel_expense']!;
      final Map<String, Object?> contribution = replacementByRole['private_contribution']!;
      if (money.toCents(money.formatBetrag((expense['soll'] ?? 0).toString())) != amount ||
          money.toCents(money.formatBetrag((expense['haben'] ?? 0).toString())) != 0 ||
          money.toCents(money.formatBetrag((expense['betrag'] ?? 0).toString())) != amount ||
          money.toCents(money.formatBetrag((contribution['soll'] ?? 0).toString())) != 0 ||
          money.toCents(money.formatBetrag((contribution['haben'] ?? 0).toString())) != amount ||
          money.toCents(money.formatBetrag((contribution['betrag'] ?? 0).toString())) != -amount) {
        throw const EuerException('EÜR blockiert: Mileage-Ersatzbuchung stimmt nicht mit der Ersatzfahrt überein');
      }
    }
    final List<Map<String, Object?>> settlements = await executor.runSelect(
      'SELECT id FROM settlement_groups WHERE source_kind = ? AND source_id = ? LIMIT 1',
      <Object?>['mileage_correction', correctionId],
    );
    if (settlements.isNotEmpty) throw const EuerException('EÜR blockiert: Mileage-Korrektur enthält eine Zahlung');

    final List<Map<String, Object?>> legSnapshots = <Map<String, Object?>>[
      for (final Map<String, Object?> leg in legs)
        <String, Object?>{
          'journal_id': leg['id'],
          'role': leg['mileage_role_snapshot'],
          'reversal_of_group_id': leg['reversal_of_group_id'],
          'category_id': leg['mileage_kategorie_id_snapshot'],
          'category_label': leg['mileage_kategorie_name_snapshot'],
          'category_art': leg['mileage_kategorie_art_snapshot'],
          'euer_line': leg['mileage_euer_zeile_snapshot'],
          'konto_skr03': leg['mileage_kategorie_skr03_snapshot'],
          'konto_skr04': leg['mileage_kategorie_skr04_snapshot'],
          'mapping_status': leg['mileage_mapping_status_snapshot'],
          'mapping_source_reference': leg['mileage_mapping_source_reference_snapshot'],
          'mapping_source_version': leg['mileage_mapping_source_version_snapshot'],
          'mapping_history_id': leg['mileage_mapping_history_id_snapshot'],
        },
    ];
    return _MileageEuerTotals(
      expenseCents: expenseCents,
      contributionCents: contributionCents,
      reportSnapshots: <Map<String, Object?>>[
        <String, Object?>{
          'correction_id': correctionId,
          'trip_id': tripId,
          'kind': correction['kind'],
          'applied_at': appliedAt,
          'legs': legSnapshots,
        },
      ],
    );
  }

  String? _validatedMileageCorrectionDate(Object? raw, String correctionId) {
    if (raw == null) return null;
    final String date = raw.toString();
    final DateTime? parsed = DateTime.tryParse(date);
    if (date.length != 10 || parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
      throw EuerException('EÜR blockiert: Mileage-Korrektur $correctionId hat ein ungültiges Buchungsdatum');
    }
    return date;
  }

  int _mileageEurCents(Object? raw, String tripId) {
    try {
      final String value = raw?.toString().trim() ?? '';
      if (!RegExp(r'^[0-9]+(?:[.][0-9]{1,2})?$').hasMatch(value)) {
        throw const FormatException();
      }
      return money.toCents(value);
    } catch (error) {
      throw EuerException('EÜR blockiert: Mileage-Betrag für $tripId ist ungültig', error);
    }
  }

  bool _mileageSnapshotIsComplete(Map<String, Object?> leg) {
    final String role = leg['mileage_role_snapshot']?.toString() ?? '';
    final String expectedArt = role == 'travel_expense' ? 'ausgabe' : 'einnahme';
    final int expectedLine = role == 'travel_expense' ? 71 : 107;
    return (leg['konto_id'] as num?)?.toInt() != null &&
        (leg['kategorie_id'] as num?)?.toInt() != null &&
        (leg['kategorie_id'] as num?)?.toInt() == (leg['mileage_kategorie_id_snapshot'] as num?)?.toInt() &&
        (leg['mileage_kategorie_name_snapshot']?.toString().trim().isNotEmpty ?? false) &&
        leg['mileage_kategorie_art_snapshot']?.toString().trim().toLowerCase() == expectedArt &&
        (leg['mileage_euer_zeile_snapshot'] as num?)?.toInt() == expectedLine &&
        (leg['mileage_mapping_status_snapshot'] == 'catalog_verified' ||
            leg['mileage_mapping_status_snapshot'] == 'user_confirmed') &&
        ((leg['mileage_mapping_history_id_snapshot'] as num?)?.toInt() ?? 0) > 0 &&
        ((leg['mileage_kategorie_skr03_snapshot']?.toString().trim().isNotEmpty ?? false) ||
            (leg['mileage_kategorie_skr04_snapshot']?.toString().trim().isNotEmpty ?? false));
  }

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
class _MileageEuerTotals {
  const _MileageEuerTotals({
    required this.expenseCents,
    required this.contributionCents,
    required this.reportSnapshots,
  });

  final int expenseCents;
  final int contributionCents;
  final List<Map<String, Object?>> reportSnapshots;
}

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
