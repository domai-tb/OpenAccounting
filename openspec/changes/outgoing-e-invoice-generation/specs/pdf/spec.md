## MODIFIED Requirements

### Requirement: ZUGFeRD and XRechnung E-Invoicing

The system SHALL generate ZUGFeRD 2.5.2 `EN16931` hybrid PDF/A-3b invoices with embedded UN/CEFACT CII D22B XML when selected for an outgoing invoice, and SHALL provide standalone XRechnung 3.0 UBL 2.1 XML export for finalized outgoing invoices. XRechnung validation SHALL use the pinned XRechnung Bundle 3.0.2 Summer 2026 technical artifacts; the bundle version MUST NOT be presented as the normative format version. These outputs SHALL be validated with the exact pinned local schema/business-rule artifacts and SHALL preserve canonical invoice values from the applicable immutable snapshot without recalculating money. XRechnung SHALL NOT be embedded in PDF/A-3. The customer ZUGFeRD setting SHALL preselect a format only; the per-invoice output choice SHALL remain explicit.

#### Scenario: ZUGFeRD PDF generation

- **GIVEN** an outgoing invoice is finalized with ZUGFeRD selected and all required values for the pinned profile
- **WHEN** finalization generates the selected output
- **THEN** the system SHALL produce a human-readable PDF/A-3b file with a validated embedded ZUGFeRD 2.5.2 `EN16931` CII invoice and matching format metadata; readiness is derived from the validated artifact

#### Scenario: XRechnung generation

- **GIVEN** a finalized outgoing invoice passes XRechnung 3.0 validation using Bundle 3.0.2 Summer 2026
- **WHEN** the user requests XRechnung export
- **THEN** the system SHALL write a standalone UBL 2.1 XML file conforming to the pinned bundle, without PDF/A-3 wrapping or invoice mutation

#### Scenario: Invalid invoice data for e-invoicing

- **GIVEN** a finalized invoice lacks a field required by the selected pinned e-invoice profile or violates one of its business rules
- **WHEN** generation is requested
- **THEN** the system SHALL reject generation with a localized error identifying the missing field/business-term or stable rule identifier and SHALL expose no partial output
