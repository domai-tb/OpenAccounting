## Context

`RechnungenDataSource.finalizeRechnung` shares one transaction for numbering, inventory, PDF persistence, journal entries, receivables, and input-tax claims. It currently applies stock and financial paths without deciding whether the persisted type is a supported invoice. `RechnungTyp` recognizes `rechnung_eingang`, `eingangsrechnung`, and `eingang`, but the finalizer does not canonicalize the incoming number range. A separate `ForderungenRepository.createForRechnung` is exposed in `AppServices` and treats every supplier-linked finalized record as incoming. Storno restores line quantities rather than the quantities actually deducted. PDF filenames contain only the range-local display number, so different ranges can target the same path.

## Goals / Non-Goals

**Goals:**

- Keep the number, snapshot, PDF, and database transaction lifecycle for supported documents.
- Post journal and partner receivable rows only for outgoing/incoming invoices; create generic input-tax claims only for incoming invoices.
- Apply the same invoice classification in `ForderungenRepository.createForRechnung`.
- Deduct stock only for outgoing sales invoices, combining repeated article lines before checking or updating stock.
- Restore Storno stock only from negative source movements and preserve the existing legacy-stock compatibility rule explicitly.
- Route incoming aliases and supplier-linked legacy `rechnung` through the incoming range; fail closed on unsupported types and invalid ranges.
- Persist each newly generated PDF by document row ID, independent of number-range collisions; never overwrite or clean up an unrelated file.

**Non-Goals:**

- Change correction-document journal, receivable, or tax signs. Dedicated Gutschrift and Storno methods remain the correction entry points; generic finalization rejects those correction types.
- Add output-tax account mappings, balanced double-entry postings, report behavior, or a supplier-document-number field.
- Rename or rewrite existing PDF files, or backfill historical accounting, tax, or inventory rows.

## Decisions

1. Reuse `RechnungTyp.canonicalize` for direction. Canonical `rechnung` without a supplier is outgoing. `rechnung_eingang`, `eingangsrechnung`, and `eingang` are incoming. A legacy `rechnung` with a supplier remains incoming. An incoming invoice linked only to a customer remains an expense/input-tax document with no customer receivable, preserving the current optional-partner behavior. A supplier link on an offer or other non-invoice type does not make it an invoice. Use this same resolved direction to select the accounting partner and PDF counterparty; on a supplier-linked legacy invoice, the supplier takes precedence if both partner IDs exist.
2. Generic finalization accepts canonical outgoing/incoming invoices and the existing document-only types `angebot`, `auftrag`, `proforma`, and `lieferschein`. Gutschrift and Storno stay on their dedicated paths; an unsupported raw type, range label used as a type, or correction type passed to the generic finalizer fails before number allocation or file writes. The invoice-derived receivable API applies the same accepted invoice types before resolving a partner.
3. Select `rechnung_ausgang` for outgoing invoices and `rechnung_eingang` for incoming aliases or supplier-linked legacy invoices. A missing, inactive, or malformed selected range fails inside the transaction; never fall back to another range. Existing display formats remain user-configured and range-local.
4. Store new finalized PDFs under `pdfs/documents/<rechnung-id>.pdf` and use a sibling temporary file. Incoming aliases use the existing generic invoice PDF layout; when a supplier exists, render that supplier as the counterparty even if the legacy row also has a customer. Existing `original_pdf_pfad` values remain untouched. Refuse to start if the row-identity target already exists. Mark the final path operation-owned only after its temporary file is successfully renamed; failure cleanup may remove only that owned path and temporary file. This protects existing root-level PDFs and same-number records without changing display-number policy.
5. Inventory participates only for outgoing invoices. First sum all inventory-enabled line quantities by article, then validate each combined quantity against the starting stock and update that article once with one matching negative movement. Tracked rows (`lager_aktiv = true`) use `bestand_aktuell` as their starting stock. The supported legacy-stock predicate is exactly `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0`; it retains the existing compatibility behavior of treating `bestand` as tracked stock, updating both stock columns, and enabling `lager_aktiv`. With `lager_aktiv = false` and no such legacy value (including both stock columns zero), stock is disabled: do not validate, deduct, or re-enable it.
6. Storno sums only negative source movements where `referenz_typ = 'rechnung'` and `referenz_id` is the source invoice ID, grouped by article. Restore one positive movement per eligible article. An article still explicitly disabled under the predicate above is skipped and stays disabled; a legacy article is restored and enabled. A source with no negative movement cannot increase stock. This also supports prior finalizations without inferring effects from line items.
7. Keep all database mutations in the existing transaction. Add a document-stage fault point after PDF rename and document update so rollback coverage can prove number/state/rows are restored and the operation-owned file is removed. Existing accounting fault points cover late outgoing and incoming posting failures. Storno rollback is exercised by a database-trigger failure after movement restoration and before the transaction commits.

The file identity is based on the existing document row, not a new registry or schema field. Combined-quantity aggregation is the smallest correction that makes stock validation, actual balances, movement rows, and later Storno restoration agree.

## Risks / Trade-offs

- Legacy rows matching the explicit predicate are treated as tracked stock even though the flag is false → preserve this compatibility rule consistently in finalization and Storno; do not apply it when current stock is already set or legacy stock is zero.
- Existing duplicate display numbers remain as historical data → keep their stored artifact paths and ensure only future generated PDFs use row identity.
- Incoming invoices without a supplier create no partner receivable → retain the existing optional-partner behavior and still use expense/input-tax classification.
- Existing incorrect outgoing input-tax and non-invoice postings remain unchanged → reconcile finalized records only through a separate correction workflow.

## Migration Plan

No schema or file migration is required. New finalizations use type-scoped posting and row-ID PDF paths. Existing PDF paths and finalized rows are preserved. Reverting the source commit restores the previous finalization behavior.

## Open Questions

None for this bounded change. Financial correction signs and historical reconciliation remain separate contracts.
