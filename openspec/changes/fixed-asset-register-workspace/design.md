## Context

`anlageverzeichnis` exists in SQLite but has no asset repository, use case, or CRUD route. Its columns are `bezeichnung`, `anschaffungsdatum`, `anschaffungskosten`, `nutzungsdauer`, `kategorie_id`, `unternehmen_id`, `status`, and `privatanteil` (`lib/core/db/database.dart:718-728`). The maintained asset spec instead names net cost, useful life in years, linear method, asset type, private-use percentage, and `verkauft_am` (`openspec/specs/accounting/spec.md:625-651`). `docs/02-buchhaltung.md:279-298` also documents `kaufdatum` and a degressive method, which the maintained spec does not support.

`EuerService.generate` reads every asset row directly for EÜR line 33, interprets the legacy amount/life/private-share columns, dynamically selects one of three optional disposal-date names, prorates partial years by inclusive active months, and calculates no opening or remaining book value (`lib/features/accounting/euer_service.dart:84-143,267-291`). The declared schema contains none of those disposal-date columns. `tax-reporting-and-export-integrity` requires disposal cutoff to be documented but supplies no cutoff formula (`spec.md:32-48`).

The active `accounting-reporting-workspaces` change owns typed EÜR/report/export workflows and is still under `REVISE`; it does not propose asset CRUD. This change owns the asset records and schedule source. It must not duplicate the EÜR calculator, report export, or period summary, and its schedule cannot be treated as complete EÜR output until the relevant contracts are accepted.

## Goals / Non-Goals

**Goals:**

- Add a canonical `/assets` workspace with typed asset create, read, update, delete/archive, and source inspection.
- Persist unambiguous canonical asset inputs and a traceable annual schedule snapshot.
- Calculate only the full-year linear AfA formula and private-use adjustment already stated in `accounting`; expose the source values and formula with each result.
- Mark unresolved fields and unsupported periods unavailable and keep their EÜR/AVEÜR result incomplete.
- Keep asset changes and schedule generation separate from journal posting and account assignment.

**Non-Goals:**

- Supporting degressive AfA, partial-year proration, remaining/opening book values, disposal gains/losses, or any other formula not defined by an accepted accounting contract.
- Automatically choosing asset account mappings or posting acquisition, depreciation, or disposal entries.
- Replacing the EÜR/tax report workspace, its form version, export lifecycle, or dashboard summary.
- Silently migrating ambiguous legacy field values into new tax inputs.

## Decisions

1. **Use a separate asset route and service owner.** Add `/assets` to the exact canonical route inventory and provide a German `/anlagen` alias. `AssetRegisterUseCases` will coordinate an asset repository and schedule service through `AppServices`; widgets will not query SQL. Keep list, create/edit form, and a selected-asset inspector in the same workspace. The primary action is `Anlage hinzufügen`; the table shows type, acquisition date, supported cost, useful life, private share, status, and schedule readiness. Follow `DESIGN.md` page-header, table, keyboard, focus, empty, and failure-state guidance.

2. **Persist canonical values without guessing legacy meaning.** New inputs use the maintained contract names and units: asset type, net purchase price, life in years, linear method, private-use percentage, acquisition date, optional category reference, and disposal date. Use the existing `anschaffungsdatum` column as the canonical acquisition date; the documentation's `kaufdatum` name does not require a duplicate field. Keep the existing `unternehmen_id` and category reference as stored links, but do not reinterpret the category as an account. Add explicit columns for contract fields not represented by the current schema and a single supported disposal-date field. Leave legacy `anschaffungskosten`, `nutzungsdauer`, and `privatanteil` intact; only make a legacy record calculation-ready after its mapping has been verified. Do not import the documentation-only degressive method.

3. **Make schedule output source-traceable and limited.** A shared `AssetScheduleService` supplies annual rows to the asset workspace and, when accepted, the existing EÜR owner. Persist the asset ID, schedule year, source-input snapshot, calculation/rule version, result state, formula, and amount or blocking reason. For a complete year with no acquisition or disposal in that year, use the maintained formula `kaufpreis_netto / nutzungsdauer_jahre`; apply the private-use percentage only to KFZ assets. Until an accepted rule covers private use for EDV or sonstig, a non-zero private-use percentage on those types makes the row unavailable. Opening/remaining book values and acquisition/disposal-year amounts stay unavailable until their formulas are accepted. The existing EÜR calculation must consume this owner rather than keep a second AfA implementation.

4. **Protect schedule history.** Permit hard deletion only before any schedule snapshot exists for that asset. Once a snapshot exists, retain the asset identity and allow archive/retirement; schedule rows are append-only, and later edits create a new input snapshot without rewriting or deleting old rows. Whether past year reports should be recalculated after a source edit remains open; a changed record alone must not silently replace a materialized schedule.

5. **Keep financial effects gated.** The `kategorie_id` field is register metadata, not a posting-account contract. The workspace creates no journal or tax-claim rows. If acquisition/disposal accounting or an account mapping is later required, it must use the accepted shared posting boundary and remain unavailable until the asset-event contract exists. The active `accounting-reporting-workspaces` EÜR page may consume only complete schedule rows and owns report/export presentation; this change does not render a parallel EÜR form.

## Risks / Trade-offs

- [Legacy table columns have ambiguous net/gross, unit, and percentage meanings.] → Preserve raw values, require explicit verification, and mark affected schedules incomplete.
- [The current EÜR AfA reader applies undocumented month proration and optional disposal fields.] → Replace that path with the shared schedule owner; partial acquisition/disposal years stay unavailable until a rule is accepted.
- [The maintained spec requires remaining book value at disposal without defining its formula.] → Retain the asset and disposal source date, but show no book value or disposal amount until the accounting contract defines it.
- [The active reporting-workspaces proposal is not approved and overlaps at EÜR line 33.] → Keep this change to asset data and its typed schedule source; do not imply the EÜR report/export is ready.

## Migration Plan

1. Add the `/assets` route, service/use-case boundary, and additive canonical asset columns plus schedule-snapshot storage. Before release, register the new schedule table and add it to the versioned profile-export inventory.
2. Preserve existing rows and values. Do not bulk-copy legacy amount, life, private-share, or date fields until an explicit mapping is confirmed.
3. Enable CRUD for verified records. Show unresolved legacy rows for review without using them in calculated schedule totals.
4. Enable only full-year schedule rows whose inputs and formula are supported. Keep EÜR/AVEÜR incomplete when an in-scope asset cannot be calculated; make no journal writes.
5. Roll back by hiding the route and service wiring while retaining asset rows and schedule snapshots; do not remove referenced records or journal history.

## Open Questions

- Does `anschaffungskosten` mean net price, gross price, or a mixed legacy value, and can `nutzungsdauer` and `privatanteil` be mapped safely to years and percent?
- How should acquisition/disposal-year AfA be prorated, what is the authoritative disposal cutoff, and how should remaining/opening book value and the final year be computed?
- Does the documentation's degressive method remain a product requirement, or is it stale relative to the maintained linear-only accounting spec?
- What account mappings, if any, apply to acquisition, annual depreciation, and disposal, and which asset actions are financial events under the accepted posting contract?
- Which `unternehmen_id` scope is authoritative for EÜR and EKS, and how should legacy rows with no company link be presented?
- How should a source edit affect already materialized schedule snapshots and previously exported EÜR artifacts?
