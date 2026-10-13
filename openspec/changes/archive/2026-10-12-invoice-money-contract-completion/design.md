## Context

`VorschauService` already converts decimal inputs to scaled integers, but current callers still pre-calculate line totals with `num` multiplication. The calculator rounds the undiscounted line before applying a line discount, applies document percentages independently per VAT bucket, and corrections omit source document discounts. Generic draft creation accepts correction types. SQLite's `NUMERIC(12,2)` declaration does not enforce its apparent scale, and the current `db` spec incorrectly promises SQLite rounding and exact decimal precision. The archived `invoice-money-invariants` review remains `REVISE`; balanced settlement and document correction changes explicitly depend on an accepted rule.

## Goals / Non-Goals

**Goals:**

- Make the calculator the only authority for line, discount, VAT, and header amounts.
- Preserve accepted 3-place quantities and 4-place unit prices through all invoice persistence and copy paths.
- Make corrections exact signed reversals, including a positive Storno of a negative Gutschrift.
- Reject malformed headers, input, and unsupported document types before durable side effects.
- Define one deterministic cent remainder rule that invoice discounts and mixed-category EÜR allocations can share.

**Non-Goals:**

- Change tax rates, legal treatment, currency, or accounting posting policy.
- Redesign the invoice database or migrate stored amounts to a different currency representation.
- Replace the current invoice layers or add dependencies.

## Decisions

### Integer arithmetic and accepted ranges

Convert the caller's finite decimal representation to scaled integers once. Keep quantity at scale 3, unit price at scale 4, and all percentage/rate inputs at scale 2. Enforce the explicit maximums in the spec: 12 total decimal digits for those values and a maximum of 9,999,999,999.99 for every rounded line, bucket, tax, discount, subtotal, and header currency amount. Use overflow-safe exact arithmetic for products and aggregate intermediates; reject a rounded line or derived amount above that limit with `valueOutOfRange` before persistence. Reject negatives, excess scale, non-finite inputs, and out-of-range values with the typed error contract. Presentation doubles are derived only from completed integer-cent results.

For line arithmetic, multiply scaled price by scaled quantity, multiply by the line-discount factor, and perform a single half-up division at the entered-mode cents boundary. Guard the exact product with `BigInt` (or an equivalent checked multiplication) so valid input scales cannot overflow before the currency bound is checked. The UI obtains the asserted line amount from the same helper instead of `quantity * price`; preview and save then compare that assertion exactly.

### Tax and document discounts

Net-mode line cents are grouped by exact tax-rate basis points only for document-discount allocation. In gross mode, first round each line gross to cents and derive that line's net once with half-up rounding; the line VAT is gross minus net. A percentage discount is rounded once against the whole net subtotal; fixed discounts are already cents. Allocate the resulting amount across rate buckets by largest remainder, breaking ties by ascending rate, then across persisted positions within each bucket by largest remainder, breaking ties by ascending position. Recompute VAT per discounted position using half-up rounding and sum the line VAT; set gross to net plus VAT. This follows the maintained accounting rule and keeps a three-line `0.03` net at `19.00%` to `0.03` VAT.

The archived alternative of rounding a document percentage independently for every rate bucket is rejected because it contradicts the maintained rule that the document discount is based on the summed subtotal and can create an extra or missing cent. Bucket totals determine only discount allocation; VAT remains rounded per position as required by the maintained accounting contract.

### Persistence and schema

Keep Drift/SQLite and the current NUMERIC affinity. Update invoice DDL declarations to `NUMERIC(12,4)` for unit price and `NUMERIC(12,3)` for quantity to describe the app contract, while tests and code explicitly enforce that SQLite does not enforce either scale. Same-affinity declarations require no table rebuild or `user_version` migration; a test must prove accepted maximum-scale values round-trip through the real executor and conversion path. Currency fields remain cent strings. If that test shows a supported value changes after reload, stop and use canonical decimal text plus a data-preserving migration before implementation can pass.

The maintained db requirement will be corrected so it makes no false claim that SQLite rounds to declared precision. Existing profiles retain numeric affinity and their stored rows; no value rewrite is required.

### Entry points, header integrity, and errors

Use-case validation remains first; datasource validation remains the backstop for direct callers. Generic drafts accept ordinary draft document types only; correction types use `createGutschrift` and `stornoRechnung`. `finalizeRechnung` recalculates saved positions and discounts, compares all three persisted totals, and rejects any mismatch before allocating a number or applying inventory, journal, receivable, PDF, or status side effects. Supported conversion paths copy discounts and accepted position scales and recalculate the same headers.

Correction creation reads the source's saved lines, discounts, and totals, validates their absolute amounts against the calculator, and applies one sign to lines and all net/VAT/gross headers. Rechnung-to-Gutschrift and Rechnung-to-Storno are negative; standalone Gutschrift is negative; Gutschrift-to-Storno is positive. Only finalized Rechnung and Gutschrift sources are eligible. The current Gutschrift-to-Storno test and behavior are preserved because an exact reversal must cancel the credit note's negative balance. This capability is the canonical source for those signs; document workflow and PDF requirements remain in the separate document-correction change.

Keep `InvoiceMoneyValidationException` as an `ArgumentError` subtype. Add stable `fields` metadata, and keep the closed code list in the spec. `lineIndex` is zero-based; `position` is the persisted line position; document-level errors carry neither. Header errors report all mismatching stored columns. UI localization maps codes/fields to messages without changing calculator behavior.

### Reusable remainder rule

Use integer floor allocations, sort unallocated cents by descending remainder, then ascending stable caller key. Invoice discounts pass VAT rate as the key; mixed-category EÜR passes its persisted deterministic category/line key. This is a rule, not a second repository or a new calculation framework.

## Risks / Trade-offs

- [SQLite numeric values are stored as INTEGER or binary REAL] → Keep accepted ranges small enough that each 3/4-place step is representable, enforce scales in application code, and require round-trip tests at boundaries.
- [Document discounts change at one-cent boundaries from current per-rate rounding] → Update preview, saved headers, PDFs, and regression fixtures together; preserve the maintained aggregate-subtotal requirement.
- [Correction sign behavior conflicts with the existing broad Storno wording] → Make the invoice-money capability canonical and require document workflow requirements to follow it; verify each direction with net, VAT, gross, and line assertions.
- [More direct datasource callers may rely on generic correction creation] → Search and test every caller before rejecting correction types; supported correction APIs remain available.

## Migration Plan

1. Add failing unit, repository, database round-trip, UI line-total, and lifecycle tests from the accepted test plan.
2. Implement fixed-point calculations, typed error metadata, exact source/header checks, and correction discount preservation.
3. Update invoice DDL declarations to the matching SQLite NUMERIC affinity scales and verify fresh and upgraded profile round-trips without rewriting rows.
4. Update user-facing and maintained specs only after the implementation and full required verification pass.

Rollback is the normal application version rollback; the same-affinity DDL declarations do not alter existing stored data. No incomplete migration is written.

## Open Questions

None. The contract decisions above are explicit and will be independently reviewed before test-plan and implementation tasks are written.
