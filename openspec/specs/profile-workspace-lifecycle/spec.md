# profile-workspace-lifecycle Specification

## Purpose
TBD - created by archiving change profile-workspace-lifecycle. Update Purpose after archive.

## Requirements

### Requirement: Profile CRUD changes real profile state

Profile management MUST discover real profiles, persist active selection, create and rename profiles, and unregister only eligible inactive profiles. Unregistering removes the profile from normal discovery but preserves its directory, database, uploads, and backups for recovery; it MUST never erase profile data.

Implementation evidence: deleteProfile validates but does nothing, while listProfiles scans directories; selection service defaults to hard-coded names based on test paths.

#### Scenario: Inactive profile can be unregistered without data loss

- Given two valid profiles exist and the target is not active
- When the user confirms deletion
- Then the target is removed from the registered-name list and no longer appears in discovery, while its profile directory and data remain unchanged

#### Scenario: Active/last profile deletion is protected

- Given the target is active or is the only remaining profile
- When deletion is requested
- Then the operation is rejected with a localized explanation and active data remains intact

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
