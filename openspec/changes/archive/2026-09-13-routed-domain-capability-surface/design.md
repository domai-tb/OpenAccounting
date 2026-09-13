## Context

The router currently uses a generic data repository with `SELECT *`, raw values, and a 100-row limit for many routes. Domain services exist for several features but are not all exposed through `AppServices` or user-facing pages. Dashboard cards, setup summaries, and bank-import recovery therefore cannot show reliable next actions.

## Goals / Non-Goals

**Goals:**

- Define the canonical route inventory and preserve German aliases, IDs, and queries.
- Give each route a typed service boundary, useful states, and a valid primary action or explicit unavailable boundary.
- Add scalable list queries and route-specific details without changing accounting calculations.
- Correct dashboard destinations and expose setup/import state and recovery.

**Non-Goals:**

- Replacing existing domain repositories or changing database accounting invariants.
- Building new inventory, tax, or reporting calculations where none exist.
- Hiding a missing capability behind fabricated placeholder data.

## Decisions

- Keep GoRouter responsible for canonical paths and alias redirects; each route page receives a typed capability from `AppServices`.
- Define route view models with explicit projections and `AsyncValue`-like states (`loading`, `data`, `empty`, `error`); raw SQL remains an internal data-source concern.
- Add list query objects carrying search, sort, page, page size, and `hasMore`/total metadata.
- Use route-specific action descriptors so available buttons come from domain status and permissions.
- Treat `/inventory` as unavailable until its service is wired; the dashboard provider must check capability registration before constructing or invoking an inventory query. In the unavailable branch it emits `CapabilityUnavailable` without touching an inventory data source.
- Keep setup and import writes transactional and expose service results, including manual-review counts, unchanged.
- Classify startup/profile state separately: `UnconfiguredProfile` may redirect to `/setup`; `DatabaseUnavailable` and `SchemaOrDataFailure` stay on the requested route with a localized retry/diagnostic state. Retry reopens the same profile and route; it never mutates completion flags.
- Preserve this alias matrix exactly: `/rechnungen` → `/invoices`, `/rechnungen/:id` → `/invoices/:id`, `/belege` → `/receipts`, `/belege/:id` → `/receipts/:id`, `/bank` → `/banking`, `/kontakte` → `/contacts`, `/steuern` → `/taxes`, `/auswertungen` → `/reports`, and `/einrichtung` → `/setup`. Every redirect carries the original path parameters and complete query string unchanged.
- The typed route matrix is the implementation boundary:

  | Canonical route | Service owner | Projection/actions | Empty or unavailable boundary |
  | --- | --- | --- | --- |
  | `/` | `DashboardService` | typed metrics, card destinations, widget config | no cards / config retry |
  | `/invoices` | `RechnungenUseCases` | paged invoices, search/status, create/import | empty create |
  | `/invoices/new` | `RechnungenUseCases` | draft form, save/finalize | validation/persistence retry |
  | `/invoices/:id` | `RechnungenUseCases` | positions, totals, lifecycle/artifact actions | typed not-found |
  | `/receipts` | `ReceiptsUseCases` | paged receipts, reconcile/import | empty import |
  | `/banking` | `BankImportUseCases` | imports, history, manual review | capability unavailable |
  | `/contacts` | `ContactsUseCases` | paged contacts, create/edit/dunning | empty create |
  | `/taxes` | `TaxReportingUseCases` | typed tax summary/export or read-only boundary | unavailable explanation |
  | `/reports` | `TaxReportingUseCases` | typed report list/export or read-only boundary | unavailable explanation |
  | `/settings` | `SettingsController` | persisted settings/profile actions | load/save retry |
  | `/help` | static localized help capability | searchable topics/contact action | empty topic |
  | `/setup` | `SetupUseCases` | company/account/category/profile writes | rollback/retry |
  | `/inventory` | `InventoryUseCases` when registered | typed stock list/actions | `CapabilityUnavailable` without fetch |

  Each row owns its loading, populated, empty, and failure view-model states and a fake service seam under `test/features/routed_surface/`.

Alternatives rejected: one generic “record viewer” for all routes (cannot express domain actions), client-side filtering after `SELECT *` (leaks data and does not scale), and silently routing missing features to a nearby page (misleads users).

## Risks / Trade-offs

- [Many routes need adapters] → Implement route groups in dependency order and preserve existing repository APIs.
- [Pagination changes query behavior] → Keep deterministic ordering and expose `hasMore`; test boundary pages.
- [A domain capability is genuinely absent] → Show a typed unavailable state with a safe return action.
- [Database errors are mistaken for setup] → Keep the three startup states distinct and test each redirect/retry path.

## Migration Plan

1. Add typed route view models and fake service adapters with failing tests.
2. Migrate invoices and banking, then receipts/contacts/taxes/reports.
3. Migrate settings/help/setup/dashboard actions and remove fabricated telemetry.
4. Add alias and pagination tests, then full analyzer/test/OpenSpec gates.
5. Roll back per route to its previous page adapter without changing stored records.

## Resolved Scope

- Tax and report routes expose only actions backed by a registered typed use case (for example, view/export); otherwise they show a truthful read-only/unavailable boundary.
- Profile switching rebinds the typed service registry after a successful transactional switch and routes to the same canonical destination. A failed switch leaves the prior profile and services active and exposes retry.
