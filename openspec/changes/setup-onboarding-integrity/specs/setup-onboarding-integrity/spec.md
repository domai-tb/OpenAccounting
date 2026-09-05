## ADDED Requirements

### Requirement: Skip and Finish leave setup with durable state

A valid Finish or explicit Skip MUST persist a defined setup state, navigate to the dashboard, and remain outside setup after router recreation; blank optional data MUST not be replaced with fake IBAN/BIC or sentinel company values that trigger the guard.

Implementation evidence: Both handlers only show a snackbar, Skip creates Meine Firma, and the guard treats that name as unconfigured.

#### Scenario: Finish reaches the dashboard

- Given required company/account values pass validation
- When the user presses Fertig
- Then setup state is committed, the route changes to the dashboard, and a recreated router does not redirect back to setup

#### Scenario: Skip follows its documented policy

- Given the user chooses Überspringen on a fresh profile
- When the skip action completes and the app restarts
- Then the app either reaches the documented usable dashboard policy or remains in a clearly resumable setup state, never an endless sentinel redirect

### Requirement: Setup writes an atomic, accounting-safe opening state

Setup MUST commit company data, account creation, category selection, setup completion, and opening balances as one recoverable operation; opening cash MUST affect the account balance without becoming ordinary income.

Implementation evidence: Completion awaits separate writes with no rollback, and ensureKassenKonto inserts an Einnahme journal while leaving saldo zero; category selection validation does not persist selection.

#### Scenario: Opening cash agrees across sources

- Given setup includes a 500 euro opening cash balance
- When setup succeeds and the dashboard loads
- Then the cash account balance and opening ledger agree at 500 euro and the amount is not counted as revenue

#### Scenario: Intermediate failure rolls back

- Given a category/account write fails after company data is stored
- When setup completion handles the failure
- Then no partial setup is marked complete and a retry can run without duplicate accounts or opening entries

### Requirement: First-run concepts are explicit and non-deceptive

The onboarding flow MUST either collect or clearly defer invoice numbering/payment terms, privacy/local-storage, and backup choices described by the design, and MUST never create demo credentials or synthetic financial identity as a hidden fallback.

Implementation evidence: The current wizard has four steps and no visible controls for those concepts; empty IBAN fields receive fake fallback values.

#### Scenario: Required first-run decisions are visible

- Given a new profile opens the wizard
- When the user reviews its steps
- Then the documented concepts are represented by controls or an explicit deferred-state explanation with a path to complete them later

#### Scenario: Blank identity is handled honestly

- Given the user leaves optional bank identity blank
- When setup saves
- Then the state records absence or asks for correction and never stores a plausible-looking fake IBAN/BIC
