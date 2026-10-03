## ADDED Requirements

### Requirement: Supported accounting and tax controls have reviewed context guidance

The coverage inventory SHALL list each supported accounting- or tax-related field and status with one of three states: reviewed, missing, or review-needed. Every reviewed entry SHALL reference a stable help-entry ID and provide German and English titles and explanations, identify the owning capability contract and revision, and describe the application's behavior and required inputs. The content SHALL NOT recommend a user's tax treatment, infer eligibility, promise legal compliance, or describe unsupported behavior as available. A field or status without a reviewed entry SHALL have no contextual guidance affordance or fabricated fallback; its coverage state SHALL remain visible in the inventory. Missing or review-needed guidance SHALL NOT disable otherwise supported field behavior.

#### Scenario: User opens guidance for a supported field

- **GIVEN** a field references a reviewed guidance entry
- **WHEN** the user activates its labeled help affordance by keyboard or pointer
- **THEN** the localized explanation SHALL identify what the field means in the application and what workflow behavior it affects
- **AND** the explanation SHALL remain tied to its owning capability contract revision.

#### Scenario: Field has no approved explanation

- **GIVEN** a supported accounting/tax control has no reviewed catalog entry or its entry is marked review-needed
- **WHEN** the control is rendered
- **THEN** the application SHALL NOT show guessed guidance or a link to unrelated help
- **AND** the guidance coverage inventory SHALL identify the missing or review-needed state while leaving otherwise supported field behavior available.

#### Scenario: Unsupported tax behavior is discussed

- **GIVEN** a field relates to a tax or accounting behavior the application has not accepted or implemented
- **WHEN** its explanation is displayed
- **THEN** the text SHALL state that the behavior is unavailable or unresolved
- **AND** SHALL NOT advise the user which tax treatment to choose or imply the action is supported.

### Requirement: Help provides a searchable glossary for contextual entries

The `/help` workspace SHALL expose the same reviewed accounting/tax guidance entries used by form controls, grouped by workflow and searchable by localized title and terms. Opening a glossary entry SHALL show its full explanation and relevant application location when available. The page SHALL remain local, require no network access, and SHALL NOT contain advice or unsupported feature claims.

#### Scenario: Search and open a help entry

- **GIVEN** the user is in Help with reviewed guidance entries available
- **WHEN** they search a German or English term and open a result
- **THEN** Help SHALL show the matching localized explanation and its related field/workflow references
- **AND** the same content entry SHALL be returned by its contextual field affordance.

#### Scenario: No glossary result is available

- **GIVEN** the search has no reviewed entry matching the active locale terms
- **WHEN** the user searches the glossary
- **THEN** Help SHALL show a localized empty state and SHALL NOT fabricate a definition.

### Requirement: Context guidance follows the desktop design schema

Context guidance SHALL use labeled keyboard-accessible controls, visible focus, logical tab order, semantic screen-reader labels, German and English content, and text scaling/narrow-window states as required by `DESIGN.md`. Long glossary content SHALL use a readable constrained text width, and status meaning SHALL NOT rely on color alone.

#### Scenario: Guidance is reachable without a pointer

- **GIVEN** keyboard focus is within an accounting form
- **WHEN** the user navigates to a contextual explanation control and activates it
- **THEN** the explanation SHALL open and close with keyboard interaction
- **AND** focus SHALL return to the originating field or help control.
