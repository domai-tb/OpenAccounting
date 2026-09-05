# Configurable Dashboard

## ADDED Requirements

### Requirement: Widget-based layout

The dashboard SHALL display widgets in a scrollable grid layout. Each widget SHALL occupy a configurable grid cell (1x1 or 2x1 width). Widgets SHALL render inside a card container with a title, optional icon, and content area. The default layout SHALL show all widgets in a sensible order.

#### Scenario: Default widget layout

GIVEN the user has no saved dashboard configuration
WHEN the dashboard loads
THEN the dashboard SHALL display all available widgets in their default order
AND each widget SHALL render its content in a card container.

#### Scenario: Widget rendering with loading state

GIVEN the dashboard is displayed
WHEN a widget begins fetching its data
THEN the widget SHALL display a loading skeleton while data is being fetched
AND SHALL render content or an empty state once data arrives.

#### Scenario: Widget with failed data fetch

GIVEN a widget's data source is unavailable
WHEN the widget attempts to fetch data
THEN the widget SHALL display an error state
AND SHALL NOT render stale or placeholder data.

### Requirement: 13+ available widgets

The system SHALL provide the following widgets: (1) Offene Rechnungen (open invoices total), (2) Zahlungseingänge (recent payments), (3) Lagerwarnung (low stock alerts), (4) Mahnung-Warnung (overdue reminder alerts), (5) Fristen (upcoming deadlines/tax dates), (6) UStVA-Frist (VAT return deadline), (7) Quick-Links (configurable shortcut links), (8) Einnahmen/Ausgaben (income vs expense chart), (9) Überfällige Rechnungen (overdue invoices), (10) Offene Verbindlichkeiten (open payables), (11) Kontostand (account balances), (12) Aktivitäts-Log (recent activity feed), (13) Lagerbestand (stock levels summary).

#### Scenario: All widgets available

GIVEN the user opens the dashboard customization panel
WHEN the panel loads
THEN all 13+ widgets SHALL be listed with toggle switches for visibility.

#### Scenario: Widget content varies by type

GIVEN the "Offene Rechnungen" widget is visible
WHEN the widget loads
THEN it SHALL display the total count and sum of unpaid invoices
AND clicking it SHALL navigate to the receivables page.

#### Scenario: Lagerwarnung with no low-stock items

GIVEN the "Lagerwarnung" widget is visible and no articles have `bestand_aktuell <= mindestbestand`
WHEN the widget loads
THEN it SHALL display "Keine Warnungen".

### Requirement: Widget visibility configuration

Each widget SHALL have a boolean visibility toggle. Hidden widgets SHALL NOT be rendered or fetched. The visibility state SHALL be persisted in `unternehmen.dashboard_config` as JSON.

#### Scenario: Hide a widget

GIVEN the "Lagerwarnung" widget is currently visible
WHEN the user toggles "Lagerwarnung" to off in the dashboard settings
THEN the Lagerwarnung widget SHALL disappear from the dashboard immediately
AND on next application start, the widget SHALL remain hidden.

#### Scenario: Show a previously hidden widget

GIVEN the "Aktivitäts-Log" widget is currently hidden
WHEN the user toggles "Aktivitäts-Log" to on in the dashboard settings
THEN the Aktivitäts-Log widget SHALL appear in its default position on the dashboard.

#### Scenario: Hidden widget does not fetch data

GIVEN the "Lagerwarnung" widget is toggled off
WHEN the dashboard loads
THEN the Lagerwarnung widget SHALL NOT make any data fetch requests.

### Requirement: Widget reordering via drag-and-drop

The dashboard customization panel SHALL support drag-and-drop reordering of visible widgets. The new order SHALL be persisted in `unternehmen.dashboard_config`. Reordering SHALL NOT change widget visibility.

#### Scenario: Drag widget to new position

GIVEN the customization panel is open with "Zahlungseingänge" at position 2
WHEN the user drags "Zahlungseingänge" to position 5
THEN the widget order SHALL update in real-time in the panel
AND on saving, the dashboard SHALL render widgets in the new order.

#### Scenario: Reorder persists across sessions

GIVEN the user has reordered widgets and saved the configuration
WHEN the user closes and reopens the application
THEN widgets SHALL appear in the saved order.

#### Scenario: Reorder does not affect visibility

GIVEN the "Lagerwarnung" widget is hidden and at position 3
WHEN the user reorders visible widgets
THEN the "Lagerwarnung" widget SHALL remain hidden at its original position.

### Requirement: Schnellzugriff-Links (Quick-Links widget)

The Quick-Links widget SHALL display user-configurable shortcut links to common actions (e.g., "Neue Rechnung", "Journal öffnen", "Artikel anlegen"). Links SHALL be stored as a JSON array of `{label, route}` objects in `unternehmen.dashboard_config`. Each link SHALL navigate to the specified route when clicked.

#### Scenario: Default quick links

GIVEN the dashboard loads with no saved Quick-Links configuration
WHEN the Quick-Links widget renders
THEN it SHALL display default links: "Neue Rechnung", "Journal", "Artikel".

#### Scenario: Custom quick link

GIVEN the user has added a quick link labeled "Mein Shop" pointing to route `/shop`
WHEN the Quick-Links widget renders
THEN the link SHALL appear in the widget
AND clicking it SHALL navigate to `/shop`.

#### Scenario: Quick link with invalid route

GIVEN the user has added a quick link pointing to a non-existent route `/nonexistent`
WHEN the user clicks the link
THEN the application SHALL display a 404 or route-not-found state.

### Requirement: Data refresh on mount

The dashboard SHALL refresh all widget data on mount (initial load) and after any data mutation (new invoice, payment, stock change). A manual refresh button SHALL be available. Refresh SHALL NOT cause layout shift or visual flicker.

#### Scenario: Initial load

GIVEN the user navigates to the dashboard
WHEN the dashboard mounts
THEN all visible widgets SHALL fetch their current data
AND display a loading state until data arrives.

#### Scenario: Refresh after mutation

GIVEN the user has created a new invoice
WHEN the user returns to the dashboard
THEN the "Offene Rechnungen" widget SHALL reflect the new invoice in its count and sum.

#### Scenario: Manual refresh

GIVEN the dashboard is displayed with current data
WHEN the user clicks the refresh button
THEN all widgets SHALL re-fetch their data
AND update their displayed content.

### Requirement: Dashboard config persistence

The dashboard configuration (widget order, visibility, Quick-Links) SHALL be stored as a JSON object in `unternehmen.dashboard_config`. The configuration SHALL be loaded on dashboard mount and saved on any change.

#### Scenario: Config saved on change

GIVEN the user changes any dashboard setting (visibility, order, links)
WHEN the change is made
THEN the updated config SHALL be persisted immediately to the database
AND no separate save action SHALL be required.

#### Scenario: Config loaded on start

GIVEN the user has a saved dashboard config
WHEN the application starts and the dashboard loads
THEN the dashboard SHALL render using the saved widget order and visibility settings.

#### Scenario: Corrupted config falls back to defaults

GIVEN the `dashboard_config` JSON is corrupted or unparseable
WHEN the dashboard loads
THEN the dashboard SHALL render with default widget order and all widgets visible.
