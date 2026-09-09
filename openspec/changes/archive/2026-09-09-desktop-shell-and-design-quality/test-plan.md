## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/desktop-shell-and-design-quality/spec.md → Responsive shell controls are context-appropriate | Breakpoints preserve usable navigation | test/integration/audit/desktop-shell-and-design-quality_test.dart | test_desktop_shell_and_design_quality_1_1_breakpoints_preserve_usable_navigation | 🔴 red |
| specs/desktop-shell-and-design-quality/spec.md → Responsive shell controls are context-appropriate | A page without filters has no inert toolbar | test/integration/audit/desktop-shell-and-design-quality_test.dart | test_desktop_shell_and_design_quality_1_2_a_page_without_filters_has_no_inert_toolbar | 🔴 red |
| specs/desktop-shell-and-design-quality/spec.md → Financial and interactive components are accessible | Long and private amounts remain legible | test/integration/audit/desktop-shell-and-design-quality_test.dart | test_desktop_shell_and_design_quality_2_1_long_and_private_amounts_remain_legible | 🔴 red |
| specs/desktop-shell-and-design-quality/spec.md → Financial and interactive components are accessible | Keyboard focus completes the interaction | test/integration/audit/desktop-shell-and-design-quality_test.dart | test_desktop_shell_and_design_quality_2_2_keyboard_focus_completes_the_interaction | 🔴 red |
| specs/desktop-shell-and-design-quality/spec.md → Dialogs and page states explain the next action | Destructive confirmation is specific | test/integration/audit/desktop-shell-and-design-quality_test.dart | test_desktop_shell_and_design_quality_3_1_destructive_confirmation_is_specific | 🔴 red |
| specs/desktop-shell-and-design-quality/spec.md → Dialogs and page states explain the next action | Failure and empty state are actionable | test/integration/audit/desktop-shell-and-design-quality_test.dart | test_desktop_shell_and_design_quality_3_2_failure_and_empty_state_are_actionable | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
