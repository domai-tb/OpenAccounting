## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/desktop-capability-availability/spec.md → Production desktop action wiring | Dropped file reaches import workflow | test/features/desktop/desktop_capability_test.dart | test_dropped_file_reaches_import_workflow | 🔴 red |
| specs/desktop-capability-availability/spec.md → Production desktop action wiring | Unsupported target reports availability | test/features/desktop/desktop_capability_test.dart | test_unsupported_target_reports_availability | 🔴 red |
| specs/desktop-capability-availability/spec.md → Updater remains fail-closed | Unapproved updater is visible as unavailable | test/features/desktop/desktop_capability_test.dart | test_unapproved_updater_is_visible_as_unavailable | 🔴 red |
| specs/desktop-capability-availability/spec.md → Updater remains fail-closed | Untrusted update is rejected | test/features/desktop/desktop_capability_test.dart | test_untrusted_update_is_rejected | 🔴 red |
| specs/specification-source-parity/spec.md → Flutter source-of-truth documentation | Architecture links match source | test/features/desktop/spec_parity_test.dart | test_architecture_links_match_source | 🔴 red |
| specs/specification-source-parity/spec.md → Flutter source-of-truth documentation | Stale architecture is detected | test/features/desktop/spec_parity_test.dart | test_stale_architecture_is_detected | 🔴 red |
| specs/specification-source-parity/spec.md → Desktop specifications are semantically consistent | Desktop specs agree | test/features/desktop/spec_parity_test.dart | test_desktop_specs_agree | 🔴 red |
| specs/specification-source-parity/spec.md → Desktop specifications are semantically consistent | Contradictory spec is rejected | test/features/desktop/spec_parity_test.dart | test_contradictory_spec_is_rejected | 🔴 red |

## Coverage Notes

Desktop target tests use injected adapters; unavailable paths return typed result. Doc parity uses mechanical check `rg -n "Tauri|React|FastAPI" docs/ openspec/specs` and strict validation.
