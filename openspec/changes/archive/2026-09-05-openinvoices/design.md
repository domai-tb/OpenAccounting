## Context

OpenInvoices is a brownfield extension of the existing OpenAccounting Flutter/Dart desktop application. The existing GetIt/AppScope/AppServices dependency flow and Page → UseCase → Repository → DataSource architecture remain authoritative. The current 38 tables define the base schema; feature migrations may add only explicitly named tables. The application targets Windows, macOS, and Linux with a single codebase.

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

### D1: State Management and Dependency Injection — Existing Flutter Services
**Decision**: Retain GetIt for registration, AppScope for widget access, AppServices for aggregation, and Flutter-native state mechanisms for page state.
**Alternatives considered**: Introducing Riverpod or another replacement state container.
**Rationale**: The existing application already provides dependency injection and service boundaries. A new required state framework would add migration risk without improving local-first behavior.

### D2: Database — Existing SQLite Base Schema
**Decision**: Retain the existing SQLite database boundary and define the current 38 tables as the base schema. Feature migrations add only explicitly named tables and increment the schema version.
**Alternatives considered**: Recreating the database or introducing an unbounded table set.
**Rationale**: Brownfield data compatibility requires preserving the current schema contract. WAL mode, foreign keys, monetary precision, and `PRAGMA user_version` remain database-layer concerns.

### D3: Navigation — Existing Flutter Routing
**Decision**: Retain the existing Flutter navigation boundary and add routes through the current app shell.
**Alternatives considered**: Replacing navigation with a new required routing framework.
**Rationale**: Feature work should not force an application-wide routing migration.

### D4: Optional Network Client — Dio Behind Data Sources
**Decision**: Dio may be used only by optional network data sources; local-first flows do not require Dio, a backend, or backend authentication.
**Alternatives considered**: Making a backend mandatory for core workflows.
**Rationale**: Data-source boundaries keep optional integrations isolated. Retries apply only to idempotent operations or mutations carrying idempotency keys.

### D5: PDF Generation — dart_pdf
**Decision**: dart_pdf (pdf/widgets) for document generation.
**Alternatives considered**: printing (render-based, less control), syncfusion_flutter_pdf (commercial).
**Rationale**: dart_pdf provides full control over layout, supports ZUGFeRD/XRechnung embedding, and PDF/A-3 archival.

### D6: Architecture — Feature-First
**Decision**: Feature-first directory structure.
**Alternatives considered**: Layer-first (features/ vs widgets/), domain-driven.
**Rationale**: Feature-first groups related code together, making it easier to locate and modify feature-specific code.

### D7: Desktop Integration — Flutter Native
**Decision**: Use Flutter desktop APIs and target-platform plugins for tray, shortcuts, window management, file associations, and optional updates.
**Alternatives considered**: Tauri, webviews, Electron, or a Python sidecar.
**Rationale**: The product is a Flutter desktop app. Tauri/webview/sidecar behavior is not part of the runtime contract; updater enablement remains conditional on a documented package-signing trust model.

### D8: Profile System
**Decision**: Multiple profiles with isolated databases via `profile.json` pointer, validated single-component names, canonical path containment, and symlink-escape rejection.
**Alternatives considered**: Single database with tenant column, separate installs.
**Rationale**: Profile isolation prevents data leaks between businesses. Restart required for profile switch (simpler than live migration).

### D9: Backup Strategy
**Decision**: Local WAL-safe rotation (max 5) below active profile `APP_DATA_DIR`, plus separately validated and explicitly approved encrypted external/SMB targets.
**Alternatives considered**: Cloud backup (requires credentials), single backup only, treating every destination as profile-local.
**Rationale**: Local backups stay within the active profile. External destinations are deliberate exceptions with OS-protected credentials and authenticated encryption for passphrase-based backups.

### D10: Brownfield Schema Evolution
**Decision**: Preserve the current 38-table base schema and use versioned migrations for feature additions, including explicitly named tables such as `inventarbewegungen`.
**Alternatives considered**: Recreating the database, implicit log tables, migration-free feature storage.
**Rationale**: Existing data and the base schema remain stable while feature storage stays explicit and reviewable.

## Risks / Trade-offs

- **[Risk]** Large scope (16 capabilities) → **[Mitigation]** Phase implementation, MVP first (core invoicing + accounting)
- **[Risk]** GoBD compliance complexity → **[Mitigation]** Immutable journal entries via database triggers, complete audit trail
- **[Risk]** PDF layout fragility → **[Mitigation]** Template-based approach, versioned templates
- **[Risk]** Desktop platform differences → **[Mitigation]** Flutter-native platform integrations and target-specific behavior documented in spec; no Tauri/webview/sidecar assumptions
- **[Risk]** drift migration complexity → **[Mitigation]** Schema versioning with backup-before-migrate pattern

## Migration Plan

Apply to existing OpenAccounting installation. Deployment:
1. Preserve current shell, DI, service, and database boundaries
2. Add versioned migrations for the base schema and explicitly named feature tables
3. Implement features in phase order
4. Validate local profile and backup path boundaries
5. Package for distribution (Windows MSI, macOS DMG, Linux AppImage) using Flutter-native tooling

## Open Questions

- Should ZUGFeRD be supported in v1 or deferred to v2?
- Which bank CSV templates are highest priority for initial release?
- Should the Anlage EKS (9-page form) be PDF-fillable or just printable?
