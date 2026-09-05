## ADDED Requirements

### Requirement: Finalized documents have real profile-local artifacts

Successful finalization of an invoice or dunning document MUST generate the appropriate PDF bytes, write them atomically below the active profile's document root, and persist a path that points to an existing readable file.

Implementation evidence: The current invoice path is recorded without a production PdfGenerator call, while dunning returns a name without writing a file.

#### Scenario: Invoice finalization creates a readable PDF

- Given a valid invoice can be finalized and the profile document directory exists
- When finalization succeeds
- Then a non-empty PDF exists at the stored path and reopening the document resolves that same artifact

#### Scenario: Artifact failure prevents a false path

- Given PDF generation or file writing fails
- When finalization handles the failure
- Then no nonexistent path is persisted, accounting/document state follows the defined rollback policy, and the UI explains the recovery action

### Requirement: Desktop artifact actions operate on stored documents

The document viewer MUST load recorded artifacts and implement preview, print, save-as, copy, and watermark behavior where supported by the platform, with explicit unavailable/error states rather than empty callbacks.

Implementation evidence: printPdf and saveAs are empty production methods, so a stored path cannot complete the user workflow.

#### Scenario: A user can reopen and save a finalized PDF

- Given a stored PDF path points to a readable artifact
- When the user opens it and chooses Save as
- Then the viewer presents the document and writes the selected destination with the same bytes

#### Scenario: Missing or unsupported actions are actionable

- Given the artifact is missing or the platform cannot print
- When the user invokes the action
- Then the viewer reports the specific issue and offers retry/open-folder/save alternatives without silently succeeding
