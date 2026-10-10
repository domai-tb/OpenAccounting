## MODIFIED Requirements

### Requirement: Dashboard stock warning widget

The dashboard SHALL display the `Lagerwarnung` widget only when the `inventory` module is effectively enabled. When shown, it SHALL list articles where `lager_aktiv = true` and `bestand_aktuell <= mindestbestand`, including article name, current stock, and minimum stock. If no articles meet the warning criteria, it SHALL display `Keine Warnungen`. Disabling the inventory module SHALL hide inventory navigation, widgets, shortcuts, and inventory-specific mutation controls without deleting inventory records or suppressing stock effects required by invoice finalization or storno.

#### Scenario: Low stock warning displayed

- **GIVEN** the `inventory` module is effectively enabled and Article X has `lager_aktiv=true`, `bestand_aktuell=3`, and `mindestbestand=10`
- **WHEN** the dashboard loads
- **THEN** the `Lagerwarnung` widget displays Article X with `3 / 10`

#### Scenario: No warnings

- **GIVEN** the `inventory` module is effectively enabled and all tracked articles have `bestand_aktuell > mindestbestand`
- **WHEN** the dashboard loads
- **THEN** the `Lagerwarnung` widget displays `Keine Warnungen`

#### Scenario: Article at exactly minimum stock

- **GIVEN** the `inventory` module is effectively enabled and an article has `lager_aktiv=true` and `bestand_aktuell = mindestbestand`
- **WHEN** the dashboard loads
- **THEN** the `Lagerwarnung` widget displays that article as a warning

#### Scenario: Stock warning hidden when inventory is disabled

- **GIVEN** the `inventory` module is disabled and inventory records exist
- **WHEN** the dashboard loads
- **THEN** the `Lagerwarnung` widget and inventory shortcuts are hidden
- **AND** all existing inventory records remain unchanged

#### Scenario: Invoice finalization keeps required stock effects

- **GIVEN** the `inventory` module is disabled and an invoice contains an article whose per-article stock tracking is enabled
- **WHEN** the invoice is finalized or storniert
- **THEN** the stock movements required by the invoice lifecycle are still applied exactly once
- **AND** disabling the module does not delete or rewrite existing inventory records

## MODIFIED Requirements

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
