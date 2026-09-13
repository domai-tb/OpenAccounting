## Why

Desktop integrations are implemented as isolated adapters but are not consistently registered from production bootstrap. The updater is intentionally fail-closed, while documentation and active specifications still describe obsolete Tauri/React/Python architecture.

## What Changes

- Wire supported desktop handlers through production bootstrap and make registration idempotent.
- Surface unavailable platform actions and updater policy states without false success.
- Define the Flutter-only platform contract and target-specific fallbacks.
- Align stale docs and contradictory OpenSpec desktop requirements with the current source of truth.

## Capabilities

### New Capabilities

- `desktop-capability-availability`: Production desktop action wiring, target support, fallbacks, and updater availability.
- `specification-source-parity`: Flutter/Dart architecture as the single source of truth for docs and active specs.

### Modified Capabilities

None. Existing desktop specifications remain the baseline until these focused parity and availability contracts are implemented.

## Impact

- `lib/main.dart`, desktop adapters, updater status UI, `docs/`, and `openspec/specs/`.
- Desktop target tests and mechanical documentation/spec validation.
- Updater installation remains out of scope until a separate signed-update policy is approved.
