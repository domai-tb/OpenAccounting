## ADDED Requirements

### Requirement: Flutter source-of-truth documentation

Project documentation SHALL describe the current Flutter/Dart, Riverpod, Drift, local-first architecture and SHALL not claim FastAPI, React/Vite, Tailwind, Tauri, webview, or Python sidecar behavior unless a separate approved change restores that architecture.

#### Scenario: Architecture links match source
- **GIVEN** a contributor reads the invoice or dashboard documentation
- **WHEN** they follow setup and architecture instructions
- **THEN** the documented commands, routes, dependencies, and runtime components SHALL match the Flutter source tree

#### Scenario: Stale architecture is detected
- **GIVEN** documentation contains an obsolete architecture identifier
- **WHEN** documentation parity checks run
- **THEN** the check SHALL fail with the file and identifier requiring correction

### Requirement: Desktop specifications are semantically consistent

Active desktop specifications SHALL agree that Flutter desktop is the source of truth, SHALL define target-specific fallbacks, and SHALL not contain contradictory Tauri/Python-sidecar requirements. Mechanical strict validation and a semantic contradiction check SHALL pass before the change is accepted.

#### Scenario: Desktop specs agree
- **GIVEN** the active desktop specifications are loaded
- **WHEN** the parity check runs
- **THEN** all desktop requirements SHALL name the same Flutter runtime contract and supported fallback behavior

#### Scenario: Contradictory spec is rejected
- **GIVEN** one active desktop spec requires Tauri while another forbids it
- **WHEN** the parity check runs
- **THEN** validation SHALL fail and identify both conflicting requirements
