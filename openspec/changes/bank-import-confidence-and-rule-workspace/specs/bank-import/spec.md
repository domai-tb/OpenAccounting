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

The system SHALL provide a localized, keyboard-accessible rule-management view within Banking for the persisted category rules supported by this specification. Users SHALL be able to list, create, edit, prioritize, enable or disable, and delete rules containing a Verwendungszweck pattern and category. Rule changes SHALL persist and affect future imports only; they SHALL NOT rewrite prior imported transactions. Active rules SHALL be evaluated by descending priority and then ascending rule ID using the maintained case-insensitive Verwendungszweck substring matcher, and the Review row SHALL show the assigned category before confirmation.

#### Scenario: Create filter rule

- **GIVEN** the user is on the filter rules screen and selects a valid category
- **WHEN** the user creates a rule with pattern "Amazon" → category "Büromaterial"
- **THEN** the rule is persisted with the requested values and future imports apply it to matching transactions in priority order

#### Scenario: Edit and prioritize filter rule

- **GIVEN** an active rule exists with a category and priority
- **WHEN** the user edits the category or priority
- **THEN** future imports use the saved category and evaluate this active rule according to descending priority and ascending rule ID

#### Scenario: Delete filter rule

- **GIVEN** a filter rule exists for pattern "Amazon" and currently classifies matching transactions
- **WHEN** the user deletes the rule
- **THEN** it no longer applies to future imports and previously imported rows remain unchanged

#### Scenario: Disabled rule no longer classifies new rows

- **GIVEN** an enabled rule currently classifies matching transactions
- **WHEN** the user disables the rule
- **THEN** a later import no longer receives that rule's category and previously imported rows remain unchanged

### Requirement: Manual vs Automatic Mode

The active profile SHALL persist its import mode in `unternehmen.bank_import_manuell`, defaulting to manual when the
setting is absent. Banking SHALL show the effective mode before import confirmation and pass it to the import service.
Automatic mode SHALL link a transaction to an existing journal entry only when its score is at least 90%; it SHALL NOT
create a journal entry or payment. Manual mode SHALL leave score suggestions unlinked and require review. Creating new
postings or applying payments remains subject to `balanced-journal-postings-and-settlement-events`.

#### Scenario: Automatic mode

GIVEN the profile import mode is "automatisch"
WHEN a transaction score is at least 90% and a candidate journal entry exists
THEN the import links the transaction to that existing journal entry and creates no new journal entry or payment.

#### Scenario: Manual mode

GIVEN the profile import mode is "manuell"
WHEN any transaction is imported
THEN all transactions require manual confirmation in Review and a score suggestion does not set `journal_id`.

#### Scenario: Missing profile mode defaults to manual

GIVEN an existing profile has no saved bank import mode
WHEN the user opens Banking after the migration
THEN manual mode is selected and no transaction can be auto-linked.

#### Scenario: Import mode remains profile-scoped

GIVEN profile A is automatic and profile B is manual
WHEN the user switches from profile A to profile B
THEN Banking uses profile B's manual mode without changing profile A's saved setting.

#### Scenario: Automatic mode does not link a low-confidence candidate

GIVEN the profile mode is "automatisch" and the best candidate scores below 90%
WHEN the import is confirmed
THEN the transaction remains unlinked and no new journal entry or payment is created.

### Requirement: Banking workspace follows the design system

The import Review, Rules, and history views SHALL use the established page, header, table, filter, status, spacing,
button, and inspector components and tokens required by `DESIGN.md`. New labels, errors, empty/loading states, tooltips,
and semantic descriptions SHALL use generated localization resources. Confidence and row status SHALL include text or
accessible semantics and SHALL not depend on color alone. All controls SHALL support keyboard use, logical focus order,
and visible focus. Layouts SHALL adapt to the documented window breakpoints without hiding actions or causing horizontal
overflow; wide transaction tables MAY scroll within their own bounded region.

#### Scenario: Desktop banking views expose localized accessible controls

GIVEN Banking is rendered at 1280 by 800 logical pixels with English selected
WHEN the user opens Review, Rules, and import history
THEN the established components render each view, visible labels and semantic descriptions use English, and all actions have keyboard-accessible names and visible focus.

#### Scenario: Narrow banking window keeps actions reachable

GIVEN Banking is rendered at 800 by 700 logical pixels with German selected
WHEN the user opens Review, Rules, and import history
THEN controls wrap or scroll within their content region, no page-level horizontal overflow occurs, and mode, rule, detail, retry, and review actions remain reachable by keyboard.

### Requirement: Per-Session Import Mode Override

The system SHALL allow a one-import mode override without changing the active profile's persisted setting. The selected
override SHALL be reset when the next import begins and SHALL NOT affect another profile.

#### Scenario: Override for single import

GIVEN the profile mode is "automatisch"
WHEN the user selects "Manuell für diesen Import"
THEN this import uses manual mode while the profile setting remains automatic.

#### Scenario: Override does not persist

GIVEN a one-import override was used
WHEN the next import begins
THEN the active profile's saved mode is applied again.
