## ADDED Requirements

### Requirement: Settings controls change live persisted application state

The Settings workspace MUST expose and persist theme, locale, region/formatting, sidebar, company/tax, storage/privacy, and backup preferences; changes MUST update the running shell without restart where the design requires.

Implementation evidence: Theme persistence exists without a reachable UI, locale is fixed, and Settings renders only static text.

#### Scenario: Language switch retains context

- Given the user is on a filtered page with English supported
- When the user changes language in Settings
- Then visible navigation/header/state copy changes immediately, the current route/filter remains, and the preference survives restart

#### Scenario: Theme/privacy changes are durable

- Given the user changes theme or privacy mode
- When the setting is applied and the app reloads
- Then the shell and money surfaces reflect the choice consistently

### Requirement: Local-first backup and integrations report real outcomes

Backup, restore, privacy/export/delete, backend detection, and SMTP/integration controls MUST be reachable from Settings, default to the documented local-first behavior, validate safe paths, and report success only after the operation actually completes.

Implementation evidence: Backup functionality has no reachable workflow; SMTP testing accepts most hosts without a connection; external backup failures are not a usable settings state.

#### Scenario: A backup can be created and restored

- Given the user selects a valid local destination
- When backup and restore run
- Then the artifact is written/validated, the result appears in history/status, and a failed restore cannot replace the active database

#### Scenario: Integration failure is truthful

- Given SMTP/backend detection or an external backup is unavailable
- When the user tests it
- Then the UI reports the actual failure, keeps local operation available, and does not show a false success
