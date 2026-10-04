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
