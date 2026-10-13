## ADDED Requirements

### Requirement: Customer detail exposes scoped data disclosure

The typed customer detail workspace SHALL expose a user-initiated action for a disclosure export of that customer. It SHALL resolve the selected customer through the typed contact service, describe the verified record relationship scope before export, and display the manifest outcome. The action SHALL be unavailable when no scoped export service is registered or when the customer cannot be loaded. UI code SHALL NOT query customer-linked database tables directly.

#### Scenario: Customer detail invokes the scoped export service

- **GIVEN** a customer detail is loaded and the disclosure export service is available
- **WHEN** the user selects the customer data export action
- **THEN** the page SHALL invoke the typed export use case for that customer's stable ID
- **AND** show the returned localized progress and outcome

#### Scenario: Export service is unavailable

- **GIVEN** the customer detail is loaded but no scoped export service is registered
- **WHEN** the user opens the disclosure action area
- **THEN** the page SHALL show a localized unavailable state
- **AND** SHALL NOT fall back to whole-profile export or raw table output
