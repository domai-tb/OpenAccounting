# 07 – Dashboard

## Overview

OpenAccounting provides a configurable dashboard with 13 widgets showing key business metrics. Layout is customizable with drag-and-drop reordering, per-widget visibility toggles, and quick-access links. Period KPIs use the annual calendar-year `AccountingPeriodSummary` only (supported years, 2025 form first); month/quarter remain unavailable until the reporting workspace accepts them.

## Period metrics (supported)

- Annual selector (`YYYY-01-01` through next `YYYY-01-01`); flow KPIs use the year, open balances use the year-end date.
- Income/expenses from the accepted annual summary; profit = income − expenses; margin = profit / income × 100 when income is positive, else unavailable.
- Year-over-year change = (current − prior) / abs(prior) × 100; zero baseline shows absolute values + "not comparable".
- Monthly income/expense + profit trends, expense/VAT distribution from the canonical reporting service with exact values + accessible text.
- Until `accounting-reporting-workspaces` is accepted, the summary shows its unavailable state naming that prerequisite; no invoice/journal/bank substitution.
- Historical open balances from event history (receivables-ledger statement + approved settlement allocations/keyed `zahlung` dates verbatim; payables from `rechnung_eingang` + supplier allocations). Write-offs/corrections without an accepted effective date and `legacy_unverified` mixes yield incomplete-history unavailable.

## Operational sources (corrected)

- Open/overdue exclude cancelled/storno, drafts (`ist_entwurf`), and paid; receipts count only accounting-confirmed payments (`bank_transaktionen.journal_id`); unmatched rows stay as reconciliation work and never count as receipts.
- VAT reserve only from the canonical tax source, labeled as estimate. Tax deadlines only from the configured tax calendar; otherwise a configuration/error state (never a hardcoded date).
- Attention items link to filtered workspaces; unmatched items use the existing `/banking?transactionId=<id>` selection preserving other query state; missing/malformed/unavailable IDs show the typed not-found state.

## Quick links

- Stored as `{label, route}` in `unternehmen.dashboard_config`; defaults: new invoice, reports, inventory.
- Routes are validated against the router allowlist before persistence; invalid entries show a localized validation message and are never persisted nor navigated to.
- Legacy persisted invalid links are filtered on load without navigation and appear as a removable invalid-link state.

---

## Default Widgets

### Offene Rechnungen (Open Invoices)

- List of unpaid, non-storniert invoices
- Columns: Rechnungsnummer, Kunde, Betrag, Faelligkeit, Mahnstufe
- Color coding: Green (≤7 days), Yellow (8-30 days), Red (>30 days)
- Click → opens Rechnung detail

### Zahlungseingänge (Recent Payments)

- Last 10 journal entries with `art = einnahme`
- Shows: Date, Amount, Partner, Category
- Sum of last 30 days

### Umsatzübersicht (Revenue Overview)

- Bar chart: Monthly revenue (current year)
- Separated by category (Betriebseinnahmen, Sonstige)
- Tooltip with exact amounts

### EÜR-Vorschau (EÜR Preview)

- Current year EÜR summary
- Top 10 line items by amount
- "Details" link → full EÜR page

### Lagerwarnung (Stock Warnings)

- Articles below `mindestbestand`
- Shows: Artikel, Aktueller Bestand, Mindestbestand
- Red: `bestand_aktuell < mindestbestand`
- Only visible when `lagerführung_aktiv`

### Überzahlungen (Overpayments)

- Customers with positive Forderung balance
- Shows: Kunde, Betrag, Datum letzte Zahlung
- Actions: Verrechnen, Rückückerstatten, Anerkennung

### Mahnwesen-Übersicht (Dunning Summary)

- Count of invoices per Mahnstufe
- Total offener Betrag per Stufe
- Customer blocks active

### Steuerfristen (Tax Deadlines)

- Upcoming UStVA, ESt-Vorauszahlung, GewSt-Vorauszahlung
- Shows: Art, Faelligkeit, Betrag (estimated)
- Color: Green (>14 days), Yellow (≤14 days), Red (overdue)

### Bank-Kontoübersicht (Bank Balance)

- Per-account balance from last import
- Shows: Konto, Letzter Import, Saldo
- Link to Bank Import page

### Schnellzugriff (Quick Access)

- User-configurable links to common pages
- Default: Neue Rechnung, Neue Buchung, Bank Import
- Drag-and-drop to reorder

### Letzte Änderungen (Recent Activity)

- Last 20 create/update/delete operations
- Shows: Timestamp, Entity, Action, User
- Helps track multi-user changes

### Dokumentenstatus (Document Pipeline)

- Kanban-style view: Entwurf → Finalisiert → Bezahlt
- Count per stage per document type
- Click → filtered list

### GuV-Warnung (GuV Threshold)

- Warning when approaching §141 AO thresholds
- Shows: Current Umsatz/Gewinn, Threshold, Percentage
- Visible when `guv_aktiv` or approaching 80% threshold

---

## Widget Configuration

### Storage

```json
{
  "dashboard_config": {
    "widgets": [
      {
        "id": "offene_rechnungen",
        "enabled": true,
        "position": 0,
        "size": "large"
      },
      {
        "id": "zahlungseingaenge",
        "enabled": true,
        "position": 1,
        "size": "medium"
      },
      {
        "id": "lagerwarnung",
        "enabled": false,
        "position": 5,
        "size": "small"
      }
    ],
    "schnellzugriff": [
      {"label": "Neue Rechnung", "route": "/rechnungen/neu"},
      {"label": "Neue Buchung", "route": "/journal/neu"},
      {"label": "Bank Import", "route": "/bank-import"}
    ]
  }
}
```

### Widget Sizes

| Size | Columns | Description |
|------|---------|-------------|
| `small` | 1 | Compact, single-column |
| `medium` | 2 | Half-width, default |
| `large` | 3 | Full-width, detailed |

### Drag-and-Drop Reordering

- Grid layout with sortable widgets
- Position stored in `dashboard_config.widgets[].position`
- Persisted on change (no save button needed)

---

## Data Refresh

### Mount Behavior

1. Dashboard component mounts
2. Parallel API calls for all enabled widgets
3. Loading states per widget (skeleton UI)
4. Data arrives → widgets render independently

### Auto-Refresh

- No polling (desktop app, not web)
- Manual refresh button in header
- Data refreshes on return from other pages (Riverpod state)

### Performance

- Each widget fetches only its data
- Heavy widgets (EÜR-Vorschau) cached for session
- Database queries optimized with indexes on `datum`, `kategorie_id`, `partner_id`

---

## Quick Access Links

### Default Links

| Label | Route | Icon |
|-------|-------|------|
| Neue Rechnung | `/rechnungen/neu` | Document |
| Neue Buchung | `/journal/neu` | Book |
| Bank Import | `/bank-import` | Bank |
| Kunden | `/kunden` | Users |
| Artikel | `/artikel` | Package |

### Custom Links

Users can add links to any route:

```json
{
  "label": "Mahnung erstellen",
  "route": "/mahnwesen/neu",
  "icon": "Bell"
}
```

---

## Responsive Behavior

### Desktop (≥1280px)

- 3-column grid
- All widgets visible
- Large widgets span full width

### Tablet (768-1279px)

- 2-column grid
- Large widgets become medium
- Small widgets stack

### Mobile (<768px)

- Single column
- Widgets stack vertically
- Quick access becomes horizontal scroll

---

## Widget Details

### Offene Rechnungen – Data Source

```sql
SELECT r.*, k.firmenname, k.mahnstufe_aktuell
FROM rechnungen r
JOIN kunden k ON r.kunde_id = k.id
WHERE r.zahlungsstatus != 'bezahlt'
  AND r.storniert = 0
  AND r.ist_entwurf = 0
ORDER BY r.faelligkeit ASC
```

### Umsatzübersicht – Aggregation

```sql
SELECT 
  strftime('%Y-%m', j.datum) as monat,
  SUM(j.brutto_betrag) as umsatz
FROM journal j
JOIN kategorien k ON j.kategorie_id = k.id
WHERE k.art = 'einnahme'
  AND j.datum >= date('now', 'start of year')
GROUP BY monat
ORDER BY monat
```

### Steuerfristen – Calculation

- UStVA: Monthly (10th of following month) or quarterly
- ESt-Vorauszahlung: Quarterly (10th)
- GewSt-Vorauszahlung: Quarterly (15th)
- Dauerfristverlaengerung adds 1 month to UStVA

---

## Technical Notes

- **State management**: Riverpod providers for dashboard config
- **API**: Local Drift/SQLite persistence for dashboard config
- **Widget lazy loading**: Each widget is a separate widget with independent data fetching
- **No WebSocket**: Desktop app uses HTTP polling on demand
- **Accessibility**: ARIA labels on all interactive elements; keyboard navigation for drag-and-drop
- **Empty states**: Each widget has a configured empty state message
