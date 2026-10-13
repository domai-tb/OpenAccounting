# setup-onboarding-integrity Specification

## Purpose
TBD - created by archiving change setup-onboarding-integrity. Update Purpose after archive.

## Requirements

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

The onboarding flow MUST either collect or clearly defer invoice numbering/payment terms, privacy/local-storage, and backup choices. A deferred choice MUST identify its later destination in Settings and SHALL NOT be represented as configured. The flow MUST NOT create demo credentials, synthetic financial identity, fabricated bank data, or a completion state that hides unfinished choices. This requirement follows the canonical four-step setup sequence and does not adopt the feature-map's alternate number-sequence step.

#### Scenario: Required first-run decisions are visible

- **GIVEN** a new profile opens setup and one or more first-run choices are deferred
- **WHEN** the user reviews the completion step and then opens Settings
- **THEN** the completion summary SHALL identify each deferred choice and provide a working destination to its owning Settings section or workspace

#### Scenario: Blank identity is handled honestly

- **GIVEN** the company, account, category, or settings source needed for a choice is unavailable
- **WHEN** setup renders that choice
- **THEN** the wizard SHALL show an explicit unavailable/deferred state and SHALL NOT claim a default was stored or synthesize a plausible value
