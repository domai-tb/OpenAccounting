## ADDED Requirements

### Requirement: Global search palette

The application SHALL open a global search palette from `Ctrl+K` on Windows/Linux and `Cmd+K` on macOS. The palette SHALL search typed projections from supported invoices, contacts, receipts, and bank transactions, and SHALL offer only implemented settings destinations and commands. Results SHALL be scoped to the active local profile and show a useful type and identifying summary. Selecting an invoice, contact, or receipt SHALL navigate to its canonical typed record route. Selecting a bank transaction SHALL navigate to `/banking?transactionId=<id>` and select that typed transaction in the banking workspace. Search SHALL be read-only and SHALL NOT reveal secret settings values or arbitrary database columns.

#### Scenario: Find and open a business record
- **GIVEN** a matching invoice or contact exists in the active profile
- **WHEN** the user opens global search and enters a matching number or name
- **THEN** a typed result with its record type and identifying summary SHALL appear
- **AND** selecting it SHALL open the canonical route for that record

#### Scenario: Find and select a bank transaction
- **GIVEN** a typed bank transaction exists in the active profile
- **WHEN** the user selects its global search result
- **THEN** the application SHALL navigate to `/banking?transactionId=<id>` for that transaction
- **AND** the banking workspace SHALL show the selected transaction's typed details

#### Scenario: Search includes supported destination and command
- **GIVEN** a Settings destination or command is registered as searchable
- **WHEN** the user searches for its label
- **THEN** the matching destination or command SHALL appear and selecting it SHALL navigate or invoke that supported intent

#### Scenario: Search fails without fabricating records
- **GIVEN** a source query fails or the active profile is unavailable
- **WHEN** search results are shown
- **THEN** the affected source SHALL show a localized retryable error or unavailable state
- **AND** it SHALL NOT show stale or fabricated results as current matches

#### Scenario: Empty search and unsupported fields
- **GIVEN** the query is empty or matches only a secret setting value or unsupported database field
- **WHEN** the palette evaluates the query
- **THEN** it SHALL show its localized empty prompt or no-results state
- **AND** it SHALL NOT return secret values or raw database rows

### Requirement: Search palette interaction and accessibility

The global search palette SHALL follow DESIGN.md §§13, 14, 16, and 33: it SHALL have a visible query field, a bounded result list, keyboard-operable selection, Escape dismissal, screen-reader labels, localized loading/empty/error/results states, and the specified overlay behavior at narrow widths. Opening or dismissing the palette SHALL preserve the current route and page state.

#### Scenario: Keyboard search preserves the current page
- **GIVEN** the user is on a page with a filter or selected record
- **WHEN** the user opens search, dismisses it with Escape, or opens a result and returns
- **THEN** the prior page and its route query/state SHALL be preserved

#### Scenario: Keyboard and assistive-technology navigation
- **GIVEN** the search palette is open with results
- **WHEN** the user navigates and selects results using the keyboard or assistive technology
- **THEN** focus SHALL remain visible and the selected result's type and summary SHALL be announced
- **AND** Escape SHALL close the palette and restore focus to its invoker

#### Scenario: Narrow-window palette
- **GIVEN** the application window is narrower than the desktop inspector breakpoint
- **WHEN** global search opens
- **THEN** the palette SHALL fit the viewport, keep the query and result actions reachable, and close without changing the current route
