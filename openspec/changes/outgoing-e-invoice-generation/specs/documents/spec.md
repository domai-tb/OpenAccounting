## MODIFIED Requirements

### Requirement: Document Lifecycle — Finalization

Finalization is an irreversible action that MUST: set `ist_entwurf` to false, assign a `nummer` from the `nummernkreis`, lock all fields against further editing, generate the PDF, store the `Absender_snapshot` (company data at finalization time), and record `ausgegeben_am` (first print/email timestamp). For an ordinary outgoing Rechnung, finalization MUST atomically persist the explicitly selected `ausgabeformat` enum (`pdf`, `zugferd`, or `xrechnung`) with the assigned number and finalized state. Finalization MUST be confirmed by the user via a confirmation dialog. A schema migration SHALL backfill existing finalized invoices to `pdf`; readers encountering a missing legacy value MUST resolve it to `pdf`, not the customer's current setting.

#### Scenario: Finalization locks document

- **GIVEN** a user finalizes a draft Rechnung
- **WHEN** finalization completes
- **THEN** the number is assigned, `ist_entwurf` becomes false, all form fields become read-only, the selected output format is persisted, and the PDF is generated and stored

#### Scenario: Finalization captures company snapshot

- **GIVEN** a Rechnung is in draft state and company address is "Musterstraße 1"
- **WHEN** the Rechnung is finalized
- **THEN** `absender_snapshot` contains the company address "Musterstraße 1", and a subsequent company address change does not affect the finalized PDF

#### Scenario: Re-finalization blocked

- **GIVEN** a Rechnung has been finalized (`ist_entwurf = false`)
- **WHEN** a user attempts to finalize it again
- **THEN** the system rejects the action with error "Dokument ist bereits finalisiert"

#### Scenario: Legacy finalized invoice defaults to PDF

- **GIVEN** a finalized invoice from before the output-format migration has no saved `ausgabeformat`
- **WHEN** the migration or finalized-detail read runs
- **THEN** `ausgabeformat` resolves to `pdf` without consulting the customer's current ZUGFeRD setting
