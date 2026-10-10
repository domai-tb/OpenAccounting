## ADDED Requirements

### Requirement: Customer and supplier workspaces

The application SHALL provide reachable, separate customer and supplier workspaces from the Contacts navigation destination. Each workspace SHALL use typed projections and documented master-data fields, support partial search over names and relevant identifiers, sortable columns, applicable filters, bounded pagination with a result count, keyboard row navigation, multi-selection, and bulk archive. Create, update, record detail, and archive actions SHALL be available through visible controls and row context menus; core actions MUST NOT depend on right-click or hover. Selecting a row SHALL open an optional inspector; opening the record SHALL provide its full detail view. Validation and persistence failures SHALL keep entered values and identify the affected field or operation. Each record SHALL expose archive and restore actions with confirmation. Archive state SHALL be stored in nullable `archived_at`; `NULL` means active, and non-`NULL` means archived. Archiving SHALL preserve record identity and historical document references, set a UTC timestamp once, and remain reversible by clearing the timestamp. Archived rows SHALL be visible and filterable. These workspaces SHALL NOT offer permanent deletion; any existing repository delete operation SHALL retain its reference guard. New-document customer and supplier pickers SHALL exclude archived rows by default and include them only when the user explicitly enables an include-archived filter. Historical documents and reports SHALL continue resolving archived records.

#### Scenario: Search, paginate, inspect, and edit a supplier
- **GIVEN** more suppliers exist than fit on one page and supplier "Bürobedarf AG" has a stored Kreditor-Nr
- **WHEN** the user selects the supplier tab, searches by that identifier, opens the matching row, and saves an updated address
- **THEN** the paginated typed list shows the matching supplier, the inspector and detail view show its stored fields, and the updated address is returned by a subsequent detail read

#### Scenario: Archive a referenced customer
- **GIVEN** customer "Müller GmbH" is referenced by a finalized invoice
- **WHEN** the user confirms the customer's archive action
- **THEN** `archived_at` is set, the customer appears in the archived view with the same identifier, and the finalized invoice still resolves to that customer
- **AND** the customer is excluded from new-document pickers by default

#### Scenario: Bulk archive selected suppliers
- **GIVEN** the supplier list has two selected supplier rows
- **WHEN** the user invokes the visible bulk archive action and confirms it
- **THEN** both suppliers receive `archived_at` timestamps, appear in the archived view, and remain resolvable from existing purchase and journal history

#### Scenario: Restore an archived customer
- **GIVEN** an archived customer has `archived_at` set
- **WHEN** the user confirms Restore
- **THEN** `archived_at` is cleared and the customer is included in default new-document pickers again

#### Scenario: Existing number and VAT form behavior is preserved
- **GIVEN** a user creates a customer or supplier with a valid local USt-IdNr format
- **WHEN** the record is saved
- **THEN** the existing Debitor-Nr or Kreditor-Nr range allocates one value and the corresponding visible customer/supplier number field stores that same value
- **AND** no BZSt/eVatR request or external-verification evidence is created

#### Scenario: Search or save fails
- **GIVEN** a customer search or update is submitted and the repository returns an error
- **WHEN** the workspace renders the result
- **THEN** it preserves the search and entered form values, shows a retryable list error or field/operation error, and does not show an unsaved update as persisted

### Requirement: Production master-data entry points

The application SHALL expose typed, navigable production entry points for the records documented in `docs/03-kunden-stammdaten.md`: articles and article groups, company data, categories, bank accounts, tax rates, and number ranges. Article and group workspaces SHALL support the create/read/update and lifecycle actions already defined by their data contracts. The company entry point SHALL read and update the singleton company record. Category, account, tax-rate, and number-range entry points SHALL expose the documented fields and existing create/read/update operations, with deletion guarded by the current capability contracts. All entry points SHALL be reachable from Contacts or Settings without a setup-only prerequisite and SHALL use typed forms and projections rather than generic raw table output.

#### Scenario: Open a documented master-data workspace
- **GIVEN** the user is on the Settings page
- **WHEN** the user opens Company, Categories, Accounts, Tax Rates, Number Ranges, Articles, or Article Groups
- **THEN** the selected workspace reads its typed record or list from the active profile and presents its documented create or update action

#### Scenario: Article group actions use the group service

- **GIVEN** the user selects the article-groups subview at `/articles?view=groups`
- **WHEN** the user creates or edits an article group
- **THEN** the workspace reads and writes an article-group entity through its typed use case
- **AND** it exposes only the create, read, update, and lifecycle actions already allowed by the article-group data contract
- **AND** it does not route the group ID through an article lookup

#### Scenario: Workspace has no supported production data source
- **GIVEN** a master-data entry point cannot load its registered typed repository
- **WHEN** the workspace renders
- **THEN** it shows a localized unavailable/retry state and does not substitute an arbitrary SQL-column listing or a setup wizard
