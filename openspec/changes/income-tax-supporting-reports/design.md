## Context

Feature-map item 54 asks for accounting-derived supporting reports for Anlage S and Anlage G (`pasted-text-1.txt:992-1001`). The repository's maintained accounting spec and runtime do not define or expose either schedule. `EuerService` computes calendar-year totals, but that does not define official S/G line mappings, commercial/professional classification, allowable source accounts, or each field's tax-year formula. The existing reporting workspace proposal owns EÜR, UStVA, EKS and exports; this change adds only the missing S/G supporting reports and uses no unreviewed totals from those reports.

## Goals / Non-Goals

**Goals:**

- Let a user inspect source-backed workpapers for the selected Anlage S or G and a supported reporting period.
- Trace every shown field to the source records and versioned mapping that produced it.
- Surface unsupported, incomplete, or ambiguous calculations explicitly.
- Make no source-data changes and perform no return submission.

**Non-Goals:**

- Decide whether a business belongs to Anlage S, Anlage G, both, or neither based on company names, occupation text, or transaction descriptions.
- Invent an official form-year field list, account mapping, tax formula, tax treatment, or filing period.
- Present EÜR, EKS, or a GuV total as an Anlage S/G field without a reviewed mapping.
- Submit a tax return or describe a workpaper as legally complete or tax advice.

## Decisions

1. **Use explicit schedule and period selection.** Add `view=income-tax-schedules` to the existing Taxes workspace, with separate Anlage S and Anlage G modes. The selected period comes from an accepted tax-report period contract. A configured business fiscal year may be used only when the accepted schedule-year contract says it applies; no calendar/year equivalence is inferred.
2. **Version the form-line mapping by tax year.** Each displayed schedule field must identify the official form edition and a reviewed mapping from that field to accepted accounting data and calculation rules. New tax-year fields do not inherit old mappings implicitly. This proposal does not supply official field inventories or formulas; they must be approved as a separate source artifact before a field can be calculated.
3. **Require explicit classification and source coverage.** The user selects the schedule being inspected. The service does not decide S versus G from unverified profile text. A line is available only when the company classification inputs, account/category mapping, posting source, and period coverage are accepted and complete for that line.
4. **Show auditable provenance.** For every available amount, show the field label, amount, period, source status, and the record/account categories included. Provide a drill-down list of contributing records and an explanation of the applied versioned rule. Display unavailable or incomplete reasons without zero-filling.
5. **Separate this workpaper from other reports.** Reuse the canonical accounting report source only after it has an accepted completeness and period contract. Do not copy a total from EÜR/EKS or calculate a parallel total in the page. A missing dependency makes the affected field or report unavailable.
6. **Keep this output advisory and read-only.** The view creates no journal posting, changes no business records, and submits nothing to tax authorities. Export, if later added, is labeled as a supporting workpaper with a versioned manifest, not a filed declaration.
7. **Follow the design system.** Use the existing Taxes page header, period controls, dense data table, accessible source drill-down, visible focus, keyboard navigation, localized statuses and field descriptions, active-locale amount/date formatting, and narrow-window behavior from `DESIGN.md`.

## Risks / Trade-offs

- [Risk] An unreviewed S/G assignment or line formula produces misleading tax values. → Mitigation: explicit selection, tax-year versioned mappings, source provenance, and fail-closed unavailable states.
- [Risk] A complete-looking table hides missing source transactions. → Mitigation: report source coverage and unresolved-record counts with every period.
- [Risk] Users confuse a workpaper with a submitted return. → Mitigation: state the supported purpose and provide no submission-success status.
- [Risk] Calendar-year EÜR values conflict with the configured business year. → Mitigation: use the accepted period contract for this schedule and keep unavailable until both owners agree on period semantics.

## Migration Plan

No database migration is required for a read-only initial version. Add the typed schedule projection and versioned mapping service, then expose the Taxes view only for accepted form-year and accounting-source contracts. Do not store guessed mappings in free-form settings or route state. Keep affected fields unavailable until their source artifact and classification requirements are accepted. Rollback hides the view and preserves all accounting records.

## Open Questions

- Which official tax-year form schema is the supported primary source, and who approves its versioned field inventory?
- Which company classification inputs and reviewer establish when Anlage S, Anlage G, or both are relevant?
- Which accepted accounting categories, accounts, and tax treatments map to each field, including unresolved or mixed business/personal records?
- Does each supported schedule use the configured business-year boundary or a separate tax year, and which authority provides that rule?
