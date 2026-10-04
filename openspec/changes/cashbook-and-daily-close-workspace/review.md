## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent reviewer; no proposal-authoring transcript
- **Tool restrictions**: read-only artifact/source inspection; no edits or tests
- **Artifacts reviewed**: proposal, design, all four delta specs, current accounting and PDF specs, existing `tagesabschluesse` schema, and current posting/reporting prerequisite reviews
- **Validation evidence**: `openspec validate cashbook-and-daily-close-workspace --type change --strict --json` passed with no issues. This is structural validation only. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ VOIDS it. -->

## Findings

### 🔴 Critical (blocking)

1. **The cash balance and write prerequisites are not accepted contracts.** Identify independently accepted contracts for direct cash-event posting, account/date balance with opening-balance and completeness handling, and receipt-link behavior before enabling cash writes, balances, close finalization, or PDFs. Current posting and reporting prerequisite reviews remain `REVISE`.
2. **Close persistence and signature verification are underspecified.** Map existing `betrag`, `kassenbestand`, `differenz`, `konto_id`, and `signatur`; define the `zaehlung_json` schema and canonical bytes; and specify how a SHA-256 digest is signed and verified. A digest alone does not define a signature trust model.

### 🟡 Moderate

None.

### 📌 Suggestions

- Preserve the expected amount and discrepancy source reference in close history so users can distinguish verified values from legacy rows.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

## Required Changes

1. Define and gate cash operations on accepted posting, balance/completeness, and receipt-link contracts.
2. Specify close persistence mapping, canonical signed content, and signature verification trust model.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.
