# OpenAccounting product vision matrix

Audit date: 2026-09-29
Workstream: product vision and UI (B)
Baseline: `dev` at `70ec70c`; Flutter is pinned to 3.47.2 by `.fvmrc`.

## Scope and evidence rules

This matrix binds the complete documented product vision. It includes `DESIGN.md`, `README.md`,
`docs/01-rechnungen.md` through `docs/08-einstellungen.md`, the active OpenSpec specifications,
and the production route, widget, service, and persistence code. The suggested MVP section in
`DESIGN.md` is not used as a scope limit.

Approved audit scope: German (`de-DE`) is primary and English is a shipped secondary locale.
The full documented vision remains in scope. The German-only wording in
`openspec/specs/app/spec.md` is a stale specification-parity conflict to reconcile, not a pending
scope decision.

The route and service columns describe the actual path found in the repository. An isolated
repository, renderer, desktop adapter, or test double is recorded as an implementation seam;
it is not evidence that a user can reach the capability. A route that displays a generic table,
an unavailable card, or a raw record dialog does not satisfy a documented dedicated workflow.

Status meanings:

- **Complete**: the documented behavior is reachable through production UI, persists where
  required, and has a visible outcome supported by the inspected source.
- **Partial**: a meaningful production slice exists, but a material workflow, state, route,
  platform path, or documented field is absent.
- **Missing**: the commitment has no reachable production capability, even when a backend or
  helper exists.
- **Blocked**: the evidence cannot be accepted as complete because a product requirement
  conflicts or a required runtime gate is unavailable. Existing behavior never resolves the
  documented requirement by itself.

The source review is static across Linux, macOS, and Windows. No macOS or Windows runtime claim
is made. Linux rendered/runtime verification belongs in the shared architecture/build gate;
this workstream did not change source or run a production fix. The durable findings below give
the exact paths that gate needs to exercise.

## Vision-to-runtime matrix

| Source commitment | Route/control | Service and data path | Persistence | Visible outcome | Status | Evidence |
|---|---|---|---|---|---|---|
| Local-first, privacy-friendly desktop accounting for German freelancers; de-DE primary, en secondary; M3 (`DESIGN.md:3-8`) | `AppShell`; all canonical routes; profile popup and local indicator | `lib/core/app.dart`; `lib/app/app_shell.dart`; `lib/core/db/profile_manager.dart`; Drift/SQLite | Active profile and database are opened at startup in `lib/main.dart:27-120` | App starts with a local profile and local database indicator | Partial | The local startup path is real. The settings, backup, integration, and ownership controls promised by the same design are not exposed. |
| Calm, focused UI with freelancer language and progressive disclosure (`DESIGN.md:12-85`) | Page headers, route details, optional inspector, context actions | `AppPageHeader`; `AppInspector`; generic route details in `app_router.dart` | No separate disclosure preference | Simple pages render, but advanced context/actions are not reachable through an inspector or typed workspace | Partial | The shell has a reusable inspector seam, but no production caller; generic raw-detail dialogs expose implementation fields instead of progressive business concepts. |
| Desktop shell supports keyboard, mouse, trackpad, resize, side-by-side work, drag/drop, context menus, and shortcuts (`DESIGN.md:87-110`) | `AppShell`, sidebar, route pages | `app_shell.dart`; `app_sidebar.dart`; desktop helper classes | Sidebar preference and window bounds use shared preferences | Resize and navigation shell exist; drag/drop and command actions are not reachable | Partial | Responsive shell is wired; `DesktopShortcutsService`, `DropService`, and file association helpers have no production bootstrap path. |
| Three-area shell and breakpoint behavior: expanded sidebar >=1200, compact rail 900-1199, drawer <900 (`DESIGN.md:119-228`) | Every route through `AppShell` | `lib/app/app_shell.dart:31-114`; `lib/design_system/components/app_sidebar.dart` | `SidebarController` stores expanded state | Drawer/rail/sidebar changes by width | Partial | Width decisions are present. The preference is loaded in a microtask, so the first frame can flash expanded, and load/write errors are swallowed. |
| Window starts at 1280x800, min 960x640, restores bounds/maximized, guards off-screen windows (`DESIGN.md:1501-1524`) | Desktop bootstrap | `lib/main.dart:145-224` | Window bounds/maximized stored in shared preferences | Window geometry is restored and constrained | Partial | Static implementation covers the documented lifecycle; Linux rendered/runtime verification remains in the shared gate and macOS/Windows are static-only. |
| Material 3 system/light/dark themes, semantic colors, component states, and token usage (`DESIGN.md:310-430`) | App theme and settings theme selector | `lib/core/theme/app_theme.dart`; `app_colors.dart`; `lib/core/app.dart:260-279` | Theme mode persisted by `ThemeModeController` | System/hell/dunkel changes theme and semantic status colors | Partial | Theme foundation and selector are production-wired. Several surfaces still construct raw generic cards/lists and do not consume the documented component contracts. |
| Reusable `AppPage`, header, data table, money, status, filter, and inspector components with shared tokens (`DESIGN.md:1658-1885`) | Route pages and design-system components | `lib/design_system/components/*`; `lib/design_system/tokens/*` | Components are stateless/view-time except preferences | Cards, headers, money, status chips, and page constraints are reused; data table/filter/inspector/dialog paths are incomplete | Partial | Token primitives and several components are real. `AppDialog`/`AppInspector` have no production callers, and `FinanceListSurface` is not the documented scalable `AppDataTable`. |
| Typography, locale-aware monetary/date formatting, tabular figures (`DESIGN.md:434-481`) | `MoneyText`, invoice/list/dashboard values | `lib/design_system/components/app_money.dart`; callers in dashboard, invoices, finance list, bank import | Values are stored in Drift; formatting is view-time | Values render in German formatting by default | Partial | Components default to `de_DE` even when English is selected, and many callers do not pass the active locale or privacy mode. |
| Icons are coherent and motion is subtle, interruptible, and reduced-motion aware (`DESIGN.md:1410-1445`) | Shell/page transitions, chips, buttons, loading states | `AppShell` animation and `MediaQuery.disableAnimations`; component-local icons | No motion preference beyond platform `disableAnimations` | Shell transitions and semantic icons appear in selected components | Partial | Shell checks reduced animations, but there is no whole-app motion contract or rendered verification of focus/animation behavior across routes. |
| All visible labels/actions/errors/loading/empty states localizable in German and English, with live switch preserving route/filter (`DESIGN.md:1108-1183`; `openspec/specs/localized-accessible-surface/spec.md:8-25`) | `/settings` locale selector; all route pages | `lib/core/app_locale.dart`; `assets/l10n/l10n_de.arb`; `assets/l10n/l10n_en.arb` | Selected locale is persisted | Locale selector changes app locale, but most pages stay German | Partial | Only a small 36-line key set exists in each ARB. `app_router.dart`, dashboard, finance list, bank import, invoice, header, and sidebar contain hardcoded user-facing strings. |
| Visible focus, complete keyboard navigation, semantic labels, text scaling, logical focus (`DESIGN.md:1448-1470`) | Sidebar semantics, buttons, fields, tables, dialogs | Flutter semantics in selected components; no unified route interaction layer | No a11y preference required | Sidebar and some controls expose semantics; tables and generic rows do not expose the full model | Partial | The sidebar adds custom Enter/Space handling, but generic finance rows are pointer-first and no production inspector or global keyboard command path is wired. |
| Documented shortcuts and command palette: Ctrl/Cmd+K, N, F, S, comma, Esc, Enter, Space, `?` (`DESIGN.md:1187-1220`) | Intended app-wide commands | `lib/features/desktop/desktop_shortcuts.dart:155-306` | None required | No production shortcut/command palette exposure found | Missing | Service callbacks are empty by default and no production caller registers `createDesktopShortcutsService`; tests inject the service directly. |
| Dashboard answers business status, attention, outstanding work, and tax reserve (`DESIGN.md:524-568`; `docs/07-dashboard.md`) | `/` dashboard cards and quick links | `lib/features/dashboard/dashboard_page.dart`; `dashboard_repository.dart`; `dashboard_widgets.dart` | Widget visibility/order/quick links in dashboard config | 13 count/text cards render with loading/error states | Partial | The repository has count/list queries and the page is reachable. Revenue chart, EÜR preview, document pipeline, GuV warning, bank balance, and tax reserve outcomes documented in `docs/07-dashboard.md` are absent. |
| Dashboard widget list, reorder, visibility, quick links, refresh, and sizes (`openspec/specs/dashboard/spec.md:9-171`; `docs/07-dashboard.md`) | `/` and “Anpassen” sheet | `dashboard_entity.dart:76-121`; `dashboard_page.dart:103-173`; `dashboard_repository.dart:33-95` | SQLite dashboard config stores order/visibility/links | User can reorder/toggle and refresh cards | Partial | IDs exist for 13 widgets, but no size is persisted; quick links include `/inventory`; config failures silently fall back and writes are fire-and-forget. |
| Dashboard cards lead to a real capability; unavailable inventory is truthful or hidden (`openspec/specs/dashboard-and-setup-workflows/spec.md:8-44`) | `/` inventory cards and `/inventory` | `dashboard_page.dart:176-219`; `InventoryUnavailablePage`; `lib/features/inventory/lager_repository.dart` | Inventory backend persists data, but no page path | Inventory cards and quick link display “Noch nicht verfügbar”/disabled | Partial | The unavailable state is truthful, but the documented capability remains in the default dashboard and has no usable route. A disabled promise is not completion. |
| First-class scalable tables: sticky header, sort, resize, search/filter, multiselect/bulk, keyboard, context menus, empty/hover/selected, column preferences, virtualized rows (`DESIGN.md:572-625`) | `/invoices`, `/receipts`, `/contacts`, `/taxes`, `/reports` | `lib/core/router/route_data_repository.dart:25-83`; `lib/design_system/components/finance_list_surface.dart:177-412` | Raw allowed-table records are queried with a fixed list limit | Generic column-like rows and count are shown | Missing | `FinanceListSurface` materializes rows in a `Column`. It has local client-side substring filtering, but no sort/selection/bulk/context menu/column chooser/pagination/virtualization. |
| Direct search/filter and global Ctrl/Cmd+K search (`DESIGN.md:629-683`) | Page headers and intended command palette | `AppPageHeader` has toolbar slots; `FinanceListSurface` uses `_searchController` and `_filteredRows`; `RouteDataRepository` has no search query API | Local filtering only; no separate search state is persisted | Generic routes expose local in-memory search, but no global/server-side search | Partial | The local search field and filtering are production code. `RouteDataRepository` exposes count/list/find only, and no production global search caller or query/sort/pagination surface was found. |
| Optional 360-440px inspector for contextual details (`DESIGN.md:687-719`) | Intended list-to-detail inspector | `lib/design_system/components/app_inspector.dart:8-239` | None | Component can trap focus and close on Escape in isolation | Missing | No production route caller was found; the component exists only as an unexposed seam. |
| Invoice split editor/live preview, narrow tabs, validation, PDF/ZUGFeRD/XRechnung choices and missing-data errors (`DESIGN.md:723-786`; `docs/01-rechnungen.md`) | `/invoices/new`; `/invoices/:id` | `app_router.dart:267-544`; `lib/pages/rechnungen/invoice_document_page.dart:24-405`; `pdf_generator.dart` | Invoice records are persisted by page services | One-position draft and simple invoice paper/preview are visible | Partial | The route is real, but there is no split editor, multi-position/article workflow, document-type selection, terms/discounts, e-invoice validation, or missing-data flow. |
| Invoice lifecycle, seven document types, conversion, payment state, and article/stock links (`docs/01-rechnungen.md:1-234`; `docs/06-dokumente.md`) | Invoice routes only | Invoice page and invoice repositories; inventory and receivable services are separate | Invoice state is persisted | Finalize and save-PDF actions exist | Partial | The visible route handles a small invoice subset; Storno/Gutschrift/Ersatzrechnung, payment allocation, copy/watermark, stock, and conversion controls are not exposed. |
| Dedicated PDF artifact actions: preview/open/save as/print with safe recovery (`openspec/specs/document-artifact-actions/spec.md:8-33`; `openspec/specs/desktop-pdf-viewer/spec.md:9-35`) | Invoice detail and document workflows | `invoice_document_page.dart:58-90,261-289`; `lib/features/desktop/pdf_viewer_service.dart:28-88` | PDF files are saved by explicit path | Inline modal preview and Save PDF are visible | Partial | `PdfViewerService` has no production caller; the route uses a modal preview and VM print is unsupported. |
| Receipts are a first-class inbox with import/watch-folder/drag/drop PDF, PNG, JPG, e-invoice and New/Review/Assigned/Booked/Error states (`DESIGN.md:790-829`) | `/receipts`, `/receipts/:id` | `app_router.dart:561-574`; `route_data_repository.dart` reads `belege`; `main.dart:91-99` registers drop unavailable | A `belege` table exists, but no reachable ingestion path was found | Generic `belege` record list/detail only; file drop explicitly reports unavailable | Missing | The route is generic and file-drop registration is `UnavailableDesktopCapability`; no inbox panes, state actions, watch folder, or drop handler reaches receipt persistence. |
| Bank workspace with import, search/filter, suggestion vs confirmed, and no silent low-confidence confirmation (`DESIGN.md:833-865`; `docs/04-bank-import.md`) | `/banking` | `lib/features/bank_import/bank_import_page.dart`; `bank_import_service.dart`; Drift bank tables | Imports, failures, and history persist | Three-stage path/file/paste → review → result and history exist | Partial | Import and retry services are real, but the UI lacks match confidence, suggestion/confirmation controls, rule management, broad templates, and actionable history. |
| Bank recovery surface: failure detail, retry, filter, pagination, history actions (`openspec/specs/bank-import-recovery-surface/spec.md`) | `/banking` result/history | `bank_import_page.dart:1001-1188` | Failure rows/history persisted | Result lists failures and retry; history is a static table | Partial | History rows have no selection/actions/detail/filter/pagination. The recovery contract is not met. |
| Receipt payment reconciliation, partial/full allocation, overpayment, and audit trail (`openspec/specs/receipts-and-payment-reconciliation/spec.md:8-42`; `docs/06-dokumente.md`) | Banking/receipts/invoice detail | Bank import links to journal; `lib/features/einkommen/forderungen_repository.dart` contains backend seams | Journal and receivable tables exist | No user-visible allocation or overpayment action found | Missing | The implementation can persist a journal link, but no route exposes receivable allocation or the required audit states. |
| Tax overview with period/status/due/completeness/export/submission vocabulary, never implying filed (`DESIGN.md:869-921`) | `/taxes` | `app_router.dart:608-620` generic `ustva_exporte`; accounting tax services | UStVA export rows and accounting data persist | Generic `ustva_exporte` list only | Missing | There is no period workspace, completeness check, export/submission state, or explicit “not filed” boundary. |
| Status vocabulary distinguishes draft/open/overdue/paid, receipt review states, tax calculation/submission, and uncertainty (`DESIGN.md:1547-1582`) | Status chips and route states | `AppStatusChip`; raw `status` fields in generic rows and bank history | Source status values persist | Some chips render raw status labels | Partial | A semantic chip component exists, but generic surfaces pass database literals and no typed status model covers receipt/tax uncertainty. |
| Reporting: EÜR, UStVA, EKS, GuV, ZM, DATEV/GoBD export (`docs/02-buchhaltung.md`; `DESIGN.md:869-921`) | `/reports` and `/taxes` | `lib/features/accounting/*` services and `route_data_repository.dart` | Accounting records/export artifacts exist | Generic `journal` list only | Missing | Backend capabilities are not exposed as typed report routes, forms, previews, exports, or status outcomes. |
| Contacts, vendors, articles, company, bank accounts, categories, and number sequences (`docs/03-kunden-stammdaten.md`; `docs/08-einstellungen.md`) | `/contacts`, `/contacts/new`; no vendor/article/company routes | `lib/pages/stammdaten/*` repositories; `ContactCreatePage` | Master-data records persist | Customer list/create is partially reachable | Partial | Customers have a generic list and create form; vendor/article/company/bank account/category/number-sequence workflows are not reachable. |
| Inventory capability and stock warnings (`docs/01-rechnungen.md`; `docs/07-dashboard.md`) | `/inventory` | `lib/features/inventory/lager_repository.dart` | Inventory backend exists | Unavailable page only | Missing | The route intentionally exposes no capability; dashboard links are disabled. |
| Dunning levels, fees/interest, blocks, PDF/mail progression (`docs/05-mahnwesen.md`) | No dunning route found | `lib/features/mahnwesen/*` services/repositories | Dunning-related backend seams exist | No dunning list/detail/settings outcome | Missing | No production navigation or action reaches the documented dunning workflow. |
| Setup should welcome, collect business profile/tax/invoicing/data-protection/backup, and finish durably (`DESIGN.md:1889-1938`; `docs/08-einstellungen.md`; `openspec/specs/setup-onboarding-integrity/spec.md`) | `/setup` | `lib/features/setup/wizard_page.dart:19-394`; router redirect | Company/profile records and setup sentinel persist | Four-step German wizard: master data, accounts, categories, finish; skip exists | Partial | The wizard is reachable and writes basic data, but lacks welcome, tax/currency, invoice sequence/terms, privacy/backup, explicit durable completion semantics, and a recovery surface. |
| Settings architecture: general/company/taxes/invoices/bank/integrations/data/privacy/backup/appearance/language/advanced/about (`DESIGN.md:925-1005`; `openspec/specs/localization-settings-and-data-protection/spec.md:8-42`) | `/settings` | `app_router.dart:640-832`; `AppLocale`, theme, privacy, `ProfileManager` | Locale/theme/privacy/profile preferences persist | Locale, theme, privacy mask, profiles, local-data card | Missing | The visible settings page has only a small subset; no backup, storage path, export/delete, network scope, integrations, accounting, invoice, bank, advanced, or about controls. |
| Privacy mode hides values/balances while preserving identity (`DESIGN.md:1009-1033`) | `/settings` switch; dashboard cards | `PrivacyModeProvider`; dashboard `MoneyText(obscured: ...)` | Privacy preference persists | Dashboard financial values can be masked | Partial | Masking is applied in dashboard paths but not generic finance rows, invoice detail, or bank import values. |
| Backup status never/current/stale/failed, local WAL-safe backup, encrypted external/SMB, restore and schedule (`DESIGN.md:1037-1068`; `docs/08-einstellungen.md:149-210`; `openspec/specs/backup/spec.md`) | Intended data/privacy/backup settings | `lib/core/db/backup_service.dart`; no production UI caller found | Backup files, schedule, restore logic exist in service | No reachable backup status/control | Missing | Service breadth is not user-facing capability; settings has no backup route, status, restore, target, or failure recovery. |
| Opt-in integrations show provider/status/scope/last success/error/disconnect (`DESIGN.md:1072-1105`; `docs/08-einstellungen.md:212-285`) | Intended settings integrations section | No reachable integration settings surface found | No visible integration connection state | No integration controls | Missing | SMTP/cert/mail backend references do not establish a production route or status model. |
| German accounting concepts and e-invoices are first-class, with a clear filed/not-filed boundary (`DESIGN.md:1586-1618`) | Invoice, tax, report, and receipt routes | Invoice/PDF/accounting service seams; generic route fallback | Accounting records persist | Basic German labels and invoice PDF exist | Partial | The German terminology is visible, but e-invoice, tax submission boundary, and accounting-specific document actions are not exposed. |
| Forms have labels, required/validation, destructive confirmation, draft autosave, explicit final action (`DESIGN.md:1224-1255`) | Setup, invoice, bank import, contact forms | Individual widgets and page-local callbacks | Some page records save; no uniform drafts | Basic fields/dialogs are visible | Partial | Invoice/setup forms lack the documented breadth and autosave; destructive and final actions are inconsistent across generic routes. |
| Dialogs, snackbars, inline and persistent warnings explain what happened and next action (`DESIGN.md:1259-1327`, `1942-1979`) | Route pages and error states | Page-local `showDialog`, `ErrorState`, debug logs; `AppDialog` component | Errors generally do not become durable task state | Some errors show retry/error text | Partial | Generic route errors and loading states exist, but the reusable `AppDialog` has no production caller, raw dialogs use hardcoded text/default destructive labels, and swallowed preference/config errors leave gaps. |
| Loading continuity, determinate imports, background tasks, no whole-app block (`DESIGN.md:1330-1375`) | Dashboard/detail/import surfaces | Skeletons and import state in pages | Import history/failures persist | Import has staged progress; dashboard/detail use generic spinners/skeletons | Partial | Bank import is the strongest path. Generic details use an unbounded spinner and several async preference writes are unobserved. |
| Charts include exact values, keyboard/text summary, locale and light/dark support (`DESIGN.md:1379-1407`) | Dashboard/reporting | No production chart widget or report route found | No chart configuration | No revenue/EÜR/GuV chart outcome | Missing | Dashboard repository returns counts/text; documented chart/report surfaces are absent. |
| Drag/drop, file association, PDF viewer and tray commands are registered production capabilities (`openspec/specs/desktop-capability-availability/spec.md`; `openspec/specs/desktop/spec.md`) | Desktop bootstrap and receipts/PDF flows | `main.dart:91-99`; desktop capability registry; helper services | Files are only persisted when a workflow calls them | Tray is registered; drop/file association explicitly unavailable; PDF helper uncalled | Partial | One desktop capability (tray) is wired. The documented import/PDF capabilities are not. |
| Future multi-company selector (`DESIGN.md:1528-1543`) | No selector route; profile popup is local profile switching | `ProfileManager` and settings profiles | Profiles persist | Profile switch requires restart; no company selector | Missing | This is explicitly future in the design, so it is a roadmap gap rather than a current-MVP defect. It remains in the full vision record. |

## Separate backlog: ideas without a current documented commitment

These are plausible product directions found as implementation seams or common accounting
product ideas, but they are not counted as failures of the current binding. They need a product
decision and a source document before becoming audit commitments:

- OCR/AI extraction and confidence review for receipt images.
- Online bank connections (FinTS/PSD2), scheduled polling, and provider health monitoring.
- Cloud sync, multi-user collaboration, invitations, and conflict resolution.
- Mobile/web clients and remote access.
- Marketplace/plugin integrations beyond the documented opt-in settings model.
- Automated tax filing or submission transport beyond the documented export/status boundary.
- Full recurring-invoice scheduling and notification automation where no active vision row defines
  its route and lifecycle.

The presence of a repository or service for one of these ideas does not promote it to a product
commitment. Conversely, a future item in `DESIGN.md` is labelled future above rather than silently
treated as complete.

## Source-heading provenance for the 43 grouped rows

The 43 data rows above are numbered in table order as `M01` through `M43` (`M01` is the first
source commitment row and `M43` the last). This map records the source-heading coverage that
supports the matrix's complete-vision claim; it does not turn a grouped row into a claim that its
runtime behavior is complete.

| Source heading or maintained document | Matrix rows | Ownership boundary |
|---|---|---|
| `DESIGN.md:3-8` local-first product, primary/secondary locales, Material 3 | M01 | B vision coverage; source/runtime limits remain in the row. |
| `DESIGN.md:12-85` calm language and progressive disclosure | M02 | B vision coverage. |
| `DESIGN.md:87-110` desktop shell input and capabilities | M03 | B vision coverage; C owns native/bootstrap evidence. |
| `DESIGN.md:119-228` shell breakpoints and three-area layout | M04 | B vision coverage. |
| `DESIGN.md:310-430` theme, semantic colors, and component states | M06 | B vision coverage; C owns shared gate evidence. |
| `DESIGN.md:434-481` typography and locale-aware formatting | M08 | B vision/localization coverage. |
| `DESIGN.md:524-568` dashboard business status and attention | M13 | B vision coverage. |
| `DESIGN.md:572-625` scalable tables | M16 | B vision coverage. |
| `DESIGN.md:629-683` local/global search | M17 | B vision coverage; local client filtering is acknowledged above. |
| `DESIGN.md:687-719` contextual inspector | M18 | B vision coverage. |
| `DESIGN.md:723-786` invoice editor and lifecycle | M19, M20 | B route coverage; A owns accounting side effects. |
| `DESIGN.md:790-829` receipt inbox and ingestion | M22 | B route coverage; C owns desktop adapter evidence. |
| `DESIGN.md:833-865` bank workspace | M23 | B route coverage; A owns reconciliation invariants. |
| `DESIGN.md:869-921` tax/reporting workspace and export vocabulary | M26, M28 | B route coverage; A owns accounting/report evidence. |
| `DESIGN.md:925-1005` settings architecture | M33 | B route coverage; A owns backup/profile behavior. |
| `DESIGN.md:1009-1033` privacy mode | M34 | B vision/UI coverage. |
| `DESIGN.md:1037-1068` backup status and restore | M35 | B surface coverage; A owns persistence evidence. |
| `DESIGN.md:1072-1105` integrations | M36 | B surface coverage. |
| `DESIGN.md:1108-1183` German/English localization and live switch | M10 | Approved scope; stale German-only spec is a parity repair. |
| `DESIGN.md:1187-1220` shortcuts and command palette | M12 | B vision coverage; C owns bootstrap evidence. |
| `DESIGN.md:1224-1255` form contracts | M38 | B vision coverage. |
| `DESIGN.md:1259-1327, 1942-1979` dialogs, warnings, and recovery | M39 | B vision coverage. |
| `DESIGN.md:1330-1375` loading continuity and background work | M40 | B vision coverage; C owns shared runtime gate. |
| `DESIGN.md:1379-1407` charts and accessible summaries | M41 | B vision coverage. |
| `DESIGN.md:1410-1445` icons, motion, reduced motion | M09 | B vision coverage. |
| `DESIGN.md:1448-1470` focus, keyboard, semantics, scaling | M11 | B vision coverage. |
| `DESIGN.md:1501-1524` window geometry | M05 | B vision coverage; C owns native lifecycle evidence. |
| `DESIGN.md:1528-1543` future multi-company selector | M43 | Retained as explicitly future vision. |
| `DESIGN.md:1547-1582` status and uncertainty vocabulary | M27 | B vision coverage. |
| `DESIGN.md:1586-1618` German accounting concepts and e-invoices | M37 | B route coverage; A owns accounting semantics. |
| `DESIGN.md:1658-1885` reusable components and tokens | M07 | B component coverage. |
| `DESIGN.md:1889-1938` setup/onboarding | M32 | B route coverage; A owns persisted setup effects. |
| `DESIGN.md:1621-1657` §39 Local-First Trust Indicators | M01, M28, M33, M35, M36 | Trust/status placement crosses local startup, export, settings, backup, and integrations; the row records the reachable boundary. |
| `DESIGN.md:1658-1709` §40 Suggested Flutter Design-System Structure | M07, M42 | Structural guidance only; C owns generated/native provenance and B owns visible component exposure. |
| `DESIGN.md:1710-1786` §41 Core Reusable Components | M07, M16-M18, M21, M39 | Component contracts are grouped here; isolated components are not counted as route exposure. |
| `DESIGN.md:1787-1818` §42 Design Tokens in Dart | M07 | Token source is covered as a component/design-system commitment. |
| `DESIGN.md:1819-1846` §43 Theme Extension for Accounting Semantics | M06, M27, M37 | Theme semantics and accounting/status vocabulary remain separate runtime checks. |
| `DESIGN.md:1847-1888` §44 Interaction States | M07, M11, M16, M38-M40 | Cross-cutting focus, selection, validation, and feedback requirements remain in the affected grouped rows. |
| `DESIGN.md:1889-1941` §45 Recommended First-Run Experience | M32, M33, M35 | Setup, settings, privacy, and backup expectations are preserved in full. |
| `DESIGN.md:1942-1982` §46 Error Design | M39, M40 | Error wording, affected-data disclosure, and actionable recovery are B state-surface evidence. |
| `DESIGN.md:1983-2040` §47 Design QA Checklist | M01-M43 | Cross-cutting checklist; it is a review aid and does not add an untracked commitment. |
| `DESIGN.md:2041-2066` §48 Recommended MVP Visual Scope | M04, M06-M07, M10-M13, M16-M19, M22-M23, M26, M32-M33, M41-M42 | Recommended implementation order only; the full documented vision remains in scope and this section is not a scope cut. |
| `DESIGN.md:2067-2084` §49 Final Design Summary | M01-M43 | Summary language is mapped to the detailed rows above; it is not treated as separate runtime proof. |
| `DESIGN.md:2085-2110` §50 References | No matrix row; references only | External design references provide context and are not product behavior evidence. |
| `docs/01-rechnungen.md` | M19, M20, M30 | B documents the vision; A owns invoice effects. |
| `docs/02-buchhaltung.md` | M28 | B route coverage; A owns accounting source/evidence. |
| `docs/03-kunden-stammdaten.md` | M29 | B route coverage. |
| `docs/04-bank-import.md` | M23 | B route coverage; A owns import/reconciliation behavior. |
| `docs/05-mahnwesen.md` | M31 | B route coverage; A owns dunning policy/effects. |
| `docs/06-dokumente.md` | M20, M25 | B route coverage; A owns document/payment effects. |
| `docs/07-dashboard.md` | M13, M14, M15, M30 | B dashboard coverage. |
| `docs/08-einstellungen.md` | M29, M32, M33, M35, M36 | B settings coverage; A owns profile/backup persistence. |
| B-referenced maintained OpenSpec rows (`typed-route-workspaces`, `localized-accessible-surface`, `dashboard*`, `desktop-drag-drop`, `document-artifact-*`, `desktop-pdf-viewer`, `bank-import-recovery-surface`, `receipts-and-payment-reconciliation`, `setup-onboarding-integrity`, `localization-settings-and-data-protection`, `backup`, `desktop-capability-availability`, `desktop`) | M01, M03, M10, M13-M15, M18, M21-M25, M32-M35, M42 | These references support B's documented expectations. The C manifest remains the per-file owner for maintained spec provenance; A's accounting source matrix remains authoritative for legal-sensitive behavior. |
| Remaining maintained specs and files not cited by B rows | Delegated through `test/integration/audit/architecture-delivery-coverage.tsv` | A/C ownership is preserved; B makes no completeness claim for their runtime implementation. |

## Approved localization scope and technical specification reconciliation

The approved scope for this audit is German and English, with German primary and English secondary.
`DESIGN.md:1108-1183`, `openspec/specs/localized-accessible-surface/spec.md:8-25`, and
`openspec/specs/app-theme/spec.md:37-54` require German and English localization with a live
language switch. `openspec/specs/app/spec.md:90-125` still says all user-facing text is German
and informal `Du`; that stale requirement is a specification-parity repair item. It does not reopen
the approved locale decision or make the localization row blocked. The current English route remains
partial until visible strings and active-locale formatting are completed.
