# OpenAccounting product vision and UI findings

Audit date: 2026-09-29
Workstream: product vision and UI (B)
Baseline: `dev` at `70ec70c` (709 tracked files; no `.codegraph`).
Scope: read-only initial audit plus independent source review. No production source, test,
asset, or configuration file was changed by this workstream.

Approved audit scope: German (`de-DE`) is primary and English is a shipped secondary locale.
The maintained German-only app specification is recorded below as a technical specification
conflict to reconcile; it is not an unresolved product-scope decision.

## How to read the findings

Each finding gives exact source lines, the documented expectation, the actual runtime path found,
a reproduction path, platform evidence limits, a minimal repair direction, a likely regression
owner, and a current status. “Open” means the source evidence is sufficient to schedule a fix.
“Blocked” means a product decision or missing runtime gate must be resolved first. A service,
repository, or isolated test is not counted as a reachable capability.

Severity is `S0` release-blocking product contract, `S1` major documented workflow absent or
misleading, `S2` substantial UI/accessibility/recovery gap, and `S3` localized polish or evidence
gap. Platform is `all-static` unless a Linux rendered run is added by the shared gate; macOS and
Windows remain static-only in this audit.

## Findings

### S1 — Generic route fallback replaces documented workspaces

- **Evidence:** `lib/core/router/app_router.dart:561-638,883-930,1029-1091`; `lib/core/router/route_data_repository.dart:25-83`.
- **Expected:** Dedicated receipts, contacts, taxes, and reports workspaces with typed projections,
  actions, search, sort, pagination, and route-specific empty/error states (`DESIGN.md:572-625,790-921`;
  `openspec/specs/typed-route-workspaces/spec.md:8-58`).
- **Actual:** `/receipts`, `/taxes`, and `/reports` all use `ProductionRoutePage` and the generic
  `FinanceListSurface`; data comes from raw `SELECT *` allow-listed tables and generic detail
  dialogs. Contacts has a generic list with one create action.
- **Reproduction:** On any desktop platform, navigate to `/receipts`, `/taxes`, `/reports`, or
  `/contacts`; the static route graph resolves to the generic surface. A Linux render should
  confirm the same visible title/row/detail behavior.
- **Minimal fix:** Replace each route with a typed page/use-case/repository projection and
  route-specific actions/states. Retain raw table access only behind those typed adapters.
- **Regression owner:** routing and feature UI owner; architecture peer verifies route-to-service
  wiring. **Status:** Open.

### S1 — Receipt inbox and ingestion are absent while the route promises receipts

- **Evidence:** `lib/core/router/app_router.dart:561-574`; `lib/main.dart:91-99`;
  `lib/features/desktop/drop_service.dart`; `lib/core/router/route_data_repository.dart:15-23`.
- **Expected:** Receipt inbox with New/Review/Assigned/Booked/Error states, PDF/PNG/JPG/e-invoice
  ingestion, watch folder, and drag/drop (`DESIGN.md:790-829`; `openspec/specs/desktop-drag-drop/spec.md:9-35`).
- **Actual:** `/receipts` is a generic `belege` record list. Startup registers file drop and file
  associations as `UnavailableDesktopCapability` with explicit “not connected to an import
  workflow”/“not registered” reasons. No production drop handler reaches receipt persistence.
- **Reproduction:** Navigate to `/receipts`, then inspect the startup capability registry or try a
  PDF drop on Linux; the route has no inbox states and startup advertises drop as unavailable.
  macOS/Windows behavior is unverified.
- **Minimal fix:** Add a typed receipt ingestion use case and inbox state machine, then bootstrap
  the supported Linux/macOS/Windows drop/association adapters only when they route to durable
  receipt records. Keep an explicit unavailable state for unsupported targets.
- **Regression owner:** receipts plus desktop capability owners. **Status:** Open.

### S1 — Settings omits backup, storage, privacy, integration, and accounting controls

- **Evidence:** `lib/core/router/app_router.dart:640-832`; `lib/core/db/backup_service.dart`;
  `openspec/specs/localization-settings-and-data-protection/spec.md:8-42`.
- **Expected:** Settings sections for general/company/taxes/invoices/bank/integrations/data/privacy/
  backup/appearance/language/advanced/about, including data path, open folder, network scope,
  export/delete, backup status/restore, and integration disconnect (`DESIGN.md:925-1105`).
- **Actual:** `/settings` exposes locale, theme, a dashboard amount mask, profile create/switch,
  and a local-data card. `BackupService` has local/encrypted/SMB/restore/schedule seams but no
  production settings caller or visible status.
- **Reproduction:** Open `/settings` and inspect every card; no backup/privacy data controls,
  storage path, export/delete, or integration section is reachable on any platform.
- **Minimal fix:** Define typed settings sections backed by the existing controllers/services;
  expose status and recoverable error actions before adding new backend capability.
- **Regression owner:** settings/data-protection owner. **Status:** Open.

### S1 — English locale is selectable but most product surfaces remain German

- **Evidence:** `assets/l10n/l10n_de.arb:1-36`; `assets/l10n/l10n_en.arb:1-36`;
  `lib/core/app_locale.dart:5-45`; `lib/core/router/app_router.dart:640-774`;
  `lib/features/bank_import/bank_import_page.dart:20`; `lib/design_system/components/app_money.dart:8-51`.
- **Expected:** Complete German/English localization for every visible label/action/tooltip/loading/
  empty/error and active-locale date/number/currency formatting, with live route/filter preservation
  (`DESIGN.md:1108-1183`; `openspec/specs/localized-accessible-surface/spec.md:8-25`).
- **Actual:** The selector offers Deutsch/English, but ARBs contain only a small key set; route,
  dashboard, finance-list, bank-import, invoice, sidebar, and header strings are mostly literals.
  Money/date helpers default to `de_DE` even when English is active.
- **Reproduction:** Select English in `/settings`, then open `/banking`, `/invoices`, and a generic
  list. Static source proves German literals and German formatting; Linux render should verify the
  visible mixed-language state.
- **Minimal fix:** Inventory every visible string into ARB keys, pass active locale into formatting,
  and add a route-preserving locale smoke test against production widgets.
- **Regression owner:** localization/design-system owner. **Status:** Partial / open technical
  reconciliation; German+English is approved scope, while the current English path remains incomplete
  and `openspec/specs/app/spec.md` still states the stale German-only rule.

### S1 — Privacy masking covers dashboard values only

- **Evidence:** `lib/core/router/app_router.dart:768-774`; `lib/features/dashboard/dashboard_page.dart:221-280`;
  `lib/design_system/components/finance_list_surface.dart:291-299,406-412`;
  `lib/pages/rechnungen/invoice_document_page.dart:204-211`.
- **Expected:** Privacy mode masks financial values/balances throughout the app while preserving
  identity (`DESIGN.md:1009-1033`).
- **Actual:** `PrivacyModeProvider` is applied to dashboard `MoneyText` paths. Generic finance rows,
  invoice detail, and bank import render amounts without the provider.
- **Reproduction:** Enable “Beträge ausblenden” in `/settings`, then visit `/invoices`, `/banking`,
  and `/reports`; source path shows unmasked value formatters outside dashboard.
- **Minimal fix:** Pass one privacy-aware formatter/view model through all monetary surfaces and
  test list/detail/import/export-preview states.
- **Regression owner:** design-system plus each feature view owner. **Status:** Open.

### S1 — Invoice editor and document lifecycle are a narrow prototype

- **Evidence:** `lib/core/router/app_router.dart:267-544`;
  `lib/pages/rechnungen/invoice_document_page.dart:24-405`;
  `docs/01-rechnungen.md:1-234`; `openspec/specs/pdf-rendering-completeness/spec.md:8-34`.
- **Expected:** Split editor/live preview, multiple positions/articles, document types, validation,
  discounts/payment terms/taxes, ZUGFeRD/XRechnung, conversion and missing-data errors.
- **Actual:** `/invoices/new` stores a one-position draft. Detail renders a simple invoice paper and
  can finalize/save PDF; there is no typed document-type editor, e-invoice flow, payment/discount
  section, or full lifecycle action set.
- **Reproduction:** Open `/invoices/new` and add the available position; the form has one simple
  item and no split preview or document-type/e-invoice choice. Open `/invoices/:id` for the limited
  finalize/modal-preview actions.
- **Minimal fix:** Introduce a typed invoice draft model and route view model that owns positions,
  validation, artifact options, and explicit finalization; do not grow the generic route surface.
- **Regression owner:** invoices/document owner. **Status:** Open.

### S1 — PDF viewer and artifact actions are not production-wired

- **Evidence:** `lib/pages/rechnungen/invoice_document_page.dart:58-90,261-289`;
  `lib/features/desktop/pdf_viewer_service.dart:28-88`; `openspec/specs/document-artifact-actions/spec.md:8-33`.
- **Expected:** Preview/open/save-as/print through an injected dedicated viewer with safe missing-
  artifact recovery.
- **Actual:** Invoice detail uses an inline modal preview and Save PDF. `PdfViewerService` is an
  isolated helper with no production caller; VM print throws `UnsupportedError`.
- **Reproduction:** Open invoice detail and choose preview/save; no dedicated viewer window or
  artifact recovery is reachable. Static caller search finds only service definitions/tests.
- **Minimal fix:** Wire a typed artifact action service from invoice/dunning/document routes and
  provide platform adapters with a visible unsupported/error state.
- **Regression owner:** PDF/desktop owner. **Status:** Open.

### S1 — Tax and reporting routes expose raw records instead of accounting workspaces

- **Evidence:** `lib/core/router/app_router.dart:608-638`;
  `lib/features/accounting/*`; `docs/02-buchhaltung.md:1-308`;
  `DESIGN.md:869-921`.
- **Expected:** Tax period status/completeness/export/submission boundary plus EÜR/UStVA/EKS/GuV/
  ZM/DATEV/GoBD report actions.
- **Actual:** `/taxes` reads generic `ustva_exporte`; `/reports` reads generic `journal`. Accounting
  services exist but no typed route action exposes report generation, preview, export, or “not filed”.
- **Reproduction:** Navigate to `/taxes` and `/reports`; only generic lists/detail dialogs render.
  Static route-to-service trace shows no production caller for the report workflow services.
- **Minimal fix:** Create typed tax/report workspaces with period state, validation, export artifact,
  and explicit submission vocabulary; connect existing services through use cases.
- **Regression owner:** accounting UI/reporting owner; persistence/legal behavior remains with the
  accounting peer. **Status:** Open.

### S1 — Bank import recovery is not an actionable history workspace

- **Evidence:** `lib/features/bank_import/bank_import_page.dart:830-915,1001-1072,1103-1188`;
  `lib/features/bank_import/bank_template.dart:73-180`;
  `openspec/specs/bank-import-recovery-surface/spec.md`.
- **Expected:** Match confidence/suggestion versus confirmed state, manual/automatic modes/rules,
  10+ templates, and history detail/filter/pagination/retry.
- **Actual:** Review is a materialized `DataTable` without score/confidence controls; only seven
  predefined templates are present; history rows have no tap/select/action/detail/filter/pagination.
  Result retry is the only substantial recovery action.
- **Reproduction:** Open `/banking`, proceed to review, then result/history. The page has path/paste
  import and retry failures but no actionable history row or match-confidence control.
- **Minimal fix:** Expose typed import result/history view models with confidence and confirmation
  actions, then add bounded pagination/filtering and rule/template management.
- **Regression owner:** banking import UI owner; accounting peer owns persistence invariants.
  **Status:** Open.

### S1 — Payment reconciliation and overpayment are backend seams without a route

- **Evidence:** `openspec/specs/receipts-and-payment-reconciliation/spec.md:8-42`;
  `lib/features/einkommen/forderungen_repository.dart`;
  `lib/features/bank_import/bank_import_service.dart`.
- **Expected:** Receipt/bank-to-receivable allocation for partial/full payments, overpayment,
  audit trail, and explicit confirmation states.
- **Actual:** Bank processing can link an imported transaction to a journal entry; no invoice/receivable
  allocation, overpayment resolution, or audit UI is reachable.
- **Reproduction:** Import a bank row and inspect the result/invoice routes; there is no allocation
  action or overpayment state. Persistence/legal details are reserved for the accounting peer.
- **Minimal fix:** Add a user-visible reconciliation use case and invoice/banking actions after the
  accounting contract is settled; expose pending/confirmed/overpaid states.
- **Regression owner:** banking/invoice UI owner with accounting peer contract review. **Status:** Open.

### S1 — Setup does not implement the documented first-run trust flow

- **Evidence:** `lib/features/setup/wizard_page.dart:19-394`;
  `DESIGN.md:1889-1938`; `openspec/specs/setup-onboarding-integrity/spec.md:8-60`;
  `docs/08-einstellungen.md:9-95`.
- **Expected:** Welcome, business profile, tax/currency/invoicing setup, data protection/backup,
  and an explicit durable completion screen with recoverable atomic writes.
- **Actual:** `/setup` has four simplified German steps (`Stammdaten`, `Konten`, `Kategorien`,
  `Abschluss`) and a skip path. It lacks tax config, currency, number sequence, terms, backup,
  privacy, and full completion recovery.
- **Reproduction:** Start with an empty profile and follow `/setup`; only the four current steps and
  basic company/account/category fields appear.
- **Minimal fix:** Make setup a typed state machine backed by transactional use cases; add the
  documented steps and a durable completion result without allowing a skip to silently demote setup.
- **Regression owner:** setup/onboarding owner. **Status:** Open.

### S1 — Master data, inventory, dunning, and recurring capabilities are not exposed

- **Evidence:** `lib/pages/stammdaten/*`; `lib/features/inventory/lager_repository.dart`;
  `lib/features/mahnwesen/*`; `lib/features/recurring/*`; `app_router.dart:577-605,1233-1258`;
  `docs/03-kunden-stammdaten.md`, `docs/05-mahnwesen.md`.
- **Expected:** Customer/vendor/article/company/account/category workflows, stock management,
  dunning progression/PDF/mail, and any documented recurring workflow should have reachable routes
  and visible state.
- **Actual:** Only a generic customer list and create page are routed. `/inventory` is an explicit
  unavailable page. Dunning, article/vendor/company, and recurring services have no route/caller.
- **Reproduction:** Inspect the sidebar and navigate each documented destination; no dunning or
  inventory workflow is reachable, and `/inventory` shows unavailable.
- **Minimal fix:** Prioritize typed routes from the product decision, then connect existing services
  through use cases and actions. Do not count disabled links as completion.
- **Regression owner:** master-data/inventory/dunning UI owners. **Status:** Open.

### S2 — Keyboard shortcuts are implemented only as an unbootstrapped helper

- **Evidence:** `lib/features/desktop/desktop_shortcuts.dart:155-306`; no production references to
  `DesktopShortcutsService` or `createDesktopShortcutsService` in `lib/main.dart`, `lib/core/app.dart`,
  or route bootstrap.
- **Expected:** App-wide commands and shortcut outcomes from `DESIGN.md:1187-1220` and
  `openspec/specs/desktop-lifecycle-and-command-wiring/spec.md:26-42`.
- **Actual:** Search/navigation/open/toggle/zoom callbacks default to empty functions. Tests inject
  the service directly, but production startup never registers it.
- **Reproduction:** On a running desktop build, press the documented shortcuts; no production
  command binding is evidenced. Linux runtime should verify after wiring; macOS/Windows remain static.
- **Minimal fix:** Register one service at app bootstrap with non-empty route-aware callbacks and
  expose unavailable commands explicitly when a capability is unsupported.
- **Regression owner:** desktop/app-shell owner. **Status:** Open.

### S2 — Inspector component is not exposed from any product route

- **Evidence:** `lib/design_system/components/app_inspector.dart:8-239`; production caller search
  found only component definition/tests.
- **Expected:** Optional 360–440px contextual inspector (`DESIGN.md:687-719`).
- **Actual:** The component has focus scope/Escape behavior in isolation, but no invoice, receipt,
  banking, or list route opens it.
- **Reproduction:** Select a row on any generic list; there is no inspector action or pane.
- **Minimal fix:** Choose one high-value route (receipts or banking), wire the component through a
  typed selection state, and preserve a full-page fallback for narrow windows.
- **Regression owner:** design-system/routing owner. **Status:** Open.

### S2 — Reusable dialog contract is unexposed and defaults every confirm to “delete”

- **Evidence:** `lib/design_system/components/app_dialog.dart:9-25,77` defines the reusable dialog
  but production caller search finds only its tests. Route code uses page-local `showDialog` calls,
  including `lib/core/router/app_router.dart:672-715` for profile creation.
- **Expected:** Confirmations and irreversible actions use a localized, semantic dialog with an action
  that names the operation (`DESIGN.md:1259-1292`).
- **Actual:** The reusable component is not in the production path, and its generic `onConfirm` fallback
  label is always “Löschen”, even when the caller is not deleting. Production dialogs therefore duplicate
  hardcoded labels and do not share one accessible contract.
- **Reproduction:** Open settings profile creation or inspect a route confirmation; no `AppDialog` is
  present. Construct `AppDialog(onConfirm: ...)` and it renders “Löschen” regardless of operation.
- **Minimal fix:** Give the component explicit localized cancel/confirm labels and wire it through the
  destructive/confirmation call sites; keep operation-specific confirmation text in the route view model.
- **Regression owner:** design-system/dialog owner. **Status:** Open.

### S2 — Generic finance rows are not scalable or keyboard-complete

- **Evidence:** `lib/design_system/components/finance_list_surface.dart:177-206,231-307,406-412`;
  `lib/core/router/route_data_repository.dart:47-83`.
- **Expected:** Virtualized, sortable/searchable/selectable tables with keyboard/context actions
  (`DESIGN.md:572-683`).
- **Actual:** All rows are built in a `Column` from raw records; `FinanceListSurface` does provide
  one local substring search through `_searchController` and `_filteredRows`, while the surface has
  no has-more/pagination, sorting, bulk selection, or row keyboard navigation.
- **Reproduction:** Open any generic route with records and use its local search field; matching rows
  are filtered in memory, but there is no table header, selection model, or keyboard row action.
- **Minimal fix:** Replace the helper with one typed `DataTable`/virtualized list contract and make
  each feature supply explicit columns, queries, selection, and actions.
- **Regression owner:** design-system plus route owners. **Status:** Open.

### S2 — Error, loading, and default toolbar strings violate the documented state model

- **Evidence:** `lib/core/router/app_router.dart:933-952,1129-1175`;
  `lib/design_system/components/app_page_header.dart:25-36,134-141,329-337`;
  `lib/design_system/components/skeleton.dart:42-57`.
- **Expected:** Content-shaped loading, localized actionable errors, persistent warnings where
  needed, and focus-preserving retry (`DESIGN.md:1296-1375,1942-1979`).
- **Actual:** Generic record detail uses an unbounded spinner; header defaults and `ErrorState` use
  hardcoded German/English labels; generic errors expose source text without route-specific recovery.
- **Reproduction:** Open a generic detail while loading or force a route data error; source path
  shows the fallback spinner/error/header labels.
- **Minimal fix:** Add localized state contracts and bounded content placeholders with retry actions
  that preserve route/filter/selection.
- **Regression owner:** design-system/routing owner. **Status:** Open.

### S2 — Dashboard configuration errors can erase the user’s visible choice

- **Evidence:** `lib/features/dashboard/dashboard_repository.dart:33-95`;
  `lib/features/dashboard/dashboard_page.dart:103-173`;
  `openspec/specs/dashboard-and-setup-workflows/spec.md:8-44`.
- **Expected:** Config load/write failure retains the user’s choice and offers retry.
- **Actual:** `loadConfig` catches errors and returns defaults; reorder/toggle calls are unawaited
  from the sheet, with no visible failure or retry state.
- **Reproduction:** Make dashboard config unavailable or fail a write; the page falls back to default
  order/visibility and gives no recovery action.
- **Minimal fix:** Keep the last in-memory choice, surface a persistent retry message, and await or
  explicitly track writes.
- **Regression owner:** dashboard owner. **Status:** Open.

### S3 — Sidebar preference hydration flashes and hides failures

- **Evidence:** `lib/app/sidebar_controller.dart:6-46`; `lib/app/app_shell.dart:31-114`;
  `openspec/specs/adaptive-shell-motion/spec.md:8-49`.
- **Expected:** Persisted sidebar state is applied before the first meaningful frame, with retry on
  preference failure and motion/reduced-motion behavior matching the design.
- **Actual:** Controller starts expanded and loads in a microtask; failures are swallowed. Shell uses
  a 250ms animation and changes compact width through a fixed `SizedBox`.
- **Reproduction:** Set compact sidebar preference, cold-start the app, and observe first-frame state;
  force preference read/write failure to see no user-facing recovery.
- **Minimal fix:** Hydrate before shell build (or show an intentional shell loading state), expose a
  retryable preference error, and test width changes with keyboard/reduced-motion settings.
- **Regression owner:** shell owner. **Status:** Open.

### S3 — Contract tests are detached fakes and cannot prove production UI exposure

- **Evidence:** `test/features/localized_accessible_surface/accessible_test.dart:6-60` defines local
  `SidebarDestination`/`OverflowActions`; `test/features/localized_accessible_surface/localized_test.dart:1-109`
  defines local `LocaleFormatter`; `test/features/routed_surface/typed_route_test.dart:1-223` defines
  local `CanonicalRoute`/fake search; `test/features/routed_surface/bank_import_test.dart:1-40` defines
  local import service/policy fakes; `test/features/routed_surface/dashboard_setup_test.dart:1-142`
  defines local dashboard/setup fakes; `test/features/state_surfaces/loading_state_test.dart:1-130`
  defines local loading/dashboard/page widgets.
- **Expected:** Tests used as evidence should exercise production widgets, route graph, providers,
  and persistence seams.
- **Actual:** These tests can pass while the production route remains generic or unlocalized. Desktop
  shortcut/drop/PDF tests similarly inject isolated helpers instead of startup wiring.
- **Reproduction:** Read imports and local class definitions in the cited tests; the production
  route/widget classes are not under test.
- **Minimal fix:** Keep pure contract tests as unit evidence, but add a small production widget/route
  smoke suite for each high-risk promise and label detached tests as contract-only.
- **Regression owner:** test/architecture owner. **Status:** Evidence gap open; shared test execution
  belongs to the architecture peer.

### S2 — Shell and theme test suites document red-phase gaps and weak acceptance

- **Evidence:** `test/app/app_shell_test.dart:1-3,100-110,136-147,493-507` labels the suite as a
  failing/RED test and names missing page headers, shell wrapping for `/setup`, and sidebar preference
  restoration as expected failures. `test/design_system/app_page_test.dart:1-4,84-126` likewise labels
  responsive padding as RED. `test/app/app_theme_test.dart:1-3,104-134` calls itself RED and permits
  a system-mode fallback instead of requiring the restored dark state.
- **Expected:** The test suite should provide a truthful, stable gate for the current production contract,
  with red tests failing for a known defect and green tests asserting the real route/widget composition.
- **Actual:** Some source-backed shell tests still carry pre-fix assumptions/comments, while the theme
  test can pass by parsing preferences directly when the provider has not restored the state. This makes
  “green” evidence weaker than a production restart/render check.
- **Reproduction:** Read the cited test comments and fallback branch; no production source is changed by
  this finding. C should run the suite and record the actual failing/passing list before any repair.
- **Minimal fix:** Either implement the documented shell contract or retire/update stale RED tests in the
  same scoped change; remove acceptance fallbacks that bypass the production provider and add a real
  production route/theme restart assertion.
- **Regression owner:** shell/theme test owner. **Status:** REVISE / gate unresolved. The current
  FVM VM baseline completed 748 tests with two named `pumpAndSettle` timeouts in
  `test/app/app_shell_test.dart` and
  `test/integration/audit/analyzer-and-integration-test-gates_test.dart`; focused reruns reproduce
  both failures. A separate 750/750 report has no preserved command or log and remains unsupported,
  so it cannot be used as a green result.

## B manifest coverage handoff

The peer-owned `test/integration/audit/architecture-delivery-coverage.tsv` assigns 51 tracked rows to
workstream B. I reviewed all 27 source/design rows and all 24 test rows. The source rows are covered by
the matrix and findings above:

- **Vision and localization:** `DESIGN.md`, `assets/l10n/l10n_de.arb`, `assets/l10n/l10n_en.arb`,
  `lib/l10n/l10n.dart`, `lib/l10n/l10n_de.dart`, `lib/l10n/l10n_en.dart`.
- **Shell/locale/theme:** `lib/app/app_drawer_scope.dart`, `lib/app/app_shell.dart`,
  `lib/app/sidebar_controller.dart`, `lib/core/app_locale.dart`, `lib/core/theme/app_colors.dart`,
  `lib/core/theme/app_theme.dart`.
- **Design system components:** `lib/design_system/components/app_card.dart`, `app_dialog.dart`,
  `app_inspector.dart`, `app_money.dart`, `app_page.dart`, `app_page_header.dart`, `app_sidebar.dart`,
  `app_status_chip.dart`, `finance_list_surface.dart`, `skeleton.dart`.
- **Design system tokens:** `lib/design_system/theme/app_typography.dart`,
  `lib/design_system/tokens/duration.dart`, `radius.dart`, `spacing.dart`, and `tokens.dart`.
- **Tests:** `test/app/app_shell_test.dart`, `app_theme_test.dart`, `window_test.dart`,
  `test/core/theme_test.dart`, all seven `test/design_system/*_test.dart` rows,
  `test/features/dashboard/config_test.dart` and `widgets_test.dart`, both
  `test/features/localized_accessible_surface/*_test.dart`, all three
  `test/features/routed_surface/*_test.dart`, `test/features/shell/adaptive_shell_test.dart`,
  `test/features/state_surfaces/loading_state_test.dart`, both
  `test/integration/audit/*_test.dart`, `test/l10n/format_test.dart`, and `test/widget_test.dart`.

The test rows were read but not executed here because the architecture peer owns the shared FVM
analyzer/test/build gate. Their evidence classes are recorded: production-backed component/database
tests, static source-probe tests (`window_test.dart`, parts of `app_theme_test.dart`), and detached
contract fakes (the localized/routed/loading suites above). The shared current gate artifact is
already available: the VM suite completed 748 tests with the two named route `pumpAndSettle`
failures, and both focused reproductions fail. The separate 750/750 report has no preserved
command/log and remains unreconciled. B runtime evidence therefore stays unresolved; it is not
pending evidence and must not be reported as a green full-suite gate.

## Approved localization scope and technical specification reconciliation

The approved scope for this audit is German and English, with German primary and English secondary.
`DESIGN.md:1108-1183`, `openspec/specs/localized-accessible-surface/spec.md:8-25`, and
`openspec/specs/app-theme/spec.md:37-54` require German and English localization with a live
language switch. `openspec/specs/app/spec.md:90-125` still says all user-facing text is German
and informal `Du`; that stale requirement is a specification-parity repair item. It does not reopen
the approved locale decision or make the B-004 scope blocked. The current English route remains
partial until visible strings and active-locale formatting are completed.

## Bounded repair queue for the independent review

The smallest reviewable fix groups are:

1. Reconcile the stale German-only app specification with the approved German/English scope, then
   replace literals and formatting defaults through the production l10n path.
2. Replace generic receipts/taxes/reports with typed route workspaces and add receipt ingestion/drop
   only when its durable state contract is ready.
3. Expose settings/data-protection/backup status and error recovery using the existing services.
4. Wire desktop commands/PDF artifact actions and add platform truthfulness at bootstrap.
5. Expand invoice, banking, setup, and dashboard flows from the documented state models.
6. Add production route/widget smoke evidence; keep detached contract tests as supplemental evidence.

Each group can be independently reviewed after the initial audit. No group was implemented here.
