## ADDED Requirements

### Requirement: Primary destinations render data-backed workflows

The primary navigation MUST route to feature pages that load records through their use cases and expose the relevant list, detail, creation, import, or reporting action rather than fixed placeholder text.

Implementation evidence: The production router imports dashboard/setup UI but the remaining destinations return centered Text widgets.

#### Scenario: A populated invoice and contact workspace is usable

- Given the database contains an invoice, a customer, and a bank transaction
- When the user opens Invoices, Contacts, or Banking
- Then the corresponding record appears with a real action and detail path backed by the feature service

#### Scenario: An empty or failed workspace is explicit

- Given a workspace has no records or its use case fails
- When the route is opened
- Then the page renders a localized empty or error state with a recovery/action affordance and does not fall back to a placeholder label

### Requirement: Route contracts support creation, detail, and query state

Invoice aliases and nested paths MUST resolve to the intended list, new-document, or record-detail workflow, and supported query parameters MUST affect the loaded view rather than being displayed as inert text.

Implementation evidence: The router treats new as an invoice ID, lacks a real /rechnungen/:id contract, and only prints query values in placeholder content.

#### Scenario: Creation and detail paths select the correct mode

- Given the user opens the canonical or legacy invoice path
- When the path is /invoices/new or /rechnungen/123
- Then the creation editor or database-backed detail view opens respectively

#### Scenario: Invalid detail and filters are handled

- Given the user opens a missing ID or an unsupported filter value
- When routing and loading occur
- Then the app shows a localized not-found/validation state and preserves the safe list route without issuing an invalid query
