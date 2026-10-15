## ADDED Requirements

### Requirement: Report route selections resolve to typed owners

`/reports` and `/taxes` SHALL resolve report query state only through the typed selections and service owners in the `accounting-reporting-workspaces` route matrix. With no report query, each route SHALL use `ReportCatalogUseCase.list` to show typed report choices and their availability. `/reports` SHALL support EÜR by supported year, EKS availability, management GuV by calendar year, DATEV by calendar month, and report export history. `/taxes` SHALL support UStVA by configured month or quarter and ZM by supported month. Each deep link SHALL preserve its report selection and period in the URL. The router or page SHALL pass a typed selection to `ReportingWorkspaceUseCase`; that use case SHALL call the named report-specific application service and return a typed result containing the exact period, availability, source/form versions, unresolved count, and source IDs where available. An unknown/invalid selection, unsupported period, or unavailable service SHALL return a localized invalid-selection or unavailable boundary and SHALL NOT query a generic table or fabricate a result.

#### Scenario: Report routes open a typed report catalog

- **GIVEN** the user opens `/reports` or `/taxes` without a report query
- **WHEN** the route resolves
- **THEN** it SHALL use `ReportCatalogUseCase.list` to render typed report choices with truthful availability and SHALL NOT show generic records

#### Scenario: Report deep link selects its typed owner

- **GIVEN** the user opens a valid `/reports` or `/taxes` report selection and supported period deep link
- **WHEN** the route resolves
- **THEN** it SHALL pass the matching typed selection to the named use case in the route matrix, preserve the route and period query, and render only the use case's typed result

#### Scenario: Export history deep link opens validated artifact history

- **GIVEN** the user opens `/reports?view=history` with an optional supported export type or date filter
- **WHEN** the route resolves
- **THEN** it SHALL use `ReportExportHistoryUseCase`, preserve the filters, and show only artifacts validated by the existing export lifecycle contract

#### Scenario: Missing or invalid report selection fails closed

- **GIVEN** a report route has an unknown report ID, malformed period, unsupported period, or unregistered owner
- **WHEN** the route loads or the user requests a result
- **THEN** it SHALL show a localized typed invalid-selection or unavailable state, preserve the requested route/query, and SHALL NOT use raw database rows as a fallback
