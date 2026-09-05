# Light Inventory Management

## ADDED Requirements

### Requirement: Per-article inventory activation

Each article SHALL have a `lager_aktiv` boolean flag (default `false`). Only articles with `lager_aktiv = true` SHALL participate in stock tracking. Articles with `lager_aktiv = false` SHALL ignore all stock-related operations.

#### Scenario: Article with inventory disabled

GIVEN an article has `lager_aktiv = false`
WHEN an invoice containing that article is finalized
THEN no stock change SHALL occur for that article.

#### Scenario: Article with inventory enabled

GIVEN an article has `lager_aktiv = true` with `bestand_aktuell = 50` and `mindestbestand = 10`
WHEN an invoice containing 3 units of that article is finalized
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

When an invoice is finalized, the system SHALL iterate all line items with articles where `lager_aktiv = true` and decrement `bestand_aktuell` by the line item quantity. The decrement SHALL be atomic (single transaction) and SHALL occur after the invoice is persisted but before the PDF is generated.

#### Scenario: Multiple line items

GIVEN an invoice contains 3 line items: Article A (qty=10, lager_aktiv=true), Article B (qty=5, lager_aktiv=false), Article C (qty=3, lager_aktiv=true)
WHEN the invoice is finalized
THEN Article A `bestand_aktuell` SHALL decrease by 10
AND Article B SHALL NOT be affected
AND Article C `bestand_aktuell` SHALL decrease by 3.

#### Scenario: No stock fields on non-inventory articles

GIVEN an article has `lager_aktiv = false`
WHEN stock operations are processed
THEN `bestand_aktuell` and `mindestbestand` SHALL be ignored by the system.

#### Scenario: Partial stock decrement on finalization failure

GIVEN an invoice contains Article A (qty=10, lager_aktiv=true) and Article B (qty=5, lager_aktiv=true, bestand_aktuell=2, minusbestand_erlaubt=false)
WHEN the invoice finalization is attempted
THEN the system SHALL NOT decrement stock for either article
AND SHALL display a stock warning for Article B.

### Requirement: Stock restore on storno

When an invoice is storniert (reversed), the system SHALL restore stock for all line items with articles where `lager_aktiv = true` by adding back the line item quantities. The restore SHALL be atomic.

#### Scenario: Storno restores stock

GIVEN an invoice containing Article A (qty=10, lager_aktiv=true, bestand_aktuell=47)
WHEN the invoice is storniert
THEN Article A `bestand_aktuell` SHALL increase by 10 to 57.

#### Scenario: Storno of already-reduced stock

GIVEN an invoice is storniert and the article's bestand_aktuell was manually adjusted downward since the original invoice
WHEN the storno is processed
THEN the storno SHALL still add back the full invoice quantity (no comparison to prior state).

#### Scenario: Storno of invoice with non-inventory articles

GIVEN an invoice contains Article A (qty=10, lager_aktiv=true) and Article B (qty=5, lager_aktiv=false)
WHEN the invoice is storniert
THEN Article A stock SHALL be restored by 10
AND Article B SHALL NOT be affected.

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

The application settings (Unternehmen) SHALL include a `lagerführung_aktiv` boolean flag. When `lagerführung_aktiv = false`, the inventory-related UI elements (Lagerwarnung widget, stock fields in article form, stock warnings in invoice form) SHALL be hidden. This is a global toggle, not per-article.

#### Scenario: Inventory globally disabled

GIVEN `unternehmen.lagerführung_aktiv = false`
WHEN the application loads
THEN the Lagerwarnung widget SHALL NOT appear on the dashboard
AND stock fields SHALL NOT appear in the article form
AND stock warnings SHALL NOT appear in the invoice form.

#### Scenario: Inventory globally enabled

GIVEN `unternehmen.lagerführung_aktiv = true`
WHEN the application loads
THEN all inventory-related UI elements SHALL be visible.

### Requirement: Inventory movement storage

The inventory feature migration SHALL add exactly one named table, `inventarbewegungen`, with `id`, `artikel_id` (foreign key to `artikel`), `datum`, `diff` (NUMERIC(10,3)), `grund`, and nullable `referenz_typ` and `referenz_id` fields. Invoice decrements, Storno restores, and manual adjustments SHALL each write one movement row in the same transaction as the stock change. `referenz_typ` and `referenz_id` SHALL identify the originating document when applicable.

#### Scenario: Automatic movement recorded

GIVEN an inventory-enabled article is included in a finalized invoice
WHEN stock is decremented
THEN `inventarbewegungen` SHALL contain the negative quantity with the invoice reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Storno movement recorded

GIVEN an inventory-enabled invoice is storniert
WHEN stock is restored
THEN `inventarbewegungen` SHALL contain the positive restored quantity with the Storno reference
AND the movement row and stock update SHALL commit or roll back together.
