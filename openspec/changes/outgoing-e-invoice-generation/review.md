## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed for this change
- **Reviewer context**: fresh-context independent subagent
- **Review date**: 2026-10-04
- **Tool restrictions**: read-only inspection; only this `review.md` was written; no tests run
- **Artifacts reviewed**: complete `proposal.md`, `design.md`, and all three delta specs; maintained `pdf` and `stammdaten` specs; `AGENTS.md`, `.fvmrc`, `openspec/config.yaml`, `DESIGN.md`, `docs/01-rechnungen.md`, and `docs/08-einstellungen.md`; invoice finalization datasource/repository/use case/detail route, PDF generator/models, customer persistence, related artifact transaction/lifecycle specs; official FeRD, XStandards Einkauf/KoSIT, German VAT statute and BMF e-invoice guidance
- **Validation**: `openspec context --json` and `openspec list --json` captured; `openspec validate outgoing-e-invoice-generation --type change --strict --json` passed structurally. No tests were run.
- **Worktree**: the proposal was untracked. At final check, separate untracked `openspec/changes/document-email-delivery-and-templates/` and `openspec/changes/print-output-preferences/` were also present; neither was inspected or modified.

<!-- STALENESS: this verdict applies only to the artifacts reviewed in this round. -->

## Findings

### 🔴 Critical (blocking)

1. **The ZUGFeRD finalization snapshot has no defined read point.** The normative requirement says serialization consumes a snapshot “read from a finalized outgoing invoice” (`specs/outgoing-e-invoice-generation/spec.md:19-27`), while ZUGFeRD is generated during finalization (`specs/outgoing-e-invoice-generation/spec.md:61-69`; `design.md:19,27`). Production currently computes the number and preview totals, builds the PDF from the draft row plus those in-memory values, writes the artifact, and only then updates `ist_entwurf`, number, totals, and `original_pdf_pfad` (`lib/pages/rechnungen/rechnungen_datasource.dart:279-284,420-480`; snapshot totals are passed from `preview` at `1360-1465`). Thus no finalized persisted row exists at the current serializer call. A separate XRechnung export can read a committed snapshot, but ZUGFeRD needs the finalized values while the same transaction is still open. **Required:** define a single typed finalization snapshot containing the allocated number, final dates, canonical line/tax/totals, and sender/customer state that both output builders consume; state when it is materialized relative to the transaction and that its amounts are exactly those persisted on commit. Keep standalone XRechnung reads restricted to committed finalized snapshots. Add a scenario that asserts XML/PDF value parity and rollback on generation failure. Do not resolve this by using the preview calculator as a second serialization source.

### 🟡 Moderate

1. **The normative version labels conflate XRechnung with its technical bundle.** `proposal.md:10`, `specs/outgoing-e-invoice-generation/spec.md:5`, `specs/pdf/spec.md:5,15-17`, and `specs/pdf/spec.md:85` name “XRechnung 3.0.2” as the supported format. The design correctly distinguishes XRechnung 3.0 from the 3.0.2 Summer 2026 bundle (`design.md:13`), and the official XStandards FAQ says 3.0.2 contains no normative changes; the current bundle supplies compatible technical components for XRechnung 3.0. **Required:** pin the output as XRechnung 3.0 / UBL 2.1 and separately identify the exact validator/configuration bundle as XRechnung Bundle 3.0.2 Summer 2026, dated 2026-08-31. Use those labels consistently in XML metadata, release metadata, requirements, and fixtures. [Official version/bundle table](https://xeinkauf.de/xrechnung/versionen-und-bundles/), [official XRechnung FAQ](https://xeinkauf.de/xrechnung/faq).

2. **The invoice guide still states unconditional legal mandatory fields.** The planned guide update (`proposal.md:15`; `design.md:35`) does not explicitly remove `docs/01-rechnungen.md:172`, which calls USt-IdNr, Leistungsdatum, and Zahlungsbedingungen mandatory without conditions. §14(4) UStG states the issuer's tax number **or** VAT ID; the statute's invoice-data list does not make payment terms universally mandatory. Actual profile rules can have their own conditional business terms. **Required:** replace this blanket list with validation against the selected pinned format's applicable rules, and describe any legal invoice data only with the relevant conditions/source. This keeps the guide from turning a format-specific rule or a product input into invented tax policy. [§14 UStG](https://www.gesetze-im-internet.de/ustg_1980/__14.html), [BMF e-invoice FAQ, questions 7a and 7b](https://www.bundesfinanzministerium.de/Content/DE/FAQ/e-rechnung.html).

3. **The UI format decision conflicts with the design-system invoice flow.** The change makes ZUGFeRD automatic from the customer-level `zugferd_aktiv` flag and offers XRechnung later as a separate export (`design.md:19,29,31`; `specs/outgoing-e-invoice-generation/spec.md:61-85`). `DESIGN.md:773-784` instead says the invoice format should be explicit with ZUGFeRD, XRechnung, and PDF as format choices, and requires missing-data feedback for the selected format. **Required:** state whether the customer flag is a default or the per-invoice selection, and specify the invoice/detail UI that exposes the selected output, its validation state, and any available alternate action; otherwise reconcile the design-system rule with the customer-flag workflow. The current detail route has finalize, save-PDF, and preview actions, but no e-invoice selection/export action (`lib/pages/rechnungen/invoice_document_page.dart:152-187`).

## Implementation Gates (not new tax-policy decisions)

- The money dependency is not accepted: the current archived `invoice-money-invariants` review ends `VERDICT: REVISE`, and no maintained `openspec/specs/invoice-money-invariants/` exists. The live invoice position model/query carries a tax percentage (`ustSatz` / `ust_satz`) but no typed e-invoice category or exemption-reason mapping (`lib/pages/rechnungen/rechnungen_item_entity.dart:1-22`; `lib/pages/rechnungen/rechnungen_datasource.dart:260-275`). Keep the stated money and tax-mapping gates closed until an accepted contract and typed mapping cover every initially supported tax situation.
- No supported offline XRechnung/PDF-A validation engine is selected or evidenced for Linux, Windows, and macOS. The design correctly treats this as a precondition (`design.md:25,40,49`); prove local packaging, validation behavior, and PDF/A-3b checks on every supported target before implementation.
- `zugferd_aktiv` is persisted and mapped by the customer repository, but current production source has no UI reference to it. The listed `master-data-workspaces-and-crud` change has `no-tasks` status. Treat its user-visible editing semantics as a prerequisite (`design.md:48`), not as an already usable setting.
- `openspec list --json` reports this change as `no-tasks` (0/0). This review did not add tasks or a test plan; the author should supply the implementation/TDD breakdown before applying the change.

## Evidence

- `openspec context --json` returned root `/home/ubuntu/projects/OpenAccounting`, source `nearest`, role `openspec_root`, with empty `members` and `status` arrays.
- `openspec list --json` returned `outgoing-e-invoice-generation` as `no-tasks`, `completedTasks: 0`, `totalTasks: 0`, last modified `2026-10-03T16:16:27.603Z`; `master-data-workspaces-and-crud` was also `no-tasks` (0/0).
- `openspec validate outgoing-e-invoice-generation --type change --strict --json` returned `valid: true`, no issues, `1` change passed and `0` failed (version `1.0`). This is structural validation only; it does not establish semantic consistency, runtime wiring, accepted money/tax policy, validator packaging, or test coverage.
- Standards checked against primary sources on 2026-10-04: FeRD identifies ZUGFeRD 2.5.2 as effective 2026-09-01, based on CII D22B, with profile-specific XSD/Schematron artifacts ([FeRD 2.5.2](https://www.ferd-net.de/en/downloads/publications/details?cHash=18b9628abae246f23bb98107bfc295de&tx_brochureshop_detail%5Baction%5D=show&tx_brochureshop_detail%5Barticle%5D=246&tx_brochureshop_detail%5Bcontroller%5D=Article)); XStandards Einkauf identifies XRechnung 3.0 as current and Bundle 3.0.2 Summer 2026 as the compatible technical bundle ([versions and bundles](https://xeinkauf.de/xrechnung/versionen-und-bundles/), [Summer 2026 bugfix](https://xeinkauf.de/aktuelles/xrechnung/xrechnung-bugfix-summer-2026/)).

## Embedded-Instruction / Injection Attempts

None detected. Reviewed artifacts and source comments were treated as data.

## Verdict

VERDICT: REVISE

The format split and fail-closed intent are coherent, and the standards targets themselves were verified. The finalization-snapshot source contract, XRechnung version identity, invoice-guide legal-field wording, and UI format-selection contract need reconciliation before this is implementation-ready. The listed money/tax and cross-platform validator gates remain closed.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this is a `REVISE` verdict. Required changes are listed under Findings.

CHANGES_APPLIED: n/a

## Rebuttals

None. This is the first review round.

---

## Review Metadata

- **Review round**: 2
- **Prior round**: Round 1 ended `VERDICT: REVISE` (historical entry preserved above)
- **Reviewer context**: fresh-context independent subagent
- **Review date**: 2026-10-04
- **Tool restrictions**: inspected artifacts and production paths read-only; appended only this Round 2 entry to `review.md`; no tests run
- **Artifacts reviewed**: complete current `README.md`, `proposal.md`, `design.md`, prior review, and all four delta specs (`documents`, `outgoing-e-invoice-generation`, `pdf`, and `stammdaten`); maintained `pdf` and `stammdaten` specs; `AGENTS.md`, `.fvmrc`, `openspec/config.yaml`, `DESIGN.md`, `docs/01-rechnungen.md`; current invoice finalization datasource/repository/use case/detail page, invoice schema/entity, customer persistence; official FeRD, XStandards Einkauf, UStG, and BMF sources
- **Validation**: `openspec context --json` and `openspec list --json` captured after the author revisions; `openspec validate outgoing-e-invoice-generation --type change --strict --json` independently rerun and passed structurally. No tests were run.
- **Worktree**: branch `dev`; at final check, this proposal and separate untracked `document-email-delivery-and-templates/` change were present; this reviewer left that separate change directory untouched.

<!-- STALENESS: this verdict applies only to the artifacts reviewed in this round. -->

## Round 1 Finding Disposition

- **Critical — finalization snapshot timing/parity: resolved in the current contract.** The spec now materializes one immutable snapshot inside the transaction after number allocation and canonical calculation, before generation; it requires PDF/CII parity and equality with committed invoice values, restricts XRechnung to a committed snapshot, and specifies rollback (`specs/outgoing-e-invoice-generation/spec.md:19-39`; `design.md:21,27`).
- **Moderate — XRechnung format/bundle identity: resolved.** The output is named XRechnung 3.0 / UBL 2.1 and the validator is separately named Bundle 3.0.2 Summer 2026 (`proposal.md:11`; `design.md:13`; `specs/outgoing-e-invoice-generation/spec.md:5,109`; `specs/pdf/spec.md:5`). Official XStandards sources confirm the bundle has technical artifacts compatible with XRechnung 3.0 and no normative summer 2026 version change ([versions and bundles](https://xeinkauf.de/xrechnung/versionen-und-bundles/), [Summer 2026 release](https://xeinkauf.de/aktuelles/xrechnung/xrechnung-bugfix-summer-2026/)).
- **Moderate — blanket legal-field claims: resolved as a proposal requirement.** The proposal and design now explicitly require replacing the unconditional USt-IdNr/service-date/payment-terms list with conditions based on applicable law and pinned format rules (`proposal.md:16`; `design.md:35`). This matches the current §14 UStG and BMF guidance ([§14 UStG](https://www.gesetze-im-internet.de/ustg_1980/__14.html), [BMF e-invoice FAQ](https://www.bundesfinanzministerium.de/Content/DE/FAQ/e-rechnung.html)). `docs/01-rechnungen.md:166-173` itself still contains the old wording; updating it remains an implementation deliverable required by the proposal.
- **Moderate — explicit format choice versus customer default: resolved.** `zugferd_aktiv` only preselects ZUGFeRD or PDF, and the user can explicitly choose among all three formats (`proposal.md:9`; `design.md:19`; `specs/stammdaten/spec.md:5-23`; `specs/outgoing-e-invoice-generation/spec.md:85-161`). The visible-choice and readiness contract aligns with `DESIGN.md:773-786`; the selected enum is persisted through finalization and restored by the detail read.

## Findings

The selected-format persistence gap identified during this round was resolved in the author revisions before this final verdict: `ausgabeformat` is part of the finalization snapshot and is atomically persisted on the finalized invoice (`proposal.md:16,29`; `design.md:19,21,37`; `specs/documents/spec.md:3-29`; `specs/outgoing-e-invoice-generation/spec.md:19-21,139-161`). The contract defines legacy `NULL` as PDF without consulting the current customer preference and covers closing/reopening an XRechnung-selected invoice while keeping XML export explicit. No unresolved findings remain.

## Implementation Gates

- The current inventory reports `outgoing-e-invoice-generation` as `no-tasks` (`completedTasks: 0`, `totalTasks: 0`). Add the implementation test plan and tasks after this design/spec review and before applying the change; strict validation does not enforce this workflow gate.
- The design's implementation preconditions remain open: an accepted invoice-money contract, an approved typed tax-category/exemption map, an offline XRechnung/PDF-A validator proven on each supported desktop OS, and a user-facing master-data path for `zugferd_aktiv` (`design.md:46-52`). The current inventory reports `master-data-workspaces-and-crud` as `no-tasks`; current code stores/maps `zugferd_aktiv` but exposes no UI for it (`lib/pages/stammdaten/kunden_repository.dart:131,174-180,240-290`). These conditions block implementation, but are explicitly retained as preconditions rather than being represented as existing production capability.
- The committed e-invoice snapshot must preserve customer data captured at finalization: the current invoice read joins current customer fields and the existing row stores the company `absender_snapshot` only (`lib/pages/rechnungen/rechnungen_datasource.dart:1207-1217`; `lib/core/db/database.dart:538-562`). Implement persistent customer snapshot data as required by `specs/outgoing-e-invoice-generation/spec.md:21`; do not build a later XRechnung export from changed live customer data.

## Evidence

- `openspec context --json`: root `/home/ubuntu/projects/OpenAccounting`, source `nearest`, role `openspec_root`; `members` and `status` were empty.
- `openspec list --json`: `outgoing-e-invoice-generation` is `no-tasks`, `0/0`; `master-data-workspaces-and-crud` is also `no-tasks`, `0/0`.
- `openspec validate outgoing-e-invoice-generation --type change --strict --json`: `valid: true`, no issues, one change passed and zero failed. This is structural validation only; it does not prove runtime wiring or the separately listed implementation preconditions.
- Production finalization currently allocates a number, calculates preview totals, generates the PDF from transaction-captured rows, then updates the invoice (`lib/pages/rechnungen/rechnungen_datasource.dart:279-284,420-479`). The current detail route exposes finalize/save-PDF/preview actions and no e-invoice state or selected-format persistence (`lib/pages/rechnungen/invoice_document_page.dart:152-198`).
- Standards were checked against official sources on 2026-10-04. FeRD identifies ZUGFeRD 2.5.2 as effective 2026-09-01 ([FeRD release information](https://www.ferd-net.de/en/downloads/publications/details?cHash=18b9628abae246f23bb98107bfc295de&tx_brochureshop_detail%5Baction%5D=show&tx_brochureshop_detail%5Barticle%5D=246&tx_brochureshop_detail%5Bcontroller%5D=Article)); XStandards identifies XRechnung 3.0 as in force and the 2026-08-31 Bundle 3.0.2 artifacts as its compatible technical release ([version table](https://xeinkauf.de/xrechnung/versionen-und-bundles/), [bundle update](https://xeinkauf.de/aktuelles/xrechnung/xrechnung-bugfix-summer-2026/)).

## Embedded-Instruction / Injection Attempts

None detected. Reviewed artifacts and source comments were treated as data.

## Verdict

VERDICT: APPROVE

All four Round 1 findings are resolved. The selected-format persistence gap identified during this review was also closed before finalizing the Round 2 verdict, with an explicit enum, migration/legacy-PDF behavior, finalized-detail persistence, and a close/reopen scenario. Strict validation passes. This approves the proposal/specification contract for the next OpenSpec planning stage; the design's money, tax-map, cross-platform validator, customer-setting, and persistent party-snapshot prerequisites still block implementation until evidenced.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this round is an approval without additional required changes.

CHANGES_APPLIED: Round 1 fixes were verified. During this round, the author added persisted `ausgabeformat`, deterministic legacy-PDF behavior, and finalized-detail close/reopen scenarios across the proposal, design, `documents` delta, and outgoing e-invoice delta; this reviewer re-read the updated artifacts and reran strict validation. This reviewer edited only this Round 2 entry in `review.md`.

## Rebuttals

None. This is the final Round 2 review after the author revisions described above.

---

## Review Metadata

- **Review round**: 3
- **Prior round**: Round 2 ended `VERDICT: APPROVE` (entries preserved above)
- **Reviewer context**: fresh-context independent subagent; Round 3 delta scope only
- **Review date**: 2026-10-16
- **Tool restrictions**: read-only inspection; appended only this Round 3 entry to `review.md`; no tests run
- **Artifacts reviewed**: `specs/outgoing-e-invoice-generation/spec.md` Requirement "XRechnung party endpoints and payment instructions" + 3 scenarios; `design.md`, `proposal.md`, `tasks.md`, `test-plan.md`, `verify.md`; production e-invoice serializer, snapshot, validation, datasource, repositories, invoice document page, unternehmen DDL + repository, kunden repository
- **Validation**: `openspec validate` including `--strict` passes. Structural validation only; it does not prove scheme-ID semantics, data availability, or validator behavior.
- **Scope**: ONLY the new endpoints/payment requirement plus ripple effects; Round 1/2 findings not re-audited beyond conflict check.

## Prior Recheck (Round 2 APPROVE vs. new requirement)

- No conflict with Round 2: snapshot/parity contract, XRechnung 3.0 vs Bundle 3.0.2 identity, explicit format choice, and fail-closed posture all stand.
- Motivated by live KoSIT evidence: `verify.md` records missing seller electronic address (R020), missing buyer electronic address (R010), and missing payment instructions BG-16 (BR-DE-1).

## Findings

### Critical (blocking)

None. Scheme IDs are correct, fail-closed is consistent, and no Round 2 finding is reopened.

### Moderate

1. **Seller fallback references a company `email` field that does not exist.** The `unternehmen` table has no `email` column and `_sellerFromCompany` reads `row['email']`, always null for company rows. Fix before implementation: drop the seller-email fallback and fail naming `ust_idnr`.
2. **No tasks or test-plan coverage for the 3 new scenarios.** Add tasks section 12 and 3 test-plan rows; correct the coverage-notes count.
3. **Design and proposal are stale relative to the new normative behavior.** Add one design decision (endpoint source mapping, scheme rationale, BG-16 deferral gate) plus a proposal bullet.
4. **No value normalization specified.** State verbatim-after-trim with malformed values deferred to pinned-rule diagnostics.
5. **Payment block scoped to XRechnung only; ZUGFeRD silent.** Clarify intentional (BR-DE-1 is XRechnung-specific).
6. **`buyerReference` provenance wording is inaccurate.** It is a per-export typed snapshot parameter, not persisted master data; reword.

## Scheme-ID Assessment (EN16931/XRechnung EAS)

- `9930` for company VAT ID (BT-34): correct (German VAT ID).
- `EM` for email endpoints: correct for both sides under EN16931.
- `0204` for buyerReference-as-Leitweg (BT-49): correct (Leitweg-ID scheme).
- Fail-closed on missing addresses matches mandatory cardinality and no-invention rules.

## Implementation Gates (carried + new)

- Round 2 gates stand, plus: accepted invoice payment-means model, company endpoint source resolution, tasks section 12 + 3 test-plan rows.

## Evidence

- `specs/outgoing-e-invoice-generation/spec.md` (new requirement + 3 scenarios).
- Serializer has no `EndpointID`/`PaymentMeans`; party snapshot carries `vatId` + `email`; `buyerReference` is an explicit optional export param.
- No company `email` column in `unternehmen` DDL/repository.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: APPROVE

Scheme IDs correct; fail-closed consistent; BG-16 deferral coherent; no conflict with Round 2. Moderate findings above must be resolved before implementation but do not overturn correctness.

## Required Changes (follow-ups before implementation)

Findings Moderate 1-6; no Critical items. Review-only; entry appended by parent.

## Rebuttals

None.

---

## Review Metadata

- **Review round**: 4
- **Prior round**: Round 3 ended `VERDICT: APPROVE` with 6 Moderate follow-ups required before implementation (entries preserved above)
- **Reviewer context**: fresh-context independent subagent; Round 4 follow-up-verification scope only
- **Review date**: 2026-10-16
- **Tool restrictions**: read-only inspection; appended only this Round 4 entry to `review.md`; no tests run
- **Artifacts reviewed**: endpoints/payment requirement + 3 scenarios; `tasks.md` section 12; `test-plan.md` new rows + coverage notes; `design.md` Decision 11; `proposal.md` What-Changes bullet
- **Validation**: structural `openspec validate` passes. Structural validation only.
- **Scope**: ONLY whether the 6 Round 3 Moderate follow-ups were correctly applied.

## Follow-up Disposition (Round 3 Moderate 1-6)

- **Moderate 1 — seller fallback dropped: applied.** Seller BT-34 from company `ust_idnr`/9930, else fails closed naming `ust_idnr`.
- **Moderate 2 — tasks + test-plan coverage: applied.** Section 12.1-12.9 present, all unchecked; 3 new red test-plan rows; coverage notes corrected to 38.
- **Moderate 3 — design + proposal currency: applied.** Decision 11 states mapping, rationale, deferral; proposal bullet matches.
- **Moderate 4 — value normalization: applied.** Verbatim after trimming; malformed deferred to pinned-rule diagnostics.
- **Moderate 5 — XRechnung-only payment gate: applied.** Stated in spec and design.
- **Moderate 6 — buyerReference provenance: applied.** Reworded to snapshot fields.

## Findings

Non-blocking nits only: design numbering `11.` before `10.`; fallback scenario title buyer-only; proposal bullet wording.

## Verdict

VERDICT: APPROVE

All 6 Round 3 Moderate follow-ups correctly applied; no new contradictions.

## Rebuttals

None.

---

## Review Metadata

- **Review round**: 4
- **Prior round**: Round 3 ended `VERDICT: APPROVE` with 6 Moderate follow-ups required before implementation (entries preserved above)
- **Reviewer context**: fresh-context independent subagent; Round 4 follow-up-verification scope only
- **Review date**: 2026-10-16
- **Tool restrictions**: read-only inspection; appended only this Round 4 entry to `review.md`; no tests run
- **Artifacts reviewed**: endpoints/payment requirement + 3 scenarios; `tasks.md` section 12; `test-plan.md` new rows + coverage notes; `design.md` Decision 11; `proposal.md` What-Changes bullet
- **Validation**: structural `openspec validate` passes. Structural validation only.
- **Scope**: ONLY whether the 6 Round 3 Moderate follow-ups were correctly applied.

## Follow-up Disposition (Round 3 Moderate 1-6)

- **Moderate 1 — seller fallback dropped: applied.** Seller BT-34 from company `ust_idnr`/9930, else fails closed naming `ust_idnr`.
- **Moderate 2 — tasks + test-plan coverage: applied.** Section 12.1-12.9 present, all unchecked; 3 new red test-plan rows; coverage notes corrected to 38.
- **Moderate 3 — design + proposal currency: applied.** Decision 11 states mapping, rationale, deferral; proposal bullet matches.
- **Moderate 4 — value normalization: applied.** Verbatim after trimming; malformed deferred to pinned-rule diagnostics.
- **Moderate 5 — XRechnung-only payment gate: applied.** Stated in spec and design.
- **Moderate 6 — buyerReference provenance: applied.** Reworded to snapshot fields.

## Findings

Non-blocking nits only: design numbering `11.` before `10.`; fallback scenario title buyer-only; proposal bullet wording.

## Verdict

VERDICT: APPROVE

All 6 Round 3 Moderate follow-ups correctly applied; no new contradictions.

## Rebuttals

None.

---

## Review Metadata

- **Review round**: 5
- **Prior round**: Round 4 ended `VERDICT: APPROVE` (entries preserved above)
- **Reviewer context**: fresh-context independent subagent; Round 5 payment-delta scope only
- **Review date**: 2026-10-16
- **Tool restrictions**: read-only inspection; appended only this Round 5 entry to `review.md`; no tests run
- **Artifacts reviewed**: payment sourcing paragraph + scenarios; design Decision 11; proposal bullet; verify KoSIT evidence; tasks 12.7-12.9; snapshot/builder/UBL/validation/fixture/tests
- **Validation**: structural `openspec validate` passes (structural only). No tests run by reviewer.
- **Scope**: ONLY the payment delta and ripple effects.

## Prior Recheck

- No Round 1/2 finding reopened. No-invention posture retained (verbatim trim, blank means null). XRechnung-only gate retained.

## Findings

### Critical (blocking)

None. BT-81 58 + BG-17 correct for German SEPA transfer; company-IBAN sourcing legitimate (pre-existing `unternehmen.iban` column); fail-closed genuine.

### Moderate (follow-ups before archive)

1. **Spec scenario contradicts its own requirement.** Scenario "Missing payment data fails closed" still reads no-model/no-block while the requirement paragraph mandates the 58/BG-17 block. Rewrite GIVEN/THEN around absent IBAN.
2. **Design Decision 11 and proposal bullet still say "defer".** One-line sync each to company-`iban` sourcing.
3. **No test asserts the positive emit path.** Add one scenario + test for 58 plus payee account equals IBAN.
4. **Company IBAN has no user-facing write path.** Settings form edits only name; normalize map drops iban. Add iban to normalize map plus a settings IBAN field (reuse konten IBAN validation) or document the source.

## Verdict

VERDICT: APPROVE

Payment delta correct; Moderate 1-4 must be resolved before archive.

## Rebuttals

None.

---

## Review Metadata

- **Review round**: 6
- **Prior round**: Round 5 ended `VERDICT: APPROVE` (payment delta; entries preserved above)
- **Reviewer context**: fresh-context independent subagent; Round 6 delivery-date delta scope only
- **Review date**: 2026-10-16
- **Tool restrictions**: read-only inspection; appended only this Round 6 entry to `review.md`; no tests run
- **Artifacts reviewed**: Requirement "XRechnung delivery date" + 2 scenarios; `tasks.md` section 13; `test-plan.md` rows; `design.md`, `proposal.md`, `verify.md`
- **Validation**: structural `openspec validate` passes (structural only). No tests run by reviewer.
- **Scope**: ONLY the delivery-date delta and ripple effects.

## Prior Recheck

- No conflict with Rounds 2-5. Motivated by live KoSIT evidence (BR-DE-TMP-32 info-level delivery note).

## Findings

### Critical (blocking)

None. BT-72 correct for a single delivery date; fail-closed consistent.

### Moderate (follow-ups before implementation)

1. **Design and proposal stale.** Add design Decision 12 plus proposal bullet.
2. **Coverage notes undercount.** Correct 38 to 40 scenarios.
3. **Tasks 13.7-13.8 scope honesty.** Record owning-invoice coordination; give 13.7 concrete test identity; add test-plan row for persistence/capture.
4. **BT-72-only vs BG-14 undecided.** Decide single-date-only scope vs period path in design.
5. **Strictness delta unrecorded.** State gate is stricter than pinned info-level rule.

### Minor

- Restate verbatim-after-trim plus ISO shape convention.

## Verdict

VERDICT: APPROVE

Delivery-date delta correct and consistent. Moderate 1-5 must be resolved before implementation.

## Rebuttals

None.

---

## Review Metadata

- **Review round**: 7
- **Prior round**: Round 6 approved the delivery-date delta only; this is the fresh review of the tax-contract revision.
- **Reviewer context**: Fresh-context independent review subagent, working from the requested on-disk commit.
- **Review date**: 2026-10-18
- **Tool restrictions**: Inspected commit `969cfa605ffddb1bf2fbd9a104fb18d544d62a36` and its six-file diff from `86a71fe301447af3fe19b24916d0f830f65decf7`; appended only this entry to `review.md`; no application tests run.
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/outgoing-e-invoice-generation/spec.md`, `test-plan.md`, `tasks.md`, and `verify.md`.
- **Validation**: `openspec validate outgoing-e-invoice-generation --type change --strict --json` → `valid: true`, zero issues. `openspec validate --specs --strict` → 72 passed, 0 failed. `openspec list --json` → 90/128 tasks complete. `git show --check` and `git diff --check 86a71fe301447af3fe19b24916d0f830f65decf7..969cfa605ffddb1bf2fbd9a104fb18d544d62a36` were clean; the commit changes exactly the six reviewed artifacts.
- **Scope**: Full review of the revised explicit tax mapping and its proposal, test, task, migration, and verification consequences.

## What This Change Does

It replaces rate-derived e-invoice tax categorization with a closed, persisted treatment and legal-basis map for S, Z, E, AE, K, and G. It keeps §25a explicitly unavailable until its category, reason, and disclosed-total relationship receive an accepted decision.

## Prior Recheck

- The revised mapping requires additive v26 tax-evidence fields after reserved migration slots v23–v25; no migration implementation is claimed here.
- A stored 0% rate alone does not classify a line; custom rates, generic exemptions, unsupported reverse-charge cases, and legacy rows without evidence fail closed.
- §19 uses the exact XRechnung text and no VATEX code. §13b uses AE, 0%, VATEX-EU-AE, and the stated reverse-charge text. K and G are separately named cross-border treatments, with VAT IDs, destination/delivery evidence, homogeneous invoice treatment, and the format-specific codes. These EN 16931 code mappings are supported by the cited XRechnung specification and European Commission guidance.
- §25a has no invented category or reason; disclosed invoice amounts remain separate from internal margin tax, and generation fails closed.
- The test plan names executable red cases for each new tax scenario. Only tasks 7.1–7.6 were reopened. `verify.md` accurately records `DECISION: FAIL`, 90/128 complete, no tests for this spec-only revision, and absent cross-platform validator proof.

## Findings

### Critical (blocking)

1. **§13b classification can be persisted without evidence that the reverse-charge case legally applies** (`design.md:32-33`; `specs/outgoing-e-invoice-generation/spec.md:57-58,63-65`).
   - **What this is:** The table maps EU services under §13b(1) and domestic construction services under §13b(2) to AE, 0%, and VATEX-EU-AE.
   - **Problem:** The required evidence is seller/buyer VAT IDs plus generic “EU destination/transaction” or “construction-service” evidence. §13b(1) requires a service taxable in Germany under §3a(2) from an entrepreneur established in another EU Member State. For §13b(2) construction services, §13b(5) limits the liable recipient to an entrepreneur who sustainably provides corresponding construction services (with a qualifying certificate providing a statutory presumption). A buyer VAT ID and proof that construction work occurred do not establish that recipient condition. For example, construction work for a VAT-registered business that does not itself sustainably provide construction services can be emitted as reverse charge even though §13b(5) does not make that recipient liable.
   - **Fix:** Specify the accepted persisted upstream evidence for the §13b(1) place-of-supply/supplier conditions and the §13b(2)/§13b(5) recipient qualification; if that evidence source is not accepted, keep these treatments unsupported and fail closed. Do not infer eligibility in the serializer. See [UStG §13b](https://www.gesetze-im-internet.de/ustg_1980/__13b.html) and [UStG §3a](https://www.gesetze-im-internet.de/ustg_1980/__3a.html).
   - **If we skip it:** An invoice can state that the recipient owes VAT when the statutory reverse-charge conditions are not met.

### Not Checked

Actual code-list files inside the pinned ZUGFeRD and XRechnung packages are not part of this spec-only revision. The design correctly leaves inspection of those exact local artifacts as an implementation gate.

## Verdict

VERDICT: REVISE

The format codes and stated fail-closed boundaries are clear, but the supported §13b cases lack the legal eligibility evidence needed to accept the treatment whitelist as written. Resolve finding 1 before treating prerequisite 1.2 as accepted.

## Required Changes

Finding 1 must be resolved before this tax contract is approved.

## Rebuttals

None.

## CHANGES_APPLIED

No proposal, design, spec, test-plan, task, or verification edits were made. This independent review entry was appended to `review.md` only.


---

What this change does: It replaces rate-derived tax categories with persisted treatment and legal-basis evidence, including case-specific §13b eligibility evidence. It keeps §25a fail-closed and specifies additive v26 persistence.

## Review Metadata

- **Review round**: 8
- **Prior round**: Round 7 ended `VERDICT: REVISE` for missing persisted §13b eligibility evidence.
- **Reviewer context**: Fresh independent review from exact commit `c08768fa688a6de345c4b27779dd0ce317f757f2`, parent `969cfa605ffddb1bf2fbd9a104fb18d544d62a36`.
- **Review date**: 2026-10-18
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/outgoing-e-invoice-generation/spec.md`, `test-plan.md`, `tasks.md`, and `verify.md` at the requested commit.
- **Validation**: `openspec validate outgoing-e-invoice-generation --type change --strict --json` passed (1/1, no issues); `openspec validate --specs --strict` passed (72/72). `git show --check` and `git diff --check 969cfa605ffddb1bf2fbd9a104fb18d544d62a36..c08768fa688a6de345c4b27779dd0ce317f757f2` were clean. `git verify-commit` reported a good EdDSA signature from key `E1E40CF8628D8C6FFB49C0A5720E5F25F4EDFDD1`. The commit changes exactly the six contract artifacts reviewed.
- **Task ledger**: Comparing `86a71fe301447af3fe19b24916d0f830f65decf7..969cfa605ffddb1bf2fbd9a104fb18d544d62a36` shows only tasks 7.1–7.6 reopened; `c08768f` leaves them open and changes no task checkbox. The ledger remains 90/128 complete.
- **Scenario coverage**: All 40 current delta-spec scenarios have one named test-plan row. Two additional test-plan rows refer to scenarios absent from the current delta (`Missing payment data fails closed` and `Invoice persists and captures the delivery date`); they do not leave a current scenario unmapped.
- **Tool restrictions**: Reviewed the six committed contract artifacts and official law/format sources only; appended this entry to `review.md`. No proposal, design, spec, task, verification, or implementation edits were made. No application tests or implementation review were performed.
- **Scope**: Recheck of Round 7’s §13b eligibility-evidence finding plus the tax contract, v26 migration ordering, task/scenario traceability, and absence of new implementation claims.

## Round 7 Finding Disposition

- **§13b(1) eligibility evidence: resolved.** The contract now requires persisted supplier establishment country/basis and German-fixed-establishment participation status; recipient status and establishment; service kind; place-of-supply basis/country; German taxability; required seller/buyer profile IDs; and a reference to the immutable upstream tax assessment. Unknown, missing, unresolved, or contradictory facts produce a localized position/field diagnostic and no artifact.
- **§13b(2) no. 4 construction eligibility: resolved for the stated supported subset.** The contract requires an explicitly taxable German construction service on German immovable property, an entrepreneur recipient, and an authority-issued USt 1 TG certificate identifying construction services, matching the immutable buyer VAT ID, and valid on `leistungsdatum`. The persisted certificate reference, scope, issue date, and validity-through date are checked. Missing, expired, mismatched, or out-of-scope evidence fails closed; a VAT ID or construction description alone does not qualify the recipient.
- **§13b(1) EU supplier boundary: legally supported.** UStG §13b(1) expressly covers services taxable in Germany under §3a(2) supplied by an entrepreneur established in another EU Member State. §13b(7) supplies the establishment and German-fixed-establishment-not-involved rules. The contract’s EU supplier requirement is therefore not an unjustified format restriction. EN 16931’s AE / VATEX-EU-AE mapping is generic reverse-charge encoding: the European Commission guidance describes it for domestic reverse charge under national law. The code neither requires nor decides the supplier’s country.
- **Explicit bounded scope:** The listed supplier-basis enum supports seat/management and fixed establishment; it does not encode the statute’s separate residence/ordinary-stay bases. The BMF USt 1 TG form also permits registration under a tax number or a VAT ID, while this contract accepts the VAT-ID-matching path. These are narrower, fail-closed evidence paths, not claims that the excluded cases are legally ineligible. Keep them unsupported unless an accepted owner decision expands the scope.
- **§25a and migration: consistent.** §25a has no approved category/reason or disclosed-total relationship, remains unavailable, and cannot disclose internal margin tax. Tax evidence is additive migration v26 after reserved v23 (mileage), v24 (setup anchor), and v25 (cashbook close evidence); legacy tax fields remain unresolved without rate-based backfill.
- **Implementation status: truthful.** The commit changes documentation only. `verify.md` continues to report the spec-only state, no tests run for this revision, §25a unresolved, migration and platform validator gates open, and `DECISION: FAIL`. No implementation or runtime capability is claimed.

## Findings

None blocking. Round 7’s missing-evidence finding is closed for the explicit supported cases. The evidence-model scope limits above remain fail-closed and are not represented as legal ineligibility.

## Evidence

- Official UStG §13b(1),(5),(7): §13b(1) states the EU-established supplier condition; §13b(5) establishes the construction-recipient qualification and a certificate valid at the time of service; §13b(7) defines establishment and treatment where a German fixed establishment is not involved. [UStG §13b](https://www.gesetze-im-internet.de/ustg_1980/__13b.html)
- Official UStG §3a(2): the general place of supply for covered business services is the recipient business establishment or the recipient fixed establishment receiving the service. [UStG §3a](https://www.gesetze-im-internet.de/ustg_1980/__3a.html)
- European Commission EN 16931 tax-code guidance, case 3: identifies AE / VATEX-EU-AE as the coding for domestic reverse charge under national law, requiring zero rates and amounts plus seller and buyer VAT IDs. [Technical guidance for tax codes in EN 16931](https://ec.europa.eu/digital-building-blocks/sites/download/attachments/467108974/eInvoicing%20technical%20guidance%20document_v1.pdf?api=v2&modificationDate=1721117125403&version=2)
- BMF USt 1 TG form issued 2026-04-10: identifies the recipient by name/address, allows registration under a tax number or VAT ID, and states an expiry date limited to at most three years. This supports the contract’s certificate date check and shows that its VAT-ID matching rule is a conservative subset. [BMF USt 1 TG form](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Umsatzsteuer/2026-04-10-bescheinigung-USt-1-TG.pdf)
- The requested commit and task/scenario checks were run directly against the specified checkout and commit. They establish structural validity, commit integrity, and mapping coverage only; they do not establish application behavior, tax assessment correctness for any real transaction, or platform validator packaging.

## Verdict

VERDICT: APPROVE

The Round 7 evidence defect is resolved for the contract’s explicitly supported §13b cases. The EU-established-supplier condition follows the German statute; the EN 16931 reverse-charge code is generic. Construction recipient eligibility, certificate scope/identity/validity, persisted evidence, and fail-closed diagnostics are now specified. Approval is limited to the stated documentation contract; §25a, v26 implementation, and platform validator gates remain open.

## Rebuttals

None.

## CHANGES_APPLIED

No contract or implementation artifacts were edited. This independent Round 8 review was appended to `review.md` only.

Verdict: Ship.

## Round 11 Author Evidence

- **Independent verdict:** `APPROVE_WITH_CHANGES`.
- **Required condition:** State that v24 is the pre-v25 starting schema baseline while v25 mileage is in flight on the current `dev` tree; preserve the serialized order v25 mileage → v26 cashbook opening/events source → v27 cashbook close evidence → v28 e-invoice typed tax evidence.
- **CHANGES_APPLIED:** yes.
- **Author scope:** contract-only wording in `proposal.md`, `design.md`, `specs/outgoing-e-invoice-generation/spec.md`, and `tasks.md`, plus this author-evidence entry. No source, test, or maintained-spec files were changed.
- **Review base:** uncommitted `dev` diff based on HEAD `81948b3ca3e90d9372f7f964527cc77c55f74ff8`.
- **Overall status:** The OpenSpec change remains incomplete at 106/138 tasks; the later persistence and implementation work remains open.
Not checked: Application runtime behavior, actual serializer output, test execution, and validator packaging on supported platforms.

## Round 12 Author Evidence (2026-10-23)

- **Independent verdict:** `REVISE`.
- **Reviewer-reported review snapshot:** base/HEAD `c3e3f51e038de63751f47aac4dd1f86b9b6b431e`; reviewed-file aggregate SHA-256 `20851d99136e478856afcd91cbf7466ab64e9a78cb8d7f14a901ed73c0d3418f`; scoped binary diff SHA-256 `6ba7221ad825fa7debfb8b1a46d9b3beaf3c249914fb271290995e192709948b`. These identify the pre-correction review snapshot and do not fingerprint the corrected artifacts.
- **Corrected contract input fingerprint (author-computed, unreviewed):** base/HEAD `c3e3f51e038de63751f47aac4dd1f86b9b6b431e`; aggregate SHA-256 `9e7f7254361a052502a5811308ddaf5af2abf71025d47e21d82e70338c065285`, computed over the sorted relative paths and bytes for `proposal.md`, `design.md`, `tasks.md`, `test-plan.md`, and all four delta specs with NUL separators; scoped binary diff SHA-256 `bb10494bc7ac26719ca02c9d45870ddccee795df132afeedc496f5527ef7ac3e` over those same paths. This identifies the corrected contract inputs only; it does not supersede Round 12's `REVISE` or imply approval.
- **Findings:** (1) `specs/outgoing-e-invoice-generation/spec.md` encoded the supplier-carried scenario and following G scenarios with literal `\n` text, so they were not separate Markdown scenarios. (2) The current builder still permits G using a third-country billing address without an explicit per-position destination, movement actor, resolved line-bound evidence, or §6(2) foreign-buyer verification; this is an implementation gap, not approval. (3) `verify.md` claimed 32 passed and 7 failed (39 total), while the current test file contains 42 top-level tests without a skip or name filter, and the latest independent review was absent from this file.
- **Author correction status:** The G scenarios have been restored as separate Markdown blocks, preserving both supplier/supplier-agent and qualified foreign-buyer/buyer-agent routes and their fail-closed cases. The exact current full-file run completed with 35 passed, 7 failed, and 0 skipped across 42 declarations; it exited 1 and is recorded with test/source hashes and all failure names in `verify.md`. The test evidence does not change the `REVISE` verdict or provide contract approval.
- **K positive output:** Still blocked until v28 input capture and a real immutable evidence resolver verify the qualifying buyer, the valid foreign EU VAT ID used, goods, date, actual destination, movement, and this invoice line/supply. A non-empty source reference is not evidence and must not produce positive K output.
- **Gate:** Round 12 remains `REVISE`. No G production work may proceed until a fresh independent semantic review approves the corrected contract; positive K remains blocked on its real resolver prerequisite.


## Round 13 Author Evidence (2026-10-23)

- **Independent verdict:** `REVISE`; this amendment is awaiting a fresh independent semantic review.
- **Reviewer-reported pre-amendment snapshot:** base/HEAD `c3e3f51e038de63751f47aac4dd1f86b9b6b431e`; corrected aggregate SHA-256 `9e7f7254361a052502a5811308ddaf5af2abf71025d47e21d82e70338c065285`; scoped diff SHA-256 `bb10494bc7ac26719ca02c9d45870ddccee795df132afeedc496f5527ef7ac3e`. These identify the reviewed pre-amendment inputs only.
- **Corrected pre-approval input snapshot:** base/HEAD `c3e3f51e038de63751f47aac4dd1f86b9b6b431e`; scoped binary diff SHA-256 `f9bcdf12ec8f00075c0bee1e2387ecbae3b0b9b4b049dbd647f1288ac1b94e72`. The reviewer independently reproduced this scoped diff for the corrected contract review; no aggregate fingerprint is claimed here.
- **Finding:** The §6a contract did not explicitly require §6a(1)(3): the buyer’s intra-Community acquisition must be subject to VAT rules in the actual destination Member State. The reviewer accepted the G supplier-carried and qualified buyer-carried route contract and the separate Markdown scenarios; that acceptance does not approve implementation or the K amendment.
- **Author amendment:** The §6a requirement, design, v28 task, test plan, and verification ledger now name the typed destination-state acquisition-tax treatment and require the immutable resolver to verify it for this buyer and these goods. Missing, unknown, not-subject, or unverified treatment fails closed. This field means applicability of destination-state VAT rules, not actual tax charged or paid; UStAE Abschnitt 6a.1(18) recognizes the buyer-used valid foreign VAT ID as evidence and does not require actual taxation. Sources: [UStG §6a(1)](https://www.gesetze-im-internet.de/ustg_1980/__6a.html) and [UStAE Abschnitt 6a.1(17)–(18)](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Umsatzsteuer/Umsatzsteuer-Anwendungserlass/Umsatzsteuer-Anwendungserlass-31-12-2025.pdf?__blob=publicationFile&v=2).
- **Implementation gate:** Positive K remains blocked until v28 captures the typed treatment and a real immutable resolver verifies the buyer, valid foreign EU VAT ID used, goods, delivery date, actual destination, movement, and exact invoice-line/supply binding. G production remains blocked until a fresh independent review approves the corrected contract.


## Round 13 Corrected Contract Approval (2026-10-23)

- **Independent verdict:** `APPROVE` for the Round 13 contract amendment; implementation and positive K/G output are not approved. The initial Round 13 `REVISE` recorded above applies to the pre-amendment input.
- **Reviewer snapshot identifiers:** base/HEAD `c3e3f51e038de63751f47aac4dd1f86b9b6b431e`; independently reproduced scoped diff SHA-256 `f9bcdf12ec8f00075c0bee1e2387ecbae3b0b9b4b049dbd647f1288ac1b94e72`; reviewer manifest fingerprint `ce3177020be20a6d394ce93b2b8ac56b8d1aaf1438cb5f397a5fd2363816e6cc`. The earlier author aggregate is omitted because it was not reproduced.
- **Approval scope:** the §6a(1)(3) typed predicate is explicit: the resolver must verify that this buyer’s acquisition of the line goods is subject to VAT rules in the actual destination Member State. This means applicability of those rules, not actual tax charged or paid. The approved G contract retains supplier-carried movement under §6(1)(1) and qualified foreign-buyer-carried movement under §6(1)(2) plus §6(2), with actual line destination and resolved movement evidence.
- **Post-approval wording synchronization:** the proposal K summary and positive K test-plan row were updated to state the approved §6a(1)(3) predicate and no-actual-tax-paid condition. These edits preserve the approved semantics.
- **Implementation status:** this approval does not approve production implementation, positive K or G output, or the v28 persistence/resolver design. Positive K/G remain blocked until their real immutable line-bound evidence path is implemented.


## Current Review Status (2026-10-25)

- **Independent verdict:** `REVISE`. The reviewed contract lacked an accepted upstream per-position §25a disclosed amount and did not define how different VATEX-EU-F/I/J reasons fit the shared E/0% breakdown.
- **Approval status:** Any prior approval of the §25a/e-invoice tax contract is void for this revision. This author repair is not approval; fresh independent review of the complete current snapshot is required before tax persistence or input-wiring code begins.
- **Source trace:** The accepted `VorschauResult` exposes only invoice-level accounting `nettoCents`, `ustCents`, `bruttoCents`, and discount totals. `EInvoiceCanonicalTotals` has only net/tax/gross; `EInvoiceSnapshotBuilder` reconstructs line splits from price/quantity/rate and groups breakdowns. No accepted per-position canonical disclosure amount or price/adjustment basis exists, so the current source is insufficient.
- **Author repair:** The delta spec, proposal, and design now require a typed accounting/disclosure result with persisted-position-keyed final BT-131, disclosed price/adjustment basis, EN 16931 disclosure totals, and separate accounting-only margin tax. For the maintained §25a-only example, net 100.00 plus internal margin tax 7.60 means payable BT-131 107.60, E-breakdown BT-117 and invoice BT-110 zero because no other taxable category contributes, and payable totals 107.60; the margin tax is embedded once and is not added again.
- **Mixed subtypes:** Same-subtype §25a lines may share one E breakdown. Mixed F/I/J reasons fail closed because Peppol BR-E-01 permits exactly one E breakdown and BR-E-10 requires a reason on it; no duplicate group or arbitrary reason is permitted.
- **Evidence boundary:** The §25a legal note/no-separate-tax claim is grounded in UStG §25a and BMF UStH 25a.1(16); the amount and E-breakdown formulas are grounded in Peppol BIS BR-E-08/09/10 and its BT-109/110/112/115 formulas. This documentation-only repair does not show that upstream source or implementation work exists.


## Current Review Status: §19/§25a E-reason compatibility (2026-10-25)

- **Independent verdict on prior snapshot:** `REVISE`. The reviewer found the previously specified §25a amount bridge resolved; the remaining blocker is that the single E/0% VAT breakdown must also reject a §19 category-E line combined with a §25a line whose BT-120/BT-121 reason differs. The reviewed frozen artifact diff SHA-256 was `c4037f3841faa1d2797f8bbe316533c91407e26a701b37d1bb24bc55137e2e98`.
- **Author amendment:** Every E/0% line must be compatible with the same exact breakdown reason pair. Repeated lines with an identical accepted pair may aggregate where the mapping permits; incompatible §19/§25a and F/I/J combinations fail closed before output. BT-33 and §25a BT-22 notes remain required for their respective mappings but cannot resolve a conflicting single E-breakdown reason. The test plan names the §19 + §25a regression and task 7.1 lists it.
- **Primary-source basis:** XRechnung 3.0.2 §13.3 specifies the §19 E/0% breakdown and its exact BT-33/BT-120 reason; Peppol BR-E-01 requires exactly one E breakdown and BR-E-10 requires its exemption reason. See [XRechnung 3.0.2 specification](https://xeinkauf.de/app/uploads/2024/07/302-XRechnung-2024-06-20.pdf), [Peppol BR-E-01](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-E-01/), and [Peppol BR-E-10](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-E-10/).
- **Approval and implementation gate:** Prior approval is void for this revision. This amendment is not approval. Task 1.2 remains open: the position-keyed §25a source contract has not been implemented and independently accepted, and the complete amended artifact snapshot requires fresh independent review before implementation or persistence work. No source code or test implementation is claimed.


## Current Review Status: BT-110 aggregation on mixed-tax invoices (2026-10-25)

- **Independent verdict on prior snapshot:** `REVISE`. Fresh review of the preceding artifact diff `eefe4d306c06778e20cdf24d1a9f97af207f2473e37a248361aece03cca64aac` found that the §25a wording incorrectly implied invoice-wide BT-110 must be zero whenever §25a is present. BT-110 sums BT-117 for all VAT breakdowns; maintained accounting behavior supports mixed standard-tax and §25a invoices.
- **Author amendment:** The normative rule now requires BT-117 for the E breakdown to be zero, while BT-110 remains the sum over every breakdown and is zero only if no other taxable category contributes. The maintained net 100.00 + internal margin tax 7.60 = payable 107.60 example is explicitly §25a-only. A mixed regression covers a §25a payable amount of 107.60 plus an S-category 50.00 line at 19%, retaining S BT-117 and invoice BT-110 at 9.50.
- **Test/task mapping:** Test plan names `section_25a_mixed_with_standard_tax_preserves_standard_bt110` in `test/features/rechnungen/e_invoice_generation_test.dart`; task 7.1 maps the same case and its expected E/S breakdown and total values. Existing all-three-subtype §25a-only amount cases, repeated same-subtype case, mixed F/I/J rejection, and §19 + §25a reason-conflict case remain specified.
- **Approval and implementation gate:** Prior approval is void for this revision. This amendment is not approval. Task 1.2 remains open because the position-keyed disclosure source is not implemented and independently accepted; the complete amended artifact snapshot requires fresh independent review before source or persistence work. No source code or test implementation is claimed.


### Independent approval of the seven-artifact tax contract (2026-10-25)

- **Independent verdict:** `APPROVE` by `/root/einvoice_tax_contract_review` for contract diff SHA-256 `d1f869af7de6ab331ce3f7658da1a2649c5140089febb0cc9cf9f80659c8ac92`, based on HEAD `692493e9346057366980b5227f81341cb3d9930f`.
- **Reviewed scope:** E-breakdown BT-117=0 versus invoice-wide BT-110 summing BT-117 across all categories; §25a-only 100.00 + 7.60 → payable 107.60; mixed §25a and standard 19% totals; §19/§25a and F/I/J shared-E reason conflicts; same-reason aggregation and all three subtype amount regressions. The reviewer found no weakened requirements.
- **Evidence basis:** Peppol BR-E-09, BR-CO-14, BR-E-08 and invoice-total formulas, the VATEX list, and UStG §25a(3). The referenced exact diff identifies the approved contract input; this appended record does not change normative wording.
- **Implementation boundary:** This verdict approves the reviewed contract semantics only. It does not independently review or approve production source, v28 persistence, subtype input capture, or runtime/platform validation. Task 1.2 remains open until its remaining accepted-dependency and source-contract conditions are verified.


### Independent review of committed-reader source slice (2026-10-25)

- **Independent verdict:** `REVISE` for the 12-path e-invoice diff SHA-256 `1b86560e917b65aabc150bfd28bf18141a1ec2fd75afbaabe9785d7aa6c2e519`, based on HEAD `783c5a77d3126e552f2bb48223089293d062675d`.
- **Finding:** `readCommittedEInvoiceSnapshot` selected legacy position fields only, while `_eInvoiceCanonicalTotals` and `EInvoiceSnapshotBuilder` require persisted typed `tax_treatment`, category, and reason data. A committed/native export could therefore fail classification despite typed fields being available in the database.
- **Author repair and verification:** Finalization and committed export now share one schema-aware optional tax-evidence projection. A synthetic v28-shaped test schema proves persisted §25a amount parity and fail-closed behavior when typed evidence columns are absent. The red regression reproduced `unresolvedTaxClassification`; after the fix, the export test passed 9/9, generation passed 45/45, invoice-money passed 19/19, scoped analysis found no issues, and the six-file formatter check reported zero changes. This records author verification only; a fresh independent source review remains pending.
- **Remaining scope:** This repair does not change accepted design/spec wording and does not complete v28 persistence, accounting margin-tax capture, or the explicit persisted price/adjustment basis. Tasks 1.2 and 7.1 remain open; no migration or schema version was changed.


### Current source review status: position-keyed line-discount basis (2026-10-25)

- **Review status:** pending fresh independent review of the current exact source and evidence diff. This author update is not an approval and does not extend any prior review verdict.
- **Source change:** existing persisted line price, quantity, and percentage discount now feed a position-keyed canonical price basis and allowance through preview, finalization, and committed export. The snapshot validates and groups those values; UBL/CII serialize the resulting allowance object.
- **Evidence:** focused generation/export/snapshot/validator/invoice-money tests passed 89/89; scoped analysis found no issues, and the formatter check reported zero changes. Tests cover net/gross standard-tax and §25a line discounts, plus committed-reader parity. Document-level discounts remain fail-closed.
- **Open contract and persistence scope:** no migration/schema code or explicit accounting margin-tax input changed. Tasks 1.2 and 7.1 remain open for the full accepted source contract, typed v29 persistence, separate §25a accounting margin tax, and remaining tax-matrix cases.


### Independent-review finding repair: UBL invoice-line child order (2026-10-25)

- **Prior finding:** the allowance preceded `cbc:LineExtensionAmount` in UBL `cac:InvoiceLine`, violating the UBL 2.1 child sequence.
- **Author repair:** UBL now serializes `cbc:LineExtensionAmount` before the optional `cac:AllowanceCharge`, and both before `cac:Item`. CII remains unchanged.
- **Regression evidence:** an index assertion failed before the edit (`LineExtensionAmount` index 475; allowance index 111) and passed after it; the focused five-file e-invoice suite passed 89 tests. This is author verification, not an independent approval.
- **Review status:** independent reviewer `APPROVED` the exact 11-path diff SHA-256 `59f9492f8f2feee3dea892dfaaa755fa029ebb696947f77852a626dc5ba6e548` on base HEAD `0b94e89ea509673fc26f5d39189174ecfb2103c3` (2026-10-25). This approval covers the reviewed source snapshot only; no task boxes, accepted contract wording, migrations, or schema versions changed.


### Independent escalated approval of the final tax-contract amendment (2026-10-25)

- **Independent verdict:** `APPROVE` from the escalated GPT-6 Luna/max reviewer for the exact five-artifact contract snapshot below.
- **Review base and current HEAD:** reviewed at base `e7bd6fbdc54cd42f48a2691b67114d495099ba7a`; current HEAD is `6ec70ff03d79a37fe6c27f2e05f5cb930bd55d33`. The only commit between them changes unrelated cashbook paths; none of these five e-invoice artifacts changed between those commits.
- **Exact approved artifact SHA-256 values:** `design.md` `de56b61ff14de8b8758339b7b37392d6f6896b7fdb19dd246a350bc7d7cddd5d`; `specs/outgoing-e-invoice-generation/spec.md` `25efc50269f3315718b1d5008c41020087c57449b664b7e198cd79a207fd1d0d`; `tasks.md` `092471dc8d00cb94796f2b54f99ebd444448437bb8a61fc244ddf1f8c013ad0b`; `test-plan.md` `3c617c3558efc65933788e6b7504a60f3914d8ab40cabad51989535dfc2cfed6`; `verify.md` `75b57aae75f4819e7ae3651ea6ec5b8e3ce09b0a7eeaae101c4443552d46fa83`.
- **Approved scope:** The closed K/G/§25a tax contract, including line-bound proof that G is an ordinary §3(1) supply and rejection of §3(1b) deemed supplies under §6(5), the accepted K/G routes and exclusions, immutable §25a eligibility/election requirements, separate position-keyed accounting margin tax, and the corresponding scenarios and task/test mapping. The reviewer approved the contract only; production eligibility resolution, input capture, and positive K/G/§25a output remain gated.
- **Task/status reconciliation:** This approval satisfies review prerequisite 1.2, so its checkbox is now checked. `verify.md` reports the resulting current ledger as 112/143 complete (112 checked, 31 open). These post-verdict checkbox/status edits are administrative and do not alter the approved normative contract. Task 1.2 completion does not authorize implementation.
- **Validation:** `openspec validate outgoing-e-invoice-generation --type change --strict --json` passes with `valid: true` and zero issues; scoped `git diff --check` is clean. No application tests were run for this documentation/status update.
