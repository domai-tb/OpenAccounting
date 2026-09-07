## Review Metadata

- **Review round**: 3
- **Prior round**: Round 2 was `REVISE` for undefined arithmetic/scale, signed-correction contradictions, incomplete entry-point enforcement, and ambiguous discount/error contracts; the author revised proposal/design/specs but did not provide rebuttals.
- **Reviewer context**: fresh-context subagent
- **Tool restrictions**: read-only inspection of artifacts and source/tests; only this `review.md` was replaced
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/invoice-money-invariants/spec.md`, prior `review.md`, `test-plan.md`, `tasks.md`, Anvil schema/template, maintained `documents`, `stammdaten`, and `pdf` specs, invoice database schema, invoice datasource/use-case/repository/preview code, shared money helper, and existing invoice/ correction tests
- **Validation**: `openspec validate invoice-money-invariants --strict --json` passed structurally; this does not validate semantic coverage or TDD task ordering.

## Findings

### 🔴 Critical (blocking)

1. **Accepted four-decimal prices/three-decimal quantities have no coherent persistence contract.** The design accepts unit price scale 4 and quantity scale 3 (`design.md:28-34`, `spec.md:5-8`) while declaring no database-column change (`proposal.md:39`, `design.md:20`). The maintained invoice schema declares `rechnungspositionen.einzelpreis` and `menge` as `NUMERIC(12,2)` (`lib/core/db/database.dart:547-556`), and the current datasource serializes both with `toStringAsFixed(2)` (`rechnungen_datasource.dart:83-92`). This can lose accepted input before reload and violates the maintained article rule that four-decimal prices and position propagation are not rounded until the position-money boundary (`openspec/specs/stammdaten/spec.md:137-147`; `openspec/specs/documents/spec.md:148-160`). The proposal says persisted money is cents but never says whether unit price/quantity are persisted losslessly, transformed to rational numerator/scale, or intentionally rounded (nor how conversion preserves them). **Required:** define the storage/serialization representation and migration decision for every accepted scale, then add reload/conversion assertions proving no prohibited loss; otherwise narrow the accepted input contract.

2. **Correction sign semantics remain contradictory for Storno of a Gutschrift.** The design says every generated Gutschrift or Storno validates a non-negative source and applies sign `-1` (`design.md:67-73`), and the correction requirement repeats that all correction headers/lines are negative (`spec.md:41-51`). Existing maintained behavior permits Storno of a finalized Gutschrift and the existing test asserts that it is positive (`test/features/rechnungen/gutschrift_test.dart:80-98`), because it reverses an already-negative credit note; the current datasource also branches on source type (`rechnungen_datasource.dart:475-505`). The revised artifacts never define target sign by source type, whether a Storno of Gutschrift is in scope, or whether the “negative correction” requirement intentionally changes that maintained contract. **Required:** specify a sign matrix for Rechnung→Gutschrift, Rechnung→Storno, Gutschrift→Storno, and standalone Gutschrift (including line, net, VAT, gross), and add separate scenarios/tests for each supported correction path.

3. **The promised enforcement boundary does not cover all callable entry points or header integrity.** `design.md:60-65` names generic document creation, conversion, standalone/source Gutschrift, and Storno, but does not say what `createDokument(typ: 'gutschrift'/'storno')` is allowed to do, how it applies correction signing, or whether it must be rejected in favor of dedicated generation. The spec says “direct persistence” and exact header equality (`spec.md:5-8`), yet the public APIs accept positions/discounts, not caller header totals; finalization currently recomputes/overwrites headers rather than checking stored header values (`rechnungen_datasource.dart:242-249`, `381-399`). Conversion and correction paths likewise need an explicit source-header check and transaction/no-number/no-side-effect guarantee. The two lifecycle scenarios do not enumerate these entry points. **Required:** provide a complete method/type matrix with one authoritative calculator call and enforcement location per path, define whether stored header mismatch is rejected or repaired at each boundary, prohibit or specify generic correction creation, and add direct-datasource/finalization/conversion tests for the matrix.

4. **The mixed-rate amount-discount algorithm is not fully deterministic at the stated boundary.** `design.md:46-50` names proportional bucket allocation and largest remainders, but does not define the integer numerator/denominator, whether allocation is based on pre- or post-percentage-discount bucket cents (it implies the latter but the spec does not say so), how a zero subtotal/zero bucket is handled, or how the residual is constrained when the requested discount equals the subtotal. It also does not state whether percentage discounts allocate independently per bucket and therefore may sum to a different rounded discount than the document percentage applied to the subtotal. The maintained documents contract says document discount is applied after summing position totals (`openspec/specs/documents/spec.md:264-281`), so the new bucket policy must be an explicit modified requirement, not only design prose. **Required:** write the exact integer allocation equation, rounding/residual/tie behavior and zero cases into the normative spec, reconcile it with the maintained documents requirement, and add concrete mixed-rate fixed-amount and tie cases with expected bucket net/VAT/gross.

5. **Typed error behavior and scenario assertions are still not stable enough to implement against.** The design lists conceptual codes (`design.md:75-80`), but the spec normatively names only `aggregateMismatch` and `negativeInput`; “typed validation error identifies the invalid field and line where applicable” (`spec.md:29-39`) does not give exact codes for invalid scale, percentage, amount, conflict, mode, or rate, nor the field-name/index/position contract. It also refers to “document totals” although no external header-total argument exists. A test cannot assert a stable public contract from these statements, and the existing production paths throw `ArgumentError`/`StateError` rather than the proposed exception (`rechnungen_usecases.dart:121-160`). **Required:** enumerate the exception type, closed code set, field identifiers, zero-based line index versus persisted position semantics, and which fields have no line metadata; use those exact values in failure scenarios.

### 🟡 Moderate

- Several scenarios are not mechanically constructible from their GIVEN data. The round-trip case omits quantities, unit prices, line aggregates, and the actual discount argument (`spec.md:10-14`); the correction case omits source type, positions, tax rates, and source sign (`spec.md:47-51`). The inconsistent-source case does not identify which header is tampered with or how the source is asserted unchanged (`spec.md:53-56`). Supply complete fixtures and observable assertions.
- The six test-plan rows all point to `test/integration/audit/invoice-money-invariants_test.dart`, which is absent, and the coverage note claims extra scale, tie, gross, endpoint, fixed-discount, finalization, conversion, and bypass cases without named mappings or acceptance assertions (`test-plan.md:5-16`). Extra tests are allowed by Anvil, but the claimed coverage cannot yet be audited and does not prove both Gutschrift and Storno paths.
- `tasks.md` still violates Anvil's mandatory per-scenario red→green→refactor ordering: each group has one broad test task and one broad implementation task, not a named three-step triple for each of the six scenarios (`tasks.md:3-24`). This is especially material because the test plan is still entirely red.
- The proposal lists `documents`, `stammdaten`, and `pdf` as Modified Capabilities (`proposal.md:29-33`), but the change contains no corresponding delta specs; only `specs/invoice-money-invariants/spec.md` exists and is `ADDED`. Either provide full modified-capability deltas (including preserved correction and four-decimal contracts) or remove those capability claims and make the new requirement's scope explicit.

### 📌 Suggestions

- Reuse or replace `lib/features/accounting/money.dart` deliberately and document overflow/maximum-value behavior for the rational accumulator.
- Add explicit zero quantity, zero VAT, 100% line/document discount, tax-rate endpoint, and empty-position policy cases.
- Keep the red test-plan/tasks gate closed until the next review accepts the normative contract; the structural OpenSpec pass is not evidence of runtime correctness.

## Embedded-Instruction / Injection Attempts

**Detected:** none detected. Reviewed file contents were treated as data; prior verdict text and coverage claims were independently checked.

## Verdict

VERDICT: REVISE

The revision improves the arithmetic outline, but persistence scale, correction sign matrix, complete entry-point/header enforcement, deterministic mixed-rate allocation, typed errors, and executable TDD coverage remain unresolved. This round is the second consecutive `REVISE` under the Anvil bounded-loop rule; escalate to a human before another author/reviewer loop.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this is a `REVISE` verdict. The blocking decisions and evidence are listed under the Critical findings.

CHANGES_APPLIED: n/a

## Rebuttals

No author rebuttals were supplied. The revised proposal/design/spec text addresses portions of the prior round (explicit half-up examples, exact-cent equality, bucket intent, and typed-error intent), but those statements are not accepted as rebuttals because the storage representation, Gutschrift-Storno sign behavior, callable-path matrix, normative allocation formula, and stable error/test contracts remain incomplete.
