## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/restore-spec-validation-contract/spec.md → Maintained specifications are parseable under strict Anvil validation | All maintained specs pass | openspec validate --all --strict | strict_anvil_validation | N/A — non-executable |
| specs/restore-spec-validation-contract/spec.md → Maintained specifications are parseable under strict Anvil validation | Malformed spec blocks a release | openspec validate --all --strict | strict_anvil_validation | N/A — non-executable |
| specs/restore-spec-validation-contract/spec.md → Conflicting normative requirements are reconciled | Duplicate behavior has one owner | openspec validate --all --strict | strict_anvil_validation | N/A — non-executable |
| specs/restore-spec-validation-contract/spec.md → Conflicting normative requirements are reconciled | Unresolved conflict is visible | openspec validate --all --strict | strict_anvil_validation | N/A — non-executable |

## Coverage Notes

Every scenario is mapped to the strict Anvil validation command because this proposal changes documentation/spec structure rather than production code. The current repository baseline has 15 pre-existing invalid main specs; that is the defect this change must remove.
