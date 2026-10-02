## MODIFIED Requirements

### Requirement: Kunden-Belege

Each customer MAY have associated Belege (customer documents: contracts, certificates, etc.). Each Beleg has id,
kunde_id FK, dateiname, original_name, mime_type, dateigroesse, sha256, hochgeladen_am, and loeschdatum (DATE,
nullable for DSGVO). The system MUST provide upload, inline preview, rename, and delete operations. Removing a customer
document from the customer record SHALL remove only its `kunden_belege` association and SHALL NOT delete shared Beleg
metadata or source bytes. Deleting the underlying Beleg SHALL require all customer, supplier, invoice, journal, template,
and package relationships to be explicitly removed first, as defined by the `documents` capability. Documents past
their loeschdatum MUST be flagged visually (red if overdue, yellow if ≤ 30 days); the date is informational and MUST
NOT trigger automatic purge until a retention policy is accepted.

#### Scenario: Customer document is unlinked without deleting evidence
- **GIVEN** a customer document is backed by a Beleg that has another active relationship
- **WHEN** the user removes the document from the customer record
- **THEN** the customer association is removed while the Beleg metadata, source bytes, and other relationship remain
  unchanged

#### Scenario: Customer document remains after its due date
- **GIVEN** a customer document has a loeschdatum in the past
- **WHEN** the application starts or displays the customer document list
- **THEN** the maintained overdue warning is shown and the source remains available without automatic deletion

#### Scenario: DSGVO expiry warning
- GIVEN a customer document has loeschdatum = 2026-02-15 and today is 2026-02-10
- WHEN the customer document list is rendered
- THEN the document is displayed with a yellow warning badge "Löschen in 5 Tagen"

#### Scenario: DSGVO overdue flag
- GIVEN a customer document has loeschdatum = 2026-02-15 and today is 2026-02-20
- WHEN the customer document list is rendered
- THEN the document is displayed with a red warning badge indicating it is overdue for deletion
