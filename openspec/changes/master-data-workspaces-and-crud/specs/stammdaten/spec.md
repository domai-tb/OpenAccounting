## ADDED Requirements

### Requirement: Customer and supplier workspaces

The application SHALL provide reachable, separate customer and supplier workspaces from the Contacts navigation destination. Each workspace SHALL use typed projections and documented master-data fields, support partial search over names and relevant identifiers, sortable columns, applicable filters, bounded pagination with a result count, keyboard row navigation, multi-selection, and bulk archive. Create, update, record detail, and archive actions SHALL be available through visible controls and row context menus; core actions MUST NOT depend on right-click or hover. Selecting a row SHALL open an optional inspector; opening the record SHALL provide its full detail view. Validation and persistence failures SHALL keep entered values and identify the affected field or operation. Each record SHALL expose an explicit archive action with confirmation. Archiving SHALL preserve the record identity and historical document references; archived state SHALL be visible and filterable. Permanent deletion and the effect of archived records on future document selection are governed by the open questions in the design and MUST NOT be inferred from this requirement.

#### Scenario: Search, paginate, inspect, and edit a supplier
- **GIVEN** more suppliers exist than fit on one page and supplier "Bürobedarf AG" has a stored Kreditor-Nr
- **WHEN** the user selects the supplier tab, searches by that identifier, opens the matching row, and saves an updated address
- **THEN** the paginated typed list shows the matching supplier, the inspector and detail view show its stored fields, and the updated address is returned by a subsequent detail read

#### Scenario: Archive a referenced customer
- **GIVEN** customer "Müller GmbH" is referenced by a finalized invoice
- **WHEN** the user confirms the customer's archive action
- **THEN** the customer appears in the archived view with the same identifier and the finalized invoice still resolves to that customer

#### Scenario: Bulk archive selected suppliers
- **GIVEN** the supplier list has two selected supplier rows
- **WHEN** the user invokes the visible bulk archive action and confirms it
- **THEN** both suppliers appear in the archived view and both supplier identifiers remain resolvable from existing purchase and journal history

#### Scenario: Search or save fails
- **GIVEN** a customer search or update is submitted and the repository returns an error
- **WHEN** the workspace renders the result
- **THEN** it preserves the search and entered form values, shows a retryable list error or field/operation error, and does not show an unsaved update as persisted

### Requirement: Production master-data entry points

The application SHALL expose typed, navigable production entry points for the records documented in `docs/03-kunden-stammdaten.md`: articles and article groups, company data, categories, bank accounts, tax rates, and number ranges. Article and group workspaces SHALL support the create/read/update and lifecycle actions already defined by their data contracts. The company entry point SHALL read and update the singleton company record. Category, account, tax-rate, and number-range entry points SHALL expose the documented fields and existing create/read/update operations, with deletion guarded by the current capability contracts. All entry points SHALL be reachable from Contacts or Settings without a setup-only prerequisite and SHALL use typed forms and projections rather than generic raw table output.

#### Scenario: Open a documented master-data workspace
- **GIVEN** the user is on the Settings page
- **WHEN** the user opens Company, Categories, Accounts, Tax Rates, Number Ranges, or Articles
- **THEN** the selected workspace reads its typed record or list from the active profile and presents its documented create or update action

#### Scenario: Workspace has no supported production data source
- **GIVEN** a master-data entry point cannot load its registered typed repository
- **WHEN** the workspace renders
- **THEN** it shows a localized unavailable/retry state and does not substitute an arbitrary SQL-column listing or a setup wizard
