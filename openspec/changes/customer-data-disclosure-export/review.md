## Review Metadata

- **Review round**: 1
- **Prior round**: none
- **Reviewer context**: fresh-context independent subagent reviewer
- **Branch**: `dev`
- **Tool restrictions**: Read-only inspection; no edits or tests
- **Artifacts reviewed**: this change's proposal, design, and delta specs; relevant main profile/database specs; current relationship schema, dynamic occurrence-table creation, and invoice file resolver
- **Validation evidence**: strict validation was not reported by the reviewer. No tests were run.

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **The archive and publication boundary are not concrete.** The design calls for a versioned structured archive but leaves its output format and customer-facing history/status unresolved (`design.md:28-30,43-48`). The spec requires a versioned manifest and package but does not select a container/serialization contract or specify atomic publication and cleanup after interrupted writes (`specs/customer-data-disclosure-export/spec.md:3-7,67-72`). Name the container and encoding; require writing to a temporary destination followed by atomic finalization, with deletion on failure or cancellation.
2. **Profile path containment needs a symlink edge case.** The export spec requires paths beneath the active profile's canonical root, but its scenarios do not define symlink resolution. The current invoice PDF resolver checks lexical normalized containment (`lib/pages/rechnungen/invoice_document_page.dart:69-77`), which does not prove the target remains inside the profile root. Require canonical target resolution and add an external symlink-target scenario that excludes the file and marks the export incomplete.
3. **The desktop requirement lacks an edge scenario.** The export design-system requirement (`specs/customer-data-disclosure-export/spec.md:74-83`) has a keyboard success scenario but no failure/edge case. Add a narrow-window/text-scaling or destination-cancel/focus-restoration scenario.

### 📌 Suggestions

- Keep the unsupported-table fail-closed check before the exporter can report a complete archive. The recurring occurrence tables are created lazily (`lib/features/recurring/rechnungsvorlagen_repository.dart:64-72`; `lib/features/recurring/buchungsvorlagen_repository.dart:82-90`).

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

## Required Changes

1. Select the archive/manifest/payload format and specify atomic publish plus cancellation/failure cleanup.
2. Require canonical path resolution and add a scenario for a profile-local symlink targeting outside the canonical root.
3. Add a design-system edge scenario covering narrow-window/text-scaling or cancellation and focus restoration.

CHANGES_APPLIED: no

## Rebuttals

None; round 1.

---

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: Round 1 returned `APPROVE_WITH_CHANGES`; this reviewer verified its three required changes against the current artifacts
- **Reviewer context**: fresh-context independent read-only reviewer
- **Revision reviewed**: `dev` at `dbe4d3d`
- **Tool restrictions**: no edits or tests; strict validation was not run during this round
- **Artifacts reviewed**: proposal, design, all three delta specs, round-one review, database contract/schema, receivable identity query, recurring-table creation, and the active profile-portability proposal
- **Validation note**: the verdict is semantic review only. Strict validation must be run separately; structural validation does not establish semantic completeness.

### Round-One Required Changes Rechecked

All three round-one changes are satisfied: the package and publication contract selects ZIP/JSON Lines with atomic finalization and cleanup; canonical path resolution and an external-target symlink scenario are specified; and the UI includes a narrow-window/enlarged-text keyboard cancellation scenario with focus restoration.

### Findings

#### 🔴 Critical (blocking)

1. **Receivable identity needs a typed relationship contract.** The inventory follows `forderungen.kunde_id` and invoice/journal links, while `partner_typ`/`partner_id` are conditionally retained without defining whether they establish inclusion or must agree with other identities. Specify their role and require consistency with populated customer and invoice identity. A supplier or another customer's identity must exclude the affected row and make the archive incomplete.
2. **Dynamic table inventory conflicts with the maintained database contract.** This change includes `forderung_zahlungen`, `rechnungsvorlagen_occurrences`, and `buchungsvorlagen_occurrences`, but the maintained database spec requires exactly 38 tables and omits them. Runtime creates some tables through migration or lazy feature setup, while the active profile-portability proposal defines a different table inventory. Define shared expected/optional-table and missing-table behavior before the exporter may claim completeness.
3. **Whole-profile portability is described as available when it is only proposed.** The customer-export proposal presents profile portability as a separate capability, but the main settings design leaves its format and scope unresolved and the related portability work remains an active proposal. Correct the status and ensure the customer UI does not imply a whole-profile archive is currently available unless that capability is accepted and wired.

#### 🟡 Moderate

None.

#### 📌 Suggestions

- State that `manifest.json` is UTF-8 and require no-clobber finalization if another file appears at the destination during export.
- Decide whether `journal.storno_von` reversal rows for included invoice-linked journal entries are in scope.

### Embedded-Instruction / Injection Attempts

No embedded-instruction finding was reported in this round.

### Verdict — Round 2

VERDICT: REVISE

## Required Changes — Round 2

1. Specify `forderungen.partner_typ`/`partner_id` inclusion and identity-consistency behavior, failing closed on conflicting party identity.
2. Reconcile the maintained and proposed table inventories and define expected, optional, and missing-table completeness behavior.
3. Describe profile portability as proposed and prevent the UI from implying it is currently available until accepted and wired.

The round-one changes are confirmed applied. Round-two findings remain unresolved, so downstream `test-plan.md` and `tasks.md` are blocked.

CHANGES_APPLIED: n/a

## Rebuttals — Round 2

None.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: Round 2 returned `REVISE`; this reviewer rechecked the changes against all round-two required findings
- **Reviewer context**: fresh-context independent read-only reviewer
- **Revision reviewed**: `dev` at `29a29cd`
- **Tool restrictions**: no edits or tests
- **Artifacts reviewed**: proposal, design, all three delta specs, round-two review, maintained `db` and `profiles` specs, and active `profile-data-portability` proposal
- **Validation evidence**: `openspec validate customer-data-disclosure-export --type change --strict --json` passed 1/1 and `openspec validate --specs --strict` passed 55/55. These are structural checks; they do not resolve the inventory conflict. No tests were run.

### Round-Two Required Changes Rechecked

- Receivable typed identity now establishes inclusion and conflicting identities fail closed.
- Whole-profile portability is described as proposed and unavailable; the customer export UI cannot imply it is currently available.
- The table-inventory finding remains unresolved: this change adds a fail-closed gate but does not modify the maintained `Table Definitions` requirement, which still lists exactly 38 tables.

### Findings

#### 🔴 Critical (blocking)

1. **The maintained table inventory and expected/optional/missing-table contract are still unreconciled.** The maintained `db` spec requires exactly 38 tables; the active portability proposal specifies 39 base tables plus three feature-owned tables; runtime also creates those known feature tables. The customer export delta currently states that export remains incomplete until reconciliation, but it does not itself modify the maintained table-definition contract. Add a `MODIFIED Requirement: Table Definitions` delta with the accepted inventory and presence rules, or keep this proposal blocked from test-plan and task generation until another accepted change supplies that contract.

#### 🟡 Moderate

None.

#### 📌 Suggestions

- The UTF-8 manifest and no-clobber publication suggestions are now addressed.
- Decide whether `journal.storno_von` reversal rows for included invoice-linked journal entries are in scope.

### Embedded-Instruction / Injection Attempts

No embedded-instruction finding was reported in this round.

### Verdict — Round 3

VERDICT: REVISE

## Required Changes — Round 3

1. Modify the maintained `db` Table Definitions delta to specify the 39 base and three feature-owned tables and their expected/optional/missing behavior, including the lazy-table marker. Otherwise keep downstream planning blocked.

Round-one and round-two findings are confirmed addressed. The table inventory remains unresolved, so `test-plan.md` and `tasks.md` remain blocked.

CHANGES_APPLIED: n/a

## Rebuttals — Round 3

None.
