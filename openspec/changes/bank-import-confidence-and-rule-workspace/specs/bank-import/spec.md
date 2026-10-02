## MODIFIED Requirements

### Requirement: Score-Based Matching

The system SHALL compute a score from 0 to 100 for each reviewed bank transaction against candidate journal entries. The maintained scoring contract SHALL award 40 points when amounts differ by at most 0.01€, 30 points when dates differ by at most 7 days, and 30 points when partner similarity is greater than 80%. Before import confirmation, Review SHALL display the best score as a percentage with a textual confidence label, and, when a candidate exists, enough candidate information to distinguish its date, amount, and description. Confidence labels SHALL use the documented ranges: 90–100 high, 70–89 medium, 50–69 low, and 0–49 none; color MUST NOT be the only indicator. Scores are suggestions; in manual mode they MUST NOT set `journal_id` or apply a payment. Existing automatic-mode behavior remains governed by the import-mode requirements and is unavailable for posting or settlement side effects until the balanced-posting dependency is complete.

#### Scenario: High-confidence match

- **GIVEN** an existing journal entry has amount within 0.01€, date within 7 days, and partner name similarity greater than 80%
- **WHEN** the system computes the matching score and the Review rows render
- **THEN** the entry is suggested with confidence score `100%` and textual label `Hoch` before import confirmation, and its date, amount, and description are visible

#### Scenario: No match

- **GIVEN** no entry satisfies any scoring factor
- **WHEN** the system computes matching scores and the Review rows render in manual mode
- **THEN** the row displays score `0%`, textual label `Keine`, a no-match state, and no journal association

### Requirement: Auto-Filter Rule CRUD

The system SHALL provide an accessible rule-management view within Banking for the persisted category rules supported by this specification. Users SHALL be able to list, create, edit, prioritize, enable or disable, and delete rules containing a Verwendungszweck pattern and category. Rule changes SHALL persist and affect future imports only; they SHALL NOT rewrite prior imported transactions. Active rules SHALL be evaluated by descending priority and then ascending rule ID using the maintained case-insensitive Verwendungszweck substring matcher, and the Review row SHALL show the assigned category before confirmation.

#### Scenario: Create filter rule

- **GIVEN** the user is on the filter rules screen and selects a valid category
- **WHEN** the user creates a rule with pattern "Amazon" → category "Büromaterial", then edits its category or priority
- **THEN** the rule is persisted with the edited values and future imports apply the saved rule to matching transactions in priority order

#### Scenario: Delete filter rule

- **GIVEN** a filter rule exists for pattern "Amazon" and currently classifies matching transactions
- **WHEN** the user deletes the rule
- **THEN** it no longer applies to future imports and previously imported rows remain unchanged

#### Scenario: Disabled rule no longer classifies new rows

- **GIVEN** an enabled rule currently classifies matching transactions
- **WHEN** the user disables the rule
- **THEN** a later import no longer receives that rule's category and previously imported rows remain unchanged
