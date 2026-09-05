## ADDED Requirements

### Requirement: Profile CRUD changes real profile state

Profile management MUST discover real profiles, persist active selection, create and rename profiles, delete only eligible inactive profiles, and never leave a deleted profile listed.

Implementation evidence: deleteProfile validates but does nothing, while listProfiles scans directories; selection service defaults to hard-coded names based on test paths.

#### Scenario: Inactive profile can be deleted

- Given two valid profiles exist and the target is not active
- When the user confirms deletion
- Then the target registry/path is removed or marked deleted according to the documented policy and it no longer appears in discovery

#### Scenario: Active/last profile deletion is protected

- Given the target is active or is the only remaining profile
- When deletion is requested
- Then the operation is rejected with a localized explanation and active data remains intact

### Requirement: Selection switches the running application coherently

Selecting a profile from startup, setup, sidebar, or settings MUST update the active pointer and application graph together, close the old database safely, open the new profile, and refresh route-visible identity.

Implementation evidence: Startup uses ProfileManager directly, UI taps are empty, and setActiveProfile currently requires an external restart.

#### Scenario: User switches profiles

- Given two profiles contain distinct company and invoice data
- When the user selects the second profile
- Then the app resolves the second database, updates the sidebar/company identity, and subsequent routes show only the second profile's data

#### Scenario: Corrupt or unavailable profile is recoverable

- Given a discovered profile cannot be opened
- When the user selects it
- Then the app keeps the current profile active, reports the failure, and offers a safe retry or removal path
