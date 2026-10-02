## MODIFIED Requirements

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
