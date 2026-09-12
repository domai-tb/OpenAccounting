# OpenAccounting

OpenAccounting is a local-first Material 3 desktop accounting app for German freelancers. It stores the active profile in a local Drift/SQLite database and supports German and English localization infrastructure.

## Getting started

Use the pinned Flutter SDK through FVM:

A few resources to get you started if this is your first Flutter project:

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test --dart-define=platform=vm
```

Desktop development requires GTK 3. Linux builds also need the native
dependencies declared by `hotkey_manager_linux` and `system_tray`.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Release checks

Run the pinned analyzer and the complete VM test suite from the repository root:

```bash
fvm flutter analyze
fvm flutter test --dart-define=platform=vm
```

Both commands must pass before accepting a release.
