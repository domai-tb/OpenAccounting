## ADDED Requirements

### Requirement: Pinned analysis is clean

The repository MUST pass fvm flutter analyze with zero diagnostics under the pinned Flutter version, including removal/replacement of deprecated lint rules and unused or dead production paths.

Implementation evidence: The current analyzer run exits 1 with 255 diagnostics, so the documented strict-lint gate is not currently usable.

#### Scenario: Analyzer gate passes

- Given the repository is checked with the pinned FVM toolchain
- When fvm flutter analyze runs
- Then it exits zero and emits no warnings, infos, or errors

#### Scenario: New diagnostics block acceptance

- Given a change introduces a lint or deprecated API warning
- When the analyzer gate runs
- Then the gate fails with the source location before the change can be accepted

### Requirement: Integration tests exercise production composition

Release-facing tests MUST instantiate the production app/composition, use real feature interfaces with injected fakes only at external boundaries, and fail when routes render placeholders, providers query an unopened database, or command callbacks are inert.

Implementation evidence: Current tests pass against local shortcut helpers and placeholder strings, while shell/dashboard tests emit uninitialized database errors.

#### Scenario: Route smoke tests prove reachability

- Given a test profile contains representative records
- When each primary route and command is exercised
- Then the test observes a real page/use-case side effect and not only a route title or placeholder string

#### Scenario: Runtime provider errors fail tests

- Given a dashboard or route dependency is not ready
- When the production app is rendered
- Then the test fails on the readiness error/log rather than accepting a fallback with hidden exception output
