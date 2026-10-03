## Context

The feature map requires optional inventory, historical movements, a physical inventory for a selected reporting date, and a result list with quantities and values (`pasted-text-1.txt:167-185`). At HEAD, `/inventory` builds `InventoryUnavailablePage` (`lib/core/router/app_router.dart:166,1273-1297`); `AppServices` does not expose an inventory service (`lib/core/app_services.dart:21-45`). Inventory repositories can read current warnings and movements and write manual stock adjustments, but those writes update `artikel.bestand_aktuell`/`bestand` and append `inventarbewegungen` (`lib/pages/stammdaten/artikel_repository.dart:326-417`; `lib/features/inventory/lager_repository.dart:39-75,84-126`). The movement rows do not establish a verified opening balance or complete historical coverage. An article price field therefore cannot be assumed to provide a historical inventory value.

The main `inventory` spec describes current stock, movements, warnings, invoice depletion/reversal, and manual adjustment, but no stocktake or valuation. Its movement-storage requirement names exactly one movement table. The `db` spec requires feature migrations to declare every table and its constraints. The active `master-data-workspaces-and-crud` proposal covers article workspaces, not stocktakes. The active `localized-accessible-surface-completion` change expects an unavailable/read-only/retry fixture for `/inventory`; retain that boundary for disabled or unavailable inventory while adding an enabled stocktake fixture. The active `dunning-workflow-integrity` route contract already includes `/inventory` and remains compatible with a typed service-backed page.

`DESIGN.md` requires desktop keyboard and pointer use (`56-70`), localizable strings and locale-aware dates/numbers (`1108-1144`), visible focus and screen-reader-compatible controls (`1448-1463`), and German-first/English-supported localization (`2004-2011`).

## Goals / Non-Goals

**Goals:**

- Let users create, enter, record, and review profile-local stocktake counts for a selected reporting date.
- Preserve enough article identity and unit context to make a recorded count understandable after later article edits.
- Keep count recording atomic and side-effect free with respect to live stock, movement history, journals, taxes, and documents.
- Display measured quantities and make unavailable historical book quantities and valuation explicit.
- Keep the workspace usable with keyboard, screen reader, resizable desktop layouts, and German/English catalogs.

**Non-Goals:**

- Choosing a valuation basis, cost source, tax/discount treatment, rounding policy, or journal-posting behavior.
- Automatically adjusting `bestand_aktuell`, writing `inventarbewegungen`, or posting accounting entries when a count is recorded.
- Claiming an as-of-date book quantity or count variance from current stock or movement rows without a verified opening baseline and complete movement coverage.
- Changing invoice stock depletion, Storno restoration, article CRUD, or general manual stock adjustment behavior.

## Decisions

### Keep `/inventory` in the existing typed service graph

Replace the placeholder route with the stocktake workspace only when `lagerführung_aktiv` is enabled. Register an inventory use case/repository through `AppServices`; keep SQL and transaction handling below the UI. When inventory is globally disabled, the profile database is unavailable, or required stocktake data cannot be read, show a localized unavailable/retry boundary and perform no writes. The enabled page uses the established shell and a dense searchable/sortable table, with explicit loading, empty, data, and error states.

The enabled stocktake fixture must be added to the active localization route coverage while preserving its disabled/unavailable/read-only/retry case. This keeps the currently specified boundary meaningful without treating it as the only `/inventory` state.

### Store count snapshots separately from movement history

Use a versioned migration for two named tables, `inventuren` and `inventur_positionen`. The header stores the selected reporting date, lifecycle status, and creation timestamp. A line stores a stable article ID, description and unit snapshots, and a nullable counted quantity while the session is a draft. The line has a unique `(inventur_id, artikel_id)` pair; `menge_gezaehlt` supports the existing three-decimal stock precision and permits zero. A recorded session requires an explicit quantity for every snapshotted tracked article; null never means zero. Keep the article ID as a historical identifier rather than a foreign key so later article edits or removal do not rewrite the evidence.

Creating a draft snapshots the currently inventory-enabled article set. Draft counts are editable; recording validates all quantities and freezes the session atomically. Corrections use a new session so the prior recorded result remains traceable. The report labels the user-selected reporting date separately from the system capture timestamp and labels its amounts as counted quantities.

Using `inventarbewegungen` for count rows was rejected because a count snapshot is not a stock movement and would blur the input used by invoice Storno restoration. Updating live stock on record was rejected because it would silently choose reconciliation and posting behavior that has not been specified.

### Fail closed for book quantities and valuation

Do not derive historical book stock or variance in this change. `bestand_aktuell` represents current stock, and existing movement rows do not prove a complete starting balance. Until a separate data contract establishes an opening baseline and history coverage, the stocktake result contains only measured quantities and makes book quantity/variance unavailable.

No valuation amount or total is produced, stored, exported, or posted while valuation policy is unspecified or required inputs are unavailable. The page presents a localized explanation; it does not substitute a sales price, an article price field, or zero for an unknown value. Count capture remains usable. This change does not create valuation or journal tables.

### Preserve desktop accessibility and localization

Use keyboard traversal and activation for table rows and count cells, visible focus, semantic labels that include article and unit, and text that remains readable when scaled or at narrow widths. Localize every action, validation/error, empty, status, and valuation-unavailable message in the German and English catalogs. Format the reporting date and counted quantities with the active locale; locale must not affect stored quantities or date semantics.

## Risks / Trade-offs

- **[Risk]** Users may read a counted quantity as a verified book quantity or assume a missing value is zero. → **Mitigation:** label count quantities and capture time, omit book quantity/variance until coverage is established, and render valuation as an explicit unavailable state.
- **[Risk]** A report date predating article catalog changes can be mistaken for a reconstruction of the historical article set. → **Mitigation:** snapshot article identifiers, descriptions, and units at count creation, show the capture timestamp, and do not claim historical book balances.
- **[Risk]** The active localization change only tests `/inventory` unavailable states. → **Mitigation:** keep that state for disabled/unavailable cases and update route coverage to include an enabled stocktake data state before implementation is considered complete.
- **[Risk]** Recording a count changes stock or causes a posting through a reused adjustment path. → **Mitigation:** commit only stocktake header/line data; do not call adjustment APIs from the count workflow.

## Migration Plan

1. Add one ordered, backed-up SQLite migration that creates only `inventuren` and `inventur_positionen` with the declared constraints. Do not rewrite current stock, movement rows, or article prices. A migration failure must leave the schema version and prior data unchanged.
2. Add typed inventory service wiring and the `/inventory` count workspace. Create and record count snapshots transactionally; retain records when the route is later disabled.
3. Add localized German/English labels and accessible keyboard, focus, and semantic behavior; retain unavailable/retry states for disabled inventory or data-service failure.
4. Keep book-quantity reconciliation and monetary valuation unavailable until the open policy/data questions are separately resolved and specified. Rollback may hide the workspace but must not delete recorded stocktakes or alter live inventory.

## Open Questions

1. **Valuation policy:** Which cost basis and source records determine per-article value on the selected date? How do acquisition dates, discounts, freight, recoverable/non-recoverable tax, currencies, missing costs, and rounding affect that value? Is valuation output informational only, or does an approved workflow require accounting postings? No value or posting is implemented until these are answered.
2. **Historical book quantity coverage:** What opening-balance record and completeness marker establish that all inventory movements through a reporting date are present, including legacy stock and pre-existing rows? Until specified, no historical book quantity or count variance is shown.
3. **Stock reconciliation:** Should a recorded count ever change current stock, and if so, should that happen through an explicit manual adjustment, a distinct reconciliation action, or an accounting workflow? This proposal leaves count recording side-effect free.
