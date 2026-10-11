## ADDED Requirements

### Requirement: Asset schedule schema preserves legacy records and history

The migration SHALL extend `anlageverzeichnis` additively with nullable canonical fields `asset_typ TEXT` constrained to `KFZ`, `EDV`, or `sonstig`; `kaufpreis_netto NUMERIC(12,2)` constrained to non-negative values; `nutzungsdauer_jahre INTEGER` constrained to positive values; `afa_methode TEXT` constrained to `linear`; `privat_anteil_prozent NUMERIC(5,2)` constrained to 0–100; and `verkauft_am TEXT`. A non-KFZ asset SHALL store no private-use percentage or zero until a type-specific rule is accepted. The existing `anschaffungsdatum` SHALL remain the canonical acquisition date. Nullable additions SHALL preserve existing legacy rows without inferred defaults. The migration SHALL preserve the existing primary keys, company/category references, status, and legacy columns `anschaffungskosten`, `nutzungsdauer`, and `privatanteil` without copying or reinterpreting legacy values. Every insert or update that sets `kaufpreis_netto` SHALL also write `anschaffungskosten` with the same amount so the legacy `NOT NULL` constraint is satisfied; reads SHALL treat `kaufpreis_netto` as canonical and SHALL NOT reinterpret `anschaffungskosten`. The migration SHALL verify each added column and roll back without advancing the schema version if verification fails.

The migration SHALL add `anlage_afa_jahreswerte` with a stable ID, `anlage_id INTEGER NOT NULL` foreign key to `anlageverzeichnis(id)` using `ON DELETE RESTRICT`, `jahr INTEGER NOT NULL`, `quell_snapshot TEXT NOT NULL`, `quell_hash TEXT NOT NULL`, `regel_version TEXT NOT NULL`, `status TEXT NOT NULL` constrained to `verfuegbar` or `nicht_verfuegbar`, `formel TEXT`, nullable `betrag NUMERIC(12,2)`, `blockierungsgrund TEXT`, and `berechnet_am TEXT NOT NULL`. A unique constraint SHALL cover `(anlage_id, jahr, quell_hash, regel_version)` so a stable source/rule result is not overwritten. An available row SHALL contain an amount and no blocking reason; an unavailable row SHALL contain no amount and a non-empty blocking reason. Schedule rows SHALL be append-only and immutable after insertion; database triggers SHALL abort every `UPDATE` or `DELETE` against this table. The table SHALL preserve prior schedule snapshots when source values or rules change. The table SHALL be owned by `fixed-asset-register-workspace`, introduced by this change's additive migration at the next accepted sequential schema version, and required at that version or later; before that version its absence SHALL NOT make the profile unhealthy. The runtime Table Definitions inventory and the profile portability export inventory SHALL declare it with this owner and version before any released profile creates it; an undeclared `anlage_afa_jahreswerte` SHALL make the profile export incomplete.

#### Scenario: Existing asset data survives migration

- **GIVEN** a profile contains legacy asset rows with arbitrary existing IDs, company/category links, and values in legacy columns
- **WHEN** the asset-schema migration completes
- **THEN** all existing rows and legacy values SHALL remain unchanged
- **AND** the canonical fields SHALL be present without inferred values
- **AND** the schema version SHALL advance only after schema verification succeeds

#### Scenario: Canonical writes satisfy the legacy required column

- **GIVEN** a new asset sets `kaufpreis_netto`
- **WHEN** the record is inserted
- **THEN** `anschaffungskosten` SHALL hold the same amount
- **AND** the insert SHALL NOT fail the legacy `NOT NULL` constraint

#### Scenario: Schedule history remains immutable

- **GIVEN** an asset has a stored annual schedule snapshot
- **WHEN** new source values or a new calculation rule produce another schedule
- **THEN** the earlier snapshot SHALL remain unchanged
- **AND** the new snapshot SHALL use its own source hash or rule version
- **AND** the asset SHALL NOT be hard-deleted while a schedule references it
