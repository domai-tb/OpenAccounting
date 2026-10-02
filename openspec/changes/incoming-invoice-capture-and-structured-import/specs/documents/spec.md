## MODIFIED Requirements

### Requirement: Document Lifecycle — Entwurf

Every document MUST begin in Entwurf (draft) state with ist_entwurf = true. Drafts MUST be fully editable: fields can be changed, positions added/removed, and the document can be deleted. Drafts MUST NOT appear in financial reports (EÜR, UStVA, EKS), MUST NOT affect stock levels, and MUST NOT be sent to customers. Outgoing Rechnung, incoming `rechnung_eingang`, Angebot, Auftrag, and Proforma support draft mode; Lieferschein and Storno are created finalized. Draft forms SHALL follow the labeled, sectioned, validation, and explicit-save behavior in DESIGN.md §§15 and 25.

#### Scenario: Draft not in EÜR
- **GIVEN** a Rechnung in Entwurf state has a total of 5000 EUR
- **WHEN** the Eür report is generated
- **THEN** this Rechnung is not included in the report

#### Scenario: Draft editable
- **GIVEN** a user opens a draft Rechnung
- **WHEN** the user modifies positions, dates, and text fields
- **THEN** all changes are saved and the document remains in Entwurf state

#### Scenario: Incoming invoice supports draft state
- **GIVEN** a supplier invoice is captured as an incoming `rechnung_eingang`
- **WHEN** the user saves the capture
- **THEN** the invoice remains editable with `ist_entwurf = true` and status `entwurf`
- **AND** finalization-owned effects do not run

#### Scenario: Lieferschein created without draft state
- **GIVEN** a user creates a new Lieferschein
- **WHEN** the Lieferschein is saved
- **THEN** ist_entwurf is false and the document is finalized immediately (no draft mode)
