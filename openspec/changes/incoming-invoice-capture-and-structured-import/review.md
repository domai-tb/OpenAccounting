## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent; read-only
- **Review scope**: proposal, design, both delta specs, maintained document/receipt specs, invoice schema, and draft path
- **Validation**: `openspec validate incoming-invoice-capture-and-structured-import --type change --strict --json` passed; structural validation only. Tests were not run.

## Findings

### Critical

1. Structured import has no bounded, testable support contract. Exact XRechnung versions, ZUGFeRD/Factur-X profiles and embedded XML variants, source-to-draft field mapping, and parser contract remain open. The spec requires supported suggestions and explicit handling of unsupported values without naming the supported inputs.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define the supported format/profile matrix and source-field mapping, including conversions and unsupported-field behavior.
2. Select the local parser contract.
3. Retain the explicit Beleg-association and accepted invoice-money-contract implementation gates.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.
