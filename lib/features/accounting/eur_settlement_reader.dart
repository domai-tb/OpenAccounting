import 'package:drift/drift.dart';

/// Settlement-based EÜR reads for cash-basis recognition.
///
/// Ordinary income is recognized only for amounts actually received (and
/// expenses only for amounts actually paid), grouped by authoritative
/// settlement date and `euer_zeile` — never by invoice-issue journal dates.
/// Unconfirmed bank rows, suggested matches, and legacy invoice-date gross
/// rows never recognize income or expenses. Write-offs, refunds, and
/// corrections are recognized only via their own settlement or correction
/// records, so they never appear here. Reversed settlements reclassify in
/// the reversal period through their negative allocations.
class EurSettlementException implements Exception {
  const EurSettlementException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Settlement totals for one reporting year in integer cents.
class EurSettlementTotals {
  const EurSettlementTotals({required this.centsByZeile, required this.einnahmenCents, required this.ausgabenCents});

  final Map<int, int> centsByZeile;
  final int einnahmenCents;
  final int ausgabenCents;
}

class EurSettlementReader {
  const EurSettlementReader._();

  /// True when settlement groups attribute any amount to [jahr] — either by
  /// settlement date or by an approved statutory timing rule.
  static Future<bool> hasSettlementData(QueryExecutor executor, int jahr) async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT COUNT(*) AS c FROM settlement_groups g LEFT JOIN statutory_timing_rules r '
        'ON r.settlement_group_id = g.id '
        'WHERE substr(g.settlement_date, 1, 4) = ? OR CAST(r.attributed_year AS TEXT) = ?',
        <Object?>[jahr.toString(), jahr.toString()],
      );
      return (((rows.single['c'] as num?) ?? 0).toInt()) > 0;
    } catch (_) {
      return false;
    }
  }

  /// Ids of durable `legacy_unverified` journal rows inside [jahr].
  static Future<List<int>> legacyUnverifiedIds(QueryExecutor executor, int jahr) async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM journal WHERE legacy_unverified = 1 AND substr(datum, 1, 4) = ? ORDER BY id',
        <Object?>[jahr.toString()],
      );
      return <int>[for (final Map<String, Object?> row in rows) ((row['id'] as num?) ?? 0).toInt()];
    } catch (_) {
      return const <int>[];
    }
  }

  /// Sums settled portions by attributed year and `euer_zeile`. Each settled
  /// portion inherits the invoice's persisted category snapshot stored on
  /// the allocation; direct cash allocations carry their own. Statutory
  /// timing exceptions move a group only through an explicit versioned rule
  /// result — never inferred from free text.
  static Future<EurSettlementTotals> totalsForYear(QueryExecutor executor, int jahr) async {
    final Map<int, int> byZeile = <int, int>{};
    var einnahmen = 0;
    var ausgaben = 0;
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT a.applied_cents AS cents, a.settlement_date AS datum, a.euer_zeile AS zeile, '
        'a.direction AS richtung, r.attributed_year AS zugeordnet '
        'FROM settlement_allocations a JOIN settlement_groups g ON g.id = a.group_id '
        'LEFT JOIN statutory_timing_rules r ON r.settlement_group_id = g.id',
        const <Object?>[],
      );
    } catch (error) {
      throw EurSettlementException('Ausgleichsdaten konnten nicht gelesen werden: $error');
    }
    for (final Map<String, Object?> row in rows) {
      final int cents = ((row['cents'] as num?) ?? 0).toInt();
      if (cents == 0) {
        continue;
      }
      final String datum = row['datum']?.toString() ?? '';
      final int settlementYear = int.tryParse(datum.length >= 4 ? datum.substring(0, 4) : '') ?? -1;
      final int attributedYear = (row['zugeordnet'] as num?)?.toInt() ?? settlementYear;
      if (attributedYear != jahr) {
        continue;
      }
      final int? zeile = (row['zeile'] as num?)?.toInt();
      if (zeile == null || zeile == 33 || zeile == 106 || zeile == 107) {
        // ponytail: AfA (33) stays asset-register owned; Hinweise (106/107)
        // never affect Gewinn. Skip instead of failing the whole period.
        continue;
      }
      byZeile.update(zeile, (int current) => current + cents, ifAbsent: () => cents);
      if ((row['richtung']?.toString() ?? 'einnahme') == 'ausgabe') {
        ausgaben += cents;
      } else {
        einnahmen += cents;
      }
    }
    return EurSettlementTotals(centsByZeile: byZeile, einnahmenCents: einnahmen, ausgabenCents: ausgaben);
  }

  /// Records an approved statutory year-boundary timing exception. Every
  /// field (rule id/version, legal basis, affected year, approver, source
  /// trace) is required; without a stored rule the settlement stays assigned
  /// by its actual settlement date.
  static Future<int> applyTimingException(
    QueryExecutor executor, {
    required String ruleId,
    required String ruleVersion,
    required String legalBasis,
    required int affectedYear,
    required String approver,
    required String sourceTrace,
    required int settlementGroupId,
    required int attributedYear,
  }) async {
    if (ruleId.trim().isEmpty ||
        ruleVersion.trim().isEmpty ||
        legalBasis.trim().isEmpty ||
        approver.trim().isEmpty ||
        sourceTrace.trim().isEmpty) {
      throw const EurSettlementException(
        'Zeitliche Ausnahmeregel braucht Regel-ID, Version, Rechtsgrundlage, Genehmiger und Quellennachweis',
      );
    }
    if (affectedYear < 2000 || affectedYear > 2100 || attributedYear < 2000 || attributedYear > 2100) {
      throw const EurSettlementException('Betroffenes Jahr und zugeordnetes Jahr müssen gültige Jahre sein');
    }
    final List<Map<String, Object?>> groups = await executor.runSelect(
      'SELECT id FROM settlement_groups WHERE id = ? LIMIT 1',
      <Object?>[settlementGroupId],
    );
    if (groups.isEmpty) {
      throw EurSettlementException('Ausgleichsgruppe #$settlementGroupId nicht gefunden');
    }
    return executor.runInsert(
      'INSERT INTO statutory_timing_rules (rule_id, rule_version, legal_basis, affected_year, approver, '
      'source_trace, settlement_group_id, attributed_year) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        ruleId.trim(),
        ruleVersion.trim(),
        legalBasis.trim(),
        affectedYear,
        approver.trim(),
        sourceTrace.trim(),
        settlementGroupId,
        attributedYear,
      ],
    );
  }

  /// Versioned rule results attributing groups to [jahr] (report trace).
  static Future<List<Map<String, Object?>>> timingRulesForYear(QueryExecutor executor, int jahr) async {
    try {
      return await executor.runSelect(
        'SELECT rule_id, rule_version, legal_basis, affected_year, approver, source_trace, settlement_group_id, '
        'attributed_year FROM statutory_timing_rules WHERE attributed_year = ? ORDER BY id',
        <Object?>[jahr],
      );
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }
}
