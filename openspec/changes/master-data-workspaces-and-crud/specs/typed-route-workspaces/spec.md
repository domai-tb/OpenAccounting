## ADDED Requirements

### Requirement: Master-data route actions are typed and reachable

The customer, supplier, article, company, category, account, tax-rate, and number-range routes SHALL be registered in the production router and resolve to their owning typed use cases and repositories. List and detail routes SHALL expose the domain actions defined by the `stammdaten` capability. Settings subroutes SHALL be directly addressable and reachable from `/settings`; workspace create, edit, and archive controls SHALL preserve the current route and query context on success or failure.

#### Scenario: Settings link opens a typed master-data surface
- **GIVEN** the user is on `/settings`
- **WHEN** the user opens the Number Ranges entry
- **THEN** the router resolves `/settings/number-ranges` to the number-range workspace and shows its typed records and actions

#### Scenario: Invalid master-data record is safely reported
- **GIVEN** a user opens `/contacts/missing` or `/articles/missing`
- **WHEN** the typed detail lookup returns no record
- **THEN** the route shows a localized not-found state with a return action and does not expose SQL or a stack trace
