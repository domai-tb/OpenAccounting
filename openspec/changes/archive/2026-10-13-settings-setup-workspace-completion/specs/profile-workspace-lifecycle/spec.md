## MODIFIED Requirements

### Requirement: Selection switches the running application coherently

Profile selection from startup, setup, sidebar, or Settings MUST persist a valid active-profile pointer before reporting success. Selecting the already active profile MUST be a no-op. Selecting a different profile MUST follow the established `profiles` and `setup` contract: clearly report that an application restart is required, and only after restart may the database and route-visible identity switch. A failed or unavailable target MUST leave the current pointer and loaded profile unchanged. The application MUST NOT present data from the selected profile as active before its database is loaded.

#### Scenario: User switches profiles

- **GIVEN** two valid profiles contain distinct company data and the first is active
- **WHEN** the user selects the second profile in Settings and confirms the switch
- **THEN** the active pointer SHALL be persisted, Settings SHALL show a restart-required message, and the current session SHALL continue to show only the first profile until restart; after restart only the second profile's data SHALL be loaded

#### Scenario: Active profile selection is a no-op

- **GIVEN** the currently loaded profile is selected
- **WHEN** the user selects it again
- **THEN** the manager SHALL not rewrite the active pointer or request restart

#### Scenario: Corrupt or unavailable profile is recoverable

- **GIVEN** a selected profile does not exist or cannot be validated
- **WHEN** the user confirms the selection
- **THEN** the active pointer and current database SHALL remain unchanged and Settings SHALL show a localized retryable error
