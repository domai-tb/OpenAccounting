## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/seed-master-data-contract/spec.md → Chart-of-accounts seeds have valid reporting mappings | Fresh profile supports reporting without custom fixtures | test/integration/audit/seed-master-data-contract_test.dart | test_seed_master_data_contract_1_1_fresh_profile_supports_reporting_without_custom_fixtures | 🔴 red |
| specs/seed-master-data-contract/spec.md → Chart-of-accounts seeds have valid reporting mappings | Seed upgrade preserves user edits | test/integration/audit/seed-master-data-contract_test.dart | test_seed_master_data_contract_1_2_seed_upgrade_preserves_user_edits | 🔴 red |
| specs/seed-master-data-contract/spec.md → Bank templates are documented and deterministic | Supported template parses its format | test/integration/audit/seed-master-data-contract_test.dart | test_seed_master_data_contract_2_1_supported_template_parses_its_format | 🔴 red |
| specs/seed-master-data-contract/spec.md → Bank templates are documented and deterministic | Unknown format is not silently mapped | test/integration/audit/seed-master-data-contract_test.dart | test_seed_master_data_contract_2_2_unknown_format_is_not_silently_mapped | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
