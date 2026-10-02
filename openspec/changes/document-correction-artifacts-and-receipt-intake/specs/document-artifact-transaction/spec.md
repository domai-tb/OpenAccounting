## MODIFIED Requirements

### Requirement: Atomic artifact and side-effect transaction

The lifecycle owner SHALL generate bytes from an immutable snapshot, write a unique profile-local temporary file, verify readability, atomically rename it, and persist its path only after success. This requirement applies to every operation that transitions a document to finalized, including Storno, Gutschrift, replacement, and conversion results. A draft result SHALL remain editable and SHALL NOT claim a finalized artifact path. Database and filesystem writes are not one atomic transaction; a persisted recovery routine SHALL reconcile them at startup. It SHALL remove owned temporary files and generated files with no committed document reference, and mark a committed document with a missing or unreadable artifact as unavailable for repair. Unknown files SHALL NOT be deleted. The side-effect matrix SHALL be: Rechnung may create receivable/journal/inventory effects; Storno reverses effects linked to the source; Gutschrift records its defined credit/reversal effects; Ersatzrechnung uses the normal invoice lifecycle when it is finalized; Angebot/Auftrag/Proforma/Lieferschein are document-only unless an existing document-type rule explicitly defines otherwise; Mahnung creates dunning state and an artifact. This requirement does not define monetary formulas, correction signs, tax treatment, or legal retention policy.

#### Scenario: Finalized invoice commits artifact and effects
- **GIVEN** a valid invoice and active profile root
- **WHEN** finalization succeeds
- **THEN** the readable PDF path and the invoice's defined receivable/journal/inventory effects commit together

#### Scenario: Writer failure rolls back
- **GIVEN** PDF generation, write, or readability verification fails
- **WHEN** finalization handles the failure
- **THEN** no path or temporary file remains and numbering, document, journal, receivable, and inventory state remain unchanged

#### Scenario: Process crash before artifact rename is reconciled
- **GIVEN** the process stops after writing a temporary artifact but before renaming it or committing the document
- **WHEN** the application next starts
- **THEN** the document remains unfinalized, owned temporary bytes are removed, and no number, path, or side effect is claimed

#### Scenario: Process crash after rename but before database commit is reconciled
- **GIVEN** the process stops after renaming a generated artifact but before the document transaction commits
- **WHEN** the application next starts
- **THEN** the document remains unfinalized, the unreferenced file under the owned artifact directory is removed, and unrelated files remain unchanged

#### Scenario: Missing committed artifact is reported
- **GIVEN** a finalized document references a missing or unreadable artifact
- **WHEN** startup reconciliation or the document detail checks the artifact
- **THEN** the artifact is marked unavailable, the document is not shown as export-complete, and the user receives a repairable error state

#### Scenario: Finalized correction has a readable artifact
- **GIVEN** an eligible finalized invoice is reversed through the supported correction lifecycle
- **WHEN** the correction operation succeeds
- **THEN** the correction has a readable profile-local PDF rendered from its own finalized snapshot, the source relationship and numbering are persisted, and type-specific side effects match the existing lifecycle contract

#### Scenario: Correction artifact failure leaves no false finalization
- **GIVEN** a correction or finalized conversion cannot generate or persist its PDF
- **WHEN** the lifecycle operation handles the failure
- **THEN** it leaves no finalized record pointing to a nonexistent artifact and rolls back the operation's numbering, relationship, and type-specific side effects
