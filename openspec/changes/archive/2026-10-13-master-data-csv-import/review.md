## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent; read-only
- **Review scope**: proposal, design, delta spec, maintained `stammdaten` and route specs, and relevant repositories
- **Validation**: `openspec validate master-data-csv-import --type change --strict --json` passed; structural validation only. Tests were not run.

## Findings

### Critical

1. Article `Update` imports can change selling prices, but the contract does not define how the paired net/gross prices remain consistent. The current article repository derives the pair on create but writes mapped price fields directly on update. Specify transactional update behavior, including input basis, tax-rate source, precision/rounding, and paired-price persistence, or exclude article price updates.
2. The importer requires a selected numeric convention but does not enumerate accepted formats or their parsing rules. Define the supported numeric formats and grammar so ambiguous values have testable outcomes.

### Suggestions

- Keep the stated gates to reconcile `docs/08` required fields and customer/supplier numbering before implementation.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Specify safe, transactional article price updates or exclude article price updates.
2. Define supported numeric formats and parsing grammar.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

---

## Review Metadata

- **Review round**: 2
- **Prior round**: 1 (`REVISE`)
- **Reviewer context**: fresh-context independent subagent; read-only review
- **Review scope**: proposal, design, delta spec, and the two round-1 blockers; checked article repository update/create behavior for conflicts
- **Validation**: `openspec validate master-data-csv-import --type change --strict --json` passed; structural validation only. Tests were not run.

## Findings

None in the scoped review.

## Evidence

1. The article update contract now excludes `vk_netto`, `vk_brutto`, `vk_eingabe`, `ust_satz`, `ust_satz_id`, and `differenzbesteuerung`; a row with any non-empty supplied value for one of these fields receives a row-level unsupported-field error and writes none of its fields. Article Create retains the single selected net-or-gross input and paired derivation contract. This is consistent across the proposal (`proposal.md:11`), design (`design.md:55-57,65`), and scenarios (`specs/master-data-csv-import/spec.md:96-114`). The existing repository accepts these keys in its generic update allowlist (`lib/pages/stammdaten/artikel_repository.dart:221-234`), so the proposal correctly requires the importer to enforce this narrower update contract.
2. Numeric parsing now has an exact decimal-point and decimal-comma grammar, specifies surrounding-whitespace trim, integer acceptance under either convention, disallowed tokens, normalization, and delegation of precision/rounding to the typed repository validator (`design.md:45`; `specs/master-data-csv-import/spec.md:45,57-70`). The accepted/rejected examples agree with the grammar.
3. The three proposal artifacts express the same two decisions; no material conflict was found in the reviewed contract.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: The proposal author addressed both round-1 blockers in proposal.md, design.md, and the delta spec. This reviewer made no artifact edits other than recording this review.

## Rebuttals

The round-1 numeric grammar and article paired-price update findings are resolved as evidenced above. The prior non-blocking suggestion to keep the documented source-field and partner-number constraints gated before implementation remains applicable.
