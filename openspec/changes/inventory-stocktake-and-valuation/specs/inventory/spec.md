## MODIFIED Requirements

### Requirement: Inventory movement storage

The migration that introduced inventory movement logging SHALL create exactly one movement table, `inventarbewegungen`, with `id`, `artikel_id` (foreign key to `artikel`), `datum`, `diff` (NUMERIC(10,3)), `grund`, and nullable `referenz_typ` and `referenz_id` fields. Outgoing-invoice deductions, Storno restores, and manual adjustments SHALL each write movement rows in the same transaction as the stock change. Repeated outgoing lines for one article SHALL produce a movement whose `diff` equals the combined stock change. Storno SHALL use the source invoice's recorded negative movement as its restoration amount. Physical count snapshots SHALL use the separately specified `inventuren` and `inventur_positionen` tables; they SHALL NOT be represented as movement rows.

#### Scenario: Automatic movement recorded

GIVEN an inventory-enabled article is included in a finalized outgoing invoice
WHEN stock is decremented
THEN `inventarbewegungen` SHALL contain the negative quantity with the invoice reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Storno movement recorded

GIVEN an outgoing invoice has a recorded negative stock movement and is storniert
WHEN stock is restored
THEN `inventarbewegungen` SHALL contain the positive restored quantity with the Storno reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Incoming and document-only finalization has no automatic movement

GIVEN an inventory-enabled article is included in a finalized incoming invoice or offer
WHEN document finalization commits
THEN no automatic inventory movement SHALL be recorded.

#### Scenario: Count snapshots are not movement rows

GIVEN a stocktake records a counted quantity for an inventory-enabled article
WHEN the count is recorded
THEN no `inventarbewegungen` row SHALL be added for that count
AND the count SHALL be stored in its stocktake position.

## ADDED Requirements

### Requirement: Physical stocktake capture and recording

When global inventory is enabled, the `/inventory` workspace SHALL let the user start a stocktake for a selected reporting date. Starting a draft SHALL require at least one currently inventory-enabled article and snapshot each such article once, with its ID, description, and unit. Users SHALL enter an explicit counted quantity for every snapshotted article; zero is a valid quantity and an unentered quantity SHALL remain missing rather than being treated as zero. Counted quantities SHALL support the article stock precision of three decimal places and SHALL NOT be negative. Recording SHALL require all quantities, atomically persist the recorded state, and make the recorded snapshot immutable. A stocktake SHALL retain both its selected reporting date and creation timestamp. Its result SHALL label stored quantities as physical counts and SHALL NOT show `bestand_aktuell` as the selected date's book quantity or calculate a count variance. When global inventory is disabled, previously recorded stocktakes SHALL remain available as read-only history, but new drafts and edits SHALL be unavailable. Creating, editing, or recording a stocktake SHALL NOT change article stock, append stock movements, create or modify business documents, or post accounting entries.

#### Scenario: Complete a physical count

GIVEN global inventory is enabled and a draft snapshots two inventory-enabled articles
WHEN the user enters 0 for the first article and 2.500 for the second, then records the stocktake
THEN one recorded stocktake SHALL show the selected reporting date, its creation timestamp, and counted quantities 0 and 2.500 with their captured article descriptions and units
AND `bestand_aktuell`, `bestand`, and `inventarbewegungen` SHALL remain unchanged.

#### Scenario: Missing count cannot be recorded

GIVEN a draft stocktake has at least one article whose counted quantity is still null
WHEN the user attempts to record it
THEN the operation SHALL fail with a localized missing-count state
AND the stocktake SHALL remain an editable draft
AND null SHALL NOT be displayed or persisted as a count of zero.

#### Scenario: Global inventory disabled

GIVEN `unternehmen.lagerführung_aktiv = false`
WHEN the user opens `/inventory` or requests stocktake creation
THEN the stocktake action SHALL show a localized unavailable state
AND previously recorded counts SHALL remain available as read-only history
AND no new stocktake row SHALL be created.

#### Scenario: No inventory-enabled articles are available

GIVEN global inventory is enabled but no article is inventory-enabled
WHEN the user starts a stocktake
THEN the workspace SHALL show a localized no-countable-articles state
AND SHALL NOT create an empty stocktake.

#### Scenario: Recorded count cannot be overwritten

GIVEN a stocktake has been recorded
WHEN the user tries to edit its date or a counted quantity
THEN the stored record SHALL remain unchanged
AND the user SHALL be directed to create a separate stocktake for a correction.

### Requirement: Physical stocktake persistence

The stocktake migration SHALL create exactly two named tables. `inventuren` SHALL contain `id` (primary key), `stichtag` (non-null ISO date text), `status` (non-null text constrained to `entwurf` or `erfasst`), and `erstellt_am` (non-null ISO timestamp text). `inventur_positionen` SHALL contain `id` (primary key), `inventur_id` (non-null foreign key to `inventuren.id`), `artikel_id` (non-null historical article identifier), `bezeichnung_snapshot` (non-null text), `einheit_snapshot` (non-null text), and `menge_gezaehlt` (nullable NUMERIC(10,3), constrained to be non-negative when present), with a unique constraint on `(inventur_id, artikel_id)`. Drafts MAY contain null counts; a transition to `erfasst` SHALL be rejected unless at least one position exists and every position has a count. Creating and recording a stocktake SHALL persist header and positions atomically. Database triggers or equivalent persistence-boundary guards SHALL reject UPDATE or DELETE of a recorded `inventuren` row and INSERT, UPDATE, or DELETE of any `inventur_positionen` row whose parent is recorded; a draft-to-recorded transition SHALL be rejected if any count is null. These tables SHALL store count evidence only and SHALL NOT store derived valuation amounts or accounting postings.

#### Scenario: Migration creates the declared stocktake tables

GIVEN the stocktake migration runs against a supported profile database
WHEN the migration completes
THEN `inventuren` and `inventur_positionen` SHALL exist with the declared columns, constraints, and foreign key
AND existing article and movement rows SHALL retain their values.

#### Scenario: Direct SQL cannot create an empty recorded header

GIVEN the stocktake migration is installed
WHEN direct SQL attempts to insert an `inventuren` header with status `erfasst` before any positions exist
THEN the persistence guard SHALL reject the insert
AND no recorded header without count positions SHALL remain.

#### Scenario: Direct update or delete of recorded stocktake is rejected

GIVEN a stocktake has status `erfasst`
WHEN direct SQL attempts to update or delete its header or to insert, update, or delete one of its positions
THEN the persistence guard SHALL reject each mutation
AND the recorded header and positions SHALL remain unchanged.

#### Scenario: Duplicate article position is rejected

GIVEN a stocktake already has one position for an article ID
WHEN a second position for the same article ID and stocktake is inserted
THEN the unique constraint SHALL reject the insert
AND the existing position SHALL remain unchanged.

### Requirement: Stocktake counts are distinct from book quantities

The stocktake result SHALL identify stored quantities as physical counts for the selected reporting date. It SHALL NOT present current article stock as the book quantity for that date. Until a separate contract defines a verifiable opening baseline and complete movement coverage through the selected date, the result SHALL label book quantity and count variance as unavailable and SHALL display the recorded physical count separately.

#### Scenario: Recorded quantities appear as physical counts

GIVEN a complete stocktake has been recorded for a selected reporting date
WHEN the stocktake result is displayed
THEN each recorded quantity SHALL be labeled as a physical count for that date
AND book quantity and count variance SHALL be labeled unavailable.

#### Scenario: Current stock is not substituted for historical quantity

GIVEN an article has a current `bestand_aktuell` value but no verified opening baseline and complete movement coverage through the selected reporting date
WHEN the user opens the stocktake result
THEN book quantity and count variance SHALL remain unavailable
AND the current `bestand_aktuell` value SHALL NOT appear as a historical quantity.

### Requirement: Inventory valuation fails closed without policy

The inventory workspace SHALL NOT calculate, store, export, or post a monetary inventory value until a reviewed valuation policy defines the applicable cost basis, source, reporting-date treatment, and required inputs. While that policy or any required input is unavailable, the stocktake result SHALL show a localized unavailable state for per-article and total value; it SHALL NOT substitute an article price or zero for an unknown value. Count capture and quantity reporting SHALL remain available. Recording a stocktake SHALL create no journal, tax, receivable, payable, or other accounting entry.

#### Scenario: Count remains available while valuation policy is unspecified

GIVEN inventory valuation has no reviewed and implemented policy
WHEN the user records a complete stocktake and opens its result
THEN counted quantities SHALL be available
AND per-article and total inventory values SHALL display a localized unavailable state with no numeric amount.

#### Scenario: Valuation request fails without side effects

GIVEN inventory valuation policy or required valuation input is unavailable
WHEN the user requests a valued report or export
THEN the request SHALL return a localized unavailable result
AND no monetary valuation or accounting entry SHALL be persisted
AND existing stocktake counts and live stock SHALL remain unchanged.
