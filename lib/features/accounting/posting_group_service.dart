import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';

/// Posting boundary for balanced, source-linked journal groups.
///
/// Every in-scope invoice-issue and settlement event posts at least two
/// account-backed legs inside one database transaction: each leg carries
/// exactly one non-zero side in integer cents (debit XOR credit), total
/// debit equals total credit, and all legs share `(source_kind, source_id)`
/// under a unique constraint. Retries return the committed group; posted
/// rows are never edited or deleted (reversal posts a linked opposite group).
/// Out-of-scope writers (recurring templates, setup opening balances, other
/// direct `journal` rows) keep their maintained single-row behavior.
class PostingException implements Exception {
  const PostingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Source identities routed through this boundary.
class PostingSource {
  const PostingSource._();

  static const String invoiceEvent = 'invoice_event';
  static const String bankTransaction = 'bank_transaction';
  static const String cashPayment = 'cash_payment';
  static const String mileageTrip = 'mileage_trip';
  static const String mileageCorrection = 'mileage_correction';
}

/// One balanced journal leg in integer cents.
class PostingLeg {
  const PostingLeg({
    required this.debitCents,
    required this.creditCents,
    this.kontoId,
    this.sollKontoId,
    this.habenKontoId,
    this.kategorieId,
    this.beschreibung,
  });

  final int debitCents;
  final int creditCents;
  final int? kontoId;
  final int? sollKontoId;
  final int? habenKontoId;
  final int? kategorieId;
  final String? beschreibung;
}

/// Committed invoice-issue group.
class PostingGroupSummary {
  const PostingGroupSummary({
    required this.rootJournalId,
    required this.sourceKind,
    required this.sourceId,
    required this.debitCents,
    required this.creditCents,
    required this.legIds,
  });

  final int rootJournalId;
  final String sourceKind;
  final String sourceId;
  final int debitCents;
  final int creditCents;
  final List<int> legIds;
}

/// One allocation of a settlement group to an open item.
class SettlementAllocationInput {
  const SettlementAllocationInput({
    this.forderungId,
    required this.appliedCents,
    this.kategorieId,
    this.euerZeile,
    this.isExpense = false,
  });

  /// Null marks a direct cash receipt/expense without an invoice.
  final int? forderungId;
  final int appliedCents;
  final int? kategorieId;
  final int? euerZeile;
  final bool isExpense;
}

/// Committed settlement group with its allocations.
class SettlementGroupSummary {
  const SettlementGroupSummary({
    required this.id,
    required this.rootJournalId,
    required this.sourceKind,
    required this.sourceId,
    required this.signedAmountCents,
    required this.settlementDate,
    required this.unappliedCents,
    required this.allocationIds,
  });

  final int id;
  final int rootJournalId;
  final String sourceKind;
  final String sourceId;
  final int signedAmountCents;
  final String settlementDate;
  final int unappliedCents;
  final List<int> allocationIds;
}

/// Stored settlement allocation row (read model for EÜR and confirmations).
class StoredAllocation {
  const StoredAllocation({
    required this.id,
    required this.groupId,
    required this.forderungId,
    required this.appliedCents,
    required this.settlementDate,
    required this.kategorieId,
    required this.euerZeile,
    required this.direction,
    this.ustSatz,
  });

  final int id;
  final int groupId;
  final int? forderungId;
  final int appliedCents;
  final String settlementDate;
  final int? kategorieId;
  final int? euerZeile;
  final String direction;
  final num? ustSatz;
}

class PostingGroupService {
  PostingGroupService(this.executor, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final QueryExecutor executor;
  final DateTime Function() _now;

  static const Set<String> _eligibleMapping = <String>{'catalog_verified', 'user_confirmed'};

  /// Idempotent DDL for the posting boundary (mirrors migration v19).

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  Future<void> ensureSchema() async {
    await _addColumnIfMissing('journal', 'source_kind', 'TEXT');
    await _addColumnIfMissing('journal', 'source_id', 'TEXT');
    await _addColumnIfMissing('journal', 'reversal_of_group_id', 'INTEGER REFERENCES journal(id)');
    await _addColumnIfMissing('journal', 'legacy_unverified', 'INTEGER NOT NULL DEFAULT 1');
    await executor.runCustom(_settlementGroupsSql);
    await executor.runCustom(_settlementAllocationsSql);
    await _addColumnIfMissing('settlement_allocations', 'ust_satz', 'NUMERIC(5,2)');
    await executor.runCustom(_statutoryTimingRulesSql);
    await executor.runCustom(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_journal_source_unique '
      'ON journal(source_kind, source_id) WHERE source_kind IS NOT NULL AND source_id IS NOT NULL AND gruppe_id = id',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_settlement_groups_bank ON settlement_groups(bank_transaction_id) '
      'WHERE bank_transaction_id IS NOT NULL',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_settlement_allocations_group ON settlement_allocations(group_id)',
    );
  }

  /// Posts an invoice-issue group: debit receivable, credit revenue (or the
  /// mirrored supplier pair supplied by the caller). Amounts are integer
  /// cents from the approved money contract; no split residual is computed
  /// here. Missing accounts or tax mappings fail before commit.

  /// Replaces both profile-local mileage role mappings as one reviewed change.
  /// A role is never inferred from a seeded category or account.
  Future<void> configureMileagePostingRoles({
    required int travelExpenseKontoId,
    required int travelExpenseKategorieId,
    required int privateContributionKontoId,
    required int privateContributionKategorieId,
  }) async {
    await _requireMileagePostingSchema(executor);
    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      await tx.runCustom('DELETE FROM mileage_posting_account_mapping');
      final String reviewedAt = DateTime.now().toUtc().toIso8601String();
      await tx.runInsert(
        'INSERT INTO mileage_posting_account_mapping (role, konto_id, kategorie_id, reviewed_at) VALUES (?, ?, ?, ?)',
        <Object?>['travel_expense', travelExpenseKontoId, travelExpenseKategorieId, reviewedAt],
      );
      await tx.runInsert(
        'INSERT INTO mileage_posting_account_mapping (role, konto_id, kategorie_id, reviewed_at) VALUES (?, ?, ?, ?)',
        <Object?>['private_contribution', privateContributionKontoId, privateContributionKategorieId, reviewedAt],
      );
      await _loadMileagePostingRoles(tx);
      await tx.send();
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  /// Posts one calculated trip as an expense debit and private-contribution
  /// credit. Journal legs, mapping snapshots, and trip state share one
  /// transaction. No bank, cash, settlement, or input-VAT row is created.
  Future<String> postMileage({required MileageTrip trip}) async {
    final String cleanTripId = trip.id.trim();
    if (!_uuidPattern.hasMatch(cleanTripId)) {
      throw const PostingException('Fahrten-ID muss eine UUID sein');
    }
    await _requireMileagePostingSchema(executor);

    final Map<String, Object?> requestedFacts = _mileageTripEntityFacts(trip);
    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      final Map<String, Object?>? tripRow = await _mileageTripRow(tx, cleanTripId);
      if (tripRow == null) throw const PostingException('Fahrt nicht gefunden');
      final Map<String, Object?> tripFacts = _validatedMileageTripFacts(tripRow);
      if (jsonEncode(requestedFacts) != jsonEncode(tripFacts)) {
        throw const PostingException('Mileage-Wiederholung hat einen abweichenden Fahrtsnapshot');
      }
      final List<Map<String, Object?>> existing = await _mileageJournalRows(tx, cleanTripId);
      if (existing.isNotEmpty || tripRow['state'] == 'posted') {
        final Map<String, _MileagePostingRoleSnapshot> roles = await _loadMileagePostingRoles(tx);
        final String eventId = await _verifyMileageReplay(tripRow, existing, cleanTripId, roles);
        await tx.send();
        return eventId;
      }
      if (tripRow['state'] != 'calculated' || tripRow['posting_event_id'] != null) {
        throw const PostingException('Nur berechnete und noch nicht gebuchte Fahrten können gebucht werden');
      }

      await _requireMileagePeriodOpen(tx, tripRow['trip_date'].toString());
      final Map<String, _MileagePostingRoleSnapshot> roles = await _loadMileagePostingRoles(tx);
      final int amountCents = _mileageAmountCents(tripRow['calculated_amount']);
      if (amountCents <= 0) throw const PostingException('Fahrtbetrag muss mindestens einen Cent betragen');
      final String eventId = _newMileageEventId();
      final String description = 'Fahrt: ${tripRow['purpose']}';
      final _MileagePostingRoleSnapshot expense = roles['travel_expense']!;
      final _MileagePostingRoleSnapshot contribution = roles['private_contribution']!;

      final int expenseId = await _insertLeg(
        tx,
        datum: tripRow['trip_date'].toString(),
        beschreibung: description,
        kategorieId: expense.kategorieId,
        art: 'Ausgabe',
        betragCents: amountCents,
        debitCents: amountCents,
        creditCents: 0,
        kontoId: expense.kontoId,
        sollKontoId: expense.kontoId,
        habenKontoId: null,
        sourceKind: PostingSource.mileageTrip,
        sourceId: cleanTripId,
      );
      final int contributionId = await _insertLeg(
        tx,
        datum: tripRow['trip_date'].toString(),
        beschreibung: description,
        kategorieId: contribution.kategorieId,
        art: 'Ausgabe',
        betragCents: -amountCents,
        debitCents: 0,
        creditCents: amountCents,
        kontoId: contribution.kontoId,
        sollKontoId: null,
        habenKontoId: contribution.kontoId,
        sourceKind: PostingSource.mileageTrip,
        sourceId: cleanTripId,
      );
      await _writeMileageLegSnapshot(tx, journalId: expenseId, role: expense);
      await _writeMileageLegSnapshot(tx, journalId: contributionId, role: contribution);
      await _sealLegs(tx, <int>[expenseId, contributionId], expenseId);
      final int changed = await tx.runUpdate(
        'UPDATE mileage_trips SET state = ?, posting_event_id = ?, updated_at = ? '
        'WHERE id = ? AND state = ? AND posting_event_id IS NULL',
        <Object?>['posted', eventId, DateTime.now().toUtc().toIso8601String(), cleanTripId, 'calculated'],
      );
      if (changed != 1) throw const PostingException('Fahrt wurde parallel geändert; Buchung bitte erneut prüfen');
      await tx.send();
      return eventId;
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      if (_isUniqueViolation(error)) {
        final Map<String, Object?>? racedTrip = await _mileageTripRow(executor, cleanTripId);
        if (racedTrip != null) {
          final Map<String, Object?> racedFacts = _validatedMileageTripFacts(racedTrip);
          if (jsonEncode(requestedFacts) != jsonEncode(racedFacts)) {
            throw const PostingException('Mileage-Wiederholung hat einen abweichenden Fahrtsnapshot');
          }
          final List<Map<String, Object?>> racedRows = await _mileageJournalRows(executor, cleanTripId);
          if (racedRows.isNotEmpty || racedTrip['state'] == 'posted') {
            final Map<String, _MileagePostingRoleSnapshot> roles = await _loadMileagePostingRoles(executor);
            return _verifyMileageReplay(racedTrip, racedRows, cleanTripId, roles);
          }
        }
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  Future<void> applyMileageCorrection({required String correctionId}) async {
    final String id = correctionId.trim();
    if (!_uuidPattern.hasMatch(id)) throw const PostingException('Korrektur-ID muss eine UUID sein');
    await _requireMileagePostingSchema(executor);
    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      final Map<String, Object?>? correction = await _mileageCorrectionRecord(tx, id);
      if (correction == null) throw const PostingException('Mileage-Korrektur nicht gefunden');
      if (correction['state'] == 'applied') {
        await _verifyAppliedMileageCorrection(tx, correction);
        await tx.send();
        return;
      }
      if (correction['state'] != 'draft') {
        throw const PostingException('Nur Entwurfskorrekturen können angewendet werden');
      }

      final String tripId = correction['trip_id']?.toString() ?? '';
      final Map<String, Object?>? source = await _mileageTripRow(tx, tripId);
      if (source == null || source['state'] != 'posted') {
        throw const PostingException('Nur gebuchte Fahrten können korrigiert werden');
      }
      final String sourceEventId = source['posting_event_id']?.toString() ?? '';
      if (!_uuidPattern.hasMatch(sourceEventId)) {
        throw const PostingException('Gebuchte Fahrt hat keine Buchungsreferenz');
      }
      _validatedMileageTripFacts(source);
      final List<Map<String, Object?>> originalRows = await _mileageOriginalRows(tx, source);
      final int originalRoot = _validateMileageOriginalRows(source, originalRows);
      final List<Map<String, Object?>> sourceSettlements = await tx.runSelect(
        'SELECT id FROM settlement_groups WHERE source_kind = ? AND source_id = ? LIMIT 1',
        <Object?>[originalRows.first['source_kind'], originalRows.first['source_id']],
      );
      if (sourceSettlements.isNotEmpty) {
        throw const PostingException('Mileage-Buchung darf keine Zahlung enthalten');
      }

      final String kind = correction['kind']?.toString() ?? '';
      final bool replace = kind == 'replace';
      if (!replace && kind != 'void') throw const PostingException('Unbekannte Mileage-Korrekturart');
      final String? replacementId = correction['replacement_trip_id']?.toString();
      Map<String, Object?>? replacement;
      int replacementAmount = 0;
      Map<String, _MileagePostingRoleSnapshot> replacementRoles = <String, _MileagePostingRoleSnapshot>{};
      if (replace) {
        if (replacementId == null || replacementId.isEmpty || replacementId == tripId) {
          throw const PostingException('Ersatzfahrt fehlt oder ist ungültig');
        }
        replacement = await _mileageTripRow(tx, replacementId);
        if (replacement == null || replacement['state'] != 'calculated' || replacement['posting_event_id'] != null) {
          throw const PostingException('Ersatzfahrt muss berechnet und noch ungebucht sein');
        }
        _validatedMileageTripFacts(replacement);
        replacementAmount = _mileageAmountCents(replacement['calculated_amount']);
        replacementRoles = await _loadMileagePostingRoles(tx);
      } else if (replacementId != null) {
        throw const PostingException('Eine Stornokorrektur darf keine Ersatzfahrt enthalten');
      }

      final DateTime appliedAt = _now().toUtc();
      final String appliedAtIso = appliedAt.toIso8601String();
      // Audit timestamps stay UTC; journal dates use the host's business-local calendar.
      final String date = appliedAt.toLocal().toIso8601String().substring(0, 10);
      await _requireMileagePeriodOpen(tx, date);
      final List<int> legIds = <int>[];
      final Map<String, int> reversalIds = <String, int>{};
      for (final Map<String, Object?> original in originalRows) {
        final String role = original['mileage_role_snapshot']?.toString() ?? '';
        final _MileagePostingRoleSnapshot snapshot = _mileageRoleSnapshotFromRow(original);
        final int debit = money.toCents(money.formatBetrag((original['soll'] ?? 0).toString()));
        final int credit = money.toCents(money.formatBetrag((original['haben'] ?? 0).toString()));
        final int amount = money.toCents(money.formatBetrag((original['betrag'] ?? 0).toString()));
        final int reversalId = await _insertLeg(
          tx,
          datum: date,
          beschreibung: 'Mileage-Korrektur: ${correction['reason']}',
          kategorieId: (original['kategorie_id'] as num?)?.toInt(),
          art: 'Ausgabe',
          betragCents: -amount,
          debitCents: credit,
          creditCents: debit,
          kontoId: (original['konto_id'] as num?)?.toInt(),
          sollKontoId: (original['haben_konto_id'] as num?)?.toInt(),
          habenKontoId: (original['soll_konto_id'] as num?)?.toInt(),
          sourceKind: PostingSource.mileageCorrection,
          sourceId: id,
          reversalOfGroupId: originalRoot,
        );
        reversalIds[role] = reversalId;
        legIds.add(reversalId);
        await _writeMileageLegSnapshot(tx, journalId: reversalId, role: snapshot);
      }
      if (replace) {
        final _MileagePostingRoleSnapshot expense = replacementRoles['travel_expense']!;
        final _MileagePostingRoleSnapshot contribution = replacementRoles['private_contribution']!;
        final String description = 'Ersatzfahrt ${replacement!['purpose']}';
        final int expenseId = await _insertLeg(
          tx,
          datum: date,
          beschreibung: description,
          kategorieId: expense.kategorieId,
          art: 'Ausgabe',
          betragCents: replacementAmount,
          debitCents: replacementAmount,
          creditCents: 0,
          kontoId: expense.kontoId,
          sollKontoId: expense.kontoId,
          habenKontoId: null,
          sourceKind: PostingSource.mileageCorrection,
          sourceId: id,
        );
        final int contributionId = await _insertLeg(
          tx,
          datum: date,
          beschreibung: description,
          kategorieId: contribution.kategorieId,
          art: 'Ausgabe',
          betragCents: -replacementAmount,
          debitCents: 0,
          creditCents: replacementAmount,
          kontoId: contribution.kontoId,
          sollKontoId: null,
          habenKontoId: contribution.kontoId,
          sourceKind: PostingSource.mileageCorrection,
          sourceId: id,
        );
        await _writeMileageLegSnapshot(tx, journalId: expenseId, role: expense);
        await _writeMileageLegSnapshot(tx, journalId: contributionId, role: contribution);
        legIds.addAll(<int>[expenseId, contributionId]);
      }
      final int rootId = reversalIds['travel_expense']!;
      await _sealLegs(tx, legIds, rootId);

      if (replace) {
        final int replacementChanged = await tx.runUpdate(
          'UPDATE mileage_trips SET state = ?, posting_event_id = ?, updated_at = ? '
          'WHERE id = ? AND state = ? AND posting_event_id IS NULL',
          <Object?>['posted', id, appliedAtIso, replacementId, 'calculated'],
        );
        if (replacementChanged != 1) throw const PostingException('Ersatzfahrt wurde parallel geändert');
      }
      final int correctionChanged = await tx.runUpdate(
        'UPDATE mileage_trip_corrections SET state = ?, accounting_correction_id = ?, applied_at = ?, '
        'applied_business_date = ? WHERE id = ? AND state = ?',
        <Object?>['applied', id, appliedAtIso, date, id, 'draft'],
      );
      if (correctionChanged != 1) throw const PostingException('Korrektur wurde parallel geändert');
      final String terminalState = replace ? 'corrected' : 'voided';
      final int sourceChanged = await tx.runUpdate(
        'UPDATE mileage_trips SET state = ?, updated_at = ? WHERE id = ? AND state = ? AND posting_event_id = ?',
        <Object?>[terminalState, appliedAtIso, tripId, 'posted', sourceEventId],
      );
      if (sourceChanged != 1) throw const PostingException('Fahrt wurde parallel geändert');
      await tx.send();
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      final Map<String, Object?>? applied = await _mileageCorrectionRecord(executor, id);
      if (applied != null && applied['state'] == 'applied') {
        try {
          await _verifyAppliedMileageCorrection(executor, applied);
          return;
        } catch (_) {
          // Keep the original failure if a competing operation did not commit a complete correction.
        }
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  Future<Map<String, Object?>?> _mileageCorrectionRecord(QueryExecutor query, String id) async {
    final List<Map<String, Object?>> rows = await query.runSelect(
      'SELECT c.*, source.state AS source_state, source.posting_event_id AS source_posting_event_id, '
      'replacement.state AS replacement_state, replacement.posting_event_id AS replacement_posting_event_id '
      'FROM mileage_trip_corrections c JOIN mileage_trips source ON source.id = c.trip_id '
      'LEFT JOIN mileage_trips replacement ON replacement.id = c.replacement_trip_id WHERE c.id = ? LIMIT 1',
      <Object?>[id],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> _mileageOriginalRows(QueryExecutor query, Map<String, Object?> source) async {
    final String tripId = source['id']?.toString() ?? '';
    final List<Map<String, Object?>> rows = await query.runSelect(
      'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
      <Object?>[PostingSource.mileageTrip, tripId],
    );
    if (rows.isNotEmpty) return rows;
    final String eventId = source['posting_event_id']?.toString() ?? '';
    final List<Map<String, Object?>> replacementRows = await query.runSelect(
      'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? AND reversal_of_group_id IS NULL ORDER BY id',
      <Object?>[PostingSource.mileageCorrection, eventId],
    );
    final List<Map<String, Object?>> prior = await query.runSelect(
      'SELECT id FROM mileage_trip_corrections WHERE id = ? AND kind = ? AND replacement_trip_id = ? '
      'AND state = ? AND accounting_correction_id = ?',
      <Object?>[eventId, 'replace', tripId, 'applied', eventId],
    );
    if (prior.length != 1) throw const PostingException('Ersatzfahrt hat keine angewendete Ursprungskorrektur');
    return replacementRows;
  }

  int _validateMileageOriginalRows(Map<String, Object?> source, List<Map<String, Object?>> rows) {
    if (rows.length != 2) throw const PostingException('Ursprüngliche Mileage-Buchung ist unvollständig');
    final bool tripSource = rows.first['source_kind'] == PostingSource.mileageTrip;
    final int rootId = (rows.first['gruppe_id'] as num?)?.toInt() ?? 0;
    final int amount = _mileageAmountCents(source['calculated_amount']);
    final Map<String, Map<String, Object?>> roles = <String, Map<String, Object?>>{};
    var debit = 0;
    var credit = 0;
    for (final Map<String, Object?> row in rows) {
      final String role = row['mileage_role_snapshot']?.toString() ?? '';
      final String expectedSource = tripSource ? source['id'].toString() : source['posting_event_id'].toString();
      final String expectedKind = tripSource ? PostingSource.mileageTrip : PostingSource.mileageCorrection;
      final int rowDebit = money.toCents(money.formatBetrag((row['soll'] ?? 0).toString()));
      final int rowCredit = money.toCents(money.formatBetrag((row['haben'] ?? 0).toString()));
      final int rowAmount = money.toCents(money.formatBetrag((row['betrag'] ?? 0).toString()));
      if ((role != 'travel_expense' && role != 'private_contribution') ||
          roles.containsKey(role) ||
          row['source_kind'] != expectedKind ||
          row['source_id'] != expectedSource ||
          (row['gruppe_id'] as num?)?.toInt() != rootId ||
          rootId <= 0 ||
          (row['immutable'] as num?)?.toInt() != 1 ||
          (row['legacy_unverified'] as num?)?.toInt() != 0 ||
          row['reversal_of_group_id'] != null ||
          row['beleg_typ'] != 'Ausgabe' ||
          row['ust_satz_id'] != null ||
          row['ust_satz'] != null ||
          row['ust_sonderfall'] != null ||
          row['vorsteuer_betrag'] != null ||
          row['marge_25a_brutto'] != null ||
          row['ust_satz_25a'] != null ||
          !_mileageRowMatchesRole(row, _mileageRoleSnapshotFromRow(row))) {
        throw const PostingException('Ursprüngliche Mileage-Buchungsgruppe ist fehlerhaft');
      }
      if (role == 'travel_expense' &&
          (rowDebit != amount ||
              rowCredit != 0 ||
              rowAmount != amount ||
              (row['soll_konto_id'] as num?)?.toInt() != (row['konto_id'] as num?)?.toInt() ||
              row['haben_konto_id'] != null)) {
        throw const PostingException('Ursprünglicher Mileage-Aufwand ist fehlerhaft');
      }
      if (role == 'private_contribution' &&
          (rowDebit != 0 ||
              rowCredit != amount ||
              rowAmount != -amount ||
              row['soll_konto_id'] != null ||
              (row['haben_konto_id'] as num?)?.toInt() != (row['konto_id'] as num?)?.toInt())) {
        throw const PostingException('Ursprüngliche Mileage-Privateinlage ist fehlerhaft');
      }
      roles[role] = row;
      debit += rowDebit;
      credit += rowCredit;
    }
    final Map<String, Object?>? expense = roles['travel_expense'];
    if (expense == null ||
        roles['private_contribution'] == null ||
        debit != amount ||
        credit != amount ||
        tripSource && (expense['id'] as num?)?.toInt() != rootId) {
      throw const PostingException('Ursprüngliche Mileage-Buchungsgruppe ist unausgeglichen');
    }
    return rootId;
  }

  _MileagePostingRoleSnapshot _mileageRoleSnapshotFromRow(Map<String, Object?> row) {
    final String role = row['mileage_role_snapshot']?.toString() ?? '';
    final int? kontoId = (row['konto_id'] as num?)?.toInt();
    final int? kategorieId = (row['kategorie_id'] as num?)?.toInt();
    final int? euerLine = (row['mileage_euer_zeile_snapshot'] as num?)?.toInt();
    final int? historyId = (row['mileage_mapping_history_id_snapshot'] as num?)?.toInt();
    if ((role != 'travel_expense' && role != 'private_contribution') ||
        kontoId == null ||
        kategorieId == null ||
        euerLine == null ||
        historyId == null) {
      throw const PostingException('Mileage-Zuordnungssnapshot ist unvollständig');
    }
    return _MileagePostingRoleSnapshot(
      role: role,
      kontoId: kontoId,
      kategorieId: kategorieId,
      categoryLabel: row['mileage_kategorie_name_snapshot']?.toString() ?? '',
      categoryArt: row['mileage_kategorie_art_snapshot']?.toString() ?? '',
      euerLine: euerLine,
      kontoSkr03: row['mileage_kategorie_skr03_snapshot']?.toString(),
      kontoSkr04: row['mileage_kategorie_skr04_snapshot']?.toString(),
      mappingStatus: row['mileage_mapping_status_snapshot']?.toString() ?? '',
      mappingSourceReference: row['mileage_mapping_source_reference_snapshot']?.toString(),
      mappingSourceVersion: row['mileage_mapping_source_version_snapshot']?.toString(),
      mappingHistoryId: historyId,
    );
  }

  Future<void> _verifyAppliedMileageCorrection(QueryExecutor query, Map<String, Object?> correction) async {
    final String id = correction['id']?.toString() ?? '';
    final String kind = correction['kind']?.toString() ?? '';
    final String state = kind == 'replace' ? 'corrected' : 'voided';
    final Map<String, Object?>? source = await _mileageTripRow(query, correction['trip_id'].toString());
    if (correction['state'] != 'applied' ||
        correction['accounting_correction_id'] != id ||
        source == null ||
        source['state'] != state) {
      throw const PostingException('Angewendete Mileage-Korrektur ist nicht konsistent');
    }
    final List<Map<String, Object?>> rows = await query.runSelect(
      'SELECT * FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
      <Object?>[PostingSource.mileageCorrection, id],
    );
    final int expected = kind == 'replace' ? 4 : 2;
    final DateTime? appliedAt = DateTime.tryParse(correction['applied_at']?.toString() ?? '');
    final Set<String> journalDates = <String>{
      for (final Map<String, Object?> row in rows) row['datum']?.toString() ?? '',
    };
    final String date = journalDates.length == 1 ? journalDates.single : '';
    final String? appliedBusinessDate = correction['applied_business_date']?.toString();
    if (rows.length != expected ||
        appliedAt == null ||
        !appliedAt.isUtc ||
        date.length != 10 ||
        DateTime.tryParse(date) == null ||
        appliedBusinessDate != null &&
            (appliedBusinessDate.length != 10 ||
                DateTime.tryParse(appliedBusinessDate) == null ||
                appliedBusinessDate != date) ||
        rows.any(
          (Map<String, Object?> row) =>
              row['datum'] != date ||
              (row['immutable'] as num?)?.toInt() != 1 ||
              (row['legacy_unverified'] as num?)?.toInt() != 0,
        )) {
      throw const PostingException('Angewendete Mileage-Korrekturgruppe ist fehlerhaft');
    }
  }

  Future<PostingGroupSummary> postInvoice({
    required String eventId,
    required String datum,
    required String beschreibung,
    required int kategorieId,
    required int totalCents,
    required int debitKontoId,
    required int creditKontoId,
    int? rechnungId,
    String? belegNr,
    String art = 'Einnahme',
  }) async {
    await ensureSchema();
    final String cleanEvent = eventId.trim();
    if (cleanEvent.isEmpty) {
      throw const PostingException('Quellereignis fehlt: invoice_event braucht eine stabile Ereignis-ID');
    }
    _requireDate(datum);
    if (totalCents <= 0) {
      throw const PostingException('Rechnungsbetrag muss mindestens einen Cent betragen');
    }
    if (art != 'Einnahme' && art != 'Ausgabe') {
      throw const PostingException('Art muss Einnahme oder Ausgabe sein');
    }
    await _requireKategorie(kategorieId);
    await _requireKonten(<int>[debitKontoId, creditKontoId]);

    final PostingGroupSummary? replay = await findInvoiceGroup(cleanEvent);
    if (replay != null) {
      return replay;
    }

    final String cleanBeschreibung = beschreibung.trim().isEmpty ? 'Rechnung $cleanEvent' : beschreibung.trim();
    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      final int firstId = await _insertLeg(
        tx,
        datum: datum,
        beschreibung: cleanBeschreibung,
        kategorieId: kategorieId,
        art: art,
        betragCents: totalCents,
        debitCents: totalCents,
        creditCents: 0,
        kontoId: debitKontoId,
        sollKontoId: debitKontoId,
        habenKontoId: null,
        rechnungId: rechnungId,
        belegNr: belegNr,
        sourceKind: PostingSource.invoiceEvent,
        sourceId: cleanEvent,
      );
      final int secondId = await _insertLeg(
        tx,
        datum: datum,
        beschreibung: cleanBeschreibung,
        kategorieId: kategorieId,
        art: art,
        betragCents: -totalCents,
        debitCents: 0,
        creditCents: totalCents,
        kontoId: creditKontoId,
        sollKontoId: null,
        habenKontoId: creditKontoId,
        rechnungId: rechnungId,
        belegNr: belegNr,
        sourceKind: PostingSource.invoiceEvent,
        sourceId: cleanEvent,
      );
      await _sealLegs(tx, <int>[firstId, secondId], firstId);
      await tx.send();
      return PostingGroupSummary(
        rootJournalId: firstId,
        sourceKind: PostingSource.invoiceEvent,
        sourceId: cleanEvent,
        debitCents: totalCents,
        creditCents: totalCents,
        legIds: <int>[firstId, secondId],
      );
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      if (_isUniqueViolation(error)) {
        final PostingGroupSummary? raced = await findInvoiceGroup(cleanEvent);
        if (raced != null) {
          return raced;
        }
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  /// Posts a settlement group for one confirmed bank transaction (or manual
  /// cash payment): one bank leg plus one counter leg per allocation, plus an
  /// excess leg when the signed amount exceeds the applied portions. Applied
  /// plus unapplied amounts reconcile to the signed bank amount. The
  /// authoritative settlement date is the bank booking/value date (or manual
  /// payment date for cash), preserved verbatim; the confirmation date is
  /// never substituted.
  Future<SettlementGroupSummary> postSettlement({
    required String sourceKind,
    required String sourceId,
    required int signedAmountCents,
    required String settlementDate,
    required int bankKontoId,
    required int counterKontoId,
    int? creditKontoId,
    required List<SettlementAllocationInput> allocations,
    int? bankTransactionId,
    int? receiptId,
    int? kategorieId,
    String? beschreibung,
  }) async {
    await ensureSchema();
    final String cleanSource = sourceId.trim();
    if (sourceKind != PostingSource.bankTransaction && sourceKind != PostingSource.cashPayment) {
      throw const PostingException('Unbekannte Ausgleichsquelle: nur bank_transaction oder cash_payment');
    }
    if (receiptId != null && (sourceKind != PostingSource.cashPayment || receiptId <= 0)) {
      throw const PostingException('Belegreferenz benötigt eine positive ID und eine Barzahlung');
    }
    if (cleanSource.isEmpty) {
      throw const PostingException('Quellereignis fehlt: Ausgleich braucht eine stabile Quell-ID');
    }
    if (signedAmountCents == 0) {
      throw const PostingException('Ausgleichsbetrag darf nicht null sein');
    }
    _requireDate(settlementDate);
    if (allocations.isEmpty) {
      throw const PostingException('Ausgleich braucht mindestens eine Zuordnung');
    }
    final int totalCents = signedAmountCents.abs();
    var appliedSum = 0;
    for (final SettlementAllocationInput allocation in allocations) {
      if (allocation.appliedCents <= 0) {
        throw const PostingException('Zugeordneter Betrag muss mindestens einen Cent betragen');
      }
      appliedSum += allocation.appliedCents;
    }
    if (appliedSum > totalCents) {
      throw const PostingException('Zugeordnete Beträge übersteigen den bestätigten Bankbetrag');
    }
    final int unappliedCents = totalCents - appliedSum;
    final int creditKonto = creditKontoId ?? counterKontoId;
    await _requireKonten(<int>[bankKontoId, counterKontoId, creditKonto]);

    final SettlementGroupSummary? replay = await findSettlementGroup(sourceKind, cleanSource);
    if (replay != null) {
      if (receiptId != null) {
        if (!await _journalReferencesReceipt(replay.rootJournalId, receiptId)) {
          throw const PostingException('Barzahlung wurde bereits ohne diesen Beleg gebucht');
        }
      }
      return replay;
    }
    if (bankTransactionId != null) {
      final SettlementGroupSummary? bankReplay = await findSettlementByBankRow(bankTransactionId);
      if (bankReplay != null) {
        return bankReplay;
      }
    }

    // Resolve and validate every allocation before opening the transaction:
    // sign direction, open balance ceiling, and the persisted EÜR snapshot.
    final List<_ResolvedAllocation> resolved = <_ResolvedAllocation>[];
    for (final SettlementAllocationInput allocation in allocations) {
      resolved.addAll(
        await _resolveAllocation(allocation, signedAmountCents: signedAmountCents, fallbackKategorie: kategorieId),
      );
    }

    final Map<int, List<_ResolvedAllocation>> resolvedByForderung = <int, List<_ResolvedAllocation>>{};
    for (final _ResolvedAllocation allocation in resolved) {
      if (allocation.forderungId == null) {
        continue;
      }
      resolvedByForderung.putIfAbsent(allocation.forderungId!, () => <_ResolvedAllocation>[]).add(allocation);
    }
    for (final List<_ResolvedAllocation> allocationsForItem in resolvedByForderung.values) {
      final _ResolvedAllocation first = allocationsForItem.first;
      final int applied = allocationsForItem.fold(
        0,
        (int total, _ResolvedAllocation item) => total + item.appliedCents,
      );
      if (applied > first.observedCents) {
        throw const PostingException('Zugeordnete Beträge übersteigen den offenen Saldo');
      }
    }

    final bool isReceipt = signedAmountCents > 0;
    final String cleanBeschreibung = beschreibung?.trim().isEmpty ?? true
        ? (isReceipt ? 'Zahlungseingang $cleanSource' : 'Zahlungsausgang $cleanSource')
        : beschreibung!.trim();
    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      if (receiptId != null) {
        final List<Map<String, Object?>> receipts = await tx.runSelect('SELECT id FROM belege WHERE id = ?', <Object?>[
          receiptId,
        ]);
        if (receipts.length != 1) throw const PostingException('Beleg nicht gefunden');
      }
      // Conditional open-item updates first: a lost race fails here and
      // leaves no provisional journal or allocation rows behind.
      for (final List<_ResolvedAllocation> allocationsForItem in resolvedByForderung.values) {
        final _ResolvedAllocation allocation = allocationsForItem.first;
        final int applied = allocationsForItem.fold(
          0,
          (int total, _ResolvedAllocation item) => total + item.appliedCents,
        );
        final int nextBalance = allocation.observedCents - applied;
        final String nextStatus = nextBalance == 0 ? 'bezahlt' : 'teilbezahlt';
        final int updated = await tx.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, aktualisiert_am = CURRENT_TIMESTAMP '
          'WHERE id = ? AND status = ? AND betrag = ?',
          <Object?>[
            money.fromCents(nextBalance),
            nextStatus,
            allocation.forderungId,
            allocation.observedStatus,
            money.fromCents(allocation.observedCents),
          ],
        );
        if (updated == 0) {
          throw const PostingException('Offener Posten wurde bereits verändert oder geschlossen');
        }
      }

      // Balanced legs: one bank leg plus one counter leg per allocation,
      // plus an excess leg for any unapplied remainder.
      final List<int> legIds = <int>[];
      final int bankDebit = isReceipt ? totalCents : 0;
      final int bankCredit = isReceipt ? 0 : totalCents;
      legIds.add(
        await _insertLeg(
          tx,
          datum: settlementDate,
          beschreibung: cleanBeschreibung,
          kategorieId: resolved.first.kategorieId,
          art: 'Zahlung',
          betragCents: isReceipt ? totalCents : -totalCents,
          debitCents: bankDebit,
          creditCents: bankCredit,
          kontoId: bankKontoId,
          sollKontoId: isReceipt ? bankKontoId : null,
          habenKontoId: isReceipt ? null : bankKontoId,
          sourceKind: sourceKind,
          sourceId: cleanSource,
        ),
      );
      for (final _ResolvedAllocation allocation in resolved) {
        final int legDebit = isReceipt ? 0 : allocation.appliedCents;
        final int legCredit = isReceipt ? allocation.appliedCents : 0;
        legIds.add(
          await _insertLeg(
            tx,
            datum: settlementDate,
            beschreibung: '$cleanBeschreibung (Posten ${allocation.forderungId ?? 'direkt'})',
            kategorieId: allocation.kategorieId,
            art: 'Zahlung',
            betragCents: isReceipt ? -allocation.appliedCents : allocation.appliedCents,
            debitCents: legDebit,
            creditCents: legCredit,
            kontoId: counterKontoId,
            sollKontoId: isReceipt ? null : counterKontoId,
            habenKontoId: isReceipt ? counterKontoId : null,
            sourceKind: sourceKind,
            sourceId: cleanSource,
          ),
        );
      }
      if (unappliedCents > 0) {
        legIds.add(
          await _insertLeg(
            tx,
            datum: settlementDate,
            beschreibung: '$cleanBeschreibung (offener Rest)',
            kategorieId: resolved.first.kategorieId,
            art: 'Zahlung',
            betragCents: isReceipt ? -unappliedCents : unappliedCents,
            debitCents: isReceipt ? 0 : unappliedCents,
            creditCents: isReceipt ? unappliedCents : 0,
            kontoId: creditKonto,
            sollKontoId: isReceipt ? null : creditKonto,
            habenKontoId: isReceipt ? creditKonto : null,
            sourceKind: sourceKind,
            sourceId: cleanSource,
          ),
        );
      }
      final int rootId = legIds.first;
      if (receiptId != null) {
        final int linked = await tx.runUpdate('UPDATE journal SET beleg_id = ? WHERE id = ?', <Object?>[
          receiptId,
          rootId,
        ]);
        if (linked != 1) throw const PostingException('Beleg konnte nicht mit der Barzahlung verknüpft werden');
      }
      await _sealLegs(tx, legIds, rootId);

      final int groupId = await tx.runInsert(
        'INSERT INTO settlement_groups (source_kind, source_id, bank_transaction_id, signed_amount_cents, '
        'settlement_date, unapplied_cents, group_root_journal_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          sourceKind,
          cleanSource,
          bankTransactionId,
          signedAmountCents,
          settlementDate,
          unappliedCents,
          rootId,
        ],
      );
      final List<int> allocationIds = <int>[];
      for (final _ResolvedAllocation allocation in resolved) {
        allocationIds.add(
          await tx.runInsert(
            'INSERT INTO settlement_allocations (group_id, forderung_id, applied_cents, settlement_date, '
            'kategorie_id, euer_zeile, direction, ust_satz) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              groupId,
              allocation.forderungId,
              allocation.appliedCents,
              settlementDate,
              allocation.kategorieId,
              allocation.euerZeile,
              allocation.direction,
              allocation.ustSatz,
            ],
          ),
        );
      }
      // Full payment clears the dunning trigger under the maintained
      // dunning contract; partial payments keep the current level.
      for (final List<_ResolvedAllocation> allocationsForItem in resolvedByForderung.values) {
        final _ResolvedAllocation allocation = allocationsForItem.first;
        final int applied = allocationsForItem.fold(
          0,
          (int total, _ResolvedAllocation item) => total + item.appliedCents,
        );
        if (allocation.observedCents - applied != 0 || allocation.rechnungId == null) {
          continue;
        }
        try {
          await tx.runUpdate('UPDATE rechnungen SET mahnstufe_aktuell = 0 WHERE id = ?', <Object?>[
            allocation.rechnungId,
          ]);
        } catch (_) {
          // ponytail: legacy rechnungen without the dunning column keep their level.
        }
      }
      if (bankTransactionId != null) {
        await tx.runUpdate('UPDATE bank_transaktionen SET status = ?, journal_id = ? WHERE id = ?', <Object?>[
          'gebucht',
          rootId,
          bankTransactionId,
        ]);
      }
      await tx.send();
      return SettlementGroupSummary(
        id: groupId,
        rootJournalId: rootId,
        sourceKind: sourceKind,
        sourceId: cleanSource,
        signedAmountCents: signedAmountCents,
        settlementDate: settlementDate,
        unappliedCents: unappliedCents,
        allocationIds: allocationIds,
      );
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      if (_isUniqueViolation(error)) {
        final SettlementGroupSummary? raced = await findSettlementGroup(sourceKind, cleanSource);
        if (raced != null) {
          if (receiptId != null) {
            if (!await _journalReferencesReceipt(raced.rootJournalId, receiptId)) {
              throw const PostingException('Barzahlung wurde bereits ohne diesen Beleg gebucht');
            }
          }
          return raced;
        }
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  /// Reverses a settlement group atomically: opposite legs, restored open
  /// balances, and negative reclassification allocations dated in the
  /// reversal period (the original period stays unchanged). A second
  /// reversal of the same group is rejected.
  Future<SettlementGroupSummary> reverseSettlementGroup({
    required String sourceKind,
    required String sourceId,
    required String reversalDate,
  }) async {
    await ensureSchema();
    _requireDate(reversalDate);
    final Map<String, Object?>? group = await _settlementGroupRow(sourceKind, sourceId.trim());
    if (group == null) {
      throw const PostingException('Ausgleichsgruppe nicht gefunden');
    }
    if (group['reversed_by_group_id'] != null) {
      throw const PostingException('Ausgleichsgruppe wurde bereits storniert');
    }
    final int groupId = (group['id']! as num).toInt();
    final int signedCents = (group['signed_amount_cents']! as num).toInt();
    final int unappliedCents = ((group['unapplied_cents'] as num?) ?? 0).toInt();
    final int rootId = (group['group_root_journal_id']! as num).toInt();
    final List<Map<String, Object?>> allocationRows = await executor.runSelect(
      'SELECT id, forderung_id, applied_cents, kategorie_id, euer_zeile, direction, ust_satz '
      'FROM settlement_allocations WHERE group_id = ? ORDER BY id',
      <Object?>[groupId],
    );
    final String stornoSource = '${sourceId.trim()}:storno';
    if (await findSettlementGroup(sourceKind, stornoSource) != null) {
      throw const PostingException('Ausgleichsgruppe wurde bereits storniert');
    }

    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      // Restore every open item by its reversed amount in the same
      // transaction; status falls back to offen when no other live
      // allocation remains on the item.
      for (final Map<String, Object?> row in allocationRows) {
        final int? forderungId = (row['forderung_id'] as num?)?.toInt();
        if (forderungId == null) {
          continue;
        }
        final int applied = (row['applied_cents']! as num).toInt();
        final List<Map<String, Object?>> current = await tx.runSelect(
          'SELECT betrag, anfangsbetrag FROM forderungen WHERE id = ?',
          <Object?>[forderungId],
        );
        if (current.isEmpty) {
          throw PostingException('Offener Posten #$forderungId nicht gefunden');
        }
        final int observed = money.toCents(money.formatBetrag(current.single['betrag'].toString()));
        final int restored = observed + applied;
        final List<Map<String, Object?>> others = await tx.runSelect(
          'SELECT COALESCE(SUM(a.applied_cents), 0) AS s FROM settlement_allocations a '
          'JOIN settlement_groups g ON g.id = a.group_id '
          'WHERE a.forderung_id = ? AND a.group_id != ? AND g.reversed_by_group_id IS NULL '
          'AND NOT EXISTS (SELECT 1 FROM settlement_groups r WHERE r.reversal_of_group_id = g.id)',
          <Object?>[forderungId, groupId],
        );
        final int otherLive = ((others.single['s'] as num?) ?? 0).toInt();
        final String nextStatus = otherLive == 0 ? 'offen' : 'teilbezahlt';
        await tx.runUpdate(
          'UPDATE forderungen SET betrag = ?, status = ?, aktualisiert_am = CURRENT_TIMESTAMP WHERE id = ?',
          <Object?>[money.fromCents(restored), nextStatus, forderungId],
        );
      }

      final List<Map<String, Object?>> legs = await tx.runSelect(
        'SELECT id, soll, haben, konto_id, soll_konto_id, haben_konto_id, kategorie_id, beleg_typ, beschreibung, ust_satz '
        'FROM journal WHERE gruppe_id = ? OR id = ? ORDER BY id',
        <Object?>[rootId, rootId],
      );
      if (legs.isEmpty) {
        throw PostingException('Buchungsgruppe #$rootId nicht gefunden');
      }
      final List<int> reversalLegIds = <int>[];
      for (final Map<String, Object?> leg in legs) {
        final int soll = money.toCents(money.formatBetrag((leg['soll'] ?? 0).toString()));
        final int haben = money.toCents(money.formatBetrag((leg['haben'] ?? 0).toString()));
        final int betrag = money.toCents(money.formatBetrag(await _legBetrag(tx, (leg['id']! as num).toInt())));
        reversalLegIds.add(
          await _insertLeg(
            tx,
            datum: reversalDate,
            beschreibung: 'Storno: ${leg['beschreibung'] ?? 'Ausgleich'}',
            kategorieId: (leg['kategorie_id'] as num?)?.toInt(),
            art: leg['beleg_typ']?.toString() ?? 'Zahlung',
            betragCents: -betrag,
            debitCents: haben,
            creditCents: soll,
            kontoId: (leg['konto_id'] as num?)?.toInt(),
            sollKontoId: (leg['haben_konto_id'] as num?)?.toInt(),
            habenKontoId: (leg['soll_konto_id'] as num?)?.toInt(),
            sourceKind: sourceKind,
            sourceId: stornoSource,
            reversalOfGroupId: rootId,
          ),
        );
      }
      final int reversalRoot = reversalLegIds.first;
      await _sealLegs(tx, reversalLegIds, reversalRoot);
      final int reversalGroupId = await tx.runInsert(
        'INSERT INTO settlement_groups (source_kind, source_id, signed_amount_cents, settlement_date, '
        'unapplied_cents, group_root_journal_id, reversal_of_group_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[sourceKind, stornoSource, -signedCents, reversalDate, -unappliedCents, reversalRoot, groupId],
      );
      final List<int> reversalAllocationIds = <int>[];
      for (final Map<String, Object?> row in allocationRows) {
        final int applied = (row['applied_cents']! as num).toInt();
        reversalAllocationIds.add(
          await tx.runInsert(
            'INSERT INTO settlement_allocations (group_id, forderung_id, applied_cents, settlement_date, '
            'kategorie_id, euer_zeile, direction, ust_satz) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              reversalGroupId,
              (row['forderung_id'] as num?)?.toInt(),
              -applied,
              reversalDate,
              (row['kategorie_id'] as num?)?.toInt(),
              (row['euer_zeile'] as num?)?.toInt(),
              row['direction']?.toString() ?? 'einnahme',
              row['ust_satz'],
            ],
          ),
        );
      }
      await tx.runUpdate('UPDATE settlement_groups SET reversed_by_group_id = ? WHERE id = ?', <Object?>[
        reversalGroupId,
        groupId,
      ]);
      await tx.send();
      return SettlementGroupSummary(
        id: reversalGroupId,
        rootJournalId: reversalRoot,
        sourceKind: sourceKind,
        sourceId: stornoSource,
        signedAmountCents: -signedCents,
        settlementDate: reversalDate,
        unappliedCents: -unappliedCents,
        allocationIds: reversalAllocationIds,
      );
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  /// Reverses an invoice-issue group with exact opposite legs. Groups with
  /// applied settlements are rejected until those settlements are reversed;
  /// linked input-tax claims are reversed alongside (never edited in place);
  /// a duplicate reversal is rejected and the original stays unchanged.
  Future<PostingGroupSummary> reverseInvoiceGroup({required String eventId, required String reversalDate}) async {
    await ensureSchema();
    _requireDate(reversalDate);
    final PostingGroupSummary? original = await findInvoiceGroup(eventId.trim());
    if (original == null) {
      throw const PostingException('Rechnungsgruppe nicht gefunden');
    }
    final List<Map<String, Object?>> legs = await executor.runSelect(
      'SELECT id, soll, haben, konto_id, soll_konto_id, haben_konto_id, kategorie_id, beleg_typ, beschreibung, '
      'rechnung_id FROM journal WHERE gruppe_id = ? OR id = ? ORDER BY id',
      <Object?>[original.rootJournalId, original.rootJournalId],
    );
    if (legs.isEmpty) {
      throw PostingException('Rechnungsgruppe #${original.rootJournalId} nicht gefunden');
    }
    final int? rechnungId = (legs.first['rechnung_id'] as num?)?.toInt();
    if (rechnungId != null) {
      final List<Map<String, Object?>> blocking = await executor.runSelect(
        'SELECT g.id AS group_id FROM settlement_allocations a '
        'JOIN settlement_groups g ON g.id = a.group_id '
        'JOIN forderungen f ON f.id = a.forderung_id '
        'WHERE f.rechnung_id = ? AND g.reversed_by_group_id IS NULL '
        'AND NOT EXISTS (SELECT 1 FROM settlement_groups r WHERE r.reversal_of_group_id = g.id) LIMIT 1',
        <Object?>[rechnungId],
      );
      if (blocking.isNotEmpty) {
        throw PostingException(
          'Rechnungsstorno blockiert: Ausgleichsgruppe ${blocking.single['group_id']} '
          'muss zuerst storniert werden',
        );
      }
    }
    final List<Map<String, Object?>> existing = await executor.runSelect(
      'SELECT id FROM journal WHERE reversal_of_group_id = ? LIMIT 1',
      <Object?>[original.rootJournalId],
    );
    if (existing.isNotEmpty) {
      throw const PostingException('Rechnungsgruppe wurde bereits storniert');
    }

    final String stornoSource = '${eventId.trim()}:storno';
    final TransactionExecutor tx = executor.beginTransaction();
    await tx.ensureOpen(_PostingTxUser());
    try {
      final List<int> reversalLegIds = <int>[];
      for (final Map<String, Object?> leg in legs) {
        final int soll = money.toCents(money.formatBetrag((leg['soll'] ?? 0).toString()));
        final int haben = money.toCents(money.formatBetrag((leg['haben'] ?? 0).toString()));
        final int betrag = money.toCents(money.formatBetrag(await _legBetrag(tx, (leg['id']! as num).toInt())));
        reversalLegIds.add(
          await _insertLeg(
            tx,
            datum: reversalDate,
            beschreibung: 'Storno: ${leg['beschreibung'] ?? 'Rechnung'}',
            kategorieId: (leg['kategorie_id'] as num?)?.toInt(),
            art: leg['beleg_typ']?.toString() ?? 'Einnahme',
            betragCents: -betrag,
            debitCents: haben,
            creditCents: soll,
            kontoId: (leg['konto_id'] as num?)?.toInt(),
            sollKontoId: (leg['haben_konto_id'] as num?)?.toInt(),
            habenKontoId: (leg['soll_konto_id'] as num?)?.toInt(),
            rechnungId: rechnungId,
            sourceKind: PostingSource.invoiceEvent,
            sourceId: stornoSource,
            reversalOfGroupId: original.rootJournalId,
          ),
        );
      }
      final int reversalRoot = reversalLegIds.first;
      await _sealLegs(tx, reversalLegIds, reversalRoot);
      // Linked input-tax-claim reversal: negated claim rows under the
      // maintained Vorsteuer contract, original rows stay unchanged.
      if (rechnungId != null) {
        try {
          final List<Map<String, Object?>> claims = await tx.runSelect(
            'SELECT betrag, faelligkeit, status FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
            <Object?>[rechnungId],
          );
          for (final Map<String, Object?> claim in claims) {
            final int cents = money.toCents(money.formatBetrag(claim['betrag'].toString()));
            await tx.runInsert(
              'INSERT INTO vorsteuer_ansprueche (rechnung_id, betrag, faelligkeit, status) VALUES (?, ?, ?, ?)',
              <Object?>[rechnungId, money.fromCents(-cents), claim['faelligkeit'] ?? reversalDate, 'offen'],
            );
          }
        } catch (_) {
          // ponytail: profiles without the claim table reverse the group only.
        }
      }
      await tx.send();
      return PostingGroupSummary(
        rootJournalId: reversalRoot,
        sourceKind: PostingSource.invoiceEvent,
        sourceId: stornoSource,
        debitCents: original.creditCents,
        creditCents: original.debitCents,
        legIds: reversalLegIds,
      );
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error is PostingException ? error : PostingException(error.toString()), stackTrace);
    }
  }

  Future<PostingGroupSummary?> findInvoiceGroup(String eventId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, gruppe_id, soll, haben FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
      <Object?>[PostingSource.invoiceEvent, eventId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _summarizeGroup(rows, PostingSource.invoiceEvent, eventId);
  }

  Future<SettlementGroupSummary?> findSettlementGroup(String sourceKind, String sourceId) async {
    final Map<String, Object?>? group = await _settlementGroupRow(sourceKind, sourceId);
    if (group == null) {
      return null;
    }
    return _summarizeSettlement(group);
  }

  Future<bool> _journalReferencesReceipt(int journalId, int receiptId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT beleg_id FROM journal WHERE id = ?',
      <Object?>[journalId],
    );
    return rows.length == 1 && rows.single['beleg_id'] == receiptId;
  }

  Future<SettlementGroupSummary?> findSettlementByBankRow(int bankTransactionId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM settlement_groups WHERE bank_transaction_id = ? ORDER BY id DESC LIMIT 1',
      <Object?>[bankTransactionId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _summarizeSettlement(rows.single);
  }

  Future<List<Map<String, Object?>>> groupLegs(int rootJournalId) {
    return executor.runSelect(
      'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, soll, haben, '
      'soll_konto_id, haben_konto_id, gruppe_id, rechnung_id, source_kind, source_id, reversal_of_group_id, '
      'legacy_unverified '
      'FROM journal WHERE gruppe_id = ? OR id = ? ORDER BY id',
      <Object?>[rootJournalId, rootJournalId],
    );
  }

  Future<List<StoredAllocation>> allocationsOf(int groupId) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, group_id, forderung_id, applied_cents, settlement_date, kategorie_id, euer_zeile, direction, ust_satz '
      'FROM settlement_allocations WHERE group_id = ? ORDER BY id',
      <Object?>[groupId],
    );
    return <StoredAllocation>[
      for (final Map<String, Object?> row in rows)
        StoredAllocation(
          id: (row['id']! as num).toInt(),
          groupId: (row['group_id']! as num).toInt(),
          forderungId: (row['forderung_id'] as num?)?.toInt(),
          appliedCents: (row['applied_cents']! as num).toInt(),
          settlementDate: row['settlement_date'].toString(),
          kategorieId: (row['kategorie_id'] as num?)?.toInt(),
          euerZeile: (row['euer_zeile'] as num?)?.toInt(),
          direction: row['direction']?.toString() ?? 'einnahme',
          ustSatz: row['ust_satz'] as num?,
        ),
    ];
  }

  Future<Map<String, Object?>?> _settlementGroupRow(String sourceKind, String sourceId) async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT * FROM settlement_groups WHERE source_kind = ? AND source_id = ? LIMIT 1',
        <Object?>[sourceKind, sourceId],
      );
      return rows.isEmpty ? null : rows.single;
    } catch (_) {
      return null;
    }
  }

  Future<SettlementGroupSummary> _summarizeSettlement(Map<String, Object?> group) async {
    final int groupId = (group['id']! as num).toInt();
    final List<StoredAllocation> allocations = await allocationsOf(groupId);
    return SettlementGroupSummary(
      id: groupId,
      rootJournalId: ((group['group_root_journal_id'] as num?) ?? 0).toInt(),
      sourceKind: group['source_kind'].toString(),
      sourceId: group['source_id'].toString(),
      signedAmountCents: (group['signed_amount_cents']! as num).toInt(),
      settlementDate: group['settlement_date'].toString(),
      unappliedCents: ((group['unapplied_cents'] as num?) ?? 0).toInt(),
      allocationIds: <int>[for (final StoredAllocation allocation in allocations) allocation.id],
    );
  }

  PostingGroupSummary _summarizeGroup(List<Map<String, Object?>> rows, String sourceKind, String sourceId) {
    var debit = 0;
    var credit = 0;
    var root = 0;
    final List<int> legIds = <int>[];
    for (final Map<String, Object?> row in rows) {
      final int id = (row['id']! as num).toInt();
      legIds.add(id);
      final int groupRef = ((row['gruppe_id'] as num?) ?? id).toInt();
      if (root == 0) {
        root = groupRef;
      }
      debit += money.toCents(money.formatBetrag((row['soll'] ?? 0).toString()));
      credit += money.toCents(money.formatBetrag((row['haben'] ?? 0).toString()));
    }
    return PostingGroupSummary(
      rootJournalId: root == 0 ? ((rows.first['id'] as num?) ?? 0).toInt() : root,
      sourceKind: sourceKind,
      sourceId: sourceId,
      debitCents: debit,
      creditCents: credit,
      legIds: legIds,
    );
  }

  /// Resolves one allocation against its open item and snapshots the
  /// invoice's persisted category/EÜR-line/tax proportion for cash-basis
  /// recognition. Direct cash allocations carry their own category.
  Future<List<_ResolvedAllocation>> _resolveAllocation(
    SettlementAllocationInput allocation, {
    required int signedAmountCents,
    int? fallbackKategorie,
  }) async {
    if (allocation.forderungId == null) {
      final int? kategorieId = allocation.kategorieId ?? fallbackKategorie;
      if (kategorieId == null) {
        throw const PostingException('Direkter Zahlungseingang braucht eine Kategorie');
      }
      final int zeile = allocation.euerZeile ?? await _kategorieZeile(kategorieId);
      return <_ResolvedAllocation>[
        _ResolvedAllocation(
          forderungId: null,
          appliedCents: allocation.appliedCents,
          observedCents: 0,
          observedStatus: 'offen',
          rechnungId: null,
          kategorieId: kategorieId,
          euerZeile: zeile,
          direction: allocation.isExpense ? 'ausgabe' : 'einnahme',
          ustSatz: null,
        ),
      ];
    }
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT f.id, f.status, f.betrag, f.partner_typ, f.rechnung_id, f.journal_id, '
      'j.kategorie_id AS journal_kategorie_id, j.ust_satz '
      'FROM forderungen f LEFT JOIN journal j ON j.id = f.journal_id WHERE f.id = ? LIMIT 1',
      <Object?>[allocation.forderungId],
    );
    if (rows.isEmpty) {
      throw PostingException('Offener Posten #${allocation.forderungId} nicht gefunden');
    }
    final Map<String, Object?> row = rows.single;
    final String? partnerTyp = row['partner_typ']?.toString();
    if (signedAmountCents > 0 && partnerTyp != 'kunde') {
      throw const PostingException('Positive Bankbuchung passt nur zu einer Kundenforderung');
    }
    if (signedAmountCents < 0 && partnerTyp != 'lieferant') {
      throw const PostingException('Negative Bankbuchung passt nur zu einer Lieferantenverbindlichkeit');
    }
    final int observed = money.toCents(money.formatBetrag(row['betrag'].toString()));
    final String status = row['status']?.toString() ?? 'offen';
    if ((status != 'offen' && status != 'teilbezahlt') || observed <= 0) {
      throw const PostingException('Offener Posten ist bereits ausgeglichen');
    }
    if (allocation.appliedCents > observed) {
      throw PostingException(
        'Zugeordnete ${money.fromCents(allocation.appliedCents)} übersteigen den offenen Saldo '
        '${money.fromCents(observed)}',
      );
    }
    final int? rechnungId = (row['rechnung_id'] as num?)?.toInt();
    if (allocation.kategorieId == null && rechnungId != null) {
      final List<Map<String, Object?>> invoiceRows = await executor.runSelect(
        'SELECT id, kategorie_id, ust_satz, betrag FROM journal WHERE rechnung_id = ? '
        'AND source_kind = ? AND legacy_unverified = 0 AND reversal_of_group_id IS NULL '
        'AND kategorie_id IS NOT NULL ORDER BY id',
        <Object?>[rechnungId, PostingSource.invoiceEvent],
      );
      final List<_InvoiceProportion> proportions = <_InvoiceProportion>[];
      for (final Map<String, Object?> invoiceRow in invoiceRows) {
        final int signedLineCents = money.toCents(money.formatBetrag(invoiceRow['betrag'].toString()));
        final bool matchesDirection = partnerTyp == 'lieferant' ? signedLineCents > 0 : signedLineCents < 0;
        if (!matchesDirection || signedLineCents == 0) {
          continue;
        }
        final int? lineId = (invoiceRow['id'] as num?)?.toInt();
        final int? lineKategorieId = (invoiceRow['kategorie_id'] as num?)?.toInt();
        if (lineId == null || lineKategorieId == null) {
          continue;
        }
        final Object? rateValue = invoiceRow['ust_satz'];
        final num? ustSatz = rateValue is num ? rateValue : num.tryParse(rateValue?.toString() ?? '');
        proportions.add(
          _InvoiceProportion(
            journalId: lineId,
            kategorieId: lineKategorieId,
            euerZeile: await _kategorieZeile(lineKategorieId),
            weightCents: signedLineCents.abs(),
            ustSatz: ustSatz,
          ),
        );
      }
      if (proportions.isNotEmpty) {
        late final Map<int, int> shares;
        try {
          shares = money.allocateProportionally<int>(
            amount: allocation.appliedCents,
            weights: <int, int>{for (final _InvoiceProportion item in proportions) item.journalId: item.weightCents},
            compareKeys: (int a, int b) => a.compareTo(b),
          );
        } on money.MoneyParseException catch (error, stackTrace) {
          Error.throwWithStackTrace(
            PostingException('Persistierte Rechnungsproportionen sind ungültig: ${error.message}'),
            stackTrace,
          );
        }
        return <_ResolvedAllocation>[
          for (final _InvoiceProportion item in proportions)
            if ((shares[item.journalId] ?? 0) > 0)
              _ResolvedAllocation(
                forderungId: (row['id']! as num).toInt(),
                appliedCents: shares[item.journalId]!,
                observedCents: observed,
                observedStatus: status,
                rechnungId: rechnungId,
                kategorieId: item.kategorieId,
                euerZeile: item.euerZeile,
                direction: partnerTyp == 'lieferant' ? 'ausgabe' : 'einnahme',
                ustSatz: item.ustSatz,
              ),
        ];
      }
    }
    int? kategorieId = allocation.kategorieId;
    kategorieId ??= await _issueKategorie((row['journal_id'] as num?)?.toInt());
    kategorieId ??= fallbackKategorie;
    if (kategorieId == null) {
      throw const PostingException('Ausgleich braucht eine Kategorie aus der zugehörigen Rechnung');
    }
    final int zeile = allocation.euerZeile ?? await _kategorieZeile(kategorieId);
    final Object? rateValue = row['ust_satz'];
    final num? ustSatz = (row['journal_kategorie_id'] as num?)?.toInt() == kategorieId
        ? rateValue is num
              ? rateValue
              : num.tryParse(rateValue?.toString() ?? '')
        : null;
    return <_ResolvedAllocation>[
      _ResolvedAllocation(
        forderungId: (row['id']! as num).toInt(),
        appliedCents: allocation.appliedCents,
        observedCents: observed,
        observedStatus: status,
        rechnungId: rechnungId,
        kategorieId: kategorieId,
        euerZeile: zeile,
        direction: partnerTyp == 'lieferant' ? 'ausgabe' : 'einnahme',
        ustSatz: ustSatz,
      ),
    ];
  }

  Future<void> _requireMileagePostingSchema(QueryExecutor query) async {
    try {
      final List<Map<String, Object?>> mappingColumns = await query.runSelect(
        'PRAGMA table_info(mileage_posting_account_mapping)',
        const <Object?>[],
      );
      final Set<String> mappingNames = <String>{
        for (final Map<String, Object?> row in mappingColumns) row['name'].toString(),
      };
      const Set<String> mappingRequired = <String>{'role', 'konto_id', 'kategorie_id', 'reviewed_at'};
      if (!mappingRequired.every(mappingNames.contains)) {
        throw const PostingException('Mileage-Kontenzuordnung fehlt; Schema v25 ist erforderlich');
      }
      final List<Map<String, Object?>> journalColumns = await query.runSelect(
        'PRAGMA table_info(journal)',
        const <Object?>[],
      );
      final Set<String> journalNames = <String>{
        for (final Map<String, Object?> row in journalColumns) row['name'].toString(),
      };
      const Set<String> snapshots = <String>{
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
      };
      if (!snapshots.every(journalNames.contains)) {
        throw const PostingException('Mileage-Journal-Snapshots fehlen; Schema v25 ist erforderlich');
      }
      final List<Map<String, Object?>> periodColumns = await query.runSelect(
        'PRAGMA table_info(mileage_posting_period_closures)',
        const <Object?>[],
      );
      const Set<String> periodRequired = <String>{'id', 'closed_from', 'closed_through', 'closed_at'};
      if (!periodRequired.every(
        (String column) => periodColumns.any((Map<String, Object?> row) => row['name'] == column),
      )) {
        throw const PostingException('Mileage-Zeitraumssperren fehlen; Schema v25 ist erforderlich');
      }
    } on PostingException {
      rethrow;
    } catch (error) {
      throw PostingException('Mileage-Buchungsschema ist nicht verfügbar: $error');
    }
  }

  Future<Map<String, Object?>?> _mileageTripRow(QueryExecutor query, String tripId) async {
    final List<Map<String, Object?>> rows = await query.runSelect(
      'SELECT id, trip_date, purpose, business_context, distance_hundredths_km, trip_kind, vehicle_source, '
      'vehicle_class, state, policy_id, policy_source, policy_version, policy_effective_from, policy_effective_to, '
      'calculated_amount, calculated_at, posting_event_id, created_at FROM mileage_trips WHERE id = ? LIMIT 1',
      <Object?>[tripId],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> _requireMileagePeriodOpen(QueryExecutor query, String tripDate) async {
    final List<Map<String, Object?>> closures = await query.runSelect(
      'SELECT id FROM mileage_posting_period_closures WHERE closed_from <= ? AND closed_through >= ? LIMIT 1',
      <Object?>[tripDate, tripDate],
    );
    if (closures.isNotEmpty) {
      throw const PostingException('Der Zeitraum des Fahrtdatums ist abgeschlossen');
    }
  }

  Future<List<Map<String, Object?>>> _mileageJournalRows(QueryExecutor query, String tripId) {
    return query.runSelect(
      'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, soll, haben, '
      'soll_konto_id, haben_konto_id, gruppe_id, legacy_unverified, immutable, source_kind, source_id, '
      'mileage_role_snapshot, mileage_kategorie_id_snapshot, mileage_kategorie_name_snapshot, '
      'mileage_kategorie_art_snapshot, mileage_euer_zeile_snapshot, mileage_kategorie_skr03_snapshot, '
      'mileage_kategorie_skr04_snapshot, '
      'mileage_mapping_status_snapshot, mileage_mapping_source_reference_snapshot, '
      'mileage_mapping_source_version_snapshot, mileage_mapping_history_id_snapshot '
      'FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
      <Object?>[PostingSource.mileageTrip, tripId],
    );
  }

  Map<String, Object?> _mileageTripEntityFacts(MileageTrip trip) => <String, Object?>{
    'id': trip.id,
    'trip_date': trip.tripDate,
    'purpose': trip.purpose,
    'business_context': trip.businessContext,
    'distance_hundredths_km': trip.distanceHundredthsKm,
    'trip_kind': mileageTripKindStorageValue(trip.tripKind),
    'vehicle_source': mileageVehicleSourceStorageValue(trip.vehicleSource),
    'vehicle_class': mileageVehicleClassStorageValue(trip.vehicleClass),
    'policy_id': trip.policyId,
    'policy_source': trip.policySource,
    'policy_version': trip.policyVersion,
    'policy_effective_from': trip.policyEffectiveFrom,
    'policy_effective_to': trip.policyEffectiveTo,
    'calculated_amount_cents': _mileageAmountCents(trip.calculatedAmount),
    'calculated_at': trip.calculatedAt,
    'created_at': trip.createdAt,
  };

  Map<String, Object?> _validatedMileageTripFacts(Map<String, Object?> trip) {
    final String tripId = trip['id']?.toString() ?? '';
    final String tripDate = trip['trip_date']?.toString() ?? '';
    _requireDate(tripDate);
    if (!_uuidPattern.hasMatch(tripId) ||
        tripDate.compareTo('2025-01-01') < 0 ||
        tripDate.compareTo('2026-12-31') > 0 ||
        (trip['purpose']?.toString().trim().isEmpty ?? true) ||
        (trip['business_context']?.toString().trim().isEmpty ?? true) ||
        trip['trip_kind'] != 'business_trip' ||
        trip['vehicle_source'] != 'private' ||
        (trip['vehicle_class'] != 'kraftwagen' && trip['vehicle_class'] != 'other_motor_vehicle') ||
        trip['policy_id'] != 'DE-private-business-travel/1' ||
        trip['policy_source'] != 'EStG-9-1-3-4a;BRKG-5-1-2;BMF-LStH-2026-A25-III-37;EÜR-2025-71' ||
        trip['policy_version'] != '1' ||
        trip['policy_effective_from'] != '2025-01-01' ||
        trip['policy_effective_to'] != '2026-12-31' ||
        (trip['calculated_at']?.toString().trim().isEmpty ?? true) ||
        DateTime.tryParse(trip['calculated_at'].toString()) == null) {
      throw const PostingException('Fahrt oder Berechnungssnapshot ist nicht buchungsfähig');
    }
    final int distance = (trip['distance_hundredths_km'] as num?)?.toInt() ?? 0;
    if (distance < 1 || distance > 999999999999) {
      throw const PostingException('Fahrtdistanz ist außerhalb des zulässigen Bereichs');
    }
    final int amountCents = _mileageAmountCents(trip['calculated_amount']);
    final int rate = trip['vehicle_class'] == 'kraftwagen' ? 30 : 20;
    final int expectedCents = (distance * rate + 50) ~/ 100;
    if (amountCents <= 0 || amountCents != expectedCents) {
      throw const PostingException('Fahrtbetrag entspricht nicht der freigegebenen Berechnung');
    }
    return <String, Object?>{
      'id': tripId,
      'trip_date': tripDate,
      'purpose': trip['purpose'].toString(),
      'business_context': trip['business_context'].toString(),
      'distance_hundredths_km': distance,
      'trip_kind': trip['trip_kind'].toString(),
      'vehicle_source': trip['vehicle_source'].toString(),
      'vehicle_class': trip['vehicle_class'].toString(),
      'policy_id': trip['policy_id'].toString(),
      'policy_source': trip['policy_source'].toString(),
      'policy_version': trip['policy_version'].toString(),
      'policy_effective_from': trip['policy_effective_from'].toString(),
      'policy_effective_to': trip['policy_effective_to'].toString(),
      'calculated_amount_cents': amountCents,
      'calculated_at': trip['calculated_at'].toString(),
      'created_at': trip['created_at']?.toString(),
    };
  }

  int _mileageAmountCents(Object? raw) {
    final String value = raw?.toString().trim() ?? '';
    final Match? match = RegExp(r'^([0-9]+)(?:[.]([0-9]{1,2}))?$').firstMatch(value);
    if (match == null) throw const PostingException('Fahrtbetrag ist kein gültiger Eurobetrag');
    final int euros = int.tryParse(match.group(1)!) ?? -1;
    final int cents = int.tryParse((match.group(2) ?? '').padRight(2, '0')) ?? -1;
    if (euros < 0 || cents < 0) throw const PostingException('Fahrtbetrag ist kein gültiger Eurobetrag');
    return euros * 100 + cents;
  }

  Future<Map<String, _MileagePostingRoleSnapshot>> _loadMileagePostingRoles(QueryExecutor query) async {
    final List<Map<String, Object?>> rows = await query.runSelect(
      'SELECT m.role, m.konto_id, m.kategorie_id, m.reviewed_at, a.kontoart, k.bezeichnung, k.art, '
      'k.euer_zeile, k.aktiv, k.konto_skr03, k.konto_skr04, k.mapping_status, k.catalog_source_reference, '
      'k.catalog_source_version, h.id AS mapping_history_id FROM mileage_posting_account_mapping m '
      'JOIN konten a ON a.id = m.konto_id JOIN kategorien k ON k.id = m.kategorie_id '
      'LEFT JOIN category_mapping_history h ON h.id = (SELECT MAX(h2.id) FROM category_mapping_history h2 '
      'WHERE h2.kategorie_id = k.id) ORDER BY m.role',
      const <Object?>[],
    );
    if (rows.length != 2) {
      throw const PostingException('Reisekosten- und Privateinlagekonto müssen ausdrücklich geprüft werden');
    }
    final Map<String, _MileagePostingRoleSnapshot> roles = <String, _MileagePostingRoleSnapshot>{};
    for (final Map<String, Object?> row in rows) {
      final String role = row['role']?.toString() ?? '';
      final int expectedLine = role == 'travel_expense' ? 71 : 107;
      final String expectedArt = role == 'travel_expense' ? 'ausgabe' : 'einnahme';
      final int? kontoId = (row['konto_id'] as num?)?.toInt();
      final int? kategorieId = (row['kategorie_id'] as num?)?.toInt();
      final int? euerLine = (row['euer_zeile'] as num?)?.toInt();
      final String status = row['mapping_status']?.toString() ?? '';
      final String? skr03 = row['konto_skr03']?.toString().trim();
      final String? skr04 = row['konto_skr04']?.toString().trim();
      final String? quelle = row['catalog_source_reference']?.toString().trim();
      final String? version = row['catalog_source_version']?.toString().trim();
      final int? historyId = (row['mapping_history_id'] as num?)?.toInt();
      final String reviewedAt = row['reviewed_at']?.toString().trim() ?? '';
      if ((role != 'travel_expense' && role != 'private_contribution') ||
          kontoId == null ||
          kategorieId == null ||
          roles.containsKey(role) ||
          row['kontoart'] != 'Sachkonto' ||
          row['aktiv'] == null ||
          (row['aktiv']! as num).toInt() != 1 ||
          row['art']?.toString().trim().toLowerCase() != expectedArt ||
          euerLine != expectedLine ||
          !_eligibleMapping.contains(status) ||
          ((skr03 ?? '').isEmpty && (skr04 ?? '').isEmpty) ||
          historyId == null ||
          historyId <= 0 ||
          reviewedAt.isEmpty ||
          DateTime.tryParse(reviewedAt) == null ||
          (status == 'catalog_verified' && ((quelle ?? '').isEmpty || (version ?? '').isEmpty)) ||
          (row['bezeichnung']?.toString().trim().isEmpty ?? true)) {
        throw PostingException('Die geprüfte Zuordnung für ${role.isEmpty ? 'Mileage' : role} ist ungültig');
      }
      roles[role] = _MileagePostingRoleSnapshot(
        role: role,
        kontoId: kontoId,
        kategorieId: kategorieId,
        categoryLabel: row['bezeichnung'].toString(),
        categoryArt: row['art'].toString(),
        euerLine: euerLine,
        kontoSkr03: skr03,
        kontoSkr04: skr04,
        mappingStatus: status,
        mappingSourceReference: quelle?.isEmpty == true ? null : quelle,
        mappingSourceVersion: version?.isEmpty == true ? null : version,
        mappingHistoryId: historyId,
      );
    }
    if (!roles.containsKey('travel_expense') || !roles.containsKey('private_contribution')) {
      throw const PostingException('Reisekosten- und Privateinlagekonto müssen ausdrücklich geprüft werden');
    }
    return roles;
  }

  Future<void> _writeMileageLegSnapshot(
    TransactionExecutor tx, {
    required int journalId,
    required _MileagePostingRoleSnapshot role,
  }) async {
    final int changed = await tx.runUpdate(
      'UPDATE journal SET mileage_role_snapshot = ?, mileage_kategorie_id_snapshot = ?, '
      'mileage_kategorie_name_snapshot = ?, mileage_kategorie_art_snapshot = ?, mileage_euer_zeile_snapshot = ?, '
      'mileage_kategorie_skr03_snapshot = ?, mileage_kategorie_skr04_snapshot = ?, '
      'mileage_mapping_status_snapshot = ?, '
      'mileage_mapping_source_reference_snapshot = ?, mileage_mapping_source_version_snapshot = ?, '
      'mileage_mapping_history_id_snapshot = ? WHERE id = ?',
      <Object?>[
        role.role,
        role.kategorieId,
        role.categoryLabel,
        role.categoryArt,
        role.euerLine,
        role.kontoSkr03,
        role.kontoSkr04,
        role.mappingStatus,
        role.mappingSourceReference,
        role.mappingSourceVersion,
        role.mappingHistoryId,
        journalId,
      ],
    );
    if (changed != 1) throw PostingException('Mileage-Snapshot für Journal $journalId fehlt');
  }

  Future<String> _verifyMileageReplay(
    Map<String, Object?> trip,
    List<Map<String, Object?>> rows,
    String tripId,
    Map<String, _MileagePostingRoleSnapshot> roles,
  ) async {
    if (trip['state'] != 'posted' || rows.length != 2) {
      throw const PostingException('Widersprüchliche oder unvollständige Mileage-Wiederholung');
    }
    final String eventId = trip['posting_event_id']?.toString() ?? '';
    if (!_uuidPattern.hasMatch(eventId) ||
        rows.any(
          (Map<String, Object?> row) =>
              row['source_kind'] != PostingSource.mileageTrip ||
              row['source_id'] != tripId ||
              row['immutable'] == null ||
              (row['immutable']! as num).toInt() != 1 ||
              (row['legacy_unverified'] as num?)?.toInt() != 0 ||
              row['datum'] != trip['trip_date'] ||
              row['beleg_typ'] != 'Ausgabe',
        )) {
      throw const PostingException('Widersprüchliche Mileage-Buchungsgruppe');
    }
    final int rootId = ((rows.first['gruppe_id'] as num?) ?? 0).toInt();
    final Map<String, Map<String, Object?>> byRole = <String, Map<String, Object?>>{};
    final int amountCents = _mileageAmountCents(trip['calculated_amount']);
    var debit = 0;
    var credit = 0;
    for (final Map<String, Object?> row in rows) {
      final int journalId = (row['id'] as num?)?.toInt() ?? 0;
      final int? groupId = (row['gruppe_id'] as num?)?.toInt();
      final String role = row['mileage_role_snapshot']?.toString() ?? '';
      if (journalId <= 0 ||
          groupId != rootId ||
          rootId <= 0 ||
          (journalId == rootId) != (groupId == journalId) ||
          byRole.containsKey(role) ||
          (role != 'travel_expense' && role != 'private_contribution') ||
          roles[role] == null ||
          !_mileageRowMatchesRole(row, roles[role]!)) {
        throw const PostingException('Mileage-Buchungsgruppe ist nicht atomar oder nicht eindeutig');
      }
      byRole[role] = row;
      final int rowDebit = money.toCents(money.formatBetrag((row['soll'] ?? 0).toString()));
      final int rowCredit = money.toCents(money.formatBetrag((row['haben'] ?? 0).toString()));
      debit += rowDebit;
      credit += rowCredit;
      if (rowDebit < 0 || rowCredit < 0 || (rowDebit == 0) == (rowCredit == 0)) {
        throw const PostingException('Mileage-Journalzeile braucht genau eine Buchungsseite');
      }
      if (role == 'travel_expense') {
        if (rowDebit != amountCents ||
            rowCredit != 0 ||
            (row['soll_konto_id'] as num?)?.toInt() != (row['konto_id'] as num?)?.toInt() ||
            row['haben_konto_id'] != null ||
            (row['betrag'] == null || money.toCents(money.formatBetrag(row['betrag'].toString())) != amountCents) ||
            (row['mileage_euer_zeile_snapshot'] as num?)?.toInt() != 71) {
          throw const PostingException('Mileage-Aufwandszeile ist nicht als Soll der Zeile 71 gebucht');
        }
      } else if (rowDebit != 0 ||
          rowCredit != amountCents ||
          (row['haben_konto_id'] as num?)?.toInt() != (row['konto_id'] as num?)?.toInt() ||
          row['soll_konto_id'] != null ||
          (row['betrag'] == null || money.toCents(money.formatBetrag(row['betrag'].toString())) != -amountCents) ||
          (row['mileage_euer_zeile_snapshot'] as num?)?.toInt() != 107) {
        throw const PostingException('Mileage-Privateinlage ist nicht als Haben der Zeile 107 gebucht');
      }
    }
    if (byRole.length != 2 ||
        rootId != ((byRole['travel_expense']?['id'] as num?)?.toInt() ?? 0) ||
        debit != amountCents ||
        credit != amountCents) {
      throw const PostingException('Mileage-Buchungsgruppe ist nicht ausgeglichen');
    }
    return eventId;
  }

  bool _mileageRowMatchesRole(Map<String, Object?> row, _MileagePostingRoleSnapshot role) {
    bool sameNullableText(String column, String? expected) => row[column]?.toString() == expected;
    return row['mileage_role_snapshot'] == role.role &&
        (row['konto_id'] as num?)?.toInt() == role.kontoId &&
        (row['kategorie_id'] as num?)?.toInt() == role.kategorieId &&
        (row['mileage_kategorie_id_snapshot'] as num?)?.toInt() == role.kategorieId &&
        row['mileage_kategorie_name_snapshot']?.toString() == role.categoryLabel &&
        row['mileage_kategorie_art_snapshot']?.toString() == role.categoryArt &&
        (row['mileage_euer_zeile_snapshot'] as num?)?.toInt() == role.euerLine &&
        sameNullableText('mileage_kategorie_skr03_snapshot', role.kontoSkr03) &&
        sameNullableText('mileage_kategorie_skr04_snapshot', role.kontoSkr04) &&
        row['mileage_mapping_status_snapshot'] == role.mappingStatus &&
        sameNullableText('mileage_mapping_source_reference_snapshot', role.mappingSourceReference) &&
        sameNullableText('mileage_mapping_source_version_snapshot', role.mappingSourceVersion) &&
        (row['mileage_mapping_history_id_snapshot'] as num?)?.toInt() == role.mappingHistoryId &&
        _eligibleMapping.contains(role.mappingStatus) &&
        role.categoryLabel.trim().isNotEmpty &&
        role.categoryArt.trim().toLowerCase() == (role.role == 'travel_expense' ? 'ausgabe' : 'einnahme') &&
        role.euerLine == (role.role == 'travel_expense' ? 71 : 107) &&
        (role.kontoSkr03?.trim().isNotEmpty == true || role.kontoSkr04?.trim().isNotEmpty == true);
  }

  static String _newMileageEventId() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256), growable: false);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes.map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<int?> _issueKategorie(int? journalId) async {
    if (journalId == null) {
      return null;
    }
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT kategorie_id FROM journal WHERE id = ? LIMIT 1',
        <Object?>[journalId],
      );
      return rows.isEmpty ? null : (rows.single['kategorie_id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<int> _kategorieZeile(int kategorieId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT euer_zeile, mapping_status FROM kategorien WHERE id = ? LIMIT 1',
      <Object?>[kategorieId],
    );
    if (rows.isEmpty) {
      throw PostingException(
        'Kategorie $kategorieId fehlt: Mapping-Prüfung für Kategorie $kategorieId öffnen und Konten zuordnen',
      );
    }
    final int? zeile = (rows.single['euer_zeile'] as num?)?.toInt();
    final String? status = rows.single['mapping_status']?.toString();
    if (zeile == null || status == null || !_eligibleMapping.contains(status)) {
      throw PostingException('Kategorie $kategorieId erfordert eine Mapping-Prüfung, bevor sie Buchungen steuern kann');
    }
    return zeile;
  }

  Future<void> _requireKategorie(int kategorieId) async {
    await _kategorieZeile(kategorieId);
  }

  Future<void> _requireKonten(List<int> kontoIds) async {
    for (final int kontoId in kontoIds) {
      if (kontoId <= 0) {
        throw PostingException('Konto $kontoId fehlt: Gegenkonto in den Stammdaten anlegen und Buchung wiederholen');
      }
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM konten WHERE id = ? LIMIT 1',
        <Object?>[kontoId],
      );
      if (rows.isEmpty) {
        throw PostingException('Konto $kontoId fehlt: Gegenkonto in den Stammdaten anlegen und Buchung wiederholen');
      }
    }
  }

  /// Inserts one balanced leg: exactly one non-zero side, explicit account,
  /// source identity, and a durable non-legacy marker. `betrag` keeps the
  /// signed leg effect for legacy readers; `soll`/`haben` carry the
  /// double-entry sides in integer cents. Legs are inserted mutable so the
  /// group root can be assigned; callers seal them via [_sealLegs] (GoBD
  /// triggers reject updates once `immutable = 1`).
  Future<int> _insertLeg(
    TransactionExecutor tx, {
    required String datum,
    required String beschreibung,
    required int? kategorieId,
    required String art,
    required int betragCents,
    required int debitCents,
    required int creditCents,
    required int? kontoId,
    required int? sollKontoId,
    required int? habenKontoId,
    int? rechnungId,
    String? belegNr,
    required String sourceKind,
    required String sourceId,
    int? reversalOfGroupId,
  }) async {
    final bool hasDebit = debitCents > 0;
    final bool hasCredit = creditCents > 0;
    if (hasDebit == hasCredit) {
      throw const PostingException('Jede Buchungszeile braucht genau eine belegte Seite (Soll oder Haben)');
    }
    if (kontoId == null && sollKontoId == null && habenKontoId == null) {
      throw const PostingException('Jede Buchungszeile braucht ein explizites Konto');
    }
    return tx.runInsert(
      'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, soll, haben, '
      'soll_konto_id, haben_konto_id, rechnung_id, beleg_nr, immutable, legacy_unverified, source_kind, source_id, '
      'reversal_of_group_id, erstellungsdatum) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, CURRENT_TIMESTAMP)',
      <Object?>[
        datum,
        beschreibung,
        kategorieId,
        money.fromCents(betragCents),
        art,
        kontoId,
        money.fromCents(debitCents),
        money.fromCents(creditCents),
        sollKontoId,
        habenKontoId,
        rechnungId,
        belegNr,
        sourceKind,
        sourceId,
        reversalOfGroupId,
      ],
    );
  }

  /// Assigns the group root and seals every leg immutable. Both updates run
  /// while the rows are still mutable; afterwards GoBD triggers protect them.
  Future<void> _sealLegs(TransactionExecutor tx, List<int> legIds, int rootId) async {
    final String placeholders = legIds.map((_) => '?').join(', ');
    await tx.runUpdate('UPDATE journal SET gruppe_id = ? WHERE id IN ($placeholders)', <Object?>[rootId, ...legIds]);
    await tx.runUpdate('UPDATE journal SET immutable = 1 WHERE id IN ($placeholders)', <Object?>[...legIds]);
  }

  Future<String> _legBetrag(TransactionExecutor tx, int legId) async {
    final List<Map<String, Object?>> rows = await tx.runSelect('SELECT betrag FROM journal WHERE id = ?', <Object?>[
      legId,
    ]);
    return rows.isEmpty ? '0.00' : rows.single['betrag'].toString();
  }

  void _requireDate(String datum) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datum)) {
      throw const PostingException('Datum muss im Format JJJJ-MM-TT vorliegen');
    }
    final List<String> parts = datum.split('-');
    final int year = int.parse(parts[0]);
    final int month = int.parse(parts[1]);
    final int day = int.parse(parts[2]);
    final DateTime parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const PostingException('Datum ist kein gültiger Kalendertag');
    }
  }

  Future<void> _addColumnIfMissing(String table, String name, String definition) async {
    final List<Map<String, Object?>> columns = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (columns.any((Map<String, Object?> column) => column['name'] == name)) {
      return;
    }
    await executor.runCustom('ALTER TABLE $table ADD COLUMN $name $definition');
  }

  static bool _isUniqueViolation(Object error) {
    final String message = error.toString().toUpperCase();
    return message.contains('UNIQUE') || message.contains('CONSTRAINT');
  }
}

class _MileagePostingRoleSnapshot {
  const _MileagePostingRoleSnapshot({
    required this.role,
    required this.kontoId,
    required this.kategorieId,
    required this.categoryLabel,
    required this.categoryArt,
    required this.euerLine,
    required this.kontoSkr03,
    required this.kontoSkr04,
    required this.mappingStatus,
    required this.mappingSourceReference,
    required this.mappingSourceVersion,
    required this.mappingHistoryId,
  });

  final String role;
  final int kontoId;
  final int kategorieId;
  final String categoryLabel;
  final String categoryArt;
  final int? euerLine;
  final String? kontoSkr03;
  final String? kontoSkr04;
  final String mappingStatus;
  final String? mappingSourceReference;
  final String? mappingSourceVersion;
  final int mappingHistoryId;
}

class _ResolvedAllocation {
  const _ResolvedAllocation({
    required this.forderungId,
    required this.appliedCents,
    required this.observedCents,
    required this.observedStatus,
    required this.rechnungId,
    required this.kategorieId,
    required this.euerZeile,
    required this.direction,
    required this.ustSatz,
  });

  final int? forderungId;
  final int appliedCents;
  final int observedCents;
  final String observedStatus;
  final int? rechnungId;
  final int kategorieId;
  final int euerZeile;
  final String direction;
  final num? ustSatz;
}

class _InvoiceProportion {
  const _InvoiceProportion({
    required this.journalId,
    required this.kategorieId,
    required this.euerZeile,
    required this.weightCents,
    required this.ustSatz,
  });

  final int journalId;
  final int kategorieId;
  final int euerZeile;
  final int weightCents;
  final num? ustSatz;
}

class _PostingTxUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

const String _settlementGroupsSql = '''
CREATE TABLE IF NOT EXISTS settlement_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_kind TEXT NOT NULL,
  source_id TEXT NOT NULL,
  bank_transaction_id INTEGER REFERENCES bank_transaktionen(id),
  signed_amount_cents INTEGER NOT NULL CHECK (signed_amount_cents != 0),
  settlement_date TEXT NOT NULL,
  unapplied_cents INTEGER NOT NULL DEFAULT 0,
  group_root_journal_id INTEGER NOT NULL REFERENCES journal(id),
  reversal_of_group_id INTEGER REFERENCES settlement_groups(id),
  reversed_by_group_id INTEGER REFERENCES settlement_groups(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (source_kind, source_id)
)''';

const String _settlementAllocationsSql = '''
CREATE TABLE IF NOT EXISTS settlement_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL REFERENCES settlement_groups(id) ON DELETE CASCADE,
  forderung_id INTEGER REFERENCES forderungen(id),
  applied_cents INTEGER NOT NULL CHECK (applied_cents != 0),
  settlement_date TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  euer_zeile INTEGER,
  direction TEXT NOT NULL DEFAULT 'einnahme' CHECK (direction IN ('einnahme', 'ausgabe')),
  ust_satz NUMERIC(5,2),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''';

const String _statutoryTimingRulesSql = '''
CREATE TABLE IF NOT EXISTS statutory_timing_rules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rule_id TEXT NOT NULL,
  rule_version TEXT NOT NULL,
  legal_basis TEXT NOT NULL,
  affected_year INTEGER NOT NULL,
  approver TEXT NOT NULL,
  source_trace TEXT NOT NULL,
  settlement_group_id INTEGER NOT NULL REFERENCES settlement_groups(id) ON DELETE CASCADE,
  attributed_year INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (rule_id, rule_version, settlement_group_id)
)''';

/// Riverpod wiring for the posting boundary. No BLoC, no new GetIt wiring.
final postingGroupServiceProvider = Provider<PostingGroupService>((ref) {
  return PostingGroupService(ref.watch(appDatabaseProvider).executor);
});
