## ADDED Requirements

### Requirement: Business-document search and combined filters

The invoice, receipt, and banking list workspaces SHALL use these persisted typed fields for search and filtering:

- Invoices: partial text search on `rechnungsnummer`, linked customer/supplier name or company, and date text; inclusive date range on `datum`; exact filter on the persisted `status`; and inclusive amount range on persisted gross `brutto_betrag`.
- Receipts: partial text search on `belegnummer`, `beschreibung`, and linked supplier name or company; inclusive date range on `datum`; exact filter on persisted `status`; and inclusive amount range on persisted `betrag`.
- Bank transactions: partial text search on `gegenkonto_name`, `gegenkonto`, and `verwendungszweck`; inclusive date range on `datum`; exact filter on the persisted transaction `status`; and inclusive amount range on persisted `betrag`.

Search SHALL not calculate or reinterpret persisted amounts/statuses. Multiple search/filter criteria SHALL be combined with AND semantics, visible as removable chips, and reflected in the matching count. Queries SHALL be bounded and use explicit typed projections; changing criteria SHALL reset pagination while pagination and detail navigation retain the selected criteria.

#### Scenario: Combine invoice criteria
- **GIVEN** persisted invoices have distinct document numbers, linked parties, dates, statuses, and gross amounts
- **WHEN** the user combines a partial party query, inclusive date range, exact persisted status, and gross-amount range
- **THEN** the result SHALL contain only invoices matching all criteria
- **AND** the active criteria and matching count SHALL be visible

#### Scenario: Combine receipt and banking criteria
- **GIVEN** receipts and bank transactions have persisted descriptions/parties, dates, statuses, and amounts
- **WHEN** the user combines text, date, status, and amount criteria on either list
- **THEN** only typed rows matching all selected criteria SHALL appear, using the fields named above
- **AND** a bank transaction result selected from global search SHALL open as `/banking?transactionId=<id>` with its typed details selected

#### Scenario: Invalid filter or query failure
- **GIVEN** an amount/date input is invalid or a list query fails
- **WHEN** the user applies the criteria
- **THEN** invalid input SHALL show a localized field error, or the failed query SHALL show a retryable error
- **AND** valid criteria SHALL remain available and no fabricated or partial rows SHALL be shown

#### Scenario: Clear one or all filters
- **GIVEN** the list has multiple active search criteria
- **WHEN** the user removes one chip or selects reset
- **THEN** only that criterion or all criteria respectively SHALL be cleared
- **AND** the updated typed result count SHALL be shown

### Requirement: Banking selection is addressable through the canonical route

The existing `/banking` route SHALL accept an optional positive integer `transactionId` query parameter. When present, the banking workspace SHALL load the typed transaction and show it as the selected record in the workspace inspector. The selection SHALL coexist with other supported banking query parameters and SHALL not change the transaction or create a posting. A missing, malformed, or unavailable transaction ID SHALL produce a localized typed not-found/unavailable state without exposing raw SQL or changing the route's other query state.

#### Scenario: Open a selected bank transaction
- **GIVEN** transaction 42 exists in the active profile
- **WHEN** the user opens `/banking?transactionId=42`
- **THEN** the banking workspace SHALL select transaction 42 and show its typed details
- **AND** the URL SHALL retain `transactionId=42` while the selection is open

#### Scenario: Invalid or missing transaction selection
- **GIVEN** `/banking` receives a non-positive, malformed, or nonexistent `transactionId`
- **WHEN** the route resolves the selection
- **THEN** it SHALL show a localized typed not-found state
- **AND** it SHALL preserve unrelated banking query parameters and SHALL NOT expose raw database rows
