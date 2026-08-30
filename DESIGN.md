# DESIGN.md — Desktop Accounting App

> Design specification for a **local-first, privacy-friendly accounting application for German freelancers**, built with **Dart and Flutter**.
>
> Primary target: **Windows, macOS, Linux desktop**  
> Primary locale: **German (`de-DE`)**  
> Secondary locale: **English (`en`)**  
> Design foundation: **Material 3 adapted for desktop productivity**

---

## 1. Product Design Principles

The application should feel like a professional desktop finance tool without looking like legacy accounting software.

### 1.1 Calm, trustworthy, and focused

Accounting data is dense and sometimes stressful. The interface should reduce cognitive load:

- Prefer restrained surfaces over decorative UI.
- Use whitespace and hierarchy instead of excessive borders.
- Keep important totals and deadlines visible.
- Avoid visual noise, gradients, oversized illustrations, and unnecessary animation.
- Use color semantically, not decoratively.

### 1.2 Designed for freelancers, not accountants

The primary user is a German freelancer or solo self-employed person.

Use language such as:

- **Einnahmen**
- **Ausgaben**
- **Offene Rechnungen**
- **Umsatzsteuer**
- **Belege**
- **Zahlungen**
- **Steuertermine**

Avoid exposing bookkeeping internals such as account numbers, debit/credit terminology, or chart-of-account details unless the user explicitly enters an advanced/accounting view.

### 1.3 Local-first is visible, but not loud

Privacy is a product property, not a marketing banner on every screen.

The UI should make data ownership understandable:

- Data is stored locally by default.
- Optional online connections are individually enabled.
- Connected services clearly show what data they can access.
- Backup state is separate from synchronization state.
- No account/login wall should exist for core local functionality.
- Network-dependent features must never be presented as required for basic accounting.
- The user can inspect, export, back up, and delete their local data.

### 1.4 Desktop-first productivity

The app should feel comfortable with:

- keyboard
- mouse
- trackpad
- large monitors
- window resizing
- side-by-side workflows
- drag and drop
- context menus
- keyboard shortcuts

Do not simply scale a mobile UI to desktop.

### 1.5 Progressive disclosure

Show the simple interpretation first and detailed accounting data second.

Example:

```text
Umsatzsteuer
1.284,32 € voraussichtlich fällig

[Details anzeigen]
```

The detailed view can then expose calculation basis, periods, bookings, tax codes, and exports.

---

## 2. Visual Direction

### Design character

The application should feel:

- modern
- precise
- quiet
- reliable
- privacy-conscious
- desktop-native
- professional without being corporate-heavy

A useful visual reference is the clarity of modern productivity tools combined with the information density of financial software.

### Avoid

- giant dashboard cards
- glassmorphism everywhere
- gradients as primary surfaces
- excessive shadows
- saturated backgrounds
- round pills for every UI element
- mobile-sized spacing on desktop
- icons without labels for important navigation
- using red/green as the only indicator of financial meaning

---

## 3. Application Shell

Use a stable three-area desktop shell:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│ Window / platform chrome                                                   │
├───────────────┬────────────────────────────────────────────────────────────┤
│               │ Page title                                    Quick action │
│   SIDEBAR     │ Search / filters / toolbar                                 │
│               ├────────────────────────────────────────────────────────────┤
│               │                                                            │
│               │                        CONTENT                             │
│               │                                                            │
│               │                                                            │
│               │                                             ┌────────────┐ │
│               │                                             │ Inspector  │ │
│               │                                             │ optional   │ │
│               │                                             └────────────┘ │
├───────────────┴────────────────────────────────────────────────────────────┤
│ Optional transient status / background operation area                     │
└────────────────────────────────────────────────────────────────────────────┘
```

### Shell layers

1. **Sidebar** — global navigation
2. **Page header / toolbar** — contextual navigation and actions
3. **Content canvas** — tables, dashboards, editors
4. **Optional inspector** — details without leaving the current workflow
5. **Transient overlays** — dialogs, menus, command palette, snackbars

---

## 4. Sidebar Navigation

A persistent left sidebar is the primary desktop navigation model.

### Expanded sidebar

Width: **240 px**

Recommended structure:

```text
[App logo]  App Name
[Workspace / company selector]

⌂  Übersicht

GESCHÄFT
▤  Rechnungen
▣  Belege
⇄  Bank & Zahlungen
♙  Kontakte

STEUERN
%  Steuern
▥  Auswertungen

────────────────────
⚙  Einstellungen
?  Hilfe
```

### Suggested top-level destinations

| Navigation | Purpose |
|---|---|
| Übersicht | Business status, tasks, deadlines, cash overview |
| Rechnungen | Offers, invoices, credit notes, recurring invoices |
| Belege | Incoming invoices, receipts, document inbox |
| Bank & Zahlungen | Bank transactions, matching, reconciliation |
| Kontakte | Customers and suppliers |
| Steuern | VAT, EÜR preparation, tax periods, submission/export status |
| Auswertungen | Revenue, expenses, profit, receivables, tax reports |
| Einstellungen | Company, taxes, invoice design, data, integrations, language |

### Sidebar behavior

#### ≥ 1200 px

- Expanded by default.
- 240 px wide.
- Icon + label.
- Section labels visible.

#### 900–1199 px

- Compact sidebar.
- Approximately 72 px wide.
- Icons only.
- Tooltip on hover.
- Clicking the menu control temporarily expands it.

#### < 900 px

- Sidebar becomes an overlay drawer.
- Main content receives full width.
- This is a fallback for small windows, not the primary desktop experience.

### Sidebar rules

- Navigation should remain shallow.
- Prefer a flat information architecture.
- Use page-level tabs for related views instead of deeply nested sidebar trees.
- Settings remain pinned near the bottom.
- The currently selected destination must be unmistakable in both light and dark themes.
- The sidebar should be collapsible manually.
- Preserve the user's sidebar state between launches when practical.

---

## 5. Page Header

Every primary page uses a consistent header.

Example:

```text
Rechnungen                                   [+ Neue Rechnung]
Alle  Entwürfe  Offen  Überfällig  Bezahlt

[⌕ Rechnungen durchsuchen…] [Zeitraum ▾] [Status ▾] [Weitere Filter]
```

### Header anatomy

1. Page title
2. Optional subtitle or contextual status
3. Primary action on the right
4. Tabs when multiple sibling views exist
5. Filter/search toolbar below

### Primary action

Use one visually dominant action per page.

Examples:

- `Neue Rechnung`
- `Beleg importieren`
- `Bankkonto verbinden`
- `Kontakt hinzufügen`

Secondary actions should use outlined, tonal, icon, or menu buttons.

---

## 6. Layout System

### Base spacing scale

Use a 4 px base grid.

| Token | Value | Typical use |
|---|---:|---|
| `space.1` | 4 px | tight icon spacing |
| `space.2` | 8 px | inline spacing |
| `space.3` | 12 px | compact controls |
| `space.4` | 16 px | component padding |
| `space.6` | 24 px | cards / page sections |
| `space.8` | 32 px | page padding |
| `space.12` | 48 px | major section separation |

### Page padding

- Normal desktop: **32 px**
- Compact desktop window: **24 px**
- Small fallback layout: **16 px**

### Content width

Do not stretch forms and text across ultrawide monitors.

Recommended patterns:

- Tables: may use full available width.
- Dashboards: fluid grid with sensible card widths.
- Forms: approximately 720–900 px maximum content width.
- Settings: approximately 900–1100 px maximum width.
- Long text/help content: approximately 720 px maximum width.

### Grid

Use a responsive 12-column conceptual grid.

Dashboard widgets should respond to available **window width**, not device type.

---

## 7. Color System

Use Material 3 `ColorScheme` as the basis, with a restrained indigo/blue brand accent.

Recommended brand seed:

```text
Primary seed: #4F46E5
```

This creates a trustworthy finance-oriented identity while remaining distinct from status colors.

### Light theme

| Token | Suggested value | Use |
|---|---|---|
| Background | `#F7F8FA` | application canvas |
| Surface | `#FFFFFF` | cards, sheets |
| Surface subtle | `#F1F3F6` | selected/secondary areas |
| Primary | `#4F46E5` | primary actions |
| Text primary | `#17181C` | main content |
| Text secondary | `#626771` | secondary metadata |
| Border | `#E1E4E8` | subtle separators |

### Dark theme

Avoid pure black.

| Token | Suggested value | Use |
|---|---|---|
| Background | `#101217` | application canvas |
| Surface | `#171A21` | cards, sheets |
| Surface elevated | `#1D2129` | menus, overlays |
| Primary | `#C5C0FF` | primary accent |
| Text primary | `#F1F2F4` | main content |
| Text secondary | `#AEB3BD` | secondary metadata |
| Border | `#2B3039` | subtle separators |

### Semantic colors

Semantic colors are separate from the brand color.

| Meaning | Light concept | Dark concept |
|---|---|---|
| Success / paid | green | muted light green |
| Warning / due soon | amber | warm amber |
| Error / overdue | red | light red |
| Information | blue | light blue |
| Neutral / draft | gray | cool gray |

Do not communicate state using color alone. Always pair color with:

- text
- icon
- shape
- status label

Examples:

```text
✓ Bezahlt
! Überfällig
○ Entwurf
↻ In Prüfung
```

---

## 8. Theme Behavior

Expose three appearance options:

```text
Darstellung
( ) System
( ) Hell
( ) Dunkel
```

Default: **System**

### Theme implementation

Flutter should use:

```dart
MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: settings.themeMode,
)
```

Use Material 3:

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4F46E5),
    brightness: Brightness.light,
  ),
)
```

Create separate light and dark schemes rather than simply inverting colors.

### Theme requirements

Every custom component must define:

- default
- hover
- pressed
- focused
- selected
- disabled

states in both themes.

Charts require separate light/dark palettes.

---

## 9. Typography

Use a clean sans-serif UI typeface.

Recommended:

```text
Inter
```

Fallback to appropriate system sans-serif fonts if Inter is unavailable.

### Type scale

| Role | Size | Weight |
|---|---:|---:|
| Page title | 28 px | 600 |
| Section title | 20 px | 600 |
| Card title | 16 px | 600 |
| Body | 14 px | 400 |
| Body emphasized | 14 px | 600 |
| Secondary / metadata | 13 px | 400 |
| Table header | 12–13 px | 600 |
| Caption | 12 px | 400 |

Desktop accounting software benefits from slightly denser typography than consumer mobile applications.

### Financial numbers

- Right-align monetary amounts in tables.
- Use tabular figures where possible.
- Always display currency when ambiguity is possible.
- Keep decimal precision consistent.
- Never truncate important financial amounts.

Examples:

```text
1.284,32 €
12.450,00 €
−382,41 €
```

German locale uses:

- decimal comma
- thousands separator
- day-month-year date conventions

---

## 10. Elevation, Borders, and Radius

Keep elevation subtle.

### Radius

| Component | Radius |
|---|---:|
| Buttons | 8 px |
| Inputs | 8 px |
| Cards | 12 px |
| Menus | 10 px |
| Dialogs | 14 px |
| Status chips | 999 px only when semantically a chip |

Do not turn every container into a rounded card.

### Borders

Prefer 1 px subtle borders for:

- tables
- grouped forms
- secondary cards
- inspector separation

### Shadows

Use shadows only for:

- floating menus
- dialogs
- command palette
- elevated inspector/overlay states

Static dashboard cards should usually rely on borders and surface contrast.

---

## 11. Dashboard

The dashboard answers four questions immediately:

1. How is the business doing?
2. What requires attention?
3. What money is outstanding?
4. What tax amount should be reserved?

Example:

```text
Übersicht                                      [+ Neue Rechnung]

2026 ▾

┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Einnahmen        │ │ Ausgaben         │ │ Gewinn           │ │ USt.-Rücklage    │
│ 42.580,00 €      │ │ 14.290,00 €      │ │ 28.290,00 €      │ │ 4.210,00 €       │
│ +12 % ggü. 2025  │ │ +3 % ggü. 2025   │ │ +18 % ggü. 2025  │ │ geschätzt        │
└──────────────────┘ └──────────────────┘ └──────────────────┘ └──────────────────┘

┌────────────────────────────────────────────┐ ┌──────────────────────────────────┐
│ Einnahmen & Ausgaben                       │ │ Aufgaben                         │
│                                            │ │ ! 3 Belege prüfen                │
│             [chart]                        │ │ ! 2 Rechnungen überfällig        │
│                                            │ │ ○ UStVA September vorbereiten    │
└────────────────────────────────────────────┘ └──────────────────────────────────┘

┌────────────────────────────────────────────┐ ┌──────────────────────────────────┐
│ Offene Rechnungen                          │ │ Konten                           │
│ 4.820,00 €                                 │ │ Geschäftskonto      8.242,12 €   │
│ davon 1.200,00 € überfällig                │ │ PayPal                 84,32 €   │
└────────────────────────────────────────────┘ └──────────────────────────────────┘
```

### Dashboard principles

- Numbers first, decoration second.
- Every KPI should be clickable and lead to its underlying records.
- Clearly label estimates.
- Provide time-period controls.
- Do not rely on a chart when a number communicates the result better.
- Dashboard cards should not contain complex editing workflows.
- The task list should prioritize items with real consequences: overdue invoices, unmatched transactions, tax deadlines, invalid documents.

---

## 12. Tables and Lists

Accounting applications are table-heavy. Treat tables as a first-class design component.

### Table characteristics

- Sticky header
- Sortable columns
- Resizable columns where useful
- Search
- Filters
- Multi-select
- Bulk actions
- Keyboard navigation
- Context menus
- Row hover
- Clear selected state
- Empty state
- Optional column chooser
- Persistent table preferences where appropriate

### Example invoice table

```text
☐  Nr.       Kunde                  Datum       Fällig      Status        Betrag
──────────────────────────────────────────────────────────────────────────────────
☐  2026-042  Muster GmbH            28.08.26    11.09.26    Offen       1.249,50 €
☐  2026-041  Studio Nord            26.08.26    09.09.26    Bezahlt       680,00 €
☐  2026-040  Beispiel AG            19.08.26    02.09.26    Überfällig  2.420,00 €
```

### Numeric alignment

- text: left
- dates: left or center
- numeric quantities: right
- money: right
- percentages: right

### Row density

Default row height: **48 px**

Offer an optional density setting:

```text
Kompakt / Standard / Komfortabel
```

### Large data sets

Do not use a naive non-virtualized table for thousands of transactions.

In Flutter, consider a virtualized/two-dimensional scrolling solution for high-volume data rather than rendering every row at once.

---

## 13. Search and Filtering

Search should be available directly on data-heavy pages.

Example:

```text
[⌕ Kunde, Rechnungsnummer oder Betrag…] [Status ▾] [Zeitraum ▾] [Filter +]
```

### Filter principles

- Common filters remain visible.
- Advanced filters open in a popover or side sheet.
- Active filters appear as removable chips.
- The UI shows the result count.
- Provide `Filter zurücksetzen` when filters are active.
- Search should tolerate partial matches.
- Search should include relevant identifiers, not only display names.

### Global search

Use:

```text
Ctrl/Cmd + K
```

for a global command/search palette.

It can locate:

- invoices
- contacts
- receipts
- transactions
- settings
- commands

Example:

```text
┌──────────────────────────────────────────────┐
│ ⌕ Suchen oder Befehl ausführen…              │
├──────────────────────────────────────────────┤
│ Rechnungen                                   │
│   2026-042 · Muster GmbH                     │
│                                              │
│ Kontakte                                     │
│   Muster GmbH                                │
│                                              │
│ Aktionen                                     │
│   + Neue Rechnung                            │
└──────────────────────────────────────────────┘
```

---

## 14. Detail Inspector

Use an optional right-side inspector for quick record review.

Width: approximately **360–440 px**

Good use cases:

- inspect a bank transaction
- inspect invoice metadata
- show contact details
- preview receipt extraction
- display validation issues

Example:

```text
┌──────────────────────────────────┐
│ Rechnung 2026-042             ×  │
│ Muster GmbH                      │
│                                  │
│ Status        Offen              │
│ Betrag        1.249,50 €         │
│ Fällig        11.09.2026         │
│                                  │
│ Zahlung                           │
│ Noch keine Zahlung zugeordnet    │
│                                  │
│ [Öffnen]              [•••]      │
└──────────────────────────────────┘
```

The inspector avoids forcing a full page transition for every inspection task.

---

## 15. Invoice Workflow

Creating an invoice is one of the app's central workflows.

### Desktop layout

Use a split editor:

```text
┌──────────────────────────────────────┬──────────────────────────────────────┐
│ Invoice editor                       │ Live preview                         │
│                                      │                                      │
│ Kunde                                │             RECHNUNG                 │
│ Rechnungsdaten                       │                                      │
│ Positionen                           │          [document preview]           │
│ Zahlungsbedingungen                 │                                      │
│ Hinweise                             │                                      │
│                                      │                                      │
├──────────────────────────────────────┴──────────────────────────────────────┤
│ Entwurf gespeichert                       [Vorschau] [Rechnung erstellen]   │
└─────────────────────────────────────────────────────────────────────────────┘
```

Recommended proportions:

- Editor: 55–60%
- Preview: 40–45%

### Narrow windows

Switch to:

```text
[Bearbeiten] [Vorschau]
```

tabs rather than compressing both panels.

### Invoice validation

Before finalization, show validation near the affected field and in a concise summary.

Examples:

```text
! Leistungsdatum fehlt
! Steuer-ID oder USt-IdNr. prüfen
! Empfängeradresse unvollständig
```

### E-invoice state

For German B2B invoicing, invoice format should be explicit:

```text
Format
● ZUGFeRD
○ XRechnung
○ PDF / sonstige Rechnung
```

Where a selected format cannot be generated due to missing data, explain exactly what is missing.

Do not hide E-invoice validity behind a generic success/error state.

---

## 16. Receipts / Document Inbox

The receipt area should behave like an inbox.

### Main actions

```text
[Beleg importieren]  [Ordner überwachen]  [Drag & Drop]
```

### States

- Neu
- Zu prüfen
- Zugeordnet
- Verbucht
- Fehler

### Desktop workflow

Use three panes when space allows:

```text
Receipt list | Document preview | Extracted fields / booking details
```

This makes reviewing many receipts much faster than opening modal dialogs repeatedly.

### Drag and drop

Desktop users should be able to drag:

- PDF
- PNG
- JPG
- supported E-invoice files

directly into the receipt view.

Always show a clear drop target during drag-over.

---

## 17. Banking and Reconciliation

The banking page is a transaction workspace.

Example:

```text
Bank & Zahlungen

Geschäftskonto · DE•• 1234       Saldo 8.242,12 €       [Aktualisieren]

[⌕ Suchen…] [Nicht zugeordnet] [Zeitraum ▾]

Datum      Beschreibung                Betrag         Zuordnung
─────────────────────────────────────────────────────────────────────
29.08.26   MUSTER GMBH              +1.249,50 €      Rechnung 2026-042 ✓
28.08.26   SOFTWARE SERVICE            -29,00 €      Vorschlag: Software
27.08.26   TRANSFER                     500,00 €      Zu prüfen
```

### Matching UX

Automatic or suggested matches must be clearly distinguishable from confirmed matches.

Example:

```text
Vorschlag
Rechnung 2026-042 · 1.249,50 €
[Zuordnen] [Anders zuordnen]
```

Never silently turn a low-confidence suggestion into a confirmed accounting action.

---

## 18. Taxes

The tax section should translate accounting records into understandable obligations.

Suggested sections:

```text
Steuern
├─ Übersicht
├─ Umsatzsteuer
├─ EÜR
├─ Steuertermine
└─ Exporte / ELSTER
```

### Tax overview

Show:

- estimated VAT liability
- period
- filing status
- due date
- completeness / unresolved records
- relevant exports or submissions

Example:

```text
Umsatzsteuer · Q3 2026

Voraussichtliche Zahllast
1.284,32 €

Fällig am 10.10.2026

3 Vorgänge müssen noch geprüft werden.

[Prüfen]                     [Details]
```

### Uncertainty

Tax calculations may be provisional.

Explicitly distinguish:

- `Geschätzt`
- `Berechnet`
- `Geprüft`
- `Übermittelt`

Never imply that a local calculation has been filed simply because it is complete.

---

## 19. Settings Architecture

Settings use a dedicated full-page view with a constrained content width.

Sidebar or section navigation inside settings:

```text
Einstellungen

Allgemein
Unternehmen
Steuern
Rechnungen
Bank & Integrationen
Daten & Datenschutz
Sicherung
Darstellung
Sprache & Region
Erweitert
Über
```

### Appearance

```text
Darstellung

Farbschema
[ System ▾ ]

Dichte
[ Standard ▾ ]

Sidebar
[x] Beim Start erweitert anzeigen
```

### Language & region

```text
Sprache & Region

Sprache
[ Deutsch (Deutschland) ▾ ]

Zahlenformat
Deutsch (Deutschland)

Währung
EUR (€)

Erster Wochentag
Montag
```

### Data & privacy

This section should be especially transparent.

```text
Daten & Datenschutz

Datenspeicher
Lokal auf diesem Gerät
/home/user/Accounting/data

[Ordner öffnen]

Netzwerkzugriffe
Bankverbindung                 Aktiv
Update-Prüfung                 Aktiv
Telemetrie                     Deaktiviert

[Netzwerkdetails anzeigen]

Daten exportieren
[Kompletten Export erstellen]

Lokale Daten löschen
[Alle Daten löschen…]
```

---

## 20. Privacy Mode

Add a dedicated privacy mode for users working in shared environments or screen sharing.

Icon:

```text
eye / eye-off
```

Behavior:

- hides dashboard monetary values
- hides bank balances
- masks invoice amounts where practical
- leaves navigation and record identity usable

Example:

```text
Kontostand
•••••• €
```

Privacy mode is separate from application locking or encryption.

---

## 21. Backup UX

Local-first software must make backup status understandable.

Example:

```text
Sicherung

Letzte Sicherung
Heute, 12:41

Ziel
/home/user/Backups/Accounting

Automatische Sicherung
[x] Aktiviert

Intervall
[ Täglich ▾ ]

[Jetzt sichern]
```

Status should differentiate:

- never backed up
- current
- stale
- failed

A failed backup deserves a persistent but non-blocking warning.

---

## 22. Integrations

Any networked feature must be opt-in and explain its scope.

Example connection card:

```text
Bankverbindung

FinTS / Bank Provider

Status
Verbunden

Letzte Aktualisierung
Heute, 13:52

Zugriff
Kontostände und Umsätze lesen

[Verbindung verwalten] [Trennen]
```

Do not use vague labels such as `Cloud aktiv`.

Every integration should expose:

- provider
- status
- permissions/scope
- last successful operation
- error state
- disconnect action

---

## 23. Localization and Internationalization

All user-facing strings must be localizable from the first implementation.

### Flutter setup

Use:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any
```

and Flutter's generated localization workflow (`gen_l10n`) with ARB files.

Suggested structure:

```text
lib/
└─ l10n/
   ├─ app_de.arb
   └─ app_en.arb
```

### Rules

- Never hardcode UI strings in widgets.
- Do not concatenate translated fragments.
- Use placeholders for dynamic values.
- Use ICU pluralization.
- Localize tooltips, errors, menus, empty states, and accessibility labels.
- Format dates, currency, percentages, and numbers using locale-aware formatters.
- Design every layout for text expansion.
- German is often longer than English; buttons and navigation labels must accommodate this.
- Do not encode locale assumptions into business logic.

### Example ARB

```json
{
  "invoiceNew": "Neue Rechnung",
  "invoiceCount": "{count, plural, =0{Keine Rechnungen} =1{1 Rechnung} other{{count} Rechnungen}}",
  "@invoiceCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

### Locale-sensitive formatting

Examples for `de-DE`:

```text
1.234,56 €
30.08.2026
30. August 2026
12,5 %
```

### Language switching

Changing language should not require a restart.

If practical, preserve:

- current page
- current selected record
- current filters

when the locale changes.

---

## 24. Keyboard and Mouse Interaction

Desktop keyboard support is mandatory.

Suggested shortcuts:

| Shortcut | Action |
|---|---|
| `Ctrl/Cmd + K` | Global search / command palette |
| `Ctrl/Cmd + N` | New item in current context |
| `Ctrl/Cmd + F` | Search current page |
| `Ctrl/Cmd + S` | Save draft |
| `Ctrl/Cmd + ,` | Settings |
| `Esc` | Close menu, dialog, inspector |
| `Enter` | Open selected row |
| `Space` | Select/check focused row where applicable |
| `?` | Keyboard shortcut overview |

### Context menus

Use right-click context menus for row actions such as:

- Open
- Duplicate
- Mark as paid
- Export
- Archive
- Delete

Important actions must still be discoverable without right-click.

### Hover

Mouse hover can reveal secondary row actions, but core functionality must not depend on hover.

---

## 25. Forms

Forms should be structured into logical sections.

Example:

```text
Unternehmensdaten

Name / Firmenname
[____________________________________]

Anschrift
[Straße und Hausnummer_______________]
[PLZ________] [Ort___________________]

Steuerdaten
[Steuernummer________________________]
[USt-IdNr.___________________________]
```

### Form rules

- Labels above controls.
- Do not use placeholder text as the only label.
- Validate after reasonable interaction, not on every keystroke.
- Validation explains the fix.
- Required fields must be clear.
- Keep destructive actions away from primary save actions.
- Changes should be autosaved only where losing explicit transactional intent is impossible.
- Drafts can autosave.
- Final accounting actions should require explicit execution.

---

## 26. Dialogs, Sheets, and Destructive Actions

### Prefer inline or inspector editing for

- metadata
- simple classification
- quick review

### Use dialogs for

- short confirmations
- irreversible actions
- choices requiring immediate resolution

### Avoid

- full forms inside small dialogs
- nested dialogs
- modal flows for routine navigation

### Destructive confirmation

Example:

```text
Rechnung löschen?

Die Rechnung 2026-042 wird dauerhaft gelöscht.
Diese Aktion kann nicht rückgängig gemacht werden.

[Abbrechen] [Rechnung löschen]
```

The destructive button uses semantic error styling, not the primary brand color.

---

## 27. Notifications and Feedback

Use different feedback channels intentionally.

### Snackbar

Use for lightweight confirmations:

```text
Rechnung als bezahlt markiert.             [Rückgängig]
```

### Inline banner

Use for page-relevant issues:

```text
! 3 Transaktionen konnten nicht aktualisiert werden. [Details]
```

### Persistent application warning

Use only when the user risks losing data or missing an important state:

```text
! Automatische Sicherung seit 7 Tagen fehlgeschlagen. [Beheben]
```

### Dialog

Use when the user must make a decision before continuing.

---

## 28. Empty States

Empty states should help the user progress.

Bad:

```text
Keine Daten.
```

Better:

```text
Noch keine Rechnungen

Erstelle deine erste Rechnung oder importiere vorhandene Rechnungsdaten.

[Neue Rechnung]  [Importieren]
```

Avoid large decorative artwork in dense business views.

---

## 29. Loading and Background Work

Local operations should feel immediate.

### Use

- subtle progress indicators for operations under a few seconds
- determinate progress for imports/exports when measurable
- background operation panel for long-running tasks
- skeletons only where they improve perceived continuity

Example:

```text
Belege importieren
42 / 128 verarbeitet
████████████░░░░░░░░ 33 %

[Im Hintergrund fortsetzen]
```

Never block the entire app for work that can safely continue in the background.

---

## 30. Charts and Data Visualization

Charts are secondary to exact values.

Recommended:

- line chart for revenue trend
- grouped/stacked bars for income vs. expenses
- horizontal bars for expense categories
- sparklines for compact trends

Avoid:

- 3D charts
- gauges
- unnecessary pie charts
- excessive animation
- more than a few simultaneous series

### Chart requirements

- readable in light and dark mode
- keyboard-accessible where interactive
- tooltip with exact values
- text summary available
- no important distinction based only on color
- restrained gridlines
- locale-aware axis labels and tooltips

---

## 31. Icons

Use one coherent icon family.

For Flutter, Material icons are a reasonable cross-platform default.

### Standard sizes

- Sidebar: 20–22 px
- Buttons: 18–20 px
- Inline indicators: 16–18 px
- Empty states: 32–40 px maximum

Icons should support labels rather than replace them for important actions.

Avoid mixing filled, rounded, outlined, and platform-specific icon styles arbitrarily.

---

## 32. Motion

Motion should communicate state changes, not showcase animation.

Recommended duration:

- hover / small state: 100–150 ms
- sidebar transition: 180–220 ms
- inspector: 180–240 ms
- dialog: 160–220 ms

Use standard easing.

Respect reduced-motion accessibility settings where available.

Avoid animating financial values in a way that delays reading the actual number.

---

## 33. Accessibility

Accessibility is part of the design system.

### Minimum requirements

- text contrast target of at least 4.5:1 for normal text
- visible keyboard focus
- complete keyboard navigation
- semantic labels for icon-only controls
- screen-reader-compatible widgets
- no information conveyed only by color
- reasonable target sizes
- support text scaling without clipping
- tooltips for compact icon-only controls
- logical focus order

### Focus style

Focused controls should have a visible focus indicator that works in both themes.

Do not remove Flutter/platform focus outlines without replacing them with an equivalent accessible indicator.

---

## 34. Responsive / Adaptive Breakpoints

Use available window width, not operating-system detection, to choose layouts.

Suggested breakpoints:

```text
< 700 px       small fallback
700–899 px     compact
900–1199 px    desktop compact
≥ 1200 px      desktop expanded
≥ 1600 px      wide desktop
```

### Behavior examples

| Width | Sidebar | Inspector | Dashboard |
|---|---|---|---|
| < 700 | drawer | full-page | 1 column |
| 700–899 | drawer/compact | overlay | 1–2 columns |
| 900–1199 | compact rail | optional | 2 columns |
| ≥ 1200 | expanded | side panel | 3–4 columns |
| ≥ 1600 | expanded | side panel | bounded 4-column layout |

Do not make content cards arbitrarily wider on ultrawide displays.

---

## 35. Window Behavior

Recommended initial window size:

```text
1280 × 800
```

Recommended minimum:

```text
960 × 640
```

If the user resizes below the preferred desktop layout, adapt rather than overflow.

Persist where practical:

- window size
- window position
- maximized state
- sidebar state

Do not restore a previous window position if it is no longer visible on an attached display.

---

## 36. Multi-Company / Workspace Model

Even if the first release targets one freelancer/business, design the app shell so a future workspace selector is possible.

Example:

```text
┌──────────────────────┐
│ ACME Studio       ▾  │
│ Einzelunternehmen    │
└──────────────────────┘
```

The company identity belongs near the top of the sidebar.

Avoid scattering company-selection controls throughout the application.

---

## 37. Status Language

Use a small, consistent vocabulary.

### Invoice

```text
Entwurf
Offen
Teilbezahlt
Bezahlt
Überfällig
Storniert
```

### Receipt

```text
Neu
Zu prüfen
Zugeordnet
Verbucht
Fehler
```

### Tax

```text
Offen
Unvollständig
Bereit
Übermittelt
Bestätigt
```

Status labels should use consistent colors and icons across the application.

---

## 38. German Accounting-Specific Design Requirements

The design must account for German workflows without hardcoding the entire app to one legal configuration.

### Important UI concepts

- EÜR
- Umsatzsteuer
- Kleinunternehmer status
- VAT rates
- reverse charge
- invoice numbering
- invoice correction / credit note
- tax periods
- tax deadlines
- business vs. private transaction classification
- E-invoice formats
- tax advisor exports
- bank reconciliation

### E-invoices

As German B2B E-invoicing requirements transition into broader mandatory issuance, invoice screens should treat structured invoice capability as a first-class format, not a hidden export option.

The UI should be capable of clearly presenting:

- invoice format
- validation state
- structured data errors
- human-readable preview
- source file
- export/download actions

---

## 39. Local-First Trust Indicators

Avoid a constantly visible “secure” badge.

Instead, show trust information where it affects decisions.

### Good places

- onboarding
- Data & Privacy settings
- integration connection dialogs
- backup settings
- export dialogs
- optional network feature explanations

### Optional subtle status

At the bottom of the sidebar:

```text
● Lokal
```

Clicking it can open a small data-status popover:

```text
Datenspeicher: Lokal
Sicherung: Heute 12:41
Netzwerk: 1 aktive Integration

[Daten & Datenschutz]
```

This is useful but should not compete with the primary workflow.

---

## 40. Suggested Flutter Design-System Structure

```text
lib/
├─ app/
│  ├─ app.dart
│  └─ app_shell.dart
│
├─ design_system/
│  ├─ theme/
│  │  ├─ app_theme.dart
│  │  ├─ app_colors.dart
│  │  ├─ app_typography.dart
│  │  └─ app_spacing.dart
│  │
│  ├─ components/
│  │  ├─ app_sidebar.dart
│  │  ├─ app_page_header.dart
│  │  ├─ app_button.dart
│  │  ├─ app_card.dart
│  │  ├─ app_status_chip.dart
│  │  ├─ app_money.dart
│  │  ├─ app_data_table.dart
│  │  ├─ app_filter_bar.dart
│  │  ├─ app_empty_state.dart
│  │  ├─ app_inspector.dart
│  │  └─ app_dialog.dart
│  │
│  └─ tokens/
│     ├─ spacing.dart
│     ├─ radius.dart
│     └─ duration.dart
│
├─ features/
│  ├─ dashboard/
│  ├─ invoices/
│  ├─ receipts/
│  ├─ banking/
│  ├─ contacts/
│  ├─ taxes/
│  ├─ reports/
│  └─ settings/
│
└─ l10n/
   ├─ app_de.arb
   └─ app_en.arb
```

Feature code should consume the design system rather than defining one-off visual styles.

---

## 41. Core Reusable Components

Create reusable primitives early.

### `AppPage`

Provides:

- page padding
- header slot
- scroll behavior
- width constraints
- background

### `AppPageHeader`

Provides:

- title
- subtitle
- primary action
- secondary actions
- tabs

### `AppDataTable`

Provides:

- sorting
- selection
- hover
- keyboard navigation
- status cells
- empty state
- loading state
- column configuration

### `MoneyText`

Provides:

- locale formatting
- currency formatting
- sign formatting
- privacy-mode masking
- tabular figures

### `StatusChip`

Provides:

- semantic icon
- semantic color
- translated label
- compact consistent styling

### `FilterBar`

Provides:

- search
- common filters
- active-filter chips
- reset
- result count

### `DetailInspector`

Provides:

- responsive side panel
- close handling
- keyboard focus management
- record actions

---

## 42. Design Tokens in Dart

Example token definitions:

```dart
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double control = 8;
  static const double card = 12;
  static const double dialog = 14;
}

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 240);
}
```

Do not scatter raw spacing, radius, and animation values throughout feature code.

---

## 43. Theme Extension for Accounting Semantics

Material's normal color scheme does not provide every finance-specific status.

Use a `ThemeExtension` for semantic accounting colors.

Conceptually:

```dart
@immutable
class AccountingColors extends ThemeExtension<AccountingColors> {
  final Color paid;
  final Color overdue;
  final Color draft;
  final Color warning;
  final Color income;
  final Color expense;

  // ...
}
```

Provide distinct light and dark variants.

Do not overload `primary`, `secondary`, or `error` for every financial state.

---

## 44. Interaction States

Every interactive component needs explicit visual behavior.

### Button

```text
default
hover
pressed
focused
disabled
loading
```

### Table row

```text
default
hover
focused
selected
selected + focused
disabled/read-only
```

### Input

```text
default
hover
focused
filled
error
disabled
read-only
```

These states should be represented centrally in the design system.

---

## 45. Recommended First-Run Experience

Keep onboarding short.

### Step 1 — Welcome

```text
Deine Buchhaltung. Lokal auf deinem Gerät.

Keine Cloud-Anmeldung erforderlich.

[Loslegen]
```

### Step 2 — Business profile

Collect:

- business/name
- address
- tax configuration
- default currency

### Step 3 — Invoicing

Collect:

- invoice number scheme
- payment terms
- logo/template optionally

### Step 4 — Data protection and backup

Explain:

- local storage path
- backup recommendation
- optional encryption/app lock

### Step 5 — Done

Offer:

```text
[Erste Rechnung erstellen]
[Beleg importieren]
[Zum Dashboard]
```

Optional online integrations should be offered later in context rather than turning onboarding into a connection wizard.

---

## 46. Error Design

Error messages should explain:

1. what happened
2. what is affected
3. what the user can do

Bad:

```text
Fehler 502.
```

Better:

```text
Bankumsätze konnten nicht aktualisiert werden.

Deine vorhandenen Daten sind weiterhin verfügbar.
Versuche es erneut oder prüfe die Bankverbindung.

[Erneut versuchen] [Verbindung prüfen]
```

For local-file errors:

```text
Die Sicherung konnte nicht geschrieben werden.

Zielordner:
/home/user/Backups/Accounting

Grund:
Kein Schreibzugriff.

[Anderen Ordner wählen]
```

---

## 47. Design QA Checklist

Before a screen is considered finished:

### Layout

- [ ] Works at 960×640.
- [ ] Works at 1280×800.
- [ ] Works on wide desktop windows.
- [ ] No text or form stretches excessively.
- [ ] Sidebar adapts correctly.
- [ ] Inspector adapts correctly.

### Theme

- [ ] Light theme complete.
- [ ] Dark theme complete.
- [ ] Hover/focus/selected states work in both.
- [ ] Charts work in both.
- [ ] No hardcoded theme-dependent colors.

### Localization

- [ ] German complete.
- [ ] English complete.
- [ ] No hardcoded UI strings.
- [ ] German labels do not overflow.
- [ ] Currency/date/number formatting respects locale.
- [ ] Pluralization uses localization rules.

### Accessibility

- [ ] Keyboard navigation works.
- [ ] Focus is visible.
- [ ] Icon-only controls have semantic labels/tooltips.
- [ ] Contrast is sufficient.
- [ ] Meaning does not depend only on color.
- [ ] Screen-reader order is logical.
- [ ] Text scaling does not break the layout.

### Desktop behavior

- [ ] Context menus where useful.
- [ ] Keyboard shortcuts work.
- [ ] Drag-and-drop works where expected.
- [ ] Window resizing is smooth.
- [ ] Selection behavior is consistent.

### Privacy

- [ ] Network activity is explicit.
- [ ] Optional services are clearly scoped.
- [ ] Local storage is visible in settings.
- [ ] Backup state is understandable.
- [ ] Privacy mode masks financial values correctly.

---

## 48. Recommended MVP Visual Scope

Implement the design system in this order:

1. Theme tokens and light/dark themes
2. Localization infrastructure
3. Application shell
4. Sidebar
5. Page header and toolbar
6. Buttons, inputs, status chips
7. Table/list system
8. Dashboard
9. Invoice editor
10. Receipt inbox
11. Banking workspace
12. Taxes
13. Settings
14. Inspector
15. Command palette
16. Accessibility and keyboard QA
17. Theme/localization polish

Do not start by independently styling every feature page.

---

## 49. Final Design Summary

The visual identity should be built around a **quiet Material 3 desktop shell**, a **collapsible left sidebar**, **dense but readable data tables**, **strong keyboard support**, **light/dark themes**, and **German-first localization**.

The most important UI principle is:

> **Show the financial situation clearly, surface the next required action, and keep bookkeeping complexity behind progressive disclosure.**

The most important privacy principle is:

> **The app works locally by default; every external connection is optional, understandable, and reversible.**

The most important desktop principle is:

> **Use the available screen to reduce navigation and modality rather than simply making mobile components larger.**

---

## 50. References

Design and implementation decisions in this document were informed by:

- Flutter — Adaptive and responsive design  
  https://docs.flutter.dev/ui/adaptive-responsive

- Flutter — Large screen devices  
  https://docs.flutter.dev/ui/adaptive-responsive/large-screens

- Flutter — Internationalizing Flutter apps  
  https://docs.flutter.dev/ui/internationalization

- Flutter — Accessibility  
  https://docs.flutter.dev/ui/accessibility

- Flutter — DataTable API / performance considerations  
  https://api.flutter.dev/flutter/material/DataTable-class.html

- Microsoft — Windows app navigation design  
  https://learn.microsoft.com/en-us/windows/apps/design/basics/navigation-basics

- Microsoft — NavigationView guidance  
  https://learn.microsoft.com/en-us/windows/apps/design/controls/navigationview

- Microsoft — App settings guidance  
  https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings

- Apple — macOS design guidance  
  https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/

- Apple — Sidebars  
  https://developer.apple.com/design/human-interface-guidelines/sidebars

- German Federal Ministry of Finance — E-invoice FAQ  
  https://www.bundesfinanzministerium.de/Content/DE/FAQ/e-rechnung.html

- Lexware Office — accounting/dashboard workflow references  
  https://www.lexware.de/funktionen/dashboard/

- sevdesk — freelancer/accounting workflow references  
  https://sevdesk.de/buchhaltungssoftware/

---

**Document status:** Initial desktop design system specification  
**Target framework:** Flutter / Dart  
**Primary market:** Germany  
**Primary platform class:** Desktop
