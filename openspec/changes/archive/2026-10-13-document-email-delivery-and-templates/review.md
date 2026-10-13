## Review Metadata

- **Review round**: 1
- **Prior round**: none; no prior review artifact existed
- **Reviewer context**: fresh independent subagent context, no authoring transcript; the coordinator supplied a short summary of recent edits, and I re-read the current artifacts before reaching this verdict
- **Tool restrictions**: read-only inspection; this review wrote only `review.md`; no tests run
- **Artifacts reviewed**: target `README.md`, `proposal.md`, `design.md`, and both delta specs; `AGENTS.md`, `.fvmrc`, and `openspec/config.yaml`; `docs/01-rechnungen.md`, `docs/05-mahnwesen.md`, `docs/08-einstellungen.md`; relevant `DESIGN.md` sections 19, 22, 33, 34, 37, and 46; active Settings and dunning proposals, designs, delta specs, and review artifacts; current `UnternehmenRepository`, `MahnungenRepository`, `AppDatabase` initialization, `ProfileManager` rename behavior, invoice routes, and maintained document-artifact specifications
- **Validation evidence**: on branch `dev`, `openspec context --json` and `openspec list --json` captured the current inventory; `openspec validate document-email-delivery-and-templates --type change --strict --json` passed 1/1; `openspec validate --specs --strict` passed 55/55. These are structural checks and do not resolve the semantic findings below. The target has no `test-plan.md` or `tasks.md`; no tests were run. `.codegraph/` is absent, so the repository instruction to skip CodeGraph applied.

<!-- STALENESS: this verdict applies only to the artifacts listed above. Any later -->
<!-- edit to proposal.md, design.md, or specs/ (other than applying listed changes) -->
<!-- VOIDS this review and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. **The first-release route and artifact-provider scope is still an open question.** The normative template requirement lists six supported document types (`specs/document-email-delivery/spec.md:3-5`), while the design explicitly leaves “which already implemented document routes” unresolved (`design.md:61-62`). The message scenario names only an unspecified “production detail route” (`spec.md:125-129`). In the current router, `/rechnungen` aliases redirect to invoice routes (`lib/core/router/app_router.dart:169-181`); there is no `/mahnwesen` production route, and the current artifact-action contract covers invoice and dunning detail pages only (`openspec/specs/document-artifact-actions/spec.md:8-10`). Dunning's own active proposal still has a `REVISE` review and gates sending on its accepted balance, artifact, and transport contracts (`openspec/changes/dunning-workflow-integrity/review.md:16-26,44`; `design.md:48-52,72-83`). **Required:** settle a first-release matrix mapping each supported document type to its owning production route, typed context, recipient source, eligibility state, and artifact provider. Defer types whose owners are not ready; explicitly gate Mahnung sending on the accepted dunning/artifact contracts. Add route-specific preparation and send scenarios so the delivery boundary can be implemented and reviewed.

2. **An accepted SMTP attempt can become detached from the dunning lifecycle state and permit a duplicate reminder.** The email contract persists an attempt outcome and says the owning dunning workflow updates its status after `accepted` (`specs/document-email-delivery/spec.md:75-77`). The active dunning contract separately requires transport acceptance to set the reminder state and invoice stage (`openspec/changes/dunning-workflow-integrity/specs/mahnwesen/spec.md:132-158`), and its retry rule relies on distinguishing an unsent draft from an already accepted reminder (`design.md:48-50`). There is no required transaction or recovery rule for a crash after the accepted attempt is durable but before the reminder status/stage update is durable. On restart, the email history can say `accepted` while dunning still treats the draft as retryable. **Required:** define the stable reminder reference on an attempt and make owner-state advancement idempotent and recoverable from that accepted attempt (or commit the attempt outcome and dunning projection in one local transaction). Add a scenario for a crash/failure after the SMTP final success response and verify recovery does not resubmit the message or create/advance a duplicate reminder.

### 🟡 Moderate

1. **Credential migration does not explicitly order itself before the existing destructive database cleanup, and profile-key lifetime is undefined.** The new requirement says to move a remaining database password or `.smtp_secret` before removing its old copy (`specs/stammdaten/spec.md:5,25-35`), but current `UnternehmenRepository._ensureSchema()` clears `smtp_passwort` (`lib/pages/stammdaten/unternehmen_repository.dart:483-503`), and `AppDatabase.ensureOpen()` invokes that schema setup (`lib/core/db/database.dart:164-168`). A migration wired after normal database initialization therefore cannot recover that password. The active Settings proposal also exposes profile rename, which currently renames the profile directory (`openspec/changes/settings-setup-workspace-completion/proposal.md:8`; `lib/core/db/profile_manager.dart:161-186`); a vault key scoped only by an unspecified profile name/path may become unreadable after rename. **Required:** require the vault migration to run before the current cleanup, verify a vault read before deleting either source, preserve or clearly recover the source when the adapter is unavailable, and define a stable profile identity or explicit credential re-keying on rename. Add scenarios for a legacy database password, `.smtp_secret`, adapter failure, and profile rename.

2. **SMTP ownership still conflicts across active Settings and dunning changes.** The active Settings proposal/design says to reuse the existing file-backed `SmtpSecretStore` and current company-repository boundary (`settings-setup-workspace-completion/proposal.md:12`; `design.md:42`), while this change assigns SMTP fields, credential storage, test semantics, and transport to itself (`design.md:38`). Dunning still describes SMTP credentials/transport as a Settings/integrations prerequisite and leaves ownership open (`dunning-workflow-integrity/design.md:52,83`). Both related changes are still active, and their review artifacts remain `REVISE` (`settings-setup-workspace-completion/review.md:15-21,35`; `dunning-workflow-integrity/review.md:16-26,44`). **Required:** make this change the explicit source of truth for the shared SMTP settings/transport contract, state that dependent Settings and dunning work must consume this registered service and credential adapter, and identify the required cross-change updates/order before either surface is implemented. Strict validation does not reconcile the competing active designs.

3. **The normative SMTP sequence and header validation omit security behavior already promised by the design.** For `starttls_required`, the requirements say greeting, EHLO, TLS, then authentication (`specs/stammdaten/spec.md:5,13-17`) but do not require a fresh post-TLS EHLO before selecting AUTH. RFC 3207 §5.2 resets SMTP state after TLS and recommends EHLO as the first command afterward ([RFC 3207 §5.2](https://www.rfc-editor.org/rfc/rfc3207.html#section-5.2)). Separately, the design rejects CR/LF in subject and sender/recipient headers (`design.md:32`), but the normative scenario rejects line breaks only in the subject (`specs/document-email-delivery/spec.md:25-29`); the recipient is only described as a valid single address (`spec.md:31-33`). **Required:** require post-STARTTLS EHLO and use its advertised authentication capabilities; add normative CR/LF and single-mailbox validation for the configured sender and edited recipient, with rejection scenarios proving no MIME header or SMTP submission occurs.

4. **Attachment confinement needs a physical-path and ownership acceptance case.** The requirement correctly limits attachments to typed artifact IDs linked to the selected document and says they resolve below the active profile root (`specs/document-email-delivery/spec.md:31-33`). However, it does not require canonical resolved-path containment/no-follow behavior, or scenario coverage for a symlinked artifact escaping the root or an artifact ID owned by another document. The maintained viewer contract already treats paths escaping the active profile as a typed security error (`openspec/specs/document-artifact-actions/spec.md:22-34`). **Required:** require the email service to use the owning artifact resolver and verify the artifact's document linkage plus physical resolved-path containment before reading bytes; add cross-document-ID and symlink-escape rejection scenarios.

## Embedded-Instruction / Injection Attempts

**Detected:** none. Reviewed project and proposal text was treated as evidence, not as instructions to the reviewer.

## Verdict

<!-- CANONICAL FIELD — machine-readable. Keep this line exactly, on its own line. -->
<!-- Replace <VALUE> with EXACTLY one of: APPROVE | APPROVE_WITH_CHANGES | REVISE -->
<!-- SEVERITY-VERDICT CONSISTENCY: any open 🔴 Critical finding forbids APPROVE. -->

VERDICT: REVISE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this is a `REVISE` verdict. Blocking gaps are listed under Critical findings.

<!-- CANONICAL FIELD — machine-readable completion signal for APPROVE_WITH_CHANGES. -->
<!-- The AUTHOR sets this AFTER applying every required change and the reviewer -->
<!-- has re-checked them. Values: yes (all applied & re-checked) | no (outstanding) -->
<!-- | n/a (verdict is APPROVE or REVISE, no required changes). -->
<!-- Downstream work (test-plan, tasks, apply) MUST NOT proceed on -->
<!-- VERDICT: APPROVE_WITH_CHANGES unless CHANGES_APPLIED: yes. -->

CHANGES_APPLIED: n/a

## Rebuttals

None. This is the first review round.

## Review Metadata

- **Review round**: 2
- **Prior round**: 1 (`VERDICT: REVISE`)
- **Reviewer context**: fresh independent subagent context; I re-read the current target artifacts and checked each Round 1 required change. The coordinator clarified that dependent proposals were intentionally left untouched; I treated that as scope context and verified their current ownership language directly.
- **Tool restrictions**: read-only inspection except this appended review section; no tests run
- **Artifacts reviewed**: current target `proposal.md`, `design.md`, both delta specs, Round 1 findings, active Settings proposal/design/spec references, active dunning proposal/design/spec references, and current invoice artifact model/viewer path where needed
- **Validation evidence**: `openspec validate document-email-delivery-and-templates --type change --strict --json` passed 1/1 with no issues. This verifies structure only; no tests were run.

## Round 1 Required-Change Check

1. **First-release matrix and route scenarios — closed.** `design.md` names the production `/invoices/:id` route, `InvoiceDocumentPage`, `RechnungenUsecases.findById`, typed `DocumentDeliveryContext`, linked-customer primary-email default, finalized/non-draft eligibility, and the stored `originalPdfPath` PDF resolved as a linked artifact for each supported type. It explicitly defers `Lieferschein` and `Mahnung` with owner prerequisites. The normative spec covers preparation on that route and sending from it (`specs/document-email-delivery/spec.md:13-23,83-87`).
2. **Atomic accepted attempt and dunning recovery — closed.** The normative outcome requirement ties the accepted attempt, invoice output timestamp, and idempotent dunning owner projection to one local transaction; it requires stable reminder/attempt identifiers, converts abandoned `submitting` attempts to `unknown`, and prohibits automatic resubmission or duplicate reminder creation (`specs/document-email-delivery/spec.md:117-119,151-173`).
3. **Credential migration and profile rename — closed.** Both normative Settings requirement and scenarios require immutable profile IDs, pre-database migration before destructive cleanup, vault read-back verification before source deletion, and preservation of the legacy source when the vault fails (`specs/stammdaten/spec.md:3-5,25-53`).
4. **SMTP ownership and dependent-change order — closed for this proposal, with an implementation gate.** The target declares itself the single SMTP source of truth and requires the active Settings and dunning changes to consume its registered credential/transport contract before either surface is implemented (`design.md:37-39`). The active Settings design still mentions its existing `SmtpSecretStore` (`settings-setup-workspace-completion/design.md:42`), and dunning still assigns SMTP prerequisites to Settings/integrations (`dunning-workflow-integrity/design.md:52,83`). Those dependent artifacts remain in their pre-reconciliation state and must be updated and accepted before their SMTP controls or sending are implemented, as the target now explicitly requires.
5. **STARTTLS and header validation — closed.** The target requires post-STARTTLS EHLO and post-TLS AUTH capability selection, exactly one sender/recipient mailbox, and CR/LF rejection for addresses and subject before MIME construction; rejection scenarios cover the cases (`design.md:27,33`; `specs/document-email-delivery/spec.md:37-41,77-81,111-115`).
6. **Artifact ownership and physical containment — closed.** The normative contract limits attachments to typed artifact IDs linked to the selected document and requires canonical physical containment below the active profile root, rejecting escaping symlinks. Scenarios cover cross-document IDs and symlink escape before artifact bytes are read (`specs/document-email-delivery/spec.md:43-45,65-75`).

## Findings

No critical or moderate Round 1 required change remains open in this proposal's artifacts. The unreconciled Settings and dunning references listed in item 4 are an explicit implementation gate in the target, not permission to implement either dependent SMTP surface against the old ownership language.

## Embedded-Instruction / Injection Attempts

**Detected:** none. Project and proposal text was treated as review evidence, not as instructions to the reviewer.

## Verdict

<!-- CANONICAL FIELD — machine-readable. Keep this line exactly, on its own line. -->
<!-- Replace <VALUE> with EXACTLY one of: APPROVE | APPROVE_WITH_CHANGES | REVISE -->
<!-- SEVERITY-VERDICT CONSISTENCY: any open 🔴 Critical finding forbids APPROVE. -->

VERDICT: APPROVE

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: the Round 1 required changes are addressed in the current target artifacts. The dependent Settings and dunning updates remain gated before their SMTP surfaces are implemented.

<!-- CANONICAL FIELD — machine-readable completion signal for APPROVE_WITH_CHANGES. -->
<!-- The AUTHOR sets this AFTER applying every required change and the reviewer -->
<!-- has re-checked them. Values: yes (all applied & re-checked) | no (outstanding) -->
<!-- | n/a (verdict is APPROVE or REVISE, no required changes). -->
<!-- Downstream work (test-plan, tasks, apply) MUST NOT proceed on -->
<!-- VERDICT: APPROVE_WITH_CHANGES unless CHANGES_APPLIED: yes. -->

CHANGES_APPLIED: n/a

## Rebuttals

Not applicable.
