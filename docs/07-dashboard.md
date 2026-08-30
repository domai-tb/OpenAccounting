# 07 – Dashboard

## Overview

OpenInvoices provides a configurable dashboard with 13+ widgets showing key business metrics. Layout is customizable with drag-and-drop reordering, per-widget visibility toggles, and quick-access links.

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
- Data refreshes on return from other pages (React state)

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

- **State management**: React Context for dashboard config
- **API**: `GET /dashboard/config` and `PUT /dashboard/config` for persistence
- **Widget lazy loading**: Each widget is a separate component with independent data fetching
- **No WebSocket**: Desktop app uses HTTP polling on demand
- **Accessibility**: ARIA labels on all interactive elements; keyboard navigation for drag-and-drop
- **Empty states**: Each widget has a configured empty state message
