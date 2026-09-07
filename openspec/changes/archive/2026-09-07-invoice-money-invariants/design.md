# Design: Enforce invoice money and discount invariants

## Context

The invoice paths currently mix floating-point arithmetic, duplicated cents conversion, caller aggregates, and
generated negative corrections. The maintained schema stores position and header money to two decimals, while article
unit prices support four decimals and inventory quantities support three decimals.

## Goals / Non-Goals

**Goals:**

- One deterministic calculator for preview and every persistence/lifecycle path.
- Integer/rational intermediate arithmetic with explicit half-up rounding.
- Exact-cent header/position reconciliation and stable typed validation failures.
- Preserve legitimate signed Gutschrift/Storno output without accepting negative caller input.

**Non-Goals:**

- Change tax law, database column types, currency, or accounting posting behavior.
- Accept arbitrary binary floating-point tolerance or silently repair malformed input.
- Localize strings inside the domain calculator; UI maps stable error codes to localized messages.

## Decisions

### Representation and accepted scale

External numeric values are converted through their decimal `toString()` representation into signed integers plus a
decimal scale; calculator operations use integers/rational division only. Unit price accepts at most four decimal
places, quantity at most three, and tax/discount percentages and asserted money totals at most two. Inputs must be
finite. Unit price, quantity, asserted line total, and caller document totals/discounts are non-negative.

Persisted line totals, header net, VAT, gross, and amount discounts are integer cents serialized with exactly two
decimal places. Equality is exact at the cent boundary; there is no epsilon tolerance.

### Rounding and calculation order

All positive midpoint ties round half up. For each line:

1. Multiply unit price by quantity exactly as scaled integers.
2. Apply the line percentage discount, whose inclusive range is 0.00 through 100.00 percent.
3. Round once to the two-decimal line-money boundary. The caller `gesamt` must equal this value exactly.
4. In `netto` mode, calculate VAT per line as rounded `net * rate / 100`; gross is net plus VAT.
5. In `brutto` mode, calculate net per line as rounded `gross * 100 / (100 + rate)`; VAT is gross minus net.

Line results are grouped by the exact two-decimal tax rate. A document percentage discount (0.00 through 100.00
inclusive) applies to each bucket's net with half-up cent rounding. A document amount discount must not exceed the
post-line-discount net subtotal; it is allocated proportionally by bucket net using largest remainders, with ties
resolved by ascending tax rate. VAT is recomputed per discounted bucket, then bucket net/VAT/gross values are summed.
Only one document discount kind may be non-zero.

Concrete examples:

- Net line: quantity 3, unit price 0.3350, 0% line discount, 19% VAT -> line net 1.01, VAT 0.19, gross 1.20.
- Line discount: quantity 2, unit price 100.0000, 10% -> asserted line net 180.00; VAT 34.20; gross 214.20.
- Mixed tax: net lines 100.00 at 19% and 50.00 at 7%, document discount 10% -> bucket nets 90.00 and 45.00,
  VAT 17.10 and 3.15, totals net 135.00, VAT 20.25, gross 155.25.
- Half-cent tie: net 0.03 at 50% VAT -> VAT 0.02 and gross 0.05.

### Entry points and enforcement

The calculator is public to preview and internal lifecycle code. `RechnungenUseCases` validates before repository
calls, and `RechnungenDataSource` validates again so direct datasource use cannot bypass the invariant. Draft creation,
generic document creation, finalization, conversion, standalone/source Gutschrift, and Storno all use the calculator.
Finalization re-reads positions and rejects a header mismatch before assigning a number or side effect.

### Signed correction policy

Caller-supplied preview/draft values must be non-negative. A generated Gutschrift or Storno first validates and
calculates the positive source positions/header, then applies sign `-1` exactly once to line totals, net, VAT, and
gross. A standalone Gutschrift also accepts positive caller positions and applies the sign internally. VAT is preserved
from the validated source/buckets rather than hard-coded to zero. Conversions preserve the calculated unsigned values
unless the target type is a correction.

### Validation errors

The calculator throws `InvoiceMoneyValidationException` containing a stable code plus optional zero-based `lineIndex`
and persisted `position`. Codes distinguish invalid scale, negative input, invalid percentage, excessive amount
discount, conflicting document discounts, invalid mode/rate, and aggregate mismatch. The UI/localization layer maps
the code and line metadata to German/English text.

## Risks / Trade-offs

- Existing permissive tests may fail -> replace expectations only where the reviewed contract explicitly changes them.
- Recalculating corrections can expose inconsistent legacy drafts -> reject before finalization/correction rather than
  create a second contradictory artifact.
- Proportional amount allocation is more code -> isolate and unit-test the deterministic largest-remainder helper.

## Migration Plan

1. Add failing calculator and persistence tests for the four acceptance scenarios and concrete examples.
2. Introduce the calculator/error type and route preview plus creation through it.
3. Add finalization/conversion/correction regression tests, then migrate those paths.
4. Run scoped format/analyze/tests followed by the full analyzer and VM suite.

Rollback is a scoped code revert; this change does not migrate stored schema or rewrite existing rows.

## Open Questions

None.
