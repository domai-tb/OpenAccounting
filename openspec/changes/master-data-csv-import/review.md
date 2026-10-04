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
