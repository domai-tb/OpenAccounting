## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/profile-workspace-lifecycle/spec.md → Profile CRUD changes real profile state | Inactive profile can be deleted | test/integration/audit/profile-workspace-lifecycle_test.dart | test_profile_workspace_lifecycle_1_1_inactive_profile_can_be_deleted | 🔴 red |
| specs/profile-workspace-lifecycle/spec.md → Profile CRUD changes real profile state | Active/last profile deletion is protected | test/integration/audit/profile-workspace-lifecycle_test.dart | test_profile_workspace_lifecycle_1_2_active_last_profile_deletion_is_protected | 🔴 red |
| specs/profile-workspace-lifecycle/spec.md → Selection switches the running application coherently | User switches profiles | test/integration/audit/profile-workspace-lifecycle_test.dart | test_profile_workspace_lifecycle_2_1_user_switches_profiles | 🔴 red |
| specs/profile-workspace-lifecycle/spec.md → Selection switches the running application coherently | Corrupt or unavailable profile is recoverable | test/integration/audit/profile-workspace-lifecycle_test.dart | test_profile_workspace_lifecycle_2_2_corrupt_or_unavailable_profile_is_recoverable | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
