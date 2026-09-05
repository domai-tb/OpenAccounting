## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/setup-onboarding-integrity/spec.md → Skip and Finish leave setup with durable state | Finish reaches the dashboard | test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_1_1_finish_reaches_the_dashboard | 🔴 red |
| specs/setup-onboarding-integrity/spec.md → Skip and Finish leave setup with durable state | Skip follows its documented policy | test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_1_2_skip_follows_its_documented_policy | 🔴 red |
| specs/setup-onboarding-integrity/spec.md → Setup writes an atomic, accounting-safe opening state | Opening cash agrees across sources | test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_2_1_opening_cash_agrees_across_sources | 🔴 red |
| specs/setup-onboarding-integrity/spec.md → Setup writes an atomic, accounting-safe opening state | Intermediate failure rolls back | test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_2_2_intermediate_failure_rolls_back | 🔴 red |
| specs/setup-onboarding-integrity/spec.md → First-run concepts are explicit and non-deceptive | Required first-run decisions are visible | test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_3_1_required_first_run_decisions_are_visible | 🔴 red |
| specs/setup-onboarding-integrity/spec.md → First-run concepts are explicit and non-deceptive | Blank identity is handled honestly | test/integration/audit/setup-onboarding-integrity_test.dart | test_setup_onboarding_integrity_3_2_blank_identity_is_handled_honestly | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
