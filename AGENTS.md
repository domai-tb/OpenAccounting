# AGENTS.md — OpenAccounting

Flutter accounting desktop app with Clean Architecture. AGPL v3.

## Quick Commands

All `flutter` and `dart` commands MUST be prefixed with `fvm` — Flutter Version Manager handles the pinned version.

```bash
fvm flutter pub get          # install deps
fvm flutter run              # launch on connected device/emulator
fvm flutter analyze          # lint + metrics (uses analysis_options.yaml)
fvm flutter test             # run all tests
fvm flutter test --dart-define=platform=vm test/path.dart  # single test file
fvm flutter gen-l10n         # regenerate localization (lib/l10n/)
fvm dart format --line-length=120 .  # format everything
```

No `Makefile`, no `taskfile`, no scripts beyond the above.

## Flutter Version

Pinned to **3.47.2** via FVM (`.fvmrc`). Never use bare `flutter` or `dart` — always go through `fvm`.

## Architecture

Layered Clean Architecture, no BLoC. Dependency flow: **Page → UseCase → Repository → DataSource**.

Each feature module lives in `lib/pages/pageN/` with a fixed file set:
- `pageN_datasource.dart` — external data access (HTTP, DB, platform)
- `pageN_repository.dart` — maps raw data to domain entities
- `pageN_usecases.dart` — business logic orchestration
- `pageN_item_entity.dart` — immutable data model
- `pageN_page.dart` — Flutter widget (StatefulWidget)

**DI**: GetIt via `lib/core/injection.dart`. UI accesses deps through `AppScope.of(context).services` — never import GetIt directly in widgets.

**Core modules** (`lib/core/`): `app_scope.dart` (InheritedWidget for DI), `app_services.dart` (aggregate of all page use-cases), `settings.dart`, `themes.dart`, `exceptions.dart`, `failures.dart`.

## Lint (Strict)

`analysis_options.yaml` enforces 150+ lint rules from `package:flutter_lints` plus many additional rules.

Key enforced rules:
- **`always_use_package_imports`** — no relative imports (e.g. `import 'package:open_plant/...'`)
- `require_trailing_commas`
- `prefer_single_quotes`
- `prefer_const_constructors`
- `avoid_print` (use `debugPrint`)
- `prefer_final_locals` / `prefer_final_in_for_each`
- `unawaited_futures` (must use `unawaited()` or await explicitly)

Run `fvm flutter analyze` before pushing — CI-equivalent checks will fail on any lint violation.

## Localization

ARB files in `assets/l10n/`. Template: `l10n_en.arb`. Generated output: `lib/l10n/`.

After editing ARB files, run `fvm flutter gen-l10n` to regenerate. Access translations via `context.l10n.someKey`.

## Settings Persistence

`shared_preferences` with JSON serialization. `SettingsController` (a `ChangeNotifier`) is the single source of truth. Loaded at startup in `injection.dart` before `runApp()`.

## Line Length

120 characters (configured in `.vscode/settings.json` and `analysis_options.yaml`). Format on save is enabled.

## Adding a New Feature

1. Create `lib/pages/myFeature/` with the 5-file pattern (datasource, repository, usecases, entity, page).
2. Register all three classes in `lib/core/injection.dart` (lazy singletons).
3. Add the use-case to `AppServices` constructor and its field in `app_services.dart`.
4. Add navigation entry in `lib/pages/home/home_page.dart`.
5. Run `fvm flutter analyze` and `fvm flutter test`.

## Testing

Only one test file exists (`test/page1_usecases_test.dart`). No test infrastructure beyond `flutter_test`. Add unit tests for use-cases and repositories as you build features.

## CI

Single GitHub Actions workflow (`.github/workflows/docs.yml`) — auto-generates GitHub Wiki from `docs/wiki/` on push to `main`. No build/lint/test CI exists yet.