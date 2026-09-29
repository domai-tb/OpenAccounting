## Review Metadata

- **Review round**: 3 (author-only TDD sequencing correction)
- **Prior round**: Round 2 REVISE; v2 matrix/source/diagnostic/nullable/compile revisions were applied, awaiting re-review
- **Reviewer context**: fresh independent read-only reviewer (findings supplied to the authoring agent by the parent orchestrator)
- **Tool restrictions**: reviewer read artifacts/source only; production and test files remain untouched
- **Artifacts reviewed**: proposal.md, design.md, specs/bank-import-row-validation-boundary/spec.md, test-plan.md, tasks.md, current bank-import entity/service/page/database, A-004 audit evidence

This round returned four additional required revisions. The author has applied them to the planning artifacts, but the changed artifacts have not received a fresh re-review; the verdict therefore remains REVISE.

## Findings

### 🔴 Critical (blocking)

- The production parse → review → confirm path could still lose an invalid raw date or call `_formatDate` with null. Applied explicit raw-date preservation, null-safe review construction, and a production-facing regression requirement; re-review still required.
- CAMT empty cells and structural failures needed exact fixtures and a nesting/required-element guard beyond opening/closing counts. Applied empty CSV date/amount, empty CAMT `<Amt>`, and `<BookgDt><Dt>2026-03-15</ValDt></BookgDt>` fixtures plus the guard requirement; re-review still required.

### 🟡 Moderate

- Canonical German diagnostics were not fixed across CSV, CAMT, and review paths. Applied the shared `Datum ungültig`/`Betrag ungültig` categories and write-time persistence requirement.
- Nullable-date JSON behavior was underspecified. Applied safe `toJson()` fields (`raw_datum`, `raw_betrag`, `source_row`, explicit nullable `parsed_datum`) and a direct red assertion.
- A nullable `RawTx.datum` migration could make existing callers fail before behavior tests. Applied compile-only task 0.2 and made it an explicit prerequisite before the six red tests.
- Empty input, missing template/header, invalid account selection, and CAMT missing-required-element cases were not enumerated as batch failures. Applied the explicit matrix and batch-rejection fixture set.
- Both date and amount invalid/empty lacked deterministic precedence. Applied date-first evaluation with one failure, both raw fields, ordered `diagnostics`, and combined error text.

### 📌 Suggestions

- Keep the package limited to A-004. Mode/payment reconciliation remains out of scope.
- Prefer one focused VM audit test with parameterized CSV/CAMT fixtures where this preserves the six named scenario mappings.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## TDD sequencing correction

- Task 0.2 is now compile-preserving `RawTx.datum` nullability and existing-call-site migration only. It preserves the old failure API/serialization behavior and does not add the source getter, raw metadata behavior, or safe JSON.
- The mixed-date red test is staged to fail first at the existing batch rejection, then at source identity/raw fields, then at nullable JSON as tasks 1.2, 1.3, and 1.4 advance. Its assertions must not fail because task 0.2 was incomplete.
- The source getter and null-safe `toJson()`/raw-field behavior are explicitly dedicated later behavior tasks. Fresh independent review is still required.

## Verdict

VERDICT: REVISE

The required revisions are present, but a fresh reviewer must re-read the exact updated artifacts and either accept them or issue a new bounded finding. No implementation is authorized by this file.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this round is REVISE, not APPROVE_WITH_CHANGES.

CHANGES_APPLIED: n/a

## Rebuttals

- **CSV/CAMT matrix:** fixed in `spec.md`, `design.md`, `test-plan.md`, and `tasks.md`; awaiting reviewer re-check.
- **Source identity:** fixed with `RawTx.sourceRowNumber`, delegating `ImportRowFailure.sourceRowNumber`, and ordinal `rowNumber`; awaiting reviewer re-check.
- **Canonical diagnostics:** fixed as write-time German category prefixes shared by CSV/CAMT/review; awaiting reviewer re-check.
- **Nullable JSON:** fixed with explicit nullable `parsed_datum` and direct `toJson()` red assertion; awaiting reviewer re-check.
- **Compile prerequisite and batch cases:** task 0.2 is now limited to nullable type/call-site compilation; source identity and JSON/raw behavior move to dedicated red/behavior tasks, while the batch matrix/fixtures remain fixed; awaiting reviewer re-check.
- **Parse → review → confirm, empty-cell fixtures, structural nesting guard, and dual-invalid precedence:** fixed in `spec.md`, `design.md`, `test-plan.md`, and `tasks.md`; awaiting reviewer re-check.

## Review round 4: fresh independent verification after implementation cleanup

- **Scope:** Resolve the bounded verifier finding for CAMT self-closing `<Amt/>` and `<Dt/>` elements without changing the existing row-versus-batch boundary.
- **Verification context:** Fresh independent read of the current parser, boundary test, delta spec, test plan, tasks, and verification record after the cleanup change. The prior Round 3 `VERDICT: REVISE` is preserved above as historical review evidence.
- **Contract decision:** A self-closing `<Amt/>` or `<Dt/>` is a present empty cell and therefore produces a row-level `Betrag ungültig` or `Datum ungültig` failure. An absent required element remains a batch-level `BankImportException`.
- **Implementation evidence:** The CAMT structure guard recognizes attribute-bearing self-closing tags, and value extraction preserves them as empty raw fields for service validation.
- **Test evidence:** `test_bank_import_row_validation_self_closing_camt_cells_are_empty_row_failures` passed; the complete boundary audit file passed all 7 tests.
- **Static/spec evidence:** `fvm flutter analyze`, scoped `fvm dart format --set-exit-if-changed`, `git diff --check`, strict change validation, and strict spec validation passed. The prior focused-plus-bank suite evidence remains 39 passed and the prior full VM evidence remains 763 passed; the full VM suite was not rerun for this narrow cleanup.
- **Scope check:** No schema migration, mode/payment expansion, route work, or unrelated audit changes were included.

### Verdict

VERDICT: APPROVED

The self-closing CAMT boundary is explicit, tested, implemented, and aligned across the specification, test plan, parser, and verification record. This approval applies to the current post-cleanup artifact state and supersedes the pending re-review requirement from Round 3 while retaining that historical `REVISE` record.

CHANGES_APPLIED: self-closing CAMT empty-cell contract, parser support, boundary test, and verification metadata.
