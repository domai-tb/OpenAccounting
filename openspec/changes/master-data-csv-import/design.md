## Context

`docs/08-einstellungen.md:352-394` describes a CSV migration workflow for customers, suppliers, and articles: choose a file, map columns, choose whether the first row is a header, select a duplicate policy, save a mapping template, and review import progress. The current production feature graph has no such workflow. Master-data repositories exist for customers, suppliers, and articles, but their create methods enforce typed fields, VAT rules, article types and price derivation, and local number allocation. The active `master-data-workspaces-and-crud` proposal owns the typed entry points and CRUD surfaces; this change adds a separate import use case to those surfaces.

The existing `import_mapping_vorlagen` table is tied to `bank_templates` by `template_id` (`lib/core/db/database.dart:904-912`), and the bank importer has its own transaction semantics and CSV parsing (`lib/features/bank_import/bank_import_service.dart`). Neither is a suitable storage or service boundary for master-data imports. `DESIGN.md` calls for searchable, navigable tables and bulk actions (`:572-625`), localized labels from the first implementation (`:1108-1120`), and visible keyboard focus, semantic status, and text-scale support (`:1983-2029`).

The CSV source's `firmenname` shorthand in docs/08 does not meet the current create validators by itself: customer and supplier creation also requires name, street, postal code, city, and country (`KundenRepository.create`, `:220-252`; `LieferantenRepository.create`, `:150-178`). Article creation requires a supported type and an explicit price basis/value (`ArtikelRepository.create`, `:104-155`). This proposal preserves those contracts and surfaces missing values as row errors.

## Goals / Non-Goals

**Goals:**

- Integrate local CSV import into the customer, supplier, and article workspaces without adding another master-data navigation system.
- Provide explicit parsing, field mapping, complete preview, typed validation, safe duplicate review, and a final confirmed commit.
- Store reusable mapping templates in the active profile without retaining source files or raw row values.
- Preserve existing record validation, generated identifiers, customer/supplier number allocation, and article price derivation.
- Make the import review responsive, localized, keyboard accessible, and clear about each row's proposed action.

**Non-Goals:**

- No bank-statement, receipt, incoming-invoice, document, journal, payment, or tax import.
- No import of database IDs, customer/supplier numbers, foreign-key IDs, stock, stock movements, or inventory settings.
- No silent fuzzy matching, speculative data cleanup, or import-driven changes to existing master-data rules.
- No source-file archive, import-history subsystem, remote service, e-invoice parser, or new CSV template for banking.
- No new top-level route; the flow is launched and returned to the owning master-data workspace.

## Decisions

### Use an independent typed import boundary

Add a master-data import use case, repository, parser/validator, and profile-local data source. The existing customer, supplier, and article workspaces invoke it through the application-service boundary. The page receives typed preview rows and row actions; CSV parsing and database operations stay below the page. Keep this capability separate from `BankImportService`, its bank history, matching rules, and tables. Do not add a canonical route: import is a navigable workflow state opened from the customer, supplier, or article list and returns to that list with its query state intact.

Rejected alternatives:

- Reusing `BankImportService` would couple master data to statement templates, account transactions, and banking status semantics.
- Extending the generic route-table reader would provide raw rows without typed validation or safe writes.
- A separate import navigation tree would duplicate the master-data routes owned by `master-data-workspaces-and-crud`.

### Parse a bounded local file and map by column position

Read the user-selected local file as bounded bytes, accept UTF-8 with optional BOM, and require the user to select comma, semicolon, or tab, header presence, and a numeric convention for numeric fields. Parse standard quoted fields, escaped quotes, and quoted line breaks. Reject malformed quoting, unsupported encodings, more than 20 MiB, or more than 50,000 data rows before preview. Preserve CSV values as inert data; never execute spreadsheet formulas or send file content over the network. Map columns by stable position rather than header label so duplicate or blank labels do not shift mappings. A header option controls whether row one is consumed or shown as data; do not guess.

Show a bounded, paginated preview and counts for the full parsed file rather than rendering all rows at once. Preserve the original source row number when parsing, validating, and displaying errors.

For every mapped numeric field, the user selects exactly one decimal convention for the file: decimal point or decimal comma. Trim surrounding whitespace, then accept only a complete token of ASCII digits with an optional single selected decimal separator between non-empty digit sequences: `^[0-9]+(?:[.][0-9]+)?$` for decimal point or `^[0-9]+(?:,[0-9]+)?$` for decimal comma. A token with no separator is an integer and is valid under either choice. Do not accept grouping separators, exponent notation, a sign, the alternate separator, whitespace inside the token, or partial numbers such as `.5`, `5.`, or `12abc`. After full-token validation, normalize the selected decimal separator for the existing typed repository conversion; the repository's field precision and rounding remain authoritative. The importer SHALL NOT apply its own precision rounding.

Rejected alternatives:

- Automatic delimiter, header, or numeric-format guesses can silently reinterpret descriptions and prices.
- A naive whole-file table would conflict with `DESIGN.md`'s large-data guidance and could render tens of thousands of rows.
- Sharing the bank parser would inherit banking-specific templates and behavior instead of defining the supported master-data format.

### Map only typed fields and reuse existing validators

Provide entity-specific allowlists of scalar fields. Customer/supplier mappings may cover identity, address, contact, tax, and documented payment-term values. Article mappings for Create may cover name/description, type, unit, article number, one explicitly selected net or gross selling-price input, purchase price, and tax value. Article Update SHALL NOT accept or change the paired selling-price and derivation fields `vk_netto`, `vk_brutto`, `vk_eingabe`, `ust_satz`, `ust_satz_id`, or `differenzbesteuerung`. For an article row selected for Update, any non-empty supplied value mapped to one of those fields makes the entire row invalid with a localized row-level `unsupported field for article update` error; none of that row's fields are written. If those fields are absent or blank, updates to other supported fields preserve the existing selling-price pair and derivation fields exactly. Reject duplicate source-to-target assignments and prohibit primary keys, generated customer/supplier numbers, related-record IDs, stock fields, and arbitrary table columns. Relation mapping by supplier/group name and initial inventory are deferred so imports cannot create hidden cross-record links or stock effects.

Use the existing typed validators for required fields, VAT IDs, allowed article types, numeric precision, and gross/net derivation. For article Create, require the user to choose one selling-price input basis, gross or net; pass that input and its tax values through the existing article create validator so it derives and persists the paired `vk_netto`/`vk_brutto` values. Do not derive or write either price during article Update. New customer and supplier records receive numbers through the existing local number allocator; incoming source IDs or external numbers are not written into database keys or generated-number fields. An absent required value remains a validation error; the importer does not supply guessed addresses, tax values, or prices. Optional new-record fields use the entity's existing defaults. On updates, blank mapped cells preserve current values; this first version does not clear fields through CSV.

Because customer/supplier identity-number semantics are an unresolved question in the active master-data-workspaces proposal, the import must not assign imported values to `kundennummer`, `debitor_nr`, `lieferantennummer`, or `kreditor_nr`. If preserving an external source number is required, resolve that data contract before implementation and extend the allowlist through an explicit reviewed spec change.

### Make duplicate policies explicit and conservative

Require `Skip` or `Update` imports to use a mapped match field selected by the user. Compare exact normalized values only: trim surrounding whitespace and compare text case-insensitively; parse typed numeric values under the selected numeric convention. Do not score or fuzzy-match names. `Skip` leaves exactly matched records unchanged and creates unmatched valid records. `Update` updates a single exact match only after the preview shows each old/new field value and the user selects that row for update. Unmatched valid rows are proposed as creates. A row with multiple existing matches or a key repeated in the source is ambiguous and cannot be updated. `Create New` may intentionally create records whose key matches existing data, but the preview labels those rows as duplicates and final confirmation includes their count. Recompute duplicate candidates inside the write transaction before committing so a record added after preview cannot be overwritten from stale evidence.

Only explicitly mapped, non-empty source values participate in an update. Unmapped and empty values preserve existing fields. In particular, importing one contact field cannot blank a stored address, tax ID, or payment term. For an article row selected for Update, any non-empty value mapped to `vk_netto`, `vk_brutto`, `vk_eingabe`, `ust_satz`, `ust_satz_id`, or `differenzbesteuerung` instead produces a row-level unsupported-field error and excludes the entire row from writes; the existing price pair and derivation fields remain unchanged. The UI records the selected per-row action in the reviewed batch and requires a final confirmation of the resulting create/update/skip counts.

Rejected alternatives:

- Fuzzy matching on company or article names can select the wrong business record.
- Automatically updating every row with a possible name match can overwrite user-entered data.
- Treating blank source cells as null during update can erase data when a CSV omits a value.

### Commit the reviewed batch atomically

No business row is written during file selection, mapping, preview, validation, or duplicate review. After final confirmation, apply selected valid creates and updates in one active-profile SQLite transaction. Number-range increments for new contacts belong to that same transaction. Extract transaction-aware internal repository methods so the importer uses the same validators, transformations, and number allocator as ordinary create/update calls without nesting independent per-row transactions. Recheck unique targets while holding the transaction; if a duplicate changed, a validator fails, or any write fails, roll back the entire batch and return a retryable failure with no success count. Keep skipped and invalid rows visible in the result. Do not create a persistent import history or retain the CSV; persist only a user-requested mapping template.

Rejected alternatives:

- Independent row commits could leave an unreported partial migration after a process interruption.
- Writing raw SQL from the page would bypass field allowlists, validation, number allocation, and the clean architecture boundary.
- Retaining source CSV data for retry is outside the documented migration workflow and expands sensitive-data retention.

### Persist templates in a dedicated profile table

Add a named, backward-compatible migration that creates a dedicated master-data import-template table. Store template name, entity type, column-index-to-field mapping, header option, delimiter, numeric convention, duplicate policy, optional match field, and timestamps. Do not reuse `import_mapping_vorlagen`: its `template_id` references a bank template. Bind the table to the active profile database so profiles never share templates. Validate the stored mapping on load; reject unknown versions, fields, entity types, duplicate targets, and policy values as an unavailable template rather than applying a partial mapping. Saving, updating, or deleting a template never writes master-data rows.

Rejected alternatives:

- Storing templates in shared preferences could leak mappings across profiles and would not follow the repository's profile persistence boundary.
- Reusing the bank table would require ambiguous entity semantics or a schema change to a bank-owned capability.
- Keeping uploaded CSV content in templates would retain personal and supplier data beyond the user's import session.

### Apply DESIGN.md to the importer

Use the existing page header, cards, form controls, status components, table patterns, and localization pipeline. Present file selection, field mapping, paginated preview, row-level validation/duplicate decisions, and final summary as distinct steps with a clear back path. Keep the preview scrollable and usable at 960×640 and narrow desktop widths. Preserve query, entity, and unsaved mapping state when the user returns to the list. Provide logical keyboard order and visible focus for mapping, row actions, and confirmation; use text/semantics in addition to color; localize all messages; and support text scaling. Do not create new shared design-system components solely for this flow.

## Risks / Trade-offs

- **[Risk]** Existing feature-map examples imply that a company name alone is enough to import a customer or supplier. → **Mitigation:** validate against current create contracts and identify all missing required fields before confirmation; reconcile docs/specs before lowering those requirements.
- **[Risk]** Exact matching misses duplicates with spelling or formatting differences. → **Mitigation:** make the selected key, comparison rule, and all candidate counts visible; require manual correction or explicit Create New for uncertain rows.
- **[Risk]** A large confirmed transaction holds a write lock and briefly blocks other profile operations. → **Mitigation:** bound file bytes and row count, validate before opening the transaction, report progress, and keep preview rendering paginated.
- **[Risk]** Importing an external business-partner number could collide with generated local numbering. → **Mitigation:** exclude generated number fields until the separate number-contract question is resolved.
- **[Risk]** Article types and persisted price fields differ across historical profiles. → **Mitigation:** use repository schema checks and validators; fail the whole batch with an actionable profile-schema error rather than guessing a fallback.

## Migration Plan

1. Confirm the master-data workspaces and the customer/supplier numbering contract are accepted; align docs/08's minimal required-field examples with the existing typed validation contract before implementation.
2. Add one ordered backward-compatible schema migration for the profile-local template table. Existing master-data rows and bank mapping templates remain untouched.
3. Add typed parser, preview and validation results, template operations, and transaction-aware create/update paths behind the master-data import use case.
4. Add import actions and localized steps to the customer, supplier, and article workspaces, including exact duplicate review, confirmation, progress, and rollback states.
5. Verify that cancellation before confirmation writes nothing, every successful batch is atomic, number allocations roll back on failure, and imports create no accounting or inventory side effects; review the UI at documented window sizes and keyboard/text-scale settings.

Rollback removes importer route/action wiring and leaves imported business rows and templates intact; it does not attempt to undo records users may already have referenced. The additive template table can remain unused. If schema rollback is required, remove only this feature's template table after confirming no profile has saved templates; never delete or rewrite imported master-data records as part of code rollback.

## Open Questions

1. **Imported legacy partner numbers:** the active `master-data-workspaces-and-crud/design.md` leaves customer/supplier numbering semantics unresolved. This design preserves existing auto-assigned local numbers and excludes imported values from generated number fields. If users must retain the source-system identifier, which explicit field should own it, and how is it searched without changing invoice/accounting identifiers? This answer is a prerequisite to enabling mappings for external IDs or partner numbers.
2. **Required source fields:** docs/08 lists only `firmenname` for customers and suppliers and `bezeichnung, typ` for articles, while current repositories require addresses and, for article creation, a price input. This proposal keeps current validators. Before implementation, should docs/08 be expanded to show those current required values, or should the master-data contract be changed in its owning proposal? Import must not bypass either contract.
