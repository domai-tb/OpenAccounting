## MODIFIED Requirements

### Requirement: Score-Based Matching

For each reviewed bank transaction, the system SHALL compute the maintained score against eligible persisted journal entries: 40 points when amount differs by at most 0.01 EUR, 30 points when dates differ by at most 7 days, and 30 points when partner similarity is greater than 80%. A candidate is eligible only when it has a valid persisted integer ID; invalid or unparsable candidate amount/date values contribute no points under the scorer. Before import confirmation, Review SHALL show the top score, its textual confidence label, and candidate date, amount, and description. Confidence labels SHALL be 90–100 high, 70–89 medium, 50–69 low, and 0–49 none. Color MUST NOT be the only indicator.

Suggestions SHALL not mutate accounting data before confirmation. In manual mode a score suggestion MUST NOT set `journal_id`; the user may explicitly select an existing journal entry in Review, persisted only after confirmation. In automatic mode, after explicit confirmation, the system SHALL link only when exactly one eligible candidate has the highest score and the score is at least 90. A tied top score remains unlinked; Review shows all candidates tied at the highest score with a deterministic display order of score descending then journal ID ascending. A candidate-query failure SHALL produce an unavailable state, never a fabricated `0%`/no-match state, and SHALL disable automatic linking for that import. The user may proceed after the unavailable warning and explicit import confirmation.

#### Scenario: High-confidence match

- **GIVEN** one eligible journal entry has amount within 0.01 EUR, date within 7 days, and partner similarity greater than 80%
- **WHEN** Review computes and displays suggestions before confirmation
- **THEN** it shows that entry with score `100%`, the localized high-confidence label, date, amount, and description without changing `journal_id`

#### Scenario: No match

- **GIVEN** a successful candidate query returns no eligible entry or no candidate scores above zero
- **WHEN** Review displays the transaction in manual mode
- **THEN** it shows score `0%`, the localized no-match confidence label, an explicit no-match state, and no journal association

#### Scenario: Tied top candidates are not auto-linked

- **GIVEN** two eligible journal entries share the same highest score of at least 90
- **WHEN** the user confirms an automatic-mode import
- **THEN** the transaction remains unlinked and Review had shown both tied candidates ordered by journal ID ascending

#### Scenario: Candidate query failure is not a no-match

- **GIVEN** loading candidate journal entries fails
- **WHEN** Review renders in automatic mode
- **THEN** it shows a localized unavailable state rather than `0%` or a no-match label, automatic linking is disabled, and the warning is visible before explicit import confirmation

### Requirement: Auto-Filter Rule CRUD

The system SHALL provide a localized, keyboard-accessible Banking view for persisted category rules in `auto_filter_regeln`. A rule SHALL contain a non-empty trimmed Verwendungszweck substring pattern, an existing category ID, an integer priority, and an active flag. The system SHALL validate these values at the repository boundary before insert/update. Matching SHALL be case-insensitive substring matching against Verwendungszweck only. Active rules SHALL be evaluated by priority descending then rule ID ascending; the first matching active rule wins. Create, edit, priority change, enable/disable, and delete SHALL affect future imports only and MUST NOT rewrite prior transactions. Review SHALL show the category assigned by a rule before confirmation.

#### Scenario: Create filter rule

- **GIVEN** the user is on Banking Rules and selects an existing category
- **WHEN** the user saves pattern `Amazon` and an integer priority
- **THEN** the rule is persisted and future matching imports receive its category in rule order

#### Scenario: Reject an invalid filter rule

- **GIVEN** the user submits a blank pattern, missing category, unknown category, or non-integer priority
- **WHEN** the repository validates the rule
- **THEN** it rejects the write with a field-specific localized validation error and persists no rule change

#### Scenario: Equal-priority rules use rule ID order

- **GIVEN** two active rules with equal priority both match a transaction
- **WHEN** the rule matcher assigns a category
- **THEN** the rule with the lower ID wins and the same result is shown in Review before confirmation

#### Scenario: Edit and prioritize a rule

- **GIVEN** an active rule exists with a category and priority
- **WHEN** the user edits its category or priority
- **THEN** later imports use the saved values in priority-descending and ID-ascending order while existing transactions remain unchanged

#### Scenario: Delete filter rule

- **GIVEN** an active rule currently classifies matching transactions
- **WHEN** the user disables or deletes it
- **THEN** it no longer classifies later imports and previously imported rows remain unchanged

### Requirement: Custom Template Creation

The Banking workspace SHALL allow a user to create and edit profile-scoped custom CSV templates stored in `bank_templates`. A template SHALL define a trimmed display name, a stable unique type identifier, either comma or semicolon delimiter, UTF-8 or ISO-8859-1 encoding, a `dd.MM.yyyy` or `yyyy-MM-dd` date-format hint, and source-header mappings for `datum`, `betrag`, and `verwendungszweck`; `partner` and `gegenkonto` mappings MAY be optional. The repository SHALL reject blank names, duplicate names within the active profile, unsupported delimiters/encodings/date formats, missing required mappings, duplicate type identifiers, and type identifiers that collide case-insensitively with predefined template types. The application SHALL generate the custom type identifier in a reserved namespace, and it SHALL remain stable when the display name or configuration is edited. Custom templates SHALL be reusable by later imports. Editing configuration SHALL affect future imports only; it MUST NOT rewrite existing import history or transactions. Predefined templates, including the CAMT.053 template, SHALL not be edited or removed through custom-template controls. Existing import rows SHALL retain their associated type when a custom template is edited.

#### Scenario: Create custom template

- **GIVEN** the user is in Banking template management
- **WHEN** the user saves a unique name, supported CSV delimiter/encoding/date hint, and mappings for date, amount, and purpose
- **THEN** the custom template is persisted in the active profile and is selectable for a later CSV import

#### Scenario: Reject invalid or colliding custom template

- **GIVEN** a custom template has a blank or duplicate name, missing required mapping, unsupported configuration, or a type identifier colliding with an existing/predefined template
- **WHEN** the repository validates the save
- **THEN** it returns a localized field-specific error and persists no template change

#### Scenario: Edit existing template

- **GIVEN** an existing custom template has prior import history
- **WHEN** the user edits its display name, delimiter, encoding, date hint, or field mapping
- **THEN** its stable type identifier remains unchanged, later imports use the saved configuration, and prior history/transactions remain unchanged

#### Scenario: Predefined templates are protected

- **GIVEN** the user opens template management
- **WHEN** predefined CSV or CAMT.053 templates are listed
- **THEN** they can be selected for imports but have no custom edit or removal action

### Requirement: Manual vs Automatic Mode

The active profile SHALL persist its mode in `unternehmen.bank_import_manuell` as integer `1` for manual and `0` for automatic. The column SHALL be `NOT NULL`, constrained to `0` or `1`, and default to `1`. Fresh schema creation SHALL include it at schema version 9. The ordered migration from version 8 to 9 SHALL add the column with manual default while preserving company data. No runtime workflow or post-migration `ensureOpen` fallback may create the column. A profile without a company row or without a resolved setting SHALL use manual mode. The Banking route SHALL obtain and change the mode through the application-scope use case and repository.

Both modes SHALL require the existing explicit Review confirmation. Automatic mode SHALL only associate a transaction with one unique existing journal candidate scoring at least 90%; it SHALL NOT create a journal entry or payment. Tied, lower-confidence, missing, or unavailable candidates remain unlinked automatically. Manual mode SHALL leave suggestions unlinked unless the user explicitly selects an existing journal entry. Posting or payment creation remains subject to `balanced-journal-postings-and-settlement-events`.

#### Scenario: Missing profile mode defaults to manual

- **GIVEN** a new profile database is created
- **WHEN** schema creation completes at version 9 and Banking loads
- **THEN** `bank_import_manuell` exists with value `1` when read and the UI shows manual mode

#### Scenario: Version-8 profile migrates without changing company data

- **GIVEN** an existing version-8 database has a company row and accounting data
- **WHEN** the ordered version-9 migration runs
- **THEN** the new column is `1`, prior company/accounting values are unchanged, and the database version is 9

#### Scenario: Failed mode migration rolls back

- **GIVEN** the version-9 mode-column migration fails
- **WHEN** profile startup reports the migration failure
- **THEN** the version remains 8, the existing company data remains intact, and Banking does not run against the missing column

#### Scenario: Automatic mode

- **GIVEN** the profile mode is automatic and a confirmed transaction has one unique top candidate scoring at least 90
- **WHEN** import persistence rechecks candidates
- **THEN** the transaction links to that existing journal entry and creates no journal entry or payment

#### Scenario: Manual mode

- **GIVEN** the profile mode is manual and a transaction has a score suggestion
- **WHEN** the user confirms the import
- **THEN** the suggestion does not set `journal_id` and no journal entry or payment is created

#### Scenario: Import mode remains profile-scoped

- **GIVEN** profile A is automatic and profile B is manual
- **WHEN** the active profile changes from A to B
- **THEN** Banking reads B's manual setting without changing A's setting

### Requirement: Per-Session Import Mode Override

Each staged import SHALL begin with the active profile's persisted mode. The user may select a one-import override without changing that setting. The override SHALL be discarded when that staged import completes, fails, is cancelled or restarted, or the active profile changes. It SHALL NOT affect another profile. Both effective modes still require explicit import confirmation.

#### Scenario: Override for single import

- **GIVEN** the saved profile mode is automatic
- **WHEN** the user selects manual for this import and confirms
- **THEN** this import uses manual mode and the saved profile value remains automatic

#### Scenario: Override does not persist

- **GIVEN** a one-import override was selected
- **WHEN** that import succeeds, fails, or is cancelled and another import begins
- **THEN** the next import uses the saved profile mode unless the user selects another override

### Requirement: Banking workspace follows the design system

The production Banking page SHALL resolve its workspace use case through `AppScope`/`AppServices`; rule, mode, history, retry, and review reads/writes SHALL pass through typed repository and data-source boundaries. The page MUST NOT construct repositories, access query executors, or issue raw SQL. Review, Rules, and history SHALL use implemented design-system components (`AppPage`, `AppPageHeader`, `AppStatusChip`) with Flutter's existing table, form, focus, and layout widgets. The feature SHALL NOT depend on undocumented implementations of `AppDataTable`, `FilterBar`, or `DetailInspector`.

New labels, errors, validation, empty/loading/unavailable states, tooltips, and semantic descriptions SHALL use generated localization resources. Confidence/status SHALL have textual or semantic meaning beyond color. Every control SHALL be keyboard accessible with logical focus order and visible focus. Focus SHALL return to the invoking row/control when a detail surface closes. Layout SHALL adapt to documented breakpoints without hiding actions or causing page-level horizontal overflow; a wide table MAY scroll in a bounded content area. German text expansion and text scaling SHALL remain readable at the specified widths.

#### Scenario: Banking resolves the typed use case

- **GIVEN** the production application graph is ready
- **WHEN** the user opens Banking and loads rules, history, and Review
- **THEN** each operation calls the registered Banking use case and no page-level SQL or repository construction occurs

#### Scenario: Rule controls work from the keyboard

- **GIVEN** Banking Rules is open with visible keyboard focus
- **WHEN** the user creates, edits, changes priority, toggles, or deletes a rule using the keyboard
- **THEN** each action is available in logical order, has an accessible localized name, and focus returns to the invoking row after the edit surface closes

#### Scenario: History and review controls work from the keyboard

- **GIVEN** history detail or an unresolved transaction is open
- **WHEN** the user opens/closes detail, retries failed rows, changes a category, associates an existing journal entry, searches, or changes page using the keyboard
- **THEN** each action is reachable, has an accessible localized name, and focus returns to the invoking row/control after navigation

#### Scenario: Narrow banking window keeps actions reachable

- **GIVEN** Banking is rendered at 800 by 700 logical pixels in German with increased text scale
- **WHEN** the user opens Review, Rules, history, detail, retry, and manual review
- **THEN** translated labels remain readable, actions remain reachable, focus is visible, and there is no page-level horizontal overflow

#### Scenario: Desktop banking views expose localized accessible controls

- **GIVEN** Banking is rendered at 1280 by 800 logical pixels in English
- **WHEN** the user opens Review, Rules, and history
- **THEN** visible strings and semantic descriptions are generated English resources and all actions remain keyboard reachable with visible focus

### Requirement: Bank Transactions Table

The system SHALL store imported transactions in `bank_transaktionen` with fields `id`, `konto_id`, `import_id`, `datum`, `betrag`, `verwendungszweck`, `gegenkonto`, `gegenkonto_name`, `kategorie_id`, `journal_id`, `dedupe_hash`, and `status`. `journal_id` SHALL reference only an existing journal entry. The existing `status` text column SHALL use exactly `neu`, `geprueft`, and `gebucht`. `neu` means awaiting explicit post-import review; `geprueft` means the user explicitly categorized/reviewed the transaction without associating a journal entry; `gebucht` means it is associated with an existing journal entry. A rule-assigned category without an explicit user decision remains `neu`. A category selected by the user during import is `geprueft` unless an existing journal entry is selected, in which case it is `gebucht`. No schema column is added for this state. Post-import review SHALL query only `neu` rows; confirming a category changes the row to `geprueft`, and associating an existing journal entry changes it to `gebucht`. A row cannot leave `neu` without a category or an existing journal link.

#### Scenario: Transaction linked to journal entry

- **GIVEN** a confirmed imported transaction is explicitly associated with an existing journal entry
- **WHEN** the import completes
- **THEN** `journal_id` references that entry, status is `gebucht`, and no journal entry or payment is created

#### Scenario: Transaction stored without journal link

- **GIVEN** a confirmed imported transaction has no selected existing journal entry
- **WHEN** the import completes
- **THEN** it is stored with its imported fields and `journal_id` is null

#### Scenario: Import assigns row review status from its decisions

- **GIVEN** a row has a rule-assigned category, a user-selected category, no category, or an existing journal link
- **WHEN** the confirmed import stores the row
- **THEN** the respective status is `neu`, `geprueft`, `neu`, or `gebucht`, with `gebucht` taking precedence when linked

#### Scenario: Automatic mode does not link a low-confidence candidate

- **GIVEN** the profile mode is automatic and a unique top candidate scores below 90
- **WHEN** the user confirms the import
- **THEN** the row remains without a journal link and no journal entry or payment is created

#### Scenario: Explicit review closes a new row

- **GIVEN** an imported row has status `neu`
- **WHEN** the user confirms a category or selects an existing journal entry in post-import review
- **THEN** its status becomes `geprueft` or `gebucht`, respectively, and it is absent from later unresolved-review queries
