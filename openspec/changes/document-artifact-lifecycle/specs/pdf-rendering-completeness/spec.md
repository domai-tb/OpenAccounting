## ADDED Requirements

### Requirement: Complete supported PDF rendering

The renderer SHALL return non-empty readable PDF bytes for Rechnung, Storno, Gutschrift, Angebot, Auftrag, Proforma, Lieferschein, and Mahnung with type-specific labels, numbers, positions, and required metadata. Rendering SHALL not persist database paths or claim finalization.

#### Scenario: Supported type renders bytes
- **GIVEN** a valid immutable snapshot for any supported type
- **WHEN** the renderer is called
- **THEN** it SHALL return non-empty readable bytes containing the type label and required type-specific fields

#### Scenario: Unsupported or incomplete snapshot fails
- **GIVEN** an unsupported type or missing required rendering field
- **WHEN** rendering is requested
- **THEN** it SHALL return a typed rendering error and SHALL not write or persist an artifact

### Requirement: Optional content and readable layout

The renderer SHALL include configured logo, signature, payment, customer address, service period, discount, margin/tax, dunning, Unicode text, and footer/page-number content. Absent optional data SHALL be intentionally omitted without corrupting totals or layout.

#### Scenario: Configured content appears
- **GIVEN** a snapshot includes logo/signature, payment, service period, discount, or margin data
- **WHEN** the PDF is rendered
- **THEN** each enabled element SHALL appear in its designated section and totals SHALL match the snapshot

#### Scenario: Missing optional content remains readable
- **GIVEN** optional assets and payment data are absent
- **WHEN** the PDF is rendered
- **THEN** the output SHALL remain readable, use a Unicode-capable font, omit only absent sections, and include page numbering
