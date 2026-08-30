# Bank Import

## ADDED Requirements

### Requirement: 3-Step Import Workflow

The system SHALL guide the user through Upload → Review → Import. Each step MUST validate before advancing.

#### Scenario: Upload step completes

GIVEN a user has selected a bank file and a matching template
WHEN the user uploads the file
THEN the system parses the file and displays raw transaction count without importing.

#### Scenario: Upload fails with invalid file

GIVEN a user selects a file that cannot be parsed by any template
WHEN the user attempts to upload
THEN the system displays an error message and prevents advancement to Review.

### Requirement: Bank Templates

The system SHALL provide predefined templates for common German banks: Sparkasse, PayPal, N26, Vivid, ING, DKB, Commerzbank.

#### Scenario: Predefined template selection

GIVEN predefined templates exist in the system
WHEN the user selects a predefined bank template
THEN delimiter, encoding, header mapping, and date format are applied automatically.

#### Scenario: No template matches uploaded file

GIVEN a user uploads a file that does not match any predefined or custom template
WHEN the system attempts to parse the file
THEN the system displays a template-selection prompt and blocks progression.

### Requirement: Custom Template Creation

The system SHALL allow users to create custom templates with field mapping, delimiter selection, and encoding choice.

#### Scenario: Create custom template

GIVEN the user is on the template management screen
WHEN the user creates a template with CSV delimiter ";", encoding "UTF-8", and field mapping for Datum, Betrag, Verwendungszweck
THEN the template is saved and reusable for future imports.

#### Scenario: Edit existing template

GIVEN a custom template exists with saved mappings
WHEN the user edits the template
THEN changes apply to all future imports using that template and existing mappings are overwritten.

### Requirement: CAMT XML Import

The system SHALL support CAMT.053 XML import. Transactions MUST be extracted from `<Ntry>` elements.

#### Scenario: Upload CAMT XML

GIVEN the system supports CAMT.053 format
WHEN the user uploads a `.xml` file with CAMT namespace
THEN the system detects the format, parses entries, and displays them in Review.

#### Scenario: Upload non-CAMT XML

GIVEN a user uploads an XML file without CAMT namespace
WHEN the system attempts to detect the format
THEN the system rejects the file with a message indicating unsupported XML format.

### Requirement: Auto-Categorization Rules

The system SHALL support pattern-matching rules on Verwendungszweck field to assign journal `kategorie_id` automatically.

#### Scenario: Pattern match assigns category

GIVEN a rule exists mapping "Netflix" → "EDV / Software"
WHEN a transaction Verwendungszweck contains "Netflix"
THEN the category is pre-filled in Review.

#### Scenario: No pattern match

GIVEN no auto-categorization rule matches a transaction
WHEN the transaction is displayed in Review
THEN the category field remains empty for manual assignment.

### Requirement: Score-Based Matching

The system SHALL compute a matching score between imported transactions and existing invoices/journal entries based on amount, date proximity, and partner name.

#### Scenario: High-confidence match

GIVEN an existing journal entry with amount within 0.01€, date within 7 days, and partner name similarity > 80%
WHEN the system computes the matching score
THEN the system suggests the match with confidence score ≥ 90%.

#### Scenario: No match

GIVEN no existing entry is within threshold
WHEN the system computes matching scores
THEN the system leaves journal_id blank and marks the transaction as unmatched.

### Requirement: Deduplication

The system SHALL prevent duplicate imports using SHA-256 hash of (Datum + Betrag + Partner + Verwendungszweck).

#### Scenario: Duplicate detection

GIVEN a transaction with identical hash exists in `bank_transaktionen`
WHEN a new import contains the same transaction
THEN it is marked as duplicate and skipped during import.

#### Scenario: Manual override of duplicate

GIVEN a transaction is flagged as duplicate
WHEN the user marks it as "trotzdem importieren"
THEN it is imported with a new hash suffix and stored as a distinct entry.

### Requirement: Bank Transactions Table

The system SHALL store imported transactions in `bank_transaktionen` with fields: id, konto_id, datum, betrag, partner, verwendungszweck, kategorie_id, journal_id, dedupe_hash.

#### Scenario: Transaction linked to journal entry

GIVEN a transaction has been matched to a journal entry
WHEN the import completes
THEN `journal_id` is set and "Gebucht" badge displays.

#### Scenario: Transaction stored without journal link

GIVEN a transaction has no matching journal entry
WHEN the import completes
THEN `journal_id` is NULL and the transaction is stored with all other fields populated.

### Requirement: Manual vs Automatic Mode

The system SHALL support two import modes: automatic (Score ≥ 90% auto-booked) and manual (all entries require review).

#### Scenario: Automatic mode

GIVEN the import mode is "automatisch"
WHEN a transaction score ≥ 90%
THEN the transaction is booked directly to journal during import.

#### Scenario: Manual mode

GIVEN the import mode is "manuell"
WHEN any transaction is imported
THEN all transactions require manual confirmation in Review.

### Requirement: Per-Session Import Mode Override

The system SHALL allow per-import mode override without changing the persistent setting.

#### Scenario: Override for single import

GIVEN the global import mode is "automatisch"
WHEN the user selects "Manuell für diesen Import"
THEN this import uses manual mode while the global setting remains automatic.

#### Scenario: Override does not persist

GIVEN a per-import override was used
WHEN the next import begins
THEN the global import mode is applied again.

### Requirement: Konto Selection Per Import

The system SHALL require the user to select which bank account (Konto) each import targets.

#### Scenario: Select target Konto

GIVEN the user is on the Upload step
WHEN they proceed past file upload
THEN they MUST select a Konto from the `konten` table before advancing to Review.

#### Scenario: No Konto selected

GIVEN the user has not selected a Konto
WHEN they attempt to advance to Review
THEN the system blocks progression with a validation error.

### Requirement: DATEV Export Compatibility

The system SHALL store transactions with fields sufficient for DATEV export: Datum, Betrag, Gegenkonto, Kontonummer, Belegnr, Verwendungszweck.

#### Scenario: Export to DATEV

GIVEN imported transactions with `journal_id` exist
WHEN the user triggers DATEV export
THEN all such transactions are included in the export file with correct DATEV field mapping.

#### Scenario: No exportable transactions

GIVEN no imported transactions have a `journal_id`
WHEN the user triggers DATEV export
THEN the system displays a message indicating no exportable transactions exist.

### Requirement: Import Protocol / History

The system SHALL maintain an import history with timestamp, template used, transaction count, duplicate count, and errors.

#### Scenario: View import history

GIVEN at least one import has been performed
WHEN the user opens import history
THEN they see a chronological list of all past imports with status.

#### Scenario: Empty import history

GIVEN no imports have been performed
WHEN the user opens import history
THEN the system displays an empty-state message indicating no prior imports.

### Requirement: Auto-Filter Rule CRUD

The system SHALL allow creating, reading, updating, and deleting auto-filter rules that assign categories based on Verwendungszweck patterns.

#### Scenario: Create filter rule

GIVEN the user is on the filter rules screen
WHEN the user creates a rule with pattern "Amazon" → category "Büromaterial"
THEN future imports apply this rule to matching transactions.

#### Scenario: Delete filter rule

GIVEN a filter rule exists for pattern "Amazon"
WHEN the user deletes the rule
THEN it no longer applies to future imports.

### Requirement: Transaction Classification Override

The system SHALL allow the user to override the auto-assigned category on any transaction in Review.

#### Scenario: Override category

GIVEN a transaction is auto-categorized as "Büromaterial"
WHEN the user changes category to "Sonstige Kosten"
THEN the override is saved with the transaction.

#### Scenario: Override reverts on re-import

GIVEN a transaction was manually recategorized during a prior import
WHEN the same transaction is imported again (different hash due to date change)
THEN the system applies auto-categorization rules anew, not the prior override.

### Requirement: Import Statistics

The system SHALL display statistics after import: total imported, duplicates skipped, auto-categorized count, manual review count.

#### Scenario: Post-import summary

GIVEN an import has completed
WHEN the system finishes processing
THEN the summary shows counts per status (imported, duplicate, auto-categorized, manual).

#### Scenario: Import with zero transactions

GIVEN an uploaded file contains zero valid transactions
WHEN import completes
THEN the summary shows 0 imported, 0 duplicates, and a message that no transactions were found.
