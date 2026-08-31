# PDF Generation Design

Status: approved
Scope: OpenSpec `openinvoices` tasks 10.1–10.9

## Goal

Add pure, testable PDF generation for the seven document types required by task 10:
Rechnung, Storno, Gutschrift, Angebot, Auftrag, Proforma, and Lieferschein.

The generator returns PDF bytes. It does not save files, open viewers, query the database, or change
application state.

## Chosen approach

Create `lib/core/pdf/pdf_generator.dart` with an immutable input snapshot and one injected logger:

- `PdfDocumentData` — document type, number, date, template, copy flag, company, customer, positions,
  per-type intro/closing text, and typed optional metadata: `stornoReason`, `referenceDocumentNumber`,
  `validUntil`, `servicePeriod`, and `linkedDocumentNumber`.
- `PdfCompanyData` — name, address, contact fields, optional logo bytes.
- `PdfCustomerData` — name/company, optional salutation, address, country, and one-time address support.
- `PdfPositionData` — position number, description, quantity, unit price, discount, net, VAT rate, VAT,
  gross, and optional Differenzbesteuerung flag.
- `PdfTextData` — introductory and closing text for one document type.

All constructors defensively copy `Uint8List` values and wrap lists/maps with unmodifiable views. The
generator never recalculates monetary values: callers provide canonical net/VAT/gross values, while the
renderer formats them with exactly two de-DE decimal places and preserves signs.

Public API:

```dart
const PdfGenerator({PdfWarningLogger? warningLogger, bool deflate = true})
Future<Uint8List> generate(PdfDocumentData data)
```

`PdfWarningLogger` is `void Function(String message)`. The service validates the exact supported type
set and throws `ArgumentError` for an unsupported type before creating output. Unknown `pdf_vorlage`
values resolve to `standard` and call the injected warning logger when present. `deflate: false` is
available for tests that inspect visible PDF markers; production keeps compression enabled.

## Rendering

- A4 `pw.MultiPage` document with reusable header, address block, title, position table, totals, and
  intro/closing text.
- Rechnung, Storno, Gutschrift, Angebot, Auftrag, and Proforma use the financial columns
  `Pos.`, `Beschreibung`, `Menge`, `Einzelpreis`, `Rabatt`, `Netto`, `USt-Satz`, `USt`, `Brutto`.
  Lieferschein uses only `Pos.`, `Beschreibung`, and `Menge`. `gruen` additionally removes VAT
  columns from financial tables and renders the §19 UStG label.
- Company header repeats on pages; logo renders only when valid logo bytes are supplied.
- Each supported document type gets its own title and optional type-specific metadata fields.
- Intro/closing text is selected by exact document type; null, empty, or whitespace-only resolved text
  emits no block. No text is taken from another document type; callers resolve any same-type company
  defaults before constructing the snapshot.
- Supported Markdown is limited to `**bold**`, `*italic*`, plain text, and line breaks. Unsupported
  markup is rendered as plain escaped text.
- Copy mode adds a diagonal `KOPIE` overlay using a rotated PDF text widget; originals do not.
- Layout uses restrained color, whitespace, clear hierarchy, and right-aligned financial values, matching
  `DESIGN.md` desktop-finance direction.

## Testing

Add task-aligned VM tests under `test/features/pdf/`:

- `rechnung_test.dart` — valid PDF contains invoice header, positions, and totals.
- `angebot_test.dart` — offer-specific title/fields render.
- `document_types_test.dart` — all seven supported document types render their own labels.
- `einleitungstext_test.dart` — type isolation, empty handling, and Markdown emphasis.
- `kopie_test.dart` — copy contains `KOPIE` and uses copy rendering; original does not.

Tests assert PDF signature, visible markers, and output behavior rather than volatile byte hashes.
Test fixtures construct `PdfGenerator(deflate: false)` where visible text inspection is required.

## Non-goals

This increment does not implement PDF viewer/download wiring, ZUGFeRD, XRechnung, PDF/A-3 archival,
embedded XML, GoBD document hashes, Mahnung/EKS/Tagesabschluss reports, or numbering persistence.
Those remain separate OpenSpec PDF scenarios and tasks.

## Risks and mitigations

- Current invoice entities expose only a subset of PDF data: callers provide a complete immutable
  snapshot, avoiding schema coupling until document data requirements are implemented.
- `pdf` layout can overflow: keep renderer helpers small, use `pw.MultiPage`, and cover long text and
  multiple positions with deterministic tests.
- Unsupported image bytes can throw: validate optional logo bytes and render the header without a logo
  when decoding fails.
- Advanced PDF scenarios (e-invoicing, PDF/A-3, hashes, reports, viewer wiring, and numbering) are
  explicitly deferred and unplanned by this increment; this design does not claim them complete.
