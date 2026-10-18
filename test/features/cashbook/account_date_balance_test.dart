import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';

void main() {
  group('CashbookBalanceCalculator', () {
    const CashbookBalanceCalculator calculator = CashbookBalanceCalculator();
    final CashbookBalanceRequest request = CashbookBalanceRequest(
      companyId: 'company-1',
      accountId: 'cash-1',
      asOfDate: DateTime(2026, 1, 31),
      currencyCode: 'EUR',
    );

    test('counts the verified opening once and only committed scoped cash movements', () {
      final CashbookBalanceResult result = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(corroboratingSaldoCents: 10000)],
          movements: <CashbookMovementEvidence>[
            _movement(
              postingGroupId: 'cash-in-1',
              sourceReference: 'posting:cash-in-1',
              effectiveAt: DateTime(2026, 1, 2, 10),
              amountCents: 1234,
            ),
            _movement(
              postingGroupId: 'cash-out-1',
              sourceReference: 'posting:cash-out-1',
              effectiveAt: DateTime(2026, 1, 3, 11),
              amountCents: -234,
            ),
            _movement(
              postingGroupId: 'draft-1',
              sourceReference: 'posting:draft-1',
              effectiveAt: DateTime(2026, 1, 4),
              amountCents: 9000,
              status: CashbookMovementStatus.draft,
            ),
            _movement(
              postingGroupId: 'other-kind-1',
              sourceReference: 'posting:other-kind-1',
              effectiveAt: DateTime(2026, 1, 4),
              amountCents: 9000,
              kind: CashbookMovementKind.other,
            ),
            _movement(
              postingGroupId: 'other-account-1',
              sourceReference: 'posting:other-account-1',
              effectiveAt: DateTime(2026, 1, 5),
              amountCents: 9000,
              accountId: 'cash-2',
            ),
            _movement(
              postingGroupId: 'after-close-1',
              sourceReference: 'posting:after-close-1',
              effectiveAt: DateTime(2026, 2),
              amountCents: 9000,
            ),
          ],
        ),
      );

      expect(result.complete, isTrue);
      expect(result.unavailableReason, isNull);
      expect(result.companyId, 'company-1');
      expect(result.accountId, 'cash-1');
      expect(result.asOfDate, DateTime(2026, 1, 31, 23, 59, 59, 999, 999));
      expect(result.balanceCents, 11000);
      expect(result.currencyCode, 'EUR');
      expect(result.sourceReferences, <String>['opening:setup-1', 'posting:cash-in-1', 'posting:cash-out-1']);
      expect(result.sourceReference, isNotEmpty);
    });

    test('returns unavailable when the approved opening source is absent', () {
      final CashbookBalanceResult result = calculator.calculate(
        request,
        const CashbookBalanceEvidence(
          openingSourceAvailable: false,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[],
          movements: <CashbookMovementEvidence>[],
        ),
      );

      expect(result.complete, isFalse);
      expect(result.balanceCents, isNull);
      expect(result.unavailableReason, CashbookBalanceUnavailableReason.openingSourceUnavailable);
    });

    test('returns unavailable for missing, duplicated, or unverified opening evidence', () {
      final List<({List<CashbookOpeningBalance> openings, CashbookBalanceUnavailableReason reason})> cases =
          <({List<CashbookOpeningBalance> openings, CashbookBalanceUnavailableReason reason})>[
            (openings: <CashbookOpeningBalance>[], reason: CashbookBalanceUnavailableReason.openingBalanceMissing),
            (
              openings: <CashbookOpeningBalance>[
                _opening(),
                _opening(identity: 'setup-2'),
              ],
              reason: CashbookBalanceUnavailableReason.openingBalanceAmbiguous,
            ),
            (
              openings: <CashbookOpeningBalance>[_opening(verified: false)],
              reason: CashbookBalanceUnavailableReason.openingBalanceUnverified,
            ),
            (
              openings: <CashbookOpeningBalance>[_opening(corroboratingSaldoCents: 9999)],
              reason: CashbookBalanceUnavailableReason.openingCorroborationConflict,
            ),
          ];

      for (final ({List<CashbookOpeningBalance> openings, CashbookBalanceUnavailableReason reason}) value in cases) {
        final CashbookBalanceResult result = calculator.calculate(
          request,
          CashbookBalanceEvidence(
            openingSourceAvailable: true,
            historyCoverageComplete: true,
            openingBalances: value.openings,
            movements: const <CashbookMovementEvidence>[],
          ),
        );

        expect(result.complete, isFalse);
        expect(result.balanceCents, isNull);
        expect(result.unavailableReason, value.reason);
      }
    });

    test('returns unavailable when the opening event is also presented as a cash movement', () {
      final CashbookBalanceResult result = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening()],
          movements: <CashbookMovementEvidence>[
            _movement(postingGroupId: 'setup-1', sourceReference: 'posting:setup-1', openingIdentity: 'setup-1'),
          ],
        ),
      );

      expect(result.complete, isFalse);
      expect(result.balanceCents, isNull);
      expect(result.unavailableReason, CashbookBalanceUnavailableReason.openingBalanceAmbiguous);
    });

    test('returns unavailable for incomplete history, unbalanced cash, or duplicate posting identity', () {
      final List<({CashbookBalanceEvidence evidence, CashbookBalanceUnavailableReason reason})> cases =
          <({CashbookBalanceEvidence evidence, CashbookBalanceUnavailableReason reason})>[
            (
              evidence: CashbookBalanceEvidence(
                openingSourceAvailable: true,
                historyCoverageComplete: false,
                openingBalances: <CashbookOpeningBalance>[_opening()],
                movements: const <CashbookMovementEvidence>[],
              ),
              reason: CashbookBalanceUnavailableReason.historyCoverageIncomplete,
            ),
            (
              evidence: CashbookBalanceEvidence(
                openingSourceAvailable: true,
                historyCoverageComplete: true,
                openingBalances: <CashbookOpeningBalance>[_opening()],
                movements: <CashbookMovementEvidence>[_movement(balanced: false)],
              ),
              reason: CashbookBalanceUnavailableReason.invalidCashMovement,
            ),
            (
              evidence: CashbookBalanceEvidence(
                openingSourceAvailable: true,
                historyCoverageComplete: true,
                openingBalances: <CashbookOpeningBalance>[_opening()],
                movements: <CashbookMovementEvidence>[_movement(linkedToAccount: false)],
              ),
              reason: CashbookBalanceUnavailableReason.invalidCashMovement,
            ),
            (
              evidence: CashbookBalanceEvidence(
                openingSourceAvailable: true,
                historyCoverageComplete: true,
                openingBalances: <CashbookOpeningBalance>[_opening()],
                movements: <CashbookMovementEvidence>[
                  _movement(postingGroupId: 'duplicate'),
                  _movement(postingGroupId: 'duplicate', sourceReference: 'posting:duplicate-copy'),
                ],
              ),
              reason: CashbookBalanceUnavailableReason.duplicateCashMovement,
            ),
          ];

      for (final ({CashbookBalanceEvidence evidence, CashbookBalanceUnavailableReason reason}) value in cases) {
        final CashbookBalanceResult result = calculator.calculate(request, value.evidence);

        expect(result.complete, isFalse);
        expect(result.balanceCents, isNull);
        expect(result.unavailableReason, value.reason);
      }
    });

    test('carries account currency, rejects mixed currencies, and refuses integer-cent overflow', () {
      final CashbookBalanceResult matchingCurrency = calculator.calculate(
        CashbookBalanceRequest(
          companyId: 'company-1',
          accountId: 'cash-1',
          asOfDate: DateTime(2026, 1, 31),
          currencyCode: 'USD',
        ),
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(currencyCode: 'USD')],
          movements: <CashbookMovementEvidence>[_movement(currencyCode: 'USD', amountCents: 50)],
        ),
      );
      final CashbookBalanceResult currencyMismatch = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening()],
          movements: <CashbookMovementEvidence>[_movement(currencyCode: 'USD')],
        ),
      );
      final CashbookBalanceResult overflow = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: 9223372036854775807)],
          movements: <CashbookMovementEvidence>[_movement(postingGroupId: 'overflow', amountCents: 1)],
        ),
      );

      expect(matchingCurrency.complete, isTrue);
      expect(matchingCurrency.balanceCents, 10050);
      expect(matchingCurrency.currencyCode, 'USD');
      expect(currencyMismatch.complete, isFalse);
      expect(currencyMismatch.balanceCents, isNull);
      expect(currencyMismatch.unavailableReason, CashbookBalanceUnavailableReason.currencyMismatch);
      expect(overflow.complete, isFalse);
      expect(overflow.balanceCents, isNull);
      expect(overflow.unavailableReason, CashbookBalanceUnavailableReason.balanceOverflow);
    });

    test('scopes opening cardinality to the requested account in a multi-account batch', () {
      final CashbookBalanceResult result = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[
            _opening(identity: 'other-account', accountId: 'cash-2', balanceCents: 9000),
            _opening(identity: 'target-account', balanceCents: 2500),
          ],
          movements: const <CashbookMovementEvidence>[],
        ),
      );

      expect(result.complete, isTrue);
      expect(result.balanceCents, 2500);
      expect(result.sourceReferences, <String>['opening:target-account']);
    });

    test('rejects unsupported or malformed cashbook currency codes', () {
      final CashbookBalanceEvidence validEvidence = CashbookBalanceEvidence(
        openingSourceAvailable: true,
        historyCoverageComplete: true,
        openingBalances: <CashbookOpeningBalance>[_opening()],
        movements: const <CashbookMovementEvidence>[],
      );
      final CashbookBalanceResult lowercaseRequest = calculator.calculate(
        CashbookBalanceRequest(
          companyId: 'company-1',
          accountId: 'cash-1',
          asOfDate: DateTime(2026, 1, 31),
          currencyCode: 'eur',
        ),
        validEvidence,
      );
      final CashbookBalanceResult malformedOpening = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(currencyCode: 'EU')],
          movements: const <CashbookMovementEvidence>[],
        ),
      );
      final CashbookBalanceResult malformedMovement = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening()],
          movements: <CashbookMovementEvidence>[_movement(currencyCode: 'EUR1')],
        ),
      );
      final CashbookBalanceResult unsupportedRequest = calculator.calculate(
        CashbookBalanceRequest(
          companyId: 'company-1',
          accountId: 'cash-1',
          asOfDate: DateTime(2026, 1, 31),
          currencyCode: 'ZZZ',
        ),
        validEvidence,
      );
      final CashbookBalanceResult unsupportedOpening = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(currencyCode: 'ZZZ')],
          movements: const <CashbookMovementEvidence>[],
        ),
      );
      final CashbookBalanceResult unsupportedMovement = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening()],
          movements: <CashbookMovementEvidence>[_movement(currencyCode: 'XAU')],
        ),
      );
      final CashbookBalanceResult unsupportedThreeDecimalCurrency = calculator.calculate(
        CashbookBalanceRequest(
          companyId: 'company-1',
          accountId: 'cash-1',
          asOfDate: DateTime(2026, 1, 31),
          currencyCode: 'KWD',
        ),
        validEvidence,
      );
      final CashbookBalanceResult unsupportedZeroDecimalCurrency = calculator.calculate(
        CashbookBalanceRequest(
          companyId: 'company-1',
          accountId: 'cash-1',
          asOfDate: DateTime(2026, 1, 31),
          currencyCode: 'JPY',
        ),
        validEvidence,
      );

      for (final CashbookBalanceResult result in <CashbookBalanceResult>[
        lowercaseRequest,
        malformedOpening,
        malformedMovement,
        unsupportedRequest,
        unsupportedOpening,
        unsupportedMovement,
        unsupportedThreeDecimalCurrency,
        unsupportedZeroDecimalCurrency,
      ]) {
        expect(result.complete, isFalse);
        expect(result.balanceCents, isNull);
        expect(result.unavailableReason, CashbookBalanceUnavailableReason.invalidCurrency);
      }
    });

    test('accepts the exact JSON-safe cent limit and rejects 2^53 plus one', () {
      final CashbookBalanceResult maximumSupported = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: 9_007_199_254_740_991)],
          movements: const <CashbookMovementEvidence>[],
        ),
      );
      final CashbookBalanceResult minimumSupported = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: -9_007_199_254_740_991)],
          movements: const <CashbookMovementEvidence>[],
        ),
      );
      final CashbookBalanceResult unsafeInteger = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: int.parse('9007199254740993'))],
          movements: const <CashbookMovementEvidence>[],
        ),
      );
      final CashbookBalanceResult unsafeNegativeInteger = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: int.parse('-9007199254740993'))],
          movements: const <CashbookMovementEvidence>[],
        ),
      );

      expect(maximumSupported.complete, isTrue);
      expect(maximumSupported.balanceCents, 9_007_199_254_740_991);
      expect(minimumSupported.complete, isTrue);
      expect(minimumSupported.balanceCents, -9_007_199_254_740_991);
      expect(unsafeInteger.complete, isFalse);
      expect(unsafeInteger.balanceCents, isNull);
      expect(unsafeInteger.unavailableReason, CashbookBalanceUnavailableReason.balanceOverflow);
      expect(unsafeNegativeInteger.complete, isFalse);
      expect(unsafeNegativeInteger.balanceCents, isNull);
      expect(unsafeNegativeInteger.unavailableReason, CashbookBalanceUnavailableReason.balanceOverflow);
    });

    test('returns unavailable when individually safe amounts exceed the JSON-safe aggregate', () {
      final CashbookBalanceResult positiveAggregateOverflow = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: 9_007_199_254_740_991)],
          movements: <CashbookMovementEvidence>[_movement(postingGroupId: 'positive-overflow', amountCents: 1)],
        ),
      );
      final CashbookBalanceResult negativeAggregateOverflow = calculator.calculate(
        request,
        CashbookBalanceEvidence(
          openingSourceAvailable: true,
          historyCoverageComplete: true,
          openingBalances: <CashbookOpeningBalance>[_opening(balanceCents: -9_007_199_254_740_991)],
          movements: <CashbookMovementEvidence>[_movement(postingGroupId: 'negative-overflow', amountCents: -1)],
        ),
      );

      for (final CashbookBalanceResult result in <CashbookBalanceResult>[
        positiveAggregateOverflow,
        negativeAggregateOverflow,
      ]) {
        expect(result.complete, isFalse);
        expect(result.balanceCents, isNull);
        expect(result.unavailableReason, CashbookBalanceUnavailableReason.balanceOverflow);
      }
    });
  });
}

CashbookOpeningBalance _opening({
  String identity = 'setup-1',
  int balanceCents = 10000,
  String accountId = 'cash-1',
  String currencyCode = 'EUR',
  bool verified = true,
  int? corroboratingSaldoCents,
}) {
  return CashbookOpeningBalance(
    identity: identity,
    companyId: 'company-1',
    accountId: accountId,
    effectiveAt: DateTime(2026),
    balanceCents: balanceCents,
    currencyCode: currencyCode,
    sourceReference: 'opening:$identity',
    verified: verified,
    identityUnambiguous: true,
    corroboratingSaldoCents: corroboratingSaldoCents,
  );
}

CashbookMovementEvidence _movement({
  String postingGroupId = 'cash-movement-1',
  String sourceReference = 'posting:cash-movement-1',
  DateTime? effectiveAt,
  int amountCents = 100,
  String companyId = 'company-1',
  String? accountId = 'cash-1',
  String currencyCode = 'EUR',
  CashbookMovementStatus status = CashbookMovementStatus.committed,
  CashbookMovementKind kind = CashbookMovementKind.cashPayment,
  bool balanced = true,
  bool linkedToAccount = true,
  String? openingIdentity,
}) {
  return CashbookMovementEvidence(
    postingGroupId: postingGroupId,
    sourceReference: sourceReference,
    companyId: companyId,
    accountId: accountId,
    effectiveAt: effectiveAt ?? DateTime(2026, 1, 2),
    amountCents: amountCents,
    currencyCode: currencyCode,
    status: status,
    kind: kind,
    balanced: balanced,
    linkedToAccount: linkedToAccount,
    openingIdentity: openingIdentity,
  );
}
