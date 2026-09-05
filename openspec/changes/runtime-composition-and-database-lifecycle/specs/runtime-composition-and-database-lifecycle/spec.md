## ADDED Requirements

### Requirement: One opened application graph owns feature lifecycles

Application startup MUST create one selected-profile database, await its open/migration lifecycle, construct the feature services from that instance, and expose the graph through the documented application scope.

Implementation evidence: Production currently mixes a Riverpod database override with an empty GetIt shim and route-local WizardService construction.

#### Scenario: Normal startup shares one ready database

- Given a profile exists and the application starts
- When the shell, dashboard, setup guard, and a feature route resolve dependencies
- Then all of them use the same opened database and no LazyDatabase or ensureOpen error is emitted

#### Scenario: Dependency resolution cannot use an unopened default

- Given a consumer is resolved before database startup completes
- When the composition boundary is exercised
- Then resolution is blocked with a typed readiness failure rather than issuing SQL against an unopened delegate

### Requirement: Feature UI respects the clean dependency direction

Production pages MUST resolve use cases from the application scope and MUST NOT construct repositories, query executors, GetIt lookups, or raw SQL directly in widgets.

Implementation evidence: The dashboard currently resolves DashboardRepository directly and setup builds a repository/service inside the route builder.

#### Scenario: A page calls its use case

- Given a page needs data or a command
- When the page is rendered and interacted with
- Then the injected use case is called and the repository/data source remain below the UI layer

#### Scenario: A missing service is diagnosed at composition time

- Given a route's required use case is not registered
- When the app graph is built
- Then composition validation identifies the missing registration before the route renders a misleading empty state
