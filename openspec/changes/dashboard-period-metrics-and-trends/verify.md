## Verification Results

### Implementation and coverage

- [x] 88 of 89 checklist entries in `tasks.md` are checked: 81 inherited tasks, six annual-summary consumption tasks, and the maintained-spec sync; task 9.2 remains open for independent review.
- [x] All 31 scenario rows in `test-plan.md` are green and map to named executable tests.
- [x] The canonical card regression failed before provider wiring because the dashboard card omitted accepted profit data.
- [x] The annual card renders income, expenses, profit, and margin directly from `DashboardAnnualKpis`; an unavailable summary remains unavailable and does not fall back to journal totals.
- [x] The widget fixture supplies profit and margin values that differ from local formulas, proving the canonical fields are consumed as supplied.
- [x] Margin uses the active locale: the regression failed on German `12,3 %` before the formatter fix and now passes for English `12.3 %` and German `12,3 %`.
- [x] Monthly trend data exposes income and expense only. No monthly profit formula or getter is present.

### Toolchain and exact-revision evidence

- Pinned toolchain: FVM Flutter 3.47.2 and Dart 3.13.2, as declared by `.fvmrc`.
- Writable FVM/package caches: `FVM_CACHE_PATH=/tmp/openaccounting-fvm-cache` and `PUB_CACHE=/tmp/openaccounting-dashboard-pub-cache`; telemetry was suppressed with `FLUTTER_SUPPRESS_ANALYTICS=true DASH__SUPPRESS_ANALYTICS=true`. `HOME` was not overridden.
- The read-only baseline revision `0881ec5c623284c4c9ee6d8e919a8a6b397b30fe` passed `fvm flutter analyze --no-pub` with no issues (exit 0; raw log: `/tmp/openaccounting-baseline-evidence/analyze-no-pub-task-cache.log`). Its full VM suite passed 1,790 tests with no failures or skipped tests, `All tests passed!`, exit 0 (raw log: `/tmp/openaccounting-baseline-evidence/test-no-pub-system-sqlite-elevated.log`).
- The dashboard implementation revision `e8a8e11e8b28788915fd709ea788ba4fd1a38071` passed `fvm flutter analyze --no-pub` with no issues (exit 0; raw log: `/tmp/openaccounting-dashboard-evidence/analyze-no-pub.log`). Its full VM suite passed 1,792 tests with no failures or skipped tests, `All tests passed!`, exit 0 (raw log: `/tmp/openaccounting-dashboard-evidence/test-system-sqlite-elevated.log`). The full-suite run includes the two added dashboard tests.
- Each full-suite run used `fvm flutter test --dart-define=platform=vm --no-pub` after `fvm flutter pub get --offline` succeeded. The temporary `hooks.user_defines.sqlite3` override selected `source: system` and `/lib/x86_64-linux-gnu/libsqlite3.so.0` to bypass blocked GitHub DNS. The resolved Dart `sqlite3` package is 3.5.2; the host library reports SQLite 3.45.1. The override existed only in each isolated test clone's temporary `pubspec.yaml` and was restored afterward; it is not a production dependency change.
- Flutter's test runner needed elevated localhost-socket permission. The first sandboxed run reached 45 test files, then all 45 failed during test-loader startup with `Failed to create server socket (OS Error: Operation not permitted, errno = 1), address = 127.0.0.1, port = 0`; no test bodies ran. The authorized elevated reruns above completed successfully. Failure inventory and raw startup log: `/tmp/openaccounting-baseline-evidence/failed-test-files.txt` and `/tmp/openaccounting-baseline-evidence/test-no-pub-system-sqlite.log`.
- Earlier online `fvm flutter pub get`, `fvm flutter analyze`, and `fvm flutter test --dart-define=platform=vm` attempts failed before analysis/test execution because DNS could not resolve `pub.dev`; the initial SQLite hook also could not download its binary from `github.com`. These are setup failures preceding the passing offline/elevated runs. Full baseline attempt history and raw logs are in `/tmp/openaccounting-baseline-evidence/README.md`.
- Focused dashboard and dashboard audit tests previously passed 73 tests. Static analysis and formatting on the dashboard source/test changes passed. The full-suite and fresh analyzer results above are tied to the exact dashboard revision, not inferred from the baseline.

### OpenSpec and review gates

- [x] The accepted Round 3 review remains applicable to proposal, design, and delta specifications; none of those files changed.
- [x] Independent implementation review approved exact checkpoint `e8a8e11e8b28788915fd709ea788ba4fd1a38071`.
- [x] The accepted dashboard delta is synchronized into `openspec/specs/dashboard/spec.md`; the Quick-Links requirement matches the delta after blank-line normalization, and all six added requirements match it byte-for-byte. The pre-existing dashboard requirements outside the modified Quick-Links block are preserved.
- [x] The agent-driven `openspec-sync-specs` workflow was run a second time against the same delta and maintained spec; it found Quick-Links and all six added requirements already synchronized, changing zero requirement blocks and zero bytes. The maintained spec SHA-256 remained `bd54e07b0c110fe2a9b6f8ede3326f88b50580a0c077dc00ce1292ea6d60b9af`; the pre/post diff is empty (`/tmp/openaccounting-dashboard-evidence/sync-pass-2.diff`, hashes in `sync-pass-2-hashes.txt`), and the delta remains unchanged.
- [x] The modified Quick-Links content has the same normalized SHA-256 in delta and maintained spec (`7c0ae15b628962f1f04344ab9ba2cfd60c4b9083a8563a8e2652b35b84825441`), and the appended requirements have the same SHA-256 byte-for-byte (`1feb5169cb6ccd2966a3a37214db26af7343d0089ccb8211793074c76647983b`). The pre-existing maintained-spec prefix and suffix outside the modified Quick-Links block are preserved byte-for-byte, except for the separator blank line before appended requirements.
- [ ] Independent semantic review of the synchronized maintained dashboard contract is pending; task 9.2 remains open until its exact-revision verdict is recorded.
- [x] Strict change validation passes 1/1, strict maintained-spec validation passes 72/72, and `git diff --check` is clean after synchronization.
- [x] This checkpoint records the maintained-spec sync and evidence; it does not archive or publish the change.

## Overall Decision

DECISION: IN PROGRESS — dashboard implementation, focused coverage, exact-revision full VM suites, static analysis, synchronization, and strict validation pass. Independent semantic review of the synchronized maintained contract remains pending, so the change is not ready to archive.
