# Proposal: Unify runtime composition and database lifecycle

## Why

The documented GetIt/AppScope architecture is not implemented: configureDependencies is a no-op, AppScope and AppServices are absent, setup constructs services inside a route, and dashboard providers can query the unopened default database. The full test suite can remain green while logging LazyDatabase initialization errors.

Evidence: lib/core/injection.dart:12-17 is empty; lib/main.dart:41-62 owns startup composition; lib/features/dashboard/dashboard_widgets.dart:145-249 queries providers; lib/core/db/database.dart:308 exposes an unopened default database.

## What Changes

- Create one application-scoped composition root for the database, repositories, use cases, and cross-feature services.
- Open and migrate the selected profile database before any route/provider can query it.
- Make page-to-use-case-to-repository-to-datasource dependency flow explicit and testable.

## Capabilities

- Unify runtime composition and database lifecycle
- Priority: High
- Dependencies: restore-spec-validation-contract.

## Impact

lib/main.dart, lib/core/injection.dart, lib/core/app_scope.dart, lib/core/app_services.dart, feature providers, and route construction; all feature exposure changes depend on this boundary.
