## Test Plan — existing app-shell capability

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| app-shell → Desktop Shell Layout | Shell renders on every primary route | test/app/app_shell_test.dart | test_shell_renders_on_every_primary_route | 🟢 green |
| app-shell → Desktop Shell Layout | Shell remains around setup guard | test/app/app_shell_test.dart | test_shell_not_black_fallback | 🟢 green |

## Coverage Notes

Coverage belongs to existing `app-shell`; placeholder tests were removed because they tested unrelated amount formatting. No new capability or feature-specific test file.
