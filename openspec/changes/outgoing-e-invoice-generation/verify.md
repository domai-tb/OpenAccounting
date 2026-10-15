## Decision: PARTIAL

This change is not ready to archive or release. `openspec list --json` reports 78 of 110 implementation tasks complete.

### Latest checkpoint: customer ZUGFeRD default editor

- Task 1.4 is complete: the customer form can set and edit the default, and explains that each invoice can still choose another format.
- `fvm flutter test --dart-define=platform=vm test/features/stammdaten/customer_zugferd_default_form_test.dart test/features/stammdaten/master_data_workspaces_test.dart test/features/stammdaten/kunden_test.dart test/features/rechnungen/invoice_output_format_widget_test.dart`: 44 passed.
- `fvm flutter analyze`: no issues.
- `fvm dart format --line-length=120 --set-exit-if-changed` on the changed Dart files: passed; 0 files changed.
- `openspec validate outgoing-e-invoice-generation --type change --strict --json`: passed, 1/1.

The latest focused test run used the shared worktree. No clean-worktree aggregate suite was run for this checkpoint.

### Verified locally

- Focused changed test set: 242 passed; after correcting the route gate's loading-animation wait, the gate passed separately (4/4).
- Full `fvm flutter analyze`: no issues.
- Profile lifecycle suites: 12 passed.
- Concurrent `createForRechnung` regression: 1 passed.
- `openspec validate --specs --strict`: 69 passed.
- `openspec validate outgoing-e-invoice-generation --type change --strict`: valid.
- `git diff --check`: clean at the time of the check.
- Invoice-money contract prerequisite is satisfied by archived `invoice-money-contract-completion` (approved; verified 1,434 tests).
- Finalized customer snapshot storage is migrated and covered by the standalone-export snapshot test (task 1.5).

Tests that inject `PinnedArtifactBundle(available: true)` prove application-level behavior only. They do not prove compliance validation.

### Open gates

- The typed tax-category/exemption mapping remains unapproved (task 1.2).
- The offline XSD/Schematron and PDF/A-3 validator is not packaged or verified on Linux, Windows, and macOS (task 1.3). The production bundle now defaults to unavailable and fails closed.
- The customer ZUGFeRD default editor is now available in customer create and edit forms (task 1.4).
- `ZugferdHybridArtifact` keeps the PDF bytes and CII XML as separate values; it does not embed XML into the PDF. Hybrid-PDF and external-validation scenarios remain red in `test-plan.md`.

The last full VM suite on clean commit `9ed436e` failed: 1,712 passed and 30 failed. It predates this checkpoint. No legal, GoBD, device, or cross-platform validation claim is made.
