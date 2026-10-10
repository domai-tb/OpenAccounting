# Light Inventory Management

## Purpose
Per-article inventory activation, stock tracking, movement logging, and low-stock warnings.

## Requirements

### Requirement: Per-article inventory activation

Each article SHALL have a `lager_aktiv` boolean flag (default `false`). Normally, only articles with `lager_aktiv = true` SHALL participate in stock tracking. During outgoing invoice finalization and Storno only, the legacy predicate `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0` SHALL be treated as tracked stock: finalization SHALL use the legacy `bestand`, update both stock columns, and enable tracking; Storno SHALL restore recorded source movements to both columns and enable tracking. A disabled article outside that exact legacy predicate SHALL ignore all stock-related operations.

#### Scenario: Article with inventory disabled

GIVEN an article has `lager_aktiv = false` and both `bestand_aktuell` and `bestand` are zero
WHEN an outgoing invoice containing that article is finalized
THEN no stock change SHALL occur for that article.

#### Scenario: Article with inventory enabled

GIVEN an article has `lager_aktiv = true` with `bestand_aktuell = 50` and `mindestbestand = 10`
WHEN an outgoing sales invoice containing 3 units of that article is finalized
THEN `bestand_aktuell` SHALL decrease to 47.

### Requirement: Stock fields on articles

The `artikel` table SHALL include: `bestand_aktuell` (NUMERIC(10,3), default 0), `mindestbestand` (NUMERIC(10,3), default 0), `minusbestand_erlaubt` (BOOLEAN, default `false`). Stock values SHALL support fractional quantities (e.g., 2.5 kg). The system SHALL NOT decrement stock below 0 unless `minusbestand_erlaubt = true`.

#### Scenario: Stock decrement blocked at zero

GIVEN an article has `bestand_aktuell = 2` and `minusbestand_erlaubt = false`
WHEN an invoice for 5 units is finalized
THEN the system SHALL prevent finalization AND display a stock warning
AND `bestand_aktuell` SHALL remain 2.

#### Scenario: Stock decrement allowed below zero

GIVEN an article has `bestand_aktuell = 2` and `minusbestand_erlaubt = true`
WHEN an invoice for 5 units is finalized
THEN `bestand_aktuell` SHALL decrease to -3
AND no stock warning SHALL block finalization.

#### Scenario: Fractional stock quantities

GIVEN an article has `bestand_aktuell = 10.5` and `lager_aktiv = true`
WHEN an invoice for 2.5 units is finalized
THEN `bestand_aktuell` SHALL decrease to 8.0.

### Requirement: Stock decrement on invoice finalization

When an outgoing sales invoice is finalized, the system SHALL aggregate its line quantities by article where inventory tracking is enabled and decrement `bestand_aktuell` once by each combined quantity. Combined quantities SHALL be validated against the starting stock before any deduction; if a combined quantity would cause negative stock and `minusbestand_erlaubt` is false, the transaction SHALL make no stock change and finalization SHALL fail. Incoming invoices and other document types SHALL NOT run sales-stock validation or change stock. The legacy compatibility predicate is exactly `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0`; for those rows, finalization SHALL use `bestand`, update both stock columns, and set `lager_aktiv = true`.

#### Scenario: Multiple line items

GIVEN an outgoing invoice contains 3 line items: Article A (qty=10, lager_aktiv=true), Article B (qty=5, lager_aktiv=false, bestand=0, bestand_aktuell=0), Article C (qty=3, lager_aktiv=true)
WHEN the invoice is finalized
THEN Article A `bestand_aktuell` SHALL decrease by 10
AND Article B SHALL NOT be affected
AND Article C `bestand_aktuell` SHALL decrease by 3.

#### Scenario: No stock fields on non-inventory articles

GIVEN an article has `lager_aktiv = false` and both stock columns are zero
WHEN an outgoing invoice with that article is finalized
THEN `bestand_aktuell` and `mindestbestand` SHALL be ignored by the system.

#### Scenario: Partial stock decrement on finalization failure

GIVEN an outgoing invoice contains Article A (qty=10, lager_aktiv=true) and Article B (qty=5, lager_aktiv=true, `bestand_aktuell=2`, `minusbestand_erlaubt=false`)
WHEN invoice finalization is attempted
THEN the system SHALL NOT decrement stock for either article
AND SHALL display a stock warning for Article B.

#### Scenario: Incoming invoice does not decrement sales stock

GIVEN an incoming invoice contains an article with `lager_aktiv = true` and stock 20
WHEN the invoice is finalized
THEN stock remains 20 and no negative invoice movement is recorded.

#### Scenario: Repeated article quantities are combined

GIVEN an outgoing invoice has two inventory-enabled lines for the same article, quantities 3 and 4, with current stock 20
WHEN the invoice is finalized
THEN stock decreases exactly once by 7 to 13
AND one negative inventory movement records -7.

#### Scenario: Repeated quantities cannot exceed disallowed stock

GIVEN an outgoing invoice has two inventory-enabled lines for the same article, quantities 3 and 3, with current stock 5 and negative stock disallowed
WHEN the invoice is finalized
THEN finalization fails before deduction
AND stock remains 5 with no movement for either line.

#### Scenario: Legacy stock is migrated by first outgoing movement

GIVEN an article has `lager_aktiv=false`, `bestand_aktuell=0`, and legacy `bestand=20`
WHEN an outgoing invoice for 3 units is finalized
THEN both stock columns become 17, `lager_aktiv` becomes true, and one -3 movement is recorded.

#### Scenario: Repeated legacy quantity finalizes and reverses exactly

GIVEN a legacy article has `lager_aktiv=false`, `bestand_aktuell=0`, and `bestand=20`, and the outgoing invoice has two lines for that article with quantities 3 and 4
WHEN the invoice is finalized and then storniert
THEN finalization sets both stock columns to 13, enables tracking, and records one -7 movement
AND Storno restores both stock columns to 20 and records one +7 movement.

#### Scenario: Disabled stock is not mistaken for legacy stock

GIVEN an article has `lager_aktiv=false`, `bestand_aktuell=0`, and `bestand=0`
WHEN an outgoing invoice line exceeds current stock
THEN finalization is not blocked by that article and neither stock column nor movement log changes.

### Requirement: Stock restore on storno

When a document is storniert, the system SHALL sum only negative inventory movements recorded for its source using `referenz_typ = 'rechnung'` and the source document ID, grouped by article. It SHALL restore those quantities atomically as one positive movement per eligible article. Articles with `lager_aktiv = true` are eligible; rows matching the legacy predicate `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0` are also eligible and SHALL be restored in both stock columns with tracking enabled. A disabled non-legacy article SHALL remain unchanged even if an old source movement exists. A source with no negative movement SHALL not increase stock.

#### Scenario: Storno restores stock

GIVEN the source invoice has one negative movement of 10 for Article A and current stock is 47
WHEN the source invoice is storniert
THEN Article A `bestand_aktuell` SHALL increase by 10 to 57
AND one positive movement of 10 SHALL reference the Storno document.

#### Scenario: Storno of already-reduced stock

GIVEN the source invoice recorded a negative movement of 10 and the article's stock was manually adjusted downward since finalization
WHEN the source invoice is storniert
THEN the storno SHALL still add back the recorded quantity of 10 without comparing stock to a prior snapshot.

#### Scenario: Storno without a source stock movement

GIVEN a finalized offer or incoming invoice has an inventory-enabled article but no negative source movement
WHEN the document is storniert
THEN stock remains unchanged and no positive Storno movement is recorded.

#### Scenario: Storno of invoice with non-inventory articles

GIVEN a source invoice has a negative movement for Article A but none for Article B, whose inventory tracking is disabled
WHEN the source invoice is storniert
THEN Article A stock SHALL be restored by its recorded quantity
AND Article B SHALL NOT be affected.

#### Scenario: Storno restores only negative movements for its source

GIVEN movements for one source article have diffs -2.000 and -3.500, plus +7.000, and other rows have -4.000 for another invoice or another reference type
WHEN that source invoice is storniert
THEN the system SHALL restore 5.500 for that article once
AND SHALL NOT restore the positive or unrelated rows.

#### Scenario: Storno restores legacy stock and preserves disabled stock

GIVEN Article A matches the legacy predicate with `bestand=17`, while Article B has tracking disabled and both stock columns zero despite a historical source movement
WHEN the source invoice is storniert
THEN Article A's two stock columns increase by the recorded quantity and its tracking is enabled
AND Article B's stock columns, flag, and movement log remain unchanged.

#### Scenario: Storno late failure rolls back restoration

GIVEN an outgoing invoice has a recorded negative movement and article stock is 17 after deduction
WHEN reversal posting fails after the Storno movement is inserted
THEN source stock remains 17, the source invoice remains unstorniert, and no Storno document, counter increment, positive movement, reversal journal, payable, or tax row remains
AND retry restores stock exactly once.

### Requirement: Dashboard stock warning widget

The dashboard SHALL include a "Lagerwarnung" widget that displays all articles where `lager_aktiv = true` AND `bestand_aktuell <= mindestbestand`. The widget SHALL show article name, current stock, and minimum stock. If no articles meet the warning criteria, the widget SHALL display "Keine Warnungen".

#### Scenario: Low stock warning displayed

GIVEN Article X has `lager_aktiv=true`, `bestand_aktuell=3`, `mindestbestand=10`
WHEN the dashboard loads
THEN the Lagerwarnung widget SHALL display Article X with "3 / 10".

#### Scenario: No warnings

GIVEN all inventory articles have `bestand_aktuell > mindestbestand`
WHEN the dashboard loads
THEN the Lagerwarnung widget SHALL display "Keine Warnungen".

#### Scenario: Article at exactly minimum stock

GIVEN an article has `lager_aktiv=true` and `bestand_aktuell = mindestbestand`
WHEN the dashboard loads
THEN the Lagerwarnung widget SHALL display that article as a warning.

### Requirement: Stock warning in invoice form

When creating or editing an invoice, the system SHALL display a warning indicator on line items where the article has `lager_aktiv = true` AND the line item quantity exceeds `bestand_aktuell`. The warning SHALL be visible per line item and SHALL NOT block saving (only finalization). Finalization SHALL be blocked unless `minusbestand_erlaubt = true`.

#### Scenario: Warning on insufficient stock

GIVEN the user adds a line item for Article A (qty=20) with `bestand_aktuell=15`
WHEN the line item is rendered
THEN a warning icon SHALL appear next to the quantity field
AND the invoice SHALL still be saveable as draft.

#### Scenario: Finalization blocked

GIVEN the user attempts to finalize an invoice with a line item having quantity > bestand_aktuell and `minusbestand_erlaubt = false`
WHEN finalization is attempted
THEN a confirmation dialog SHALL appear asking to proceed or cancel
AND proceeding SHALL set `minusbestand_erlaubt = true` for the affected articles (user override).

#### Scenario: Draft save not blocked by stock warning

GIVEN an article has `bestand_aktuell=2` and `lager_aktiv=true`
WHEN the user saves an invoice as draft with qty=5 for that article
THEN the invoice SHALL be saved successfully as draft.

### Requirement: Manual stock adjustment

The system SHALL provide a manual stock adjustment interface in the article detail view. The user SHALL be able to set `bestand_aktuell` to an absolute value or adjust by a delta (+/-). Each adjustment SHALL be recorded in a stock movement log (datum, artikel_id, diff, grund). The stock adjustment SHALL NOT require an invoice or journal entry.

#### Scenario: Absolute stock set

GIVEN an article has `bestand_aktuell = 15`
WHEN the user sets `bestand_aktuell` to 100 via the manual adjustment interface
THEN `bestand_aktuell` SHALL be 100
AND a stock movement log entry SHALL be created with diff=+85 and grund="Manuelle Korrektur".

#### Scenario: Relative stock adjustment

GIVEN an article has `bestand_aktuell = 15`
WHEN the user adjusts the article by -5 via the manual adjustment interface
THEN `bestand_aktuell` SHALL decrease to 10
AND a stock movement log entry SHALL be created with diff=-5 and grund="Manuelle Korrektur".

#### Scenario: Negative stock set via manual adjustment

GIVEN an article has `bestand_aktuell = 5`
WHEN the user sets `bestand_aktuell` to -3 via the manual adjustment interface
THEN `bestand_aktuell` SHALL be -3
AND a stock movement log entry SHALL be created with diff=-8.

### Requirement: Configurable inventory activation in settings

The Settings workspace SHALL expose inventory availability through the `inventory` entry in `unternehmen.feature_modules_json`, resolved by the module catalog. The documented `lagerführung_aktiv` setting (stored as `lagerfuehrung_aktiv` where present) SHALL be migration-only input and SHALL NOT be read or written as a runtime module switch. `artikel.lager_aktiv` SHALL remain the independent per-article stock-tracking flag. Article stock data SHALL retain the maintained fields `bestand_aktuell` (`NUMERIC(10,3)`, default 0), `bestand` (legacy stock value), `mindestbestand` (`NUMERIC(10,3)`, default 0), and `minusbestand_erlaubt` (boolean, default false).

When the `inventory` module is disabled, inventory navigation, dashboard warnings, article stock fields, manual stock controls, inventory shortcuts, and invoice stock-warning indicators SHALL be hidden or unavailable. Disabling the module SHALL preserve article stock fields and movement records and SHALL NOT suppress the stock effects required by outgoing invoice finalization or storno. When enabled, invoice line items for tracked articles SHALL show a per-line warning when the line quantity exceeds `bestand_aktuell`; the warning SHALL NOT block saving a draft. Finalization SHALL follow the maintained stock confirmation flow, including the `minusbestand_erlaubt` override when the user confirms proceeding with insufficient stock.

#### Scenario: Inventory globally disabled

- **GIVEN** the catalog entry `inventory` is disabled for the active business
- **WHEN** the application loads
- **THEN** the `lagerführung_aktiv` / `lagerfuehrung_aktiv` legacy value is not consulted as a runtime switch
- **AND** the Lagerwarnung widget, article stock fields, manual stock controls, inventory shortcuts, and invoice stock-warning indicators are hidden or unavailable
- **AND** existing article stock values, per-article tracking flags, and movement records remain unchanged

#### Scenario: Inventory globally enabled

- **GIVEN** the catalog entry `inventory` is effectively enabled for the active business
- **WHEN** the application loads
- **THEN** the inventory entry points and article stock fields are available subject to each article's `lager_aktiv` value
- **AND** invoice line items for tracked articles can display stock warnings

#### Scenario: Per-article stock fields retain their maintained meaning

- **GIVEN** the `inventory` module is effectively enabled
- **WHEN** an article is displayed or edited
- **THEN** `lager_aktiv` controls whether the article normally participates in stock tracking
- **AND** `bestand_aktuell`, `bestand`, `mindestbestand`, and `minusbestand_erlaubt` retain their maintained stock, legacy compatibility, minimum, and negative-stock meanings

#### Scenario: Invoice stock warning allows draft save

- **GIVEN** the `inventory` module is effectively enabled and a tracked article has `bestand_aktuell=15` with an invoice line quantity of 20
- **WHEN** the invoice line is rendered and the user saves the invoice as a draft
- **THEN** a warning is shown on that line and the draft is saved successfully

#### Scenario: Invoice stock warning uses maintained finalization confirmation

- **GIVEN** the `inventory` module is effectively enabled and a tracked article has insufficient stock with `minusbestand_erlaubt=false`
- **WHEN** the user finalizes an invoice containing that article
- **THEN** the maintained confirmation flow asks whether to proceed or cancel
- **AND** proceeding applies the maintained `minusbestand_erlaubt` override for affected articles

#### Scenario: Disabled module does not suppress invoice stock effects

- **GIVEN** the `inventory` module is disabled and an outgoing invoice contains an article that participates in stock tracking
- **WHEN** the invoice is finalized or storniert
- **THEN** the stock update or restoration required by the invoice lifecycle still occurs exactly once
- **AND** module disablement does not rewrite the article stock values or movement history

### Requirement: Inventory movement storage

The inventory feature migration SHALL add exactly one named table, `inventarbewegungen`, with `id`, `artikel_id` (foreign key to `artikel`), `datum`, `diff` (NUMERIC(10,3)), `grund`, and nullable `referenz_typ` and `referenz_id` fields. Outgoing-invoice deductions, Storno restores, and manual adjustments SHALL each write movement rows in the same transaction as the stock change. Repeated outgoing lines for one article SHALL produce a movement whose `diff` equals the combined stock change. Storno SHALL use the source invoice's recorded negative movement as its restoration amount.

#### Scenario: Automatic movement recorded

GIVEN an inventory-enabled article is included in a finalized outgoing invoice
WHEN stock is decremented
THEN `inventarbewegungen` SHALL contain the negative quantity with the invoice reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Storno movement recorded

GIVEN an outgoing invoice has a recorded negative stock movement and is storniert
WHEN stock is restored
THEN `inventarbewegungen` SHALL contain the positive restored quantity with the Storno reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Incoming and document-only finalization has no automatic movement

GIVEN an inventory-enabled article is included in a finalized incoming invoice or offer
WHEN document finalization commits
THEN no automatic inventory movement SHALL be recorded.
