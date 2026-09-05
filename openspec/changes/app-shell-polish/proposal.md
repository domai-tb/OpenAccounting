## Why

App shell still has 30+ red layout/state/keyboard/theme/error/print/routing scenarios not flipped; splitting makes <20 test rows per change and respects DESIGN §3-§6, §8, §24, §34.

## What Changes

- Split from openinvoices monolith for agent-friendly scope (<15 tasks)
- Implements deferred/red specs for app-shell-polish
- VM-safe fakes, DESIGN.md alignment

## Capabilities

### New Capabilities
- app-shell-layout: sidebar/canvas/inspector responsive
- app-shell-state: provider caching/invalidation
- app-shell-keyboard: Ctrl+F,+,E/A, zoom

### Modified Capabilities
- none — additive

## Impact

- Affected: lib/features/*, test/features/*
- Dependencies: existing drift/riverpod, no new heavy deps
