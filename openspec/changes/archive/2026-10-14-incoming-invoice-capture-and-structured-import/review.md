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

---

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: 1 REVISE (support matrix, parser contract, field mapping, gates)
- **Reviewer context**: fresh-context independent subagent; read-only
- **Review scope**: proposal.md, design.md, specs/incoming-invoice-capture/spec.md, specs/documents/spec.md, tasks.md, test-plan.md, review.md round 1
- **Validation**: reads only; no shell, no tests per task instructions

### Round-1 closure check

1. Version/profile matrix — CLOSED. `specs/incoming-invoice-capture/spec.md:21` normatively SHALLs standalone XRechnung 3.0 (UBL 2.1 `.xml`) and ZUGFeRD 2.5.2 / Factur-X 1.0.x EN 16931 only incl. XRECHNUNG URN alias; MINIMUM, BASIC WL, BASIC, EXTENDED SHALL be rejected.
2. Parser contract — PARTIAL. `design.md:41` fixes `xml` direct, byte-scan extraction, 2 MiB reject, DTD/external-entity reject. Not restated as SHALL in any `specs/` requirement; normative language missing.
3. Field mapping + EUR-only + unsupported list — CLOSED. `spec.md:21` SHALLs BT-1→`fremd_rechnungsnummer`, BT-2→datum, BT-9→faelligkeit, BT-153/129/146/152 line mapping, BT-106/112/115 display-only, EUR-only (BT-5=EUR), 10-item unsupported list each surfaced with manual fallback and no silent coercion; BG-4/BT-30 hint-only with never-auto-select.
4. BASIC WL reject scenario — CLOSED in spec, OPEN in traceability. `spec.md:50-53` scenario present; `tasks.md:34-41` and `test-plan.md:6-17` map only unreadable/unrepresentable, no task or test row for BASIC WL.
5. Gates kept — CLOSED. `design.md:51` retains Beleg-association + accepted money-contract preconditions; `design.md:62` orders them first; `spec.md:21` SHALLs conversion follow separately accepted money contract with no added policy.
6. `fremd_rechnungsnummer` migration — CLOSED. `spec.md:5,21` separate nullable storage; `design.md:62,64` additive nullable `fremd_rechnungsnummer TEXT NULL` migration with no `notiz` substitute and safe rollback.

### Findings

#### Critical

None; money/Beleg gates stay closed per instructions.

#### Major

1. Parser limits not normative: 2 MiB cap, DTD/external-entity rejection, `xml`-direct + byte-scan live only in `design.md:41`; no SHALL in `specs/`, so untestable as written.
2. New BASIC WL scenario (`spec.md:50-53`) has no task in `tasks.md` §4 and no row in `test-plan.md`; violates the change's own every-scenario-maps-to-a-test rule (`test-plan.md:3,21`).

#### Minor

None.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Promote parser contract to one SHALL in `incoming-invoice-capture` (xml-direct, byte-scan, 2 MiB reject, DTD/external-entity reject).
2. Add missing task trio + test-plan row for the BASIC WL unsupported-profile scenario.

CHANGES_APPLIED: n/a

## Rebuttals

None; no implementation follows regardless.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: 1 REVISE (matrix, BT mapping, EUR-only, gates, migration); 2 REVISE (parser SHALL, BASIC WL task row)
- **Reviewer context**: fresh-context independent subagent; read-only
- **Review scope**: specs/incoming-invoice-capture/spec.md, specs/documents/spec.md, tasks.md, test-plan.md, design.md, proposal.md, review.md rounds 1–2
- **Validation**: reads only; no shell, no tests per task instructions

### Round-1 closure check (re-verified)

1. Version/profile matrix — CLOSED. `spec.md:21` SHALLs standalone XRechnung 3.0 (UBL 2.1 `.xml`) and ZUGFeRD 2.5.2 / Factur-X 1.0.x EN 16931 only incl. XRECHNUNG URN alias; MINIMUM, BASIC WL, BASIC, EXTENDED SHALL be rejected.
2. BT field mapping + EUR-only + unsupported list — CLOSED. `spec.md:21` SHALLs BT-1→`fremd_rechnungsnummer`, BT-2→datum, BT-9→faelligkeit, BT-153/129/146/152 line mapping, BT-106/112/115 display-only, EUR-only (BT-5=EUR), 10-item unsupported list each surfaced with manual fallback and no silent coercion; BG-4/BT-30 hint-only, never auto-select.
3. Gates kept — CLOSED. `design.md:51` retains Beleg-association + accepted money-contract preconditions; `spec.md:21` SHALLs conversion follow separately accepted money contract with no added policy.
4. `fremd_rechnungsnummer` migration — CLOSED. `spec.md:5,21` separate nullable storage; `design.md:62` additive nullable `fremd_rechnungsnummer TEXT NULL` migration, no `notiz` substitute, safe rollback.

### Round-2 closure check

1. Parser contract normative — CLOSED. `spec.md:21` now SHALLs: `xml` package direct, byte-scan extraction of embedded ZUGFeRD XML, reject inputs over 2 MiB, reject any XML with DTD or external entities, try/catch map of parse failures to unreadable review state, preserve raw decimal strings without computing. Previously design-only (`design.md:41`); now testable normative language.
2. BASIC WL trio + test row — CLOSED. `spec.md:50-53` scenario "Unsupported profile falls back to manual entry" now maps to `tasks.md:42-44` red-green-refactor trio (`test_unsupported_profile_falls_back_to_manual_entry`) and `test-plan.md:18` red row. Change's own every-scenario-maps-to-a-test rule (`test-plan.md:3,21`) satisfied.

### Traceability (scenario → task → test-plan row)

- Draft not in EÜR → tasks 1.1–1.3 → test-plan:8. Covered.
- Draft editable → tasks 1.4–1.6 → test-plan:9. Covered.
- Incoming invoice supports draft state → tasks 1.7–1.9 → test-plan:10. Covered.
- Lieferschein created without draft state → tasks 1.10–1.12 → test-plan:11. Covered.
- Save manually reviewed PDF as incoming draft → tasks 2.1–2.3 → test-plan:12. Covered.
- Missing supplier prevents draft creation → tasks 2.4–2.6 → test-plan:13. Covered.
- Confirm structured fields into incoming draft → tasks 3.1–3.3 → test-plan:14. Covered.
- Unconfirmed suggestions do not create draft → tasks 3.4–3.6 → test-plan:15. Covered.
- Unreadable structured data falls back to manual entry → tasks 4.1–4.3 → test-plan:16. Covered.
- Unrepresentable value not silently mapped → tasks 4.4–4.6 → test-plan:17. Covered.
- Unsupported profile falls back to manual entry → tasks 4.7–4.9 → test-plan:18. Covered.
- Total: 11 scenarios → 11 trios → 11 red test-plan rows. No orphan scenario, task, or row.

### Findings

#### Critical

None.

#### Major

None; money/Beleg gates stay closed per instructions.

#### Minor

None.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: APPROVE

## Required Changes

None.

CHANGES_APPLIED: n/a

## Rebuttals

None; no implementation follows regardless (money/Beleg gates closed); verdict governs spec quality only.
