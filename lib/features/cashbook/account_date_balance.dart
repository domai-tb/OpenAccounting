import 'dart:convert';

/// Why an account/date cash balance cannot be used.
enum CashbookBalanceUnavailableReason {
  invalidSelection,
  openingSourceUnavailable,
  openingBalanceMissing,
  openingBalanceAmbiguous,
  openingBalanceUnverified,
  openingCorroborationConflict,
  historyCoverageIncomplete,
  currencyMismatch,
  invalidCashMovement,
  duplicateCashMovement,
  ambiguousOpeningCutover,
  missingSourceReference,
  balanceOverflow,
}

/// The posting state supplied by the committed cash-posting boundary.
enum CashbookMovementStatus { draft, committed, cancelled }

/// The source kind of a candidate posting group.
enum CashbookMovementKind { cashPayment, other }

/// Explicit company, account, local date, and account currency requested for a balance.
class CashbookBalanceRequest {
  const CashbookBalanceRequest({
    required this.companyId,
    required this.accountId,
    required this.asOfDate,
    required this.currencyCode,
  });

  final String companyId;
  final String accountId;
  final DateTime asOfDate;

  /// Currency code from the selected cash account; values are compared without conversion.
  final String currencyCode;
}

/// Opening-event and history coverage supplied by trusted application sources.
class CashbookBalanceEvidence {
  const CashbookBalanceEvidence({
    required this.openingSourceAvailable,
    required this.historyCoverageComplete,
    required this.openingBalances,
    required this.movements,
  });

  final bool openingSourceAvailable;
  final bool historyCoverageComplete;
  final List<CashbookOpeningBalance> openingBalances;
  final List<CashbookMovementEvidence> movements;
}

/// A verified opening balance as of an exact point in time.
class CashbookOpeningBalance {
  const CashbookOpeningBalance({
    required this.identity,
    required this.companyId,
    required this.accountId,
    required this.effectiveAt,
    required this.balanceCents,
    required this.currencyCode,
    required this.sourceReference,
    required this.verified,
    required this.identityUnambiguous,
    this.corroboratingSaldoCents,
  });

  final String identity;
  final String companyId;
  final String accountId;
  final DateTime effectiveAt;

  /// Integer minor units using the app's two-decimal convention (100 cents per currency unit).
  final int balanceCents;
  final String currencyCode;
  final String sourceReference;
  final bool verified;
  final bool identityUnambiguous;

  /// Optional setup metadata checked for agreement and never added to the balance.
  final int? corroboratingSaldoCents;
}

/// A candidate from the balanced cash-posting boundary.
class CashbookMovementEvidence {
  const CashbookMovementEvidence({
    required this.postingGroupId,
    required this.sourceReference,
    required this.companyId,
    required this.accountId,
    required this.effectiveAt,
    required this.amountCents,
    required this.currencyCode,
    required this.status,
    required this.kind,
    required this.balanced,
    required this.linkedToAccount,
    this.openingIdentity,
  });

  final String? postingGroupId;
  final String? sourceReference;
  final String? companyId;
  final String? accountId;
  final DateTime? effectiveAt;

  /// Signed cash effect in integer minor units using the app's two-decimal convention.
  /// Receipts are positive and payments negative.
  final int? amountCents;

  final String? currencyCode;
  final CashbookMovementStatus status;
  final CashbookMovementKind kind;
  final bool balanced;
  final bool linkedToAccount;

  /// Set only when the source identifies this row as the supplied opening event itself.
  final String? openingIdentity;
}

/// One account/date balance, or an unavailable result with no usable amount.
class CashbookBalanceResult {
  const CashbookBalanceResult._({
    required this.companyId,
    required this.accountId,
    required this.asOfDate,
    required this.balanceCents,
    required this.currencyCode,
    required this.sourceReference,
    required this.sourceReferences,
    required this.complete,
    required this.unavailableReason,
  });

  factory CashbookBalanceResult.available({
    required String companyId,
    required String accountId,
    required DateTime asOfDate,
    required int balanceCents,
    required String currencyCode,
    required String sourceReference,
    required List<String> sourceReferences,
  }) {
    return CashbookBalanceResult._(
      companyId: companyId,
      accountId: accountId,
      asOfDate: asOfDate,
      balanceCents: balanceCents,
      currencyCode: currencyCode,
      sourceReference: sourceReference,
      sourceReferences: List<String>.unmodifiable(sourceReferences),
      complete: true,
      unavailableReason: null,
    );
  }

  factory CashbookBalanceResult.unavailable({
    required String companyId,
    required String accountId,
    required DateTime asOfDate,
    required String currencyCode,
    required String sourceReference,
    required List<String> sourceReferences,
    required CashbookBalanceUnavailableReason reason,
  }) {
    return CashbookBalanceResult._(
      companyId: companyId,
      accountId: accountId,
      asOfDate: asOfDate,
      balanceCents: null,
      currencyCode: currencyCode,
      sourceReference: sourceReference,
      sourceReferences: List<String>.unmodifiable(sourceReferences),
      complete: false,
      unavailableReason: reason,
    );
  }

  final String companyId;
  final String accountId;
  final DateTime asOfDate;

  /// Exact integer minor units using the app's two-decimal convention.
  final int? balanceCents;
  final String currencyCode;
  final String sourceReference;
  final List<String> sourceReferences;
  final bool complete;
  final CashbookBalanceUnavailableReason? unavailableReason;
}

/// Produces exact account/date balances from a verified opening and posted cash groups.
class CashbookBalanceCalculator {
  const CashbookBalanceCalculator();

  static final BigInt _minimumCents = BigInt.from(-9223372036854775807) - BigInt.one;
  static final BigInt _maximumCents = BigInt.from(9223372036854775807);

  CashbookBalanceResult calculate(CashbookBalanceRequest request, CashbookBalanceEvidence evidence) {
    final DateTime asOfDate = _endOfLocalDay(request.asOfDate);
    final List<String> sourceReferences = <String>[];

    CashbookBalanceResult unavailable(CashbookBalanceUnavailableReason reason) {
      return CashbookBalanceResult.unavailable(
        companyId: request.companyId,
        accountId: request.accountId,
        asOfDate: asOfDate,
        currencyCode: request.currencyCode,
        sourceReference: _sourceReference(request, sourceReferences),
        sourceReferences: sourceReferences,
        reason: reason,
      );
    }

    if (request.companyId.trim().isEmpty || request.accountId.trim().isEmpty) {
      return unavailable(CashbookBalanceUnavailableReason.invalidSelection);
    }
    if (request.currencyCode.trim().isEmpty) {
      return unavailable(CashbookBalanceUnavailableReason.invalidSelection);
    }
    if (!evidence.openingSourceAvailable) {
      return unavailable(CashbookBalanceUnavailableReason.openingSourceUnavailable);
    }
    if (evidence.openingBalances.isEmpty) {
      return unavailable(CashbookBalanceUnavailableReason.openingBalanceMissing);
    }
    if (evidence.openingBalances.length != 1) {
      for (final CashbookOpeningBalance opening in evidence.openingBalances) {
        if (opening.sourceReference.trim().isNotEmpty) sourceReferences.add(opening.sourceReference);
      }
      return unavailable(CashbookBalanceUnavailableReason.openingBalanceAmbiguous);
    }

    final CashbookOpeningBalance opening = evidence.openingBalances.single;
    if (!opening.verified) return unavailable(CashbookBalanceUnavailableReason.openingBalanceUnverified);
    if (!opening.identityUnambiguous || opening.identity.trim().isEmpty) {
      return unavailable(CashbookBalanceUnavailableReason.openingBalanceAmbiguous);
    }
    if (opening.companyId != request.companyId || opening.accountId != request.accountId) {
      return unavailable(CashbookBalanceUnavailableReason.openingBalanceAmbiguous);
    }
    final BigInt openingCents = BigInt.from(opening.balanceCents);
    if (openingCents < _minimumCents || openingCents > _maximumCents) {
      return unavailable(CashbookBalanceUnavailableReason.balanceOverflow);
    }
    if (opening.effectiveAt.isAfter(asOfDate)) {
      return unavailable(CashbookBalanceUnavailableReason.openingBalanceMissing);
    }
    if (opening.currencyCode != request.currencyCode) {
      return unavailable(CashbookBalanceUnavailableReason.currencyMismatch);
    }
    if (opening.sourceReference.trim().isEmpty) {
      return unavailable(CashbookBalanceUnavailableReason.missingSourceReference);
    }
    sourceReferences.add(opening.sourceReference);
    if (opening.corroboratingSaldoCents != null && opening.corroboratingSaldoCents != opening.balanceCents) {
      return unavailable(CashbookBalanceUnavailableReason.openingCorroborationConflict);
    }
    if (!evidence.historyCoverageComplete) {
      return unavailable(CashbookBalanceUnavailableReason.historyCoverageIncomplete);
    }

    final List<CashbookMovementEvidence> candidates =
        evidence.movements
            .where(
              (CashbookMovementEvidence movement) =>
                  movement.kind == CashbookMovementKind.cashPayment &&
                  movement.status == CashbookMovementStatus.committed &&
                  (movement.companyId == null || movement.companyId == request.companyId) &&
                  (movement.accountId == null || movement.accountId == request.accountId),
            )
            .toList()
          ..sort((CashbookMovementEvidence left, CashbookMovementEvidence right) {
            final String leftId = left.postingGroupId ?? '';
            final String rightId = right.postingGroupId ?? '';
            return leftId.compareTo(rightId);
          });

    BigInt balance = BigInt.from(opening.balanceCents);
    final Set<String> postingGroupIds = <String>{};

    for (final CashbookMovementEvidence movement in candidates) {
      if (movement.effectiveAt != null && movement.effectiveAt!.isAfter(asOfDate)) continue;
      if (movement.companyId != null && movement.companyId != request.companyId) continue;
      if (movement.accountId != null && movement.accountId != request.accountId) continue;
      if (movement.companyId == null || movement.accountId == null || movement.effectiveAt == null) {
        return unavailable(CashbookBalanceUnavailableReason.invalidCashMovement);
      }
      if (movement.openingIdentity != null) {
        if (movement.sourceReference != null && movement.sourceReference!.trim().isNotEmpty) {
          sourceReferences.add(movement.sourceReference!);
        }
        return unavailable(CashbookBalanceUnavailableReason.openingBalanceAmbiguous);
      }
      if (movement.effectiveAt!.isBefore(opening.effectiveAt)) continue;
      if (movement.effectiveAt!.isAtSameMomentAs(opening.effectiveAt)) {
        if (movement.sourceReference != null && movement.sourceReference!.trim().isNotEmpty) {
          sourceReferences.add(movement.sourceReference!);
        }
        return unavailable(CashbookBalanceUnavailableReason.ambiguousOpeningCutover);
      }
      if (!movement.balanced || !movement.linkedToAccount) {
        if (movement.sourceReference != null && movement.sourceReference!.trim().isNotEmpty) {
          sourceReferences.add(movement.sourceReference!);
        }
        return unavailable(CashbookBalanceUnavailableReason.invalidCashMovement);
      }
      if (movement.postingGroupId == null || movement.postingGroupId!.trim().isEmpty) {
        return unavailable(CashbookBalanceUnavailableReason.invalidCashMovement);
      }
      if (!postingGroupIds.add(movement.postingGroupId!)) {
        if (movement.sourceReference != null && movement.sourceReference!.trim().isNotEmpty) {
          sourceReferences.add(movement.sourceReference!);
        }
        return unavailable(CashbookBalanceUnavailableReason.duplicateCashMovement);
      }
      if (movement.currencyCode != request.currencyCode) {
        if (movement.sourceReference != null && movement.sourceReference!.trim().isNotEmpty) {
          sourceReferences.add(movement.sourceReference!);
        }
        return unavailable(CashbookBalanceUnavailableReason.currencyMismatch);
      }
      if (movement.sourceReference == null || movement.sourceReference!.trim().isEmpty) {
        return unavailable(CashbookBalanceUnavailableReason.missingSourceReference);
      }
      if (movement.amountCents == null) {
        return unavailable(CashbookBalanceUnavailableReason.invalidCashMovement);
      }

      final BigInt movementAmountCents = BigInt.from(movement.amountCents!);
      if (movementAmountCents < _minimumCents || movementAmountCents > _maximumCents) {
        return unavailable(CashbookBalanceUnavailableReason.balanceOverflow);
      }
      sourceReferences.add(movement.sourceReference!);
      balance += movementAmountCents;
      if (balance < _minimumCents || balance > _maximumCents) {
        return unavailable(CashbookBalanceUnavailableReason.balanceOverflow);
      }
    }

    sourceReferences.sort();
    return CashbookBalanceResult.available(
      companyId: request.companyId,
      accountId: request.accountId,
      asOfDate: asOfDate,
      balanceCents: balance.toInt(),
      currencyCode: request.currencyCode,
      sourceReference: _sourceReference(request, sourceReferences),
      sourceReferences: sourceReferences,
    );
  }

  DateTime _endOfLocalDay(DateTime date) => DateTime(date.year, date.month, date.day, 23, 59, 59, 999, 999);

  String _sourceReference(CashbookBalanceRequest request, List<String> sourceReferences) {
    final List<String> references = List<String>.of(sourceReferences)..sort();
    return 'cashbook-balance:${jsonEncode(<String>[request.companyId, request.accountId, _dateKey(request.asOfDate), request.currencyCode, ...references])}';
  }

  String _dateKey(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
