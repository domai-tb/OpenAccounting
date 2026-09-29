# Initial audit acceptance record

Audit date: 2026-09-29  
Independent reviewer: Luna, fresh context  
Checkout: `dev` at `70ec70cc7b0ee4d314565a0782da1ffbdd126ea6`  
Scope: challenge the three initial audit workstreams and consolidate their 52 finding rows. This record is documentation only; it does not authorize production repairs, commits, pushes, or publication.

## Decision after evidence-record repair

- **C: APPROVE FOR EVIDENCE LEDGER.** The revised C report and manifest now assign all 521 C paths exactly once with explicit per-file statuses and C-COV anchors. The ledger preserves static/generated/asset/archive limits and does not turn provenance into runtime proof. macOS and Windows remain static-only.
- **B: APPROVE FOR EVIDENCE LEDGER.** The 21 product/UI findings remain supported. The revised records state the approved German+English scope, acknowledge local client-side search, add a source-heading map for all 43 grouped rows, and record the current 748-test/two-timeout VM evidence against the unsupported 750/750 report. B-004 and B-021 remain partial/unresolved findings rather than being marked complete.
- **A: APPROVE FOR SOURCE EVIDENCE ONLY.** A fresh-context source re-read independently confirms all 18 source-anchored findings. The explicit per-row closure is recorded in the A report; it does not resolve the five contract/policy blockers or the named unexecuted concurrency/fault/runtime cases.
- **Whole initial audit: BLOCK.** The evidence records are repaired, but the full VM gate remains unresolved (748 completed tests plus two focused `pumpAndSettle` failures versus an unsupported 750/750 claim), contract decisions and negative cases remain open, and no production repair is authorized by this record. A fresh reviewer must accept these records before implementation.

## Evidence inventory

The author reports and source matrices are preserved here:

- [A accounting and persistence findings](../audits/2026-09-29-accounting-persistence-audit.md) and [A official/product source matrix](../audits/2026-09-29-accounting-source-matrix.md).
- [B product vision/UI findings](product-vision-findings-2026-09-29.md) and [B product vision matrix](product-vision-matrix-2026-09-29.md).
- [Current shared baseline](baseline-2026-09-29.md), including the isolated Linux profile smoke and the two route-smoke VM failures.
- [C architecture and delivery findings](../../test/integration/audit/architecture-delivery-audit.md) and [C coverage manifest](../../test/integration/audit/architecture-delivery-coverage.tsv).
- [Stale 2026-09-12 baseline](../../test/integration/audit/_baseline.md), retained as historical context only.

The manifest contains 709 tracked paths exactly once: A 137, B 51, C 521. The revised C ledger
now gives every C path an exact path, an explicit status, and a C-COV anchor; its evidence limits
remain documented in the C report. It is still an assignment/provenance ledger, not per-file runtime
proof.

B’s matrix has 43 grouped commitments and references 14 of the 52 maintained OpenSpec specs. The
revised matrix maps the DESIGN headings, docs/01 through docs/08, B-referenced specs, and the
remaining A/C-owned specs to M01–M43. Grouping remains acceptable because the source-to-row map
and ownership handoff are explicit.

## Current gate evidence

These checks were run against the current checkout after the reports were written. They are the current baseline for this record; the old `_baseline.md` is not reused as current evidence.

| Check | Current result | Boundary |
| --- | --- | --- |
| `fvm flutter analyze` | PASS, no issues | Linux/FVM environment only; native source exclusions remain. |
| `fvm flutter test --dart-define=platform=vm` | **FAIL / UNRESOLVED** | The current baseline completed 748 tests with two `pumpAndSettle` timeouts (`test/app/app_shell_test.dart` and `test/integration/audit/analyzer-and-integration-test-gates_test.dart`); focused reruns reproduce both. A separate broad run reported 750/750, but no command or log is preserved, so that result is unsupported and cannot make the gate green. |
| `fvm dart run tool/release_gate.dart` | PASS | The gate is analyzer-only. |
| `fvm flutter build linux --debug` | PASS | Debug Linux bundle only. |
| Linux launch smoke under `xvfb-run` | PASS, bounded readiness | The isolated-profile baseline created the profile DB/WAL/SHM files, exposed a Dart VM service, and stopped with deliberate TERM (143). A separate 20-second bounded run also reached the VM service and timed out at the bound. No desktop action or full workflow was exercised. |
| Linux bundle `ldd` check | PASS in this environment | Resolved observed Flutter/GTK/X11/Wayland/plugin libraries; no host portability claim. |
| `openspec validate --specs --strict` | PASS, 52/52 | Structural validation only; it does not resolve semantic conflicts or prove runtime wiring. |
| macOS build/runtime | UNVERIFIED | Static files only. |
| Windows build/runtime | UNVERIFIED | Static files only. |

The 2026-09-12 analyzer/test counts in `_baseline.md` are stale. A source matrix’s official links remain useful evidence boundaries, not a legal-compliance certification; the A report correctly keeps that limitation. Current official references include [UStG §15](https://www.gesetze-im-internet.de/ustg_1980/__15.html), [BGB §288](https://www.gesetze-im-internet.de/bgb/__288.html), and [2026 GoBD text, Rz. 107–111](https://ao.bundesfinanzministerium.de/ao/2026/Anhaenge/BMF-Schreiben-und-gleichlautende-Laendererlasse/Anhang-33/inhalt.html). They do not choose this product’s document signs, dunning policy, retention behavior, or account mappings.

## Consolidated finding register

The B identifiers below are stable ledger identifiers assigned in report order; the B source report has descriptive headings rather than IDs. “Reproducible” means the cited source path supports the reported behavior; it does not mean the behavior satisfies the product contract.

### A — accounting and persistence (18 findings)

| ID | Finding | Independent disposition |
| --- | --- | --- |
| A-001 | Document finalization posts effects without a type policy | **REPRODUCIBLE / contract blocked.** Generic finalization and tax insertion are source-anchored; freeze document-type effects and Gutschrift/Storno signs first. |
| A-002 | Journal rows are not complete double-entry or immutable posting | **REPRODUCIBLE / open.** Journal inserts omit debit/credit identity in the cited paths and several posting paths start mutable. |
| A-003 | UStVA/EÜR treat outgoing VAT claims as input tax | **REPRODUCIBLE / high priority.** Claims are created for non-zero VAT without direction and report queries do not filter source direction. |
| A-004 | Bank import rejects a whole batch before the partial-row contract runs | **REPRODUCIBLE / open.** `_validateImport` runs before row-level persistence; malformed-row execution remains untested. |
| A-005 | Bank-import mode and receipt reconciliation are not exposed end to end | **REPRODUCIBLE / overlap B-010.** The page caller omits mode and matching does not apply a receivable payment. |
| A-006 | Payment replay and overpayment handling do not preserve the accounting contract | **REPRODUCIBLE / open.** Idempotency returns by key without request fingerprint; excess is not a separate credit item. |
| A-007 | Concurrent write-off can post duplicate loss journals | **REPRODUCIBLE source risk / concurrency unexecuted.** The state read precedes the transaction conditional check. |
| A-008 | Direct inventory edits bypass movement and stock-policy enforcement | **REPRODUCIBLE / overlap B-012.** Generic article update accepts stock and adjustment paths omit policy checks. |
| A-009 | Recurring direct posting can leave an unlinked or orphan tax claim | **REPRODUCIBLE source risk / concurrency unexecuted.** The losing occurrence path deletes its journal but not its already-inserted tax claim. |
| A-010 | Recurring invoice creation and due-date advancement are split across transactions | **REPRODUCIBLE / open.** Invoice occurrence commits before the template due-date update. |
| A-011 | Dunning interest uses arbitrary configured rate and stale stage state | **REPRODUCIBLE / policy blocked.** [BGB §288](https://www.gesetze-im-internet.de/bgb/__288.html) supplies a source boundary, not the product’s rate/date/party policy. |
| A-012 | Dunning entrypoints, send, and PDF paths miss documented artifact behavior | **REPRODUCIBLE / overlap B-007 and B-012.** Send/PDF paths are source-anchored; SMTP/content execution is absent. |
| A-013 | Backup scheduling exists as a helper but is not wired into startup/services | **REPRODUCIBLE / overlap B-003.** Startup does not invoke due scheduling or expose result state. |
| A-014 | Profile deletion removes the database despite the profile safety contract | **REPRODUCIBLE / contract blocked.** Implementation and maintained spec/test disagree; do not choose purge or retention by inference. |
| A-015 | Schema evolution mutates columns outside the versioned migration transaction | **REPRODUCIBLE source risk / fault injection unexecuted.** Additive initialization changes follow the versioned migration path. |
| A-016 | DATEV export invents account mappings and can leave artifacts without export history | **REPRODUCIBLE / open.** Fallback accounts and artifact-before-log ordering are visible in source. |
| A-017 | Persisted monetary scale and caller precision disagree with the schema contract | **REPRODUCIBLE / numeric contract needed.** Invoice callers persist three/four decimal fields into two-decimal declarations; SQLite affinity does not settle portability. |
| A-018 | Synthetic chart seed and km/EKS precision leave reporting semantics implicit | **REPRODUCIBLE / product/data-model decision.** Seed labels/mappings are synthetic and km parsing uses the money scale. |

A’s focused 55-test command is useful but is a happy-path/selected-failure gate. The two current route-smoke timeouts and the conflicting broad-run count must be resolved before calling the VM gate green; neither run closes the negative cases named in A-004, A-007, A-009, A-011, A-015, or the profile, SMTP/PDF, tax-direction, and export-history cases.

### B — product vision and UI (21 findings)

| ID | Finding | Independent disposition |
| --- | --- | --- |
| B-001 | Generic route fallback replaces documented workspaces | **REPRODUCIBLE / open.** `/receipts`, `/taxes`, and `/reports` use generic route/data surfaces. |
| B-002 | Receipt inbox and ingestion are absent while the route promises receipts | **REPRODUCIBLE / overlap C-001/C-002.** Startup explicitly registers drop/file association as unavailable and no receipt ingestion path is wired. |
| B-003 | Settings omits backup, storage, privacy, integration, and accounting controls | **REPRODUCIBLE / overlap A-013.** Visible settings and service callers support the gap. |
| B-004 | English locale is selectable but most surfaces remain German | **PARTIAL / technical reconciliation, finding retained.** German+English is the approved audit scope; reconcile the stale German-only app spec technically, then complete localization. Do not re-ask the product decision. |
| B-005 | Privacy masking covers dashboard values only | **REPRODUCIBLE / open.** Generic finance, invoice, and bank paths bypass the dashboard masking path. |
| B-006 | Invoice editor/document lifecycle is a narrow prototype | **REPRODUCIBLE / overlap A-001.** Current route supports a small draft/finalize/PDF subset. |
| B-007 | PDF viewer and artifact actions are not production-wired | **REPRODUCIBLE / overlap C-002 and A-012.** Inline preview/save exists; dedicated viewer/print helper has no production caller. |
| B-008 | Tax/reporting routes expose raw records instead of accounting workspaces | **REPRODUCIBLE / overlap A-003/A-016.** Services exist but typed report actions are not routed. |
| B-009 | Bank-import recovery is not an actionable history workspace | **REPRODUCIBLE / overlap A-004/A-005.** Seven templates and static history are source-anchored. |
| B-010 | Payment reconciliation and overpayment are backend seams without a route | **REPRODUCIBLE / overlap A-005/A-006.** No allocation/overpayment action is reachable. |
| B-011 | Setup does not implement the documented first-run trust flow | **REPRODUCIBLE / overlap A setup evidence.** Four simplified steps omit documented tax, invoice, privacy, backup, and recovery states. |
| B-012 | Master data, inventory, dunning, and recurring capabilities are not exposed | **REPRODUCIBLE / overlap A-008/A-012.** Existing backend seams do not establish route exposure. |
| B-013 | Keyboard shortcuts are only an unbootstrapped helper | **REPRODUCIBLE / overlap C-003.** Empty callbacks and absent production registration are source-anchored. |
| B-014 | Inspector component is not exposed from a product route | **REPRODUCIBLE / open.** Component tests do not establish a route caller. |
| B-015 | Reusable dialog contract is unexposed and defaults confirmation to “delete” | **REPRODUCIBLE / open.** `AppDialog` has no production caller and its fallback label is hardcoded. |
| B-016 | Generic finance rows are not scalable or keyboard-complete | **REPRODUCIBLE with matrix correction.** Rows are materialized in a `Column` and lack sort/pagination/selection/virtualization. The matrix’s “no search” statement is too strong: `FinanceListSurface` has a local `TextEditingController`, header callback, and client-side `_filteredRows`; global/server-side search remains absent. |
| B-017 | Error/loading/default toolbar strings violate the documented state model | **REPRODUCIBLE / open.** Generic state paths use hardcoded/default labels and weak recovery. |
| B-018 | Dashboard configuration errors can erase visible user choice | **REPRODUCIBLE / open.** Load falls back to defaults and writes are unawaited. |
| B-019 | Sidebar preference hydration flashes and hides failures | **REPRODUCIBLE / open.** Microtask hydration and swallowed errors are source-anchored. |
| B-020 | Contract tests are detached fakes and cannot prove production exposure | **REPRODUCIBLE evidence gap / overlap C provenance.** Local fake route/services are useful unit tests but not production composition evidence. |
| B-021 | Shell/theme tests document red-phase gaps and weak acceptance | **REVISE / gate unresolved, finding retained.** The current baseline completed 748 tests with two named route-smoke `pumpAndSettle` timeouts, and focused reruns reproduce both. The separate 750/750 report has no preserved command/log and is unsupported. Stale RED comments and fallback assertions still weaken evidence and should be updated or removed. |

The B matrix now includes a source-heading map for the cited DESIGN sections, docs 01–08
commitments grouped into M01–M43, and the remaining maintained specs owned by A/C. This is a
provenance repair, not a request to inflate the matrix with one row per sentence.

### C — architecture, delivery, native, and specification parity (13 findings)

| ID | Finding | Independent disposition |
| --- | --- | --- |
| C-001 | Production bootstrap leaves most desktop capabilities unavailable | **REPRODUCIBLE / open.** Main registers tray and explicit unavailable drop/file association; no shortcut/PDF/single-instance/drop adapter is constructed. |
| C-002 | Desktop action libraries contain fakes/placeholders instead of OS side effects | **REPRODUCIBLE / open.** Literal `APP_DATA_DIR`, fake association/window backends, unsupported print, and process-local lock are visible. |
| C-003 | Shortcuts/tray commands are not connected to application intents | **REPRODUCIBLE / open; overlap B-013.** Empty callbacks and no production shortcut registration are visible; the stale invoice-route note should be corrected because `/invoices/new` exists. |
| C-004 | Window state has competing formats and unawaited close lifecycle | **REPRODUCIBLE / open.** Main CSV keys differ from `WindowStateService`; listener/disposal ordering is not closed. |
| C-005 | Production UI bypasses the application service boundary | **REPRODUCIBLE / open.** Dashboard/setup construct repositories/executors in route/widget paths. |
| C-006 | Brand and platform data-path contracts contradict each other | **REPRODUCIBLE / BLOCKED canonical decision.** Decide OpenAccounting/OpenInvoices, profile(s), Linux/macOS roots, and Windows `APPDATA`/`LOCALAPPDATA`, then update code/spec/docs/tests together. |
| C-007 | Database table count and migration-hook ownership are out of parity | **REPRODUCIBLE / BLOCKED cross-workstream.** The 39-table runtime, 38-table spec language, empty `_postHooks`, and A migration evidence need one owner decision. |
| C-008 | Structural OpenSpec green status hides semantic drift | **REPRODUCIBLE / open evidence and contract matrix.** 52/52 strict validation is structural; 28 specs retain TBD Purpose and 16 retain implementation-evidence text. |
| C-009 | CI validates only the protected branch and Linux debug build | **REPRODUCIBLE / open delivery gap.** Current Linux checks do not verify macOS/Windows compilation/runtime or the `dev` workflow. |
| C-010 | No release artifact/signing pipeline and updater is intentionally disabled | **REPRODUCIBLE / BLOCKED release policy.** Decide manual/automated package, trust root, signing, key rotation, and version provenance before claiming delivery. |
| C-011 | Declared dependencies have no direct source use | **REPRODUCIBLE candidate / open.** Keep as a dependency-ownership review; do not remove packages from this finding alone. The report’s shell reproduction needs quoted regex/arguments so `|` is not parsed as a shell pipe. |
| C-012 | Generated artifact/native provenance is not checked in CI | **REPRODUCIBLE / open.** Generated registrants/ARB outputs are tracked but no regenerate-and-diff gate is present. |
| C-013 | AGENTS.md is stale relative to the application graph/delivery surface | **REPRODUCIBLE / open.** Riverpod/Drift/GoRouter, test inventory, CI, and localization-template claims disagree with the checkout. |

## Consolidated repair groups

These are bounded candidates for later Anvil routing. They are planning slices, not approvals to change production code.

| Group | Findings | Smallest coherent scope |
| --- | --- | --- |
| Contract and legal/product truth | A-001, A-003, A-011, A-014, A-017, A-018, C-006, C-007, C-010, B-004 | Record canonical document/tax/dunning/profile/money/path/release decisions, update conflicting specs, and add executable parity checks before implementation. |
| Posting, tax, money, and persistence integrity | A-002–A-010, A-015–A-018 | Freeze typed posting and account mapping, direction-aware tax claims, row-level bank parsing, conditional receivable transitions, inventory policy, recurring atomicity, migration ownership, and DATEV log/mapping behavior. |
| Production desktop/composition | C-001–C-005, B-002, B-007, B-013, B-020 | Wire real profile-aware adapters and AppServices, preserve truthful unavailable states, and prove actions through production composition tests; Linux startup alone is insufficient. |
| First-class route and vision exposure | B-001, B-005–B-012, B-014–B-019 | Replace generic workspaces with typed routes/use cases, then add privacy, settings, invoice/bank/setup/report/inventory/dunning states and recovery. |
| Delivery and evidence integrity | C-008–C-013, B-020–B-021, manifest | Repair per-file provenance/statuses, add source-heading mapping, update stale instructions/tests, and add native/generated/package gates with explicit macOS/Windows limits. |

## Decisions to route to the product/architecture owner

1. Is the canonical product/data contract **OpenAccounting** or **OpenInvoices**? Choose exact Linux/macOS/Windows roots, `APPDATA` versus `LOCALAPPDATA`, and singular versus plural profile directories.
2. Does deleting a profile retain the directory/database for recovery, as the maintained spec says, or purge it, as the current test/implementation do? If retention is chosen, define a separate explicit purge operation.
3. Which typed document effects apply to outgoing/incoming invoices, Gutschrift, Storno, Angebot, Auftrag, Proforma, and Lieferschein? Include signed journal, receivable, inventory, tax, and PDF behavior.
4. Which input-tax direction/reverse-charge/special-scheme rules are in scope, and what must the product call “not filed” versus exported? The official UStG/ELSTER sources do not supply this product matrix.
5. Should dunning rates be date-based statutory base-rate calculations with consumer/business branching, a configured policy, or a hybrid snapshot? Decide fee defaults and automatic block release.
6. What are the supported money, quantity, tax-rate, negative-input, and rounding/allocation scales? Align the SQLite declarations, callers, reports, and export contract.
7. Is release delivery manual with signed artifacts or automated per-platform packaging? Define trust root, signing, key rotation, versioning, and updater availability.

The German+English localization decision is already treated as approved scope for this audit. The remaining German-only `app` spec is a technical specification conflict to reconcile, not a question to send back for product selection.
