## MODIFIED Requirements

### Requirement: Profile manager UI

The application SHALL provide a `Profile` menu entry accessible from the main navigation or Settings. The Profile Manager SHALL display all profiles with name, database size, and last-modified timestamp, and support create, select, rename, and eligible delete actions. For exactly one profile, the entry SHALL be visible only when the module catalog resolves `profile_manager` as effectively enabled. When more than one profile exists, the entry SHALL be visible regardless of the saved catalog preference. Profile switching requires a process restart.

#### Scenario: Profile manager accessible with multiple profiles

- **GIVEN** more than one profile directory exists and the saved `profile_manager` preference is disabled
- **WHEN** the application loads
- **THEN** the Profile Manager menu entry is visible regardless of that preference

#### Scenario: Profile manager hidden with single profile

- **GIVEN** exactly one profile exists and the module catalog resolves `profile_manager` as disabled
- **WHEN** the application loads
- **THEN** the Profile Manager menu entry is hidden

#### Scenario: Profile manager shown when explicitly activated

- **GIVEN** exactly one profile exists and the module catalog resolves `profile_manager` as enabled
- **WHEN** the application loads
- **THEN** the Profile Manager menu entry is visible
