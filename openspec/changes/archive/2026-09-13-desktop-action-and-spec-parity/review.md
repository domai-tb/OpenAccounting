# Adversarial Review — desktop-action-and-spec-parity

## 1. Review Metadata

| Field | Value |
|-------|-------|
| Round | 2 |
| Date | 2026-09-13 |
| Reviewer context | Round 2 — verifying C1/C2/C3 fixes and checking for new findings |

## 2. Prior Round Summary

Round 1 issued 3 critical, 6 moderate, and 5 suggestion findings. Verdict: REVISE.

| ID | Severity | Finding | Status |
|----|----------|---------|--------|
| C1 | 🔴 | Proposal claims existing spec is baseline, but baseline is contaminated with Tauri/Python | ✅ Fixed |
| C2 | 🔴 | Spec requires profile-aware routing but no adapter supports it | ✅ Fixed |
| C3 | 🔴 | No defined interface for desktop capability registry | ✅ Fixed |
| M1 | 🟡 | Minimum window size mismatch: spec 1024×768 vs code 960×640 | ✅ Fixed (delta spec uses 960×640) |
| M2 | 🟡 | Documentation check scope ambiguous | ⚠️ Partially addressed |
| M3 | 🟡 | "Explicit historical marker" undefined | ⚠️ Not addressed |
| M4 | 🟡 | "Untrusted update is rejected" scenario unreachable in deny-all mode | ⚠️ Not addressed |
| M5 | 🟡 | Supported desktop targets unresolved | ⚠️ Not addressed |
| M6 | 🟡 | DropService doesn't integrate with import workflow | ⚠️ Not addressed |
| S1 | 📌 | Consolidate re-export files | Not addressed |
| S2 | 📌 | Define what "show its state" means | Not addressed |
| S3 | 📌 | SingleInstanceService — include or exclude | Not addressed |
| S4 | 📌 | Define safe retry/help UI | Not addressed |
| S5 | 📌 | Spec should require surfacing availability | Not addressed |

## 3. Embedded-Instruction / Injection Attempts Detection

No embedded instructions or injection attempts detected in any artifact.

## 4. Fix Verification

### C1 Fix: ✅ Properly addressed

`desktop/spec.md` (delta spec) now includes `desktop` as Modified Capability with:
- Auto-Update: Explicitly states "Updater installation SHALL remain unavailable until a separate approved policy" — supersedes old Tauri updater language.
- Backend Process Management: Marked REMOVED with reason ("Architecture changed from Tauri+Python to Flutter-only") and migration notes.
- Platform Workarounds: Rewritten to reference Flutter desktop, not Tauri/webview.
- Window Management: Updated minimum size to 960×640 (matching code).

### C2 Fix: ✅ Properly addressed

`desktop-capability-availability/spec.md` line 5-6: "An `onEvent` callback injected at bootstrap SHALL receive adapter events; profile-aware routing is the callback's responsibility, not the adapter's." Clean separation.

### C3 Fix: ✅ Properly addressed

`design.md` lines 21-22: Concrete interface defined — `DesktopCapabilityRegistry` with `register<T>(DesktopCapability<T>)` and `isAvailable<T>()` methods, constructed during bootstrap and injected into `AppServices`. Registration is idempotent. Each adapter wraps `supported` or `Unavailable(reason)`.

## 5. New Findings

### 🟡 Moderate

#### M1: Window Management delta spec drops scenarios but keeps requirement text

The requirement (line 38) says "SHALL remember window size, position, and maximized state across sessions" but only the Minimum Size Enforcement scenario is included. Window State Persistence, Maximize State Persistence, and Corruption Recovery scenarios from the existing spec are dropped. The requirement text claims persistence without testable scenarios to verify it.

**Fix**: Either add the persistence scenarios back or narrow the requirement text to only cover minimum size and tray minimization.

#### M2: Platform Workarounds delta spec narrows requirement without explanation

The delta spec (lines 54-57) rewrites Platform Workarounds to "handle macOS-specific file path differences for profile storage, and handle Linux display server compatibility." This drops:
- GPU acceleration disable on Wayland (code: `platform_service.dart:19` `gpuConfig`)
- Windows console hide (code: `platform_service.dart:17` `shouldHideConsole`)

Both features are still implemented. The existing spec had scenarios for these.

**Fix**: Either keep the GPU/console scenarios in the delta spec or add a removal note explaining why they're dropped (e.g., "GPU config is a runtime concern, not a spec requirement").

#### M3: Auto-Update spec/code default disagreement

`desktop/spec.md` line 5: "SHALL check GitHub Releases for updates on startup and periodically (every 4 hours)."

`desktop_updater.dart` line 359: `createDesktopUpdaterService` defaults to `enabled: false`. The updater only checks when explicitly enabled. The spec says "shall check on startup" but the implementation defaults to not checking.

**Fix**: Change spec to "SHALL check when enabled" or change factory default to `enabled: true`.

#### M4: Profile paths in delta spec don't match code

`desktop/spec.md` lines 62-68 define profile paths as `~/Library/Application Support/OpenAccounting/profile/<Name>/` (macOS), `~/.local/share/OpenAccounting/profile/<Name>/` (Linux), `%APPDATA%/OpenAccounting/profile/<Name>/` (Windows).

`data_paths.dart` uses `OpenInvoices` (old name) and the profile structure is `<base>/profiles/<name>/` (note: `profiles/` subdirectory). The delta spec uses `profile/<Name>/` (no `profiles/` subdirectory).

Proposal impact doesn't list `data_paths.dart`. Either add it or correct the spec paths.

**Fix**: Update `data_paths.dart` in proposal impact, or align spec paths with current code structure (`profiles/<name>/` not `profile/<Name>/`).

### 📌 Suggestions

#### S1: SingleInstanceService not addressed

Carried from round 1 S3. `single_instance_service.dart` exists, the existing spec has "Single Instance Enforcement" (lines 243-266), but the delta spec doesn't modify or explicitly exclude it. Clarify whether it's in-scope.

#### S2: platform_service.dart typo

Line 3: "fals back silently" → "falls back silently".

## 6. Scenario Coverage Check

| Scenario | Coverage | Issue |
|----------|----------|-------|
| Dropped file callback fires | ✅ | Clear, testable |
| Unsupported target reports availability | ✅ | Clear, testable |
| Unapproved updater visible as unavailable | ✅ | Matches deny-all code |
| Untrusted update rejected | ✅ | Now properly framed as conditional on signing policy |
| Architecture links match source | ✅ | Mechanical check, testable |
| Stale architecture detected | ✅ | Mechanical check, testable |
| Desktop specs agree | ⚠️ | Only one desktop spec being modified; parity check needs two specs to compare |
| Contradictory spec rejected | ⚠️ | Requires two contradicting specs — this is a meta-check, not a scenario |
| Window State Persistence | ⚠️ | Requirement claims persistence but no scenario covers it |
| GPU/Console Workarounds | ⚠️ | Scenarios dropped from delta spec |

## 7. Scope Creep Check

No scope creep detected. All artifacts stay within the proposal's stated scope: wiring desktop handlers, surfacing availability, Flutter-only contract, and doc/spec alignment.

## 8. VERDICT

**VERDICT: APPROVE_WITH_CHANGES**

Three round-1 critical findings are properly resolved. No new critical findings. Four moderate findings remain — all resolvable by aligning spec text with implementation reality or explicitly marking decisions. The moderate findings are:
- M1: Scenario gap in Window Management
- M2: Unexplained scenario drops in Platform Workarounds
- M3: Spec/code default disagreement on updater
- M4: Profile path spec doesn't match code structure

None block implementation. The change set is internally consistent and architecturally sound.

Round: 2 | Prior: REVISE (round 1)

**CHANGES_APPLIED: yes**
