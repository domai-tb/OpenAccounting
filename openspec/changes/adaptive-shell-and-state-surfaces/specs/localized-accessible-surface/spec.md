## ADDED Requirements

### Requirement: Locale-complete visible UI

All visible labels, actions, tooltips, loading/empty/error messages, dates, numbers, and currency values SHALL use the active locale. Supported locales SHALL not silently fall back to unrelated German literals. Every visible string SHALL have an ARB key, and a parity check SHALL fail when a key is absent from any supported locale.

#### Scenario: English state copy is complete
- **GIVEN** the active locale is English
- **WHEN** a route renders loading, data, empty, and error states
- **THEN** every visible message and action SHALL be English and formatting SHALL use the English locale

#### Scenario: Missing translation fails validation
- **GIVEN** a new visible string has no ARB key
- **WHEN** localization validation runs
- **THEN** the check SHALL fail with the missing key before the UI can ship

#### Scenario: Locale formats accounting values
- **GIVEN** the active locale is English and a route contains a date, decimal amount, and currency
- **WHEN** the data state renders
- **THEN** the date, decimal separator, currency symbol, and accessible text SHALL use the active locale formatter rather than a hardcoded German format

### Requirement: Accessible keyboard and semantics contract

Interactive controls SHALL expose a localized semantic role, name, and state, visible focus in both themes, and a keyboard activation path equivalent to pointer activation. Navigation destinations, buttons, text fields, overflow menus, and dialogs SHALL have deterministic traversal order and Enter/Space or platform-equivalent activation. Narrow layouts SHALL keep all actions reachable.

#### Scenario: Focused navigation activates
- **GIVEN** focus is on a compact sidebar destination
- **WHEN** the user presses Enter or Space
- **THEN** the destination SHALL activate, announce its selected state, and preserve visible focus

#### Scenario: Narrow action remains reachable
- **GIVEN** the viewport is 320 logical pixels wide
- **WHEN** secondary actions collapse into overflow
- **THEN** every action SHALL remain reachable by keyboard and semantics without clipping or overlap

#### Scenario: Focus semantics survive state settling
- **GIVEN** focus is on a search field or action while a route transitions from loading to data or error
- **WHEN** the state settles
- **THEN** the focused control SHALL retain its semantic name and focus ring where it still exists, or focus SHALL move to the route heading with an announced localized state
