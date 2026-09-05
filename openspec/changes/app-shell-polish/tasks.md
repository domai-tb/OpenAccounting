## 1. Existing app-shell capability

This is a test/artifact ownership correction. No production behavior or new scenario was introduced; existing general shell tests were already red/green under the app-shell change and are reused here instead of duplicated.

- [x] 1.1 Remove placeholder amount-formatting tests and assign shell coverage to existing tests in `test/app/app_shell_test.dart`
- [x] 1.2 Keep shell behavior in existing `lib/app/app_shell.dart` — no separate production feature
- [x] 1.3 Verify refactor; general shell and full suite stay green
