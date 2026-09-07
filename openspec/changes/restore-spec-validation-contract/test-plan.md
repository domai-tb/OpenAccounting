## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/restore-spec-validation-contract/spec.md → Maintained specs pass strict validation | Strict validation passes for all maintained specs | openspec validate --specs --strict | openspec-strict-validation-passes | 🟢 green |
| specs/restore-spec-validation-contract/spec.md → Maintained specs pass strict validation | Missing section fails validation | openspec validate --specs --strict (with intentional break) | openspec-missing-section-fails | N/A — non-executable |

## Coverage Notes

This is a schema/documentation change. The primary test is the `openspec validate --specs --strict` CLI command. No Dart code tests needed.
