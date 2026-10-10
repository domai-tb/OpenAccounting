## Context

Feature-map item 73 asks for explanations of VAT treatment, GoBD concepts, tax categories, invoice statuses, and special accounting situations (`pasted-text-1.txt:1259-1269`). Production `HelpPage` is a generic list of static placeholder tiles for settings, local storage, and invoices; source contains no accounting/tax helper text beyond a bank import path hint. `DESIGN.md` requires labels above form controls, keyboard focus, semantic accessible labels, German-first localization, and a maximum 720 px width for long help content. The product vision says the app prepares accounting information and does not replace professional tax advice (`pasted-text-1.txt:1338-1343`).

## Goals / Non-Goals

**Goals:**

- Explain what supported accounting/tax controls mean in OpenAccounting and what the selected value changes in its workflows.
- Make each explanation available beside its field/status and through a Help glossary.
- Keep content reviewed, versioned, localized, and connected to the capability contract it explains.
- Make unsupported or unsettled behavior explicit without guessing.

**Non-Goals:**

- Recommend tax treatment, decide whether a business qualifies for a tax regime, or replace professional advice.
- Change posting, invoicing, tax calculation, accounting-category, or filing behavior.
- Add external network help, user-authored policy content, or a legal-knowledge search engine.
- Explain every general application feature in the first delivery; coverage is limited to accounting and tax concepts and states named in the feature map.

## Decisions

1. **Use one typed content catalog.** Each help entry has a stable ID, a German and English title/body, the control or status IDs it explains, the owning capability/specification, an explanation revision, and a review state. Visible content comes only from localized resources. A field without a reviewed entry has no fabricated fallback; its help affordance is unavailable and the coverage check reports it.
2. **Keep guidance next to the decision.** Relevant controls and statuses use a labeled `Erklärung`/`Why this matters` affordance or short helper text that opens a nearby detail surface. Do not rely on hover, color, or an unlabeled icon. The same stable entry is listed in Help, searchable by its localized terms and grouped by workflow.
3. **Explain product behavior, not user eligibility.** Content may define the application's supported meaning, required inputs, and consequences of a choice. It SHALL NOT recommend a rate/category, infer a tax status from profile text, promise legal compliance, or describe an unimplemented action as available. Where policy is unresolved, the entry states the limitation and points to the relevant review/unavailable state.
4. **Tie explanations to accepted behavior.** Each entry references the reviewed capability contract for the behavior it describes. If the contract changes, the entry returns to review-needed until its text is reconciled. No official tax-year claim is included without an approved source and version.
5. **Bound the first release inventory.** The initial coverage inventory has exactly these stable IDs, each bound to one UI route and one control/status ID; it is a maintainer-facing artifact and each begins `missing` until reviewed German/English copy is approved. IDs are anchored to the named maintained capability requirement, so later controls require an explicit inventory addition rather than silently expanding scope.

| Stable help ID | Owning capability requirement | UI route | Control / Status ID | Initial state |
|---|---|---|---|---|
| `accounting.category.skr-mapping` | `accounting` → Kategorien | `/reports` | `konten.skrMappingField` | missing |
| `accounting.journal.immutability` | `accounting` → Journal Entries | `/reports` | `journal.immutabilityNotice` | missing |
| `accounting.journal.storno` | `accounting` → Storno Correction | `/reports` | `journal.stornoAction` | missing |
| `accounting.journal.group` | `accounting` → Journal Entries | `/reports` | `journal.groupField` | missing |
| `accounting.euer.input-tax-claim` | `accounting` → Input-tax claim direction during generic finalization | `/taxes` | `euer.inputTaxClaimField` | review-needed |
| `einkommen.forderung.status` | `einkommen` → Forderungen table for open items | `/invoices` | `forderung.statusControl` | missing |
| `einkommen.forderung.overpayment` | `einkommen` → Überzahlungs-Protokoll | `/invoices` | `forderung.overpaymentNotice` | missing |
| `einkommen.verbindlichkeit.payment` | `einkommen` → Verbindlichkeiten | `/invoices` | `verbindlichkeit.paymentControl` | missing |
| `mahnwesen.fee-interest` | `mahnwesen` → Mahngebühr Tracking and Verzugszinsen Tracking | `/invoices` | `mahnung.feeInterestField` | review-needed |
| `bank-import.match-status` | `bank-import` → Score-Based Matching | `/banking` | `bankImport.matchStatusControl` | missing |
| `bank-import.classification` | `bank-import` → Transaction Classification Override | `/banking` | `bankImport.classificationControl` | missing |
| `documents.angebot.status` | `documents` → Angebot status lifecycle | `/invoices` | `angebot.statusControl` | missing |
| `documents.auftrag.status` | `documents` → Auftrag status lifecycle | `/invoices` | `auftrag.statusControl` | missing |
| `accounting.correction.credit-sign` | `correction-document-accounting-integrity` → Correction totals preserve signed VAT mathematics | `/invoices` | `correction.creditSignField` | review-needed |
| `accounting.tax.special-25a` | `accounting` → Differenzbesteuerung §25a Accounting | `/taxes` | `tax.special25aField` | review-needed |

No other field or status receives contextual help in the first release. The first-release reviewed set is all 15 stable IDs above; each SHALL have reviewed German and English copy before release, each SHALL be attached to its listed route/control or status, and each SHALL be listed and searchable in the `/help` glossary. `missing` and `review-needed` rows stay in the repository coverage inventory only; they do not render placeholders or warnings in the app, and any entry not yet reviewed stays maintainer-only with no end-user affordance. Entries whose text depends on law must record primary source, jurisdiction/provision, version or tax year, retrieval date, applicability period, and owning spec revision. The German Accounting and Tax Domain Reviewer is accountable for source-language meaning; the English Localization Reviewer is accountable for the translation. Contract/source changes and an annual pre-release review move the entry to `review-needed` until both approvals are recorded.
6. **Follow `DESIGN.md`.** Keep inline help short, use a labeled accessible control for longer content, preserve logical keyboard order and visible focus, localize all text, support text scaling and narrow windows, and constrain glossary text to approximately 720 px.

## Risks / Trade-offs

- [Risk] Explanations imply legal or tax advice. → Mitigation: describe app behavior only, name unsupported cases, and require domain review for each content entry.
- [Risk] Guidance becomes stale after accounting rules change. → Mitigation: store an owning spec reference and require re-review on contract change.
- [Risk] Field-level guidance adds visual noise. → Mitigation: keep short helper text near the field and put full explanations behind an explicit labeled affordance.
- [Risk] A glossary exists while controls have no registered guidance. → Mitigation: maintain a control-to-entry coverage inventory and show missing coverage to reviewers; do not claim all fields are covered based only on glossary entries.

## Migration Plan

No database migration is needed. Add the typed catalog, localized entries, shared context-help widget/API, and Help glossary. Roll out only entries reviewed against accepted product contracts. A missing or review-needed content entry SHALL display no unsupported explanation and SHALL NOT block the underlying supported field. The Help glossary and per-field affordance can be hidden during rollback without changing business records.

## Open Questions

None open. Decisions taken during design:

- Reviewer ownership is the German Accounting and Tax Domain Reviewer for source-language meaning and the English Localization Reviewer for the translation; both approvals are required before an entry is marked reviewed.
- Every law-dependent entry MUST cite an authoritative primary source with jurisdiction/provision, publication/effective version or applicable tax year, retrieval date, applicability period, and owning spec revision before it can be reviewed; re-review is triggered by source change, owning-contract change, expiry of the applicability period, or the annual pre-release review.
- The first-release coverage matrix is closed at the 15 stable IDs above; no additional field IDs belong in the first release, and any later control requires an explicit inventory addition.
