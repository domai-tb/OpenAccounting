# OpenAccounting contract triage and bounded Anvil queue

Audit date: 2026-09-29  
Scope: bounded contract decisions and proposal selection after the A/B/C audit artifacts.  
Checkout: `dev` at `70ec70c`; FVM Flutter `3.47.2`; no `.codegraph/` directory.  
This is a triage handoff. It contains no production repair and no OpenSpec change directory.

## Decision candidates sent to root first

These are the only three product decisions currently blocking the named accounting repairs. The
official sources establish boundaries; they do not choose this product's document or workflow
semantics.

### 1. Gutschrift and Storno effect contract

**Question for root:** Which signed effect model is canonical, including standalone Gutschrift,
linked Gutschrift, inventory, and Storno-of-Gutschrift?

| Option | Contract | Impact |
|---|---|---|
| **A — signed correction bundle (recommended)** | Show a positive credit amount to the user but persist/post signed negative positions. A linked Gutschrift reverses the selected source financial effects and creates a traceable customer credit; a standalone Gutschrift creates a credit item without source inventory effects. A Storno-of-Gutschrift is the exact positive inverse of the Gutschrift's persisted effects. Inventory changes require an explicit returned-stock selection. | Matches the correction spec's signed VAT rule, the artifact matrix's “credit/reversal” wording, the existing negative Gutschrift tests, and the documented overpayment/refund workflow. It requires one typed effect matrix and a source/effect snapshot. |
| B — operational credit only | Gutschrift creates a credit balance and PDF, but no journal/receivable/tax/inventory posting until a later apply/refund action; Storno cancels that credit state. | Smaller initial posting surface, but it conflicts with “Gutschrift records credit/reversal” and requires a second application lifecycle before reports and audit trails are complete. |
| C — invoice-equivalent correction | Gutschrift is always a full invoice-like negative posting, with the same source-side effects as Storno; Storno-of-Gutschrift always reverses that complete bundle. | Simple accounting invariant, but standalone overpayment credits and physical returns become indistinguishable without additional document/effect types. |

Evidence: `openspec/specs/document-artifact-transaction/spec.md:8-15` says Rechnung may create
receivable/journal/inventory effects, Storno reverses linked effects, Gutschrift records
credit/reversal, and the other document types are document-only;
`openspec/specs/correction-document-accounting-integrity/spec.md:8-24` requires signed
position-derived VAT totals; `docs/01-rechnungen.md:13-21,42-64` calls Gutschrift a positive
adjustment but gives Storno negative effects; `docs/06-dokumente.md:73-102,205-242` describes
Gutschrift/refund and overpayment credit handling; `test/features/rechnungen/gutschrift_test.dart:9-31,80-98`
expects negative Gutschrift lines and a positive Storno-of-Gutschrift; the current implementation
persists negative Gutschrift totals at `lib/pages/rechnungen/rechnungen_datasource.dart:914-975`
and uses a special positive correction sign at `:643-679`.

The UStG source does not settle this product choice. UStG §15 describes qualifying input-tax
conditions for supplies/services and invoice evidence, so tax direction still needs a typed
product mapping: [UStG §15](https://www.gesetze-im-internet.de/ustg_1980/__15.html).

### 2. Dunning rate, fee, and block policy

**Question for root:** Should statutory late interest be the default source, and how should
party type, the business surcharge, level fees, and block clearing be represented?

| Option | Contract | Impact |
|---|---|---|
| A — user policy only | Keep configured per-level rates and fees as the source of truth, with no statutory claim. | Preserves current configurability, but contradicts the documented German-law-aware behavior and leaves the 2026 baseline unenforced. |
| B — statutory-only | Resolve the applicable base rate by effective date and party type, apply the statutory spread, apply the business surcharge only to eligible business claims, and remove arbitrary per-level interest overrides. | Strongest legal baseline and deterministic historical output, but requires party classification, base-rate history, and a clear product stance on non-statutory level fees. |
| **C — statutory default with explicit product policy (recommended)** | Default interest to the dated statutory base-rate calculation and snapshot base rate, spread, party type, and applied amount on each Mahnung. Keep level Mahngebühr as an explicit fixed-euro product setting; model the business surcharge separately and only when enabled for an eligible business claim. On full payment clear the automatic invoice stage/customer block; retain a manual Mahnsperre until its explicit removal/expiry. | Meets the stated 2026 German baseline while retaining product control over fees and operational blocking. It requires a typed rate-source/snapshot contract and an atomic dunning/payment transition. |

Evidence: `docs/05-mahnwesen.md:9-68,98-157,257-264` uses percentage fee examples,
promises automatic block clearing, and names BGB §288; `openspec/specs/mahnwesen/spec.md:25-55,89-119,153-189,207-253`
allows configurable fees/rates, requires snapshots and level reset, and currently specifies a
default-interest setting; the current seed defaults differ at
`lib/features/mahnwesen/mahnstufen_repository.dart:41-65`; interest currently uses arbitrary
`zinssatz` at `lib/features/mahnwesen/mahnungen_repository.dart:85-98,162-170` and the payment
path does not clear the stage/block (`docs/audits/2026-09-29-accounting-persistence-audit.md:144-154`).

The 2026 official baseline is [BGB §288](https://www.gesetze-im-internet.de/bgb/__288.html),
which states five percentage points above the base rate generally, nine for claims where no
consumer is involved, and a €40 creditor surcharge for eligible business claims. The dated base
rate table is maintained by the [Deutsche Bundesbank](https://www.bundesbank.de/de/bundesbank/organisation/agb-und-regelungen/basiszinssatz-607820).
This triage does not infer eligibility beyond those sources.

### 3. Profile deletion and retained data

**Question for root:** Does “delete profile” mean hide/detach while retaining data, purge data,
or retain it in a recoverable archive state?

| Option | Contract | Impact |
|---|---|---|
| **A — detach and retain (recommended)** | Remove the profile from the active/profile registry, retain its directory/database, and provide a separate explicit purge command with a destructive confirmation and backup check. Exclude detached profiles from normal selection while retaining a recovery path. | Matches the maintained safety contract and makes accidental local data loss reversible. It needs a durable registry/tombstone representation because the current `profile.json` stores only `active` and `listProfiles()` discovers directories. |
| B — purge on delete | Keep current recursive directory deletion after confirmation; update the maintained spec and test to make irreversible purge the contract. | Smallest code change, but it permanently destroys the local database and directly conflicts with the current profile safety requirement. |
| C — recoverable archive | Move the profile directory to a versioned archive/trash area, hide it from normal selection, and offer restore or later purge. | Strong recovery UX, but adds archive naming, path migration, and retention rules beyond the current documented contract. |

Evidence: `openspec/specs/profiles/spec.md:159-182` requires removing the profile entry while
retaining the directory/database and forbids deleting the active/last profile;
`lib/core/db/profile_manager.dart:49-80,111-123,144-158` uses an active-only pointer,
directory discovery, and recursive deletion; `test/integration/audit/profile-workspace-lifecycle_test.dart:26-44`
expects physical deletion. This is a spec/test/code contradiction, not a legal conclusion.

### Additional architecture and delivery choices that are genuinely blocked

These are owner decisions surfaced by the independent acceptance record. They are separate from
the three accounting questions above, but they block truthful path, migration, and release work.

#### 4. Canonical product and profile paths (C-006)

**Question for root:** Which exact product name, platform roots, profile cardinality, and database
filename are canonical across code, specs, docs, and tests?

| Option | Contract | Impact |
|---|---|---|
| **A — OpenAccounting, plural profiles (recommended)** | Use `OpenAccounting` in the product-facing name and paths; use Linux `$HOME/.local/share/OpenAccounting`, macOS `~/Library/Application Support/OpenAccounting`, Windows `%LOCALAPPDATA%\\OpenAccounting`, `profiles/<name>/`, and one documented database filename. | Aligns the shipped app identity and current `ProfileManager` plural layout, while making the Linux runtime contract explicit. Requires one migration/alias plan for existing OpenInvoices paths. |
| B — preserve current runtime identity | Keep `OpenInvoices`, the current `data_paths.dart` roots, `profiles/<name>/`, and `openinvoices.db`; revise OpenAccounting references in docs/specs/tests. | Lowest runtime migration risk, but preserves the product-name mismatch visible to users and maintainers. |
| C — compatibility bridge | Keep both names as read-only migration aliases, select one new canonical root, and write only there. | Eases upgrades, but creates a durable dual-path contract and additional discovery/security cases. |

Evidence: `test/integration/audit/architecture-delivery-audit.md:94-102` records the
OpenInvoices/OpenAccounting, `profile/`/`profiles/`, and `APPDATA`/`LOCALAPPDATA` conflicts;
`lib/core/db/data_paths.dart:5-20` currently resolves OpenInvoices roots and
`lib/core/db/profile_manager.dart:22-40` uses plural profiles and `openinvoices.db`;
`openspec/specs/desktop/spec.md:293-305` and `openspec/specs/db/spec.md:194-203` preserve the
competing contracts. macOS and Windows remain static-only for this run.

#### 5. Database inventory and migration-hook owner (C-007)

**Question for root:** Is `inventarbewegungen` part of the canonical base schema, and which layer
owns post-migration triggers/seeds and their transaction boundary?

| Option | Contract | Impact |
|---|---|---|
| **A — 39-table single migration owner (recommended)** | Declare all 39 runtime tables, including `inventarbewegungen`, in the maintained base inventory; make the migration runner's versioned post-hooks the owner of schema-dependent triggers/seeds and verification. | Gives one inventory and one ordering/transaction owner, matching runtime truth and reducing duplicate initialization paths. Requires reconciling the DB spec's 38-table wording and current `AppDatabase.ensureOpen` calls. |
| B — 38-table core plus versioned inventory module | Keep 38 base tables and add `inventarbewegungen` through an explicitly versioned inventory migration with its own hook contract. | Preserves the split language, but requires a documented module boundary and upgrade ordering for every profile database. |
| C — application bootstrap owns hooks | Keep 39 tables but formally make `AppDatabase.ensureOpen` the post-migration owner; `_postHooks` stays empty by design and the specs/tests say so. | Smallest structural change, but initialization semantics remain split unless the bootstrap contract is made explicit and tested. |

Evidence: `test/integration/audit/architecture-delivery-audit.md:104-112` identifies the
39/38 inventory and empty-hook conflict; `lib/core/db/database.dart:49-89,139-180` exposes the
39-table runtime and additive initialization; `lib/core/db/migrations.dart:349-352` leaves
`_postHooks` empty; `openspec/specs/db/spec.md:73-89,130-154,314-322` carries the competing
inventory and hook requirements.

#### 6. Release artifact and signing policy (C-010)

**Question for root:** Under the authorized Linux runtime and static macOS/Windows scope, should
the project publish a manually signed Linux artifact, build it through automation, or remain
development-only until a trust root exists?

| Option | Contract | Impact |
|---|---|---|
| **A — manual Linux release (recommended for the current scope)** | Produce a versioned Linux artifact manually, record its source/version and signing provenance, keep updater/install unavailable until a trust root exists, and document macOS/Windows as static-only. | Establishes a truthful Linux delivery gate with the smallest platform scope. It does not claim automated updates or native macOS/Windows runtime support. |
| B — automated signed Linux delivery | Define a repository trust root, key rotation, reproducible version injection, package/signature verification, and CI publish/install checks for Linux. | Stronger repeatability, but adds key custody and CI release work before product delivery can be claimed. |
| C — development-only gate | Keep artifacts unsigned and unpublished; explicitly label the application as development-only until signing and updater policy is approved. | Avoids an implied release promise, but postpones all release claims and requires the product surface to state that limitation. |

Evidence: `test/integration/audit/architecture-delivery-audit.md:134-142` records the missing
version/package/signing pipeline and disabled updater; `pubspec.yaml:1-4` remains at version
`0.0.1`, `tool/release_gate.dart:3-21` is analyzer-only, and
`lib/features/desktop/desktop_updater.dart:2-3,45-48,154-174,354-375` deliberately denies
verification/install. This recommendation is a delivery policy, not a claim of legal compliance.

### Audit corrections carried into this triage

- German+English is approved scope; B-004 is a technical German-only spec reconciliation, not a
  product question. The full documented vision remains binding, and ideas without a commitment stay
  in the documented backlog (`docs/audit/product-vision-matrix-2026-09-29.md:7-17,84-101`).
- The route surfaces do have local client-side search through `FinanceListSurface`'s controller and
  `_filteredRows`; the missing capability is global/server-side search (`lib/design_system/components/finance_list_surface.dart:53-95,199-207`).
- The current VM evidence is 748 completed tests with two named `pumpAndSettle` timeouts, while a
  historical/broad run reported 750/750. Treat the gate as unresolved until deterministic evidence
  exists (`docs/audit/baseline-2026-09-29.md:9-29`; timeout stacks in
  `/tmp/openaccounting-baseline-20260929-vm-tests.log:844-884,991-1044`).
- B's “43 grouped rows cover the whole vision” claim still needs source-heading-to-row provenance;
  do not treat grouped assignment as per-file evidence (`docs/audit/initial-audit-acceptance-2026-09-29.md:25-27,102`).

## Constraints already resolved by user authorization

- Full documented vision remains binding; the suggested MVP boundary is not a scope cut. Keep
  ideas without a current commitment in the documented backlog. Sources:
  `docs/audit/product-vision-matrix-2026-09-29.md:7-17,84-101`.
- German and English are both approved shipped locales. The German-only requirement in
  `openspec/specs/app/spec.md:90-125` is superseded for this triage by the user's explicit
  approval; the production localization repair is therefore queueable.
- Use the 2026 German official source baseline for legal-sensitive behavior. No source here is a
  compliance certification.
- Linux is the only runtime/render gate in this run. macOS and Windows remain static evidence;
  `docs/audit/product-vision-matrix-2026-09-29.md:31-34` and
  `test/integration/audit/architecture-delivery-audit.md:21-36` record the same boundary.
- No commitment is silently deferred. The named blockers and cross-workstream gates remain listed
  below even when they are not ready for implementation.

## Prioritized bounded Anvil proposal queue

The repository has no active changes (`openspec context --json`, `openspec list --json`), and
`openspec validate --specs --strict` passes 52 specs structurally. That green result is only a
shape check. Every queue item requires a fresh Anvil review before implementation, with complete
metadata, source/test evidence, and a non-empty scoped implementation diff.

### P0 — safe, narrow repairs with no product decision dependency

1. **`route-smoke-settlement-lifecycle` — current VM gate.** The current baseline names two
   failures: `test/app/app_shell_test.dart:34-59` and
   `test/integration/audit/analyzer-and-integration-test-gates_test.dart:49-75`; both time out
   after a `router.go` navigation while the initial settle completes
   (`docs/audit/baseline-2026-09-29.md:22-29`). The production surfaces can keep indeterminate
   indicators mounted while route-owned work is pending: dashboard configuration uses a spinner at
   `lib/features/dashboard/dashboard_page.dart:68-73`, bank import owns `_isLoading` around
   `lib/features/bank_import/bank_import_page.dart:89-109,119-179`, list workspaces watch futures
   at `lib/design_system/components/finance_list_surface.dart:70-95`, and settings starts a profile
   `FutureBuilder` at `lib/core/router/app_router.dart:656-667,787-816`.
   The first implementation task is to instrument the failing route index and identify the mounted
   ticker/future; then repair the production lifecycle so every navigated route reaches a terminal
   data or error state and disposes route-owned async work. Preserve `pumpAndSettle` as the invariant
   and add a focused regression for the identified culprit. A timeout increase, broad `pump` swap,
   animation disable, or skip is not evidence of repair. Required artifacts: proposal/design,
   delta spec for route readiness, red source-level/widget test, test-plan/tasks, fresh Anvil review,
   and Linux verify evidence.

2. **`bank-import-row-validation-boundary` — A-004.** Move malformed date/amount handling into
   the existing per-row failure result so valid rows still persist; keep file/account metadata as
   batch-level failures. Add the malformed-valid mixed-row, retry, and history assertions. This is
   a follow-up to archived `2026-09-05-bank-import-workflow-integrity`, whose test plan covers
   persistence failures but not upfront row validation (`lib/features/bank_import/bank_import_service.dart:217-245,427-460`).
   Required artifacts: proposal, design, delta spec, red test-plan row, tasks, fresh review, and
   verify. Do not claim the separate documented mode/history UI complete; B-queue work remains.

3. **`receivable-request-fingerprint-and-conditional-writeoff` — A-006/A-007 subset.** Store a
   request fingerprint (amount, target, direction, and date policy) with an idempotency key and
   return a typed conflict when a reused key differs; move write-off state validation inside the
   transaction and require a conditional state transition before one loss journal is created.
   Existing `2026-09-09-receivables-ledger-integrity` covers statement arithmetic/schema startup,
   not these command races (`lib/features/einkommen/forderungen_repository.dart:279-399,402-441`).
   Split overpayment/credit semantics into the Gutschrift decision gate. Required artifacts are
   proposal/design/delta spec/test-plan/tasks/review/verify plus concurrency tests.

4. **`localized-accessible-surface-completion` — B S1 and the explicit locale authorization.**
   Inventory every production-visible string and formatter, complete German/English ARB parity,
   pass active locale and privacy-aware money formatting through route/list/detail/import states,
   and add a Linux production route smoke. Collision anchors are archived
   `2026-09-09-localization-settings-and-data-protection` and
   `2026-09-13-adaptive-shell-and-state-surfaces`; inspect current source before creating a
   follow-up. Required artifacts include ARB/generated-output provenance, a route/state matrix,
   red production-widget tests, fresh review, and Linux render evidence. This item is not blocked
   by the former German-only requirement because the user has resolved it.

### P1 — bounded cross-cutting gates

5. **`generated-artifact-provenance-check` — C-012.** Add a non-mutating CI check that regenerates
   localization/plugin outputs in an isolated workspace and fails on a diff. It has no product
   semantic dependency and covers all targets statically. Required artifacts: proposal/design,
   spec parity delta, CI test-plan/tasks, fresh review, and verify. Use `fvm flutter gen-l10n` for
   Flutter generation and preserve the no-rewrite audit worktree.

6. **`desktop-command-bootstrap-and-availability` — C-001/C-003, Linux runtime plus static
   macOS/Windows.** Wire the documented shortcut/tray callbacks through AppServices, register
   truthful availability for unsupported adapters, and add a production composition/command-spy
   test. Reuse archived `2026-09-09-desktop-lifecycle-and-command-wiring` and
   `2026-09-13-desktop-action-and-spec-parity`; do not recreate either broad change. Keep OS
   effect claims bounded to Linux runtime and macOS/Windows static inspection. Required artifacts:
   proposal/design/spec parity delta/test-plan/tasks/fresh review/verify, with an explicit command
   matrix and unavailable states.

### Explicitly gated, retained in the queue but not currently unblocked

- **Correction/tax/money:** A-001, A-003, and A-017 remain behind the Gutschrift/Storno and
  numeric-scale decisions. Archived `2026-09-07-invoice-money-invariants/review.md:43-55` is a
  `REVISE` with unresolved scale, sign, entry-point, allocation, error, and executable-test
  contracts; its historical verify PASS is not a fresh approval.
- **Dunning:** A-011 needs the rate/fee/party/block choice above before code or UI can be judged.
  A-012 also needs a real artifact/send policy and overlaps the B dunning route commitment.
- **Profile/path/migration:** A-014, C-006, and C-007 require the retention/registry and canonical
  path/table/migration ownership decisions. Do not implement recursive deletion while the profile
  spec says retain.
- **Release policy:** C-010 remains gated on the manual Linux artifact versus automated signing/trust
  root choice. Keep the updater unavailable and make no macOS/Windows runtime claim until that policy
  is recorded.
- **Inventory and recurring:** A-008 has a manual-negative-stock contradiction between
  `openspec/specs/inventory/spec.md:25-41,143-166`; A-009/A-010 overlap archived recurring work
  and should wait for the money/tax posting contract. These are recorded gates, not silent drops.
- **Backup/DATEV/tax reports and broad route work:** A-013, A-016, B S1 route work, and C-005/C-009
  depend on the profile/path, debit-credit, report-direction, or composition ownership matrix.
  They need their own bounded follow-up after those dependencies are resolved.

## Required Anvil lifecycle for each queue item

1. Re-read `AGENTS.md`, `.fvmrc`, `openspec/config.yaml`, current source, and the cited archived
   change; create one narrowly scoped change only after confirming no active collision.
2. Produce `proposal.md`, `design.md`, delta specs, `test-plan.md`, and `tasks.md` in dependency
   order. Each test-plan row must start red for the production path and identify exact observable
   evidence.
3. Obtain a fresh-context review with reviewer metadata and a complete verdict. `VERDICT: APPROVE`
   without context/evidence is insufficient; any `REVISE` blocks implementation.
4. Apply with FVM-prefixed analyzer/tests, run the relevant Linux runtime gate, and use static
   macOS/Windows checks only. Validate the change strictly and record verify evidence before any
   sync/archive/commit step. No push, merge, or publish is implied.
