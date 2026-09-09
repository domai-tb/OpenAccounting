## Implementation Tasks

## 1. Profile CRUD changes real profile state — Inactive profile can be deleted

- [ ] 1.1 Write failing test test/integration/audit/profile-workspace-lifecycle_test.dart → test_profile_workspace_lifecycle_1_1_inactive_profile_can_be_deleted (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Profile CRUD changes real profile state to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Profile CRUD changes real profile state — Active/last profile deletion is protected

- [ ] 2.1 Write failing test test/integration/audit/profile-workspace-lifecycle_test.dart → test_profile_workspace_lifecycle_1_2_active_last_profile_deletion_is_protected (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Profile CRUD changes real profile state to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Selection switches the running application coherently — User switches profiles

- [ ] 3.1 Write failing test test/integration/audit/profile-workspace-lifecycle_test.dart → test_profile_workspace_lifecycle_2_1_user_switches_profiles (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Selection switches the running application coherently to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Selection switches the running application coherently — Corrupt or unavailable profile is recoverable

- [ ] 4.1 Write failing test test/integration/audit/profile-workspace-lifecycle_test.dart → test_profile_workspace_lifecycle_2_2_corrupt_or_unavailable_profile_is_recoverable (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Selection switches the running application coherently to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
