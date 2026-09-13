# document-artifact-actions Specification

## Purpose
TBD - created by archiving change document-artifact-lifecycle. Update Purpose after archive.

## Requirements

### Requirement: Routed artifact actions

Invoice and dunning detail pages SHALL expose Preview, Open, Save As, and supported Print actions through injected viewer services. The page SHALL show artifact type, number, status, and the lifecycle owner’s current state.

#### Scenario: User previews and saves an artifact
- **GIVEN** a finalized document has a readable stored PDF
- **WHEN** the user chooses Preview and Save As
- **THEN** preview SHALL open the stored bytes and Save As SHALL write byte-equivalent bytes to the selected destination

#### Scenario: Viewer reports unsupported print
- **GIVEN** the target platform cannot print
- **WHEN** the user chooses Print
- **THEN** the UI SHALL show an explicit unsupported state and offer Save As or help without claiming success

### Requirement: Missing artifact recovery

The UI SHALL detect when a persisted path is missing, invalid, or outside the active profile root and SHALL offer regeneration, safe location, or return actions. It SHALL not expose raw paths as the only explanation.

#### Scenario: Missing file offers regeneration
- **GIVEN** the database points to a deleted PDF
- **WHEN** the user opens document actions
- **THEN** the page SHALL identify the artifact as missing and offer regeneration or a safe recovery action

#### Scenario: Unsafe path is rejected
- **GIVEN** a persisted artifact path escapes the active profile root
- **WHEN** the viewer resolves it
- **THEN** the viewer SHALL reject it, show a typed security error, and SHALL not open or copy the file
