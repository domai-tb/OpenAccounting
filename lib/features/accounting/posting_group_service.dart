import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

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
  PostingGroupService(this.executor);

  final QueryExecutor executor;

  static const Set<String> _eligibleMapping = <String>{'catalog_verified', 'user_confirmed'};

  /// Idempotent DDL for the posting boundary (mirrors migration v19).
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
    int? kategorieId,
    String? beschreibung,
  }) async {
    await ensureSchema();
    final String cleanSource = sourceId.trim();
    if (sourceKind != PostingSource.bankTransaction && sourceKind != PostingSource.cashPayment) {
      throw const PostingException('Unbekannte Ausgleichsquelle: nur bank_transaction oder cash_payment');
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
