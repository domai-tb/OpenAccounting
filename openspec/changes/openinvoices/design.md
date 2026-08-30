## Context

OpenInvoices is a greenfield Flutter/Dart desktop application. There is no existing codebase — all 38 database tables, business logic, and UI are built from scratch. The application targets Windows, macOS, and Linux with a single codebase.

## Goals / Non-Goals

**Goals:**
- Cross-platform desktop application with native feel
- GoBD-compliant accounting with complete audit trail
- 1:1 feature coverage for all invoicing and accounting requirements
- Desktop-first UX with system tray, global shortcuts, offline operation
- Multi-profile support for managing multiple businesses

**Non-Goals:**
- Mobile application (desktop only for v1)
- Multi-user / concurrent access (single-user desktop)
- Cloud sync (local-first, user manages backup)
- Web application (Flutter desktop only)
- Real-time collaboration

## Decisions

### D1: State Management — Riverpod 2.x
**Decision**: Riverpod 2 with code generation for type-safe providers.
**Alternatives considered**: BLoC (more boilerplate), GetX (less type-safe), Provider (limited for complex state).
**Rationale**: Riverpod provides compile-time safety, dependency injection, and caching via AsyncNotifier pattern. Code generation reduces boilerplate.

### D2: Database — drift (SQLite)
**Decision**: drift ORM over SQLite with WAL mode.
**Alternatives considered**: sqflite (less type-safe), floor (less mature), isar (different paradigm).
**Rationale**: drift provides type-safe queries, migration support, and WAL mode for concurrent reads. 38 tables with NUMERIC(12,2) for money. Schema versioning via PRAGMA user_version.

### D3: Navigation — GoRouter
**Decision**: GoRouter with named routes and deep linking.
**Alternatives considered**: auto_route (code gen heavy), Navigator 2.0 (complex), beamer (less maintained).
**Rationale**: GoRouter provides declarative routing, URL-based navigation, and redirect guards for setup wizard.

### D4: HTTP Client — Dio
**Decision**: Dio with retry interceptor and error handling.
**Alternatives considered**: http (less features), Chopper (code gen).
**Rationale**: Dio provides interceptors, retry, timeout, and structured error handling. Used for backend API communication.

### D5: PDF Generation — dart_pdf
**Decision**: dart_pdf (pdf/widgets) for document generation.
**Alternatives considered**: printing (render-based, less control), syncfusion_flutter_pdf (commercial).
**Rationale**: dart_pdf provides full control over layout, supports ZUGFeRD/XRechnung embedding, and PDF/A-3 archival.

### D6: Architecture — Feature-First
**Decision**: Feature-first directory structure.
**Alternatives considered**: Layer-first (features/ vs widgets/), domain-driven.
**Rationale**: Feature-first groups related code together, making it easier to locate and modify feature-specific code.

### D7: Desktop Integration
**Decision**: system_tray + hotkey_manager + window_manager + auto_updater.
**Alternatives considered**: tauri (Rust overhead), electron (not Flutter).
**Rationale**: These packages provide native desktop features without leaving Flutter.

### D8: Profile System
**Decision**: Multiple profiles with isolated databases via profile.json pointer.
**Alternatives considered**: Single database with tenant column, separate installs.
**Rationale**: Profile isolation prevents data leaks between businesses. Restart required for profile switch (simpler than live migration).

### D9: Backup Strategy
**Decision**: Local WAL-safe rotation (max 5) + AES-256-GCM encrypted external + SMB network share.
**Alternatives considered**: Cloud backup (requires credentials), single backup only.
**Rationale**: Three-tier backup balances convenience (local) with security (encrypted) and redundancy (SMB).

### D10: Greenfield Build
**Decision**: All 38 tables created fresh on first run. No migration from existing systems.
**Alternatives considered**: Import from CSV, migration scripts.
**Rationale**: Greenfield means no legacy data to migrate. Seed data populated on first run.

## Risks / Trade-offs

- **[Risk]** Large scope (16 capabilities) → **[Mitigation]** Phase implementation, MVP first (core invoicing + accounting)
- **[Risk]** GoBD compliance complexity → **[Mitigation]** Immutable journal entries via database triggers, complete audit trail
- **[Risk]** PDF layout fragility → **[Mitigation]** Template-based approach, versioned templates
- **[Risk]** Desktop platform differences → **[Mitigation]** Platform-specific workarounds documented in spec
- **[Risk]** drift migration complexity → **[Mitigation]** Schema versioning with backup-before-migrate pattern

## Migration Plan

Not applicable — greenfield project. Deployment:
1. `flutter create openinvoices`
2. Add dependencies to pubspec.yaml
3. Implement database layer (drift)
4. Implement features in phase order
5. Package for distribution (Windows MSI, macOS DMG, Linux AppImage)

## Open Questions

- Should ZUGFeRD be supported in v1 or deferred to v2?
- Which bank CSV templates are highest priority for initial release?
- Should the Anlage EKS (9-page form) be PDF-fillable or just printable?
