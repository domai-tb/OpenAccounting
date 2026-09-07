## ADDED Requirements

### Requirement: The production schema is defined by migrations

Every table and column required by a production feature MUST be created or changed by an ordered migration before the feature can query it; runtime workflows MUST not create schema objects as a side effect.

Implementation evidence: Invoice finalization creates inventarbewegungen lazily and ForderungenRepository.ensureSchema is called by tests rather than normal startup.

#### Scenario: Fresh database has the complete schema

- Given a new profile database is opened through the normal startup path
- When ensureOpen completes
- Then all feature tables and required columns exist before any route or use case runs

#### Scenario: A workflow cannot hide missing schema

- Given a migration omitted a required table or column
- When the feature is invoked
- Then startup or migration fails with the missing schema identified rather than silently creating it or swallowing the error

### Requirement: Migrations fail safely and preserve data

Migration execution MUST reject unsupported future versions, surface unrecoverable DDL errors, and preserve all supported data/columns during table rebuilds.

Implementation evidence: run returns false for version greater than currentVersion, ALTER failures are caught broadly, and _rebuildRechnungen copies a limited column list.

#### Scenario: Unsupported future database is rejected

- Given a profile database has a schema version newer than the application
- When startup opens it
- Then the app reports an incompatible-database state and does not run against an unknown schema

#### Scenario: Legacy rebuild preserves extended data

- Given an older invoice table contains columns added by later feature migrations
- When the rebuild migration runs
- Then supported columns and rows retain their values and the migration either commits fully or rolls back
