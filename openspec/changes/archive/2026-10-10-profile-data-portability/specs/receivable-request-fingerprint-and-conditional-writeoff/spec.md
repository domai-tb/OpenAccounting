## MODIFIED Requirements

### Requirement: Legacy payment rows have an explicit unknown-fingerprint policy

The v7-to-v8 migration MUST be owned by MigrationRunner and run inside its existing backup/migration transaction. Fresh schema creation, v7 upgrade, and repair of a present current-version payment table MUST use the shared transaction path: raw executor.runCustom('BEGIN'), followed by COMMIT on success or ROLLBACK on failure. The v7-to-v8 migration MUST create forderung_zahlungen when absent, add nullable fingerprint columns when an accepted legacy v7 table exists, repair missing unique non-null key/journal constraints, and verify them before setting user_version to 8. Before a current-version repair or any later migration could recreate forderung_zahlungen, startup MUST compare its presence with PRAGMA user_version. If user_version is 8 or greater and the table is absent, startup MUST stop before repair, preserve the original database, leave the table absent as a durable schema-health/completeness signal, mark the profile unavailable for complete export, and return the accepted typed schema-migration failure. It MUST NOT create an empty replacement table automatically. A present table with a repairable schema or constraint defect MAY be repaired only transactionally and while preserving all existing rows; failed or unverifiable repair MUST roll back. Fresh database creation MUST create and verify the table. AppDatabase.ensureOpen MUST invoke the feature-schema callback after the existing 39 AppDatabase.allTableNames tables have been created or migrated and before triggers, seeds, repository hooks, _opened = true, or service exposure. The shared feature_table_state database-health table is separate from that legacy 39-name list and is introduced by the coordinated v13 migration. The payment table remains feature-owned and excluded from the 39-name list. Existing relation, journal, amount, type, key, and date values MUST be preserved. Rows with a non-null key and any missing fingerprint field MUST be classified as legacy-unknown; the migration MUST NOT infer requested cents or direction from applied amount or partner data. A key colliding with such a row MUST return typed legacyFingerprintUnknown without mutation. Keyless legacy rows remain readable historical effects and do not participate in keyed replay. Failed DDL or duplicate-constraint repair MUST roll back columns, indexes, rows, and user_version.

#### Scenario: A v7 lazy table migrates without changing legacy rows

- **GIVEN** a profile at PRAGMA user_version = 7 has a lazy forderung_zahlungen table and rows without fingerprint columns
- **WHEN** the profile opens through the migration runner
- **THEN** schema version becomes 8, nullable fingerprint columns exist, every legacy row keeps its original values, and keyed legacy rows are classified legacy-unknown

#### Scenario: A missing v7 relation table is created safely

- **GIVEN** a v7 profile has forderungen and journals but no forderung_zahlungen table
- **WHEN** the normal v7-to-v8 migration opens the profile
- **THEN** the relation table, foreign keys, unique journal constraint, and unique non-null key constraint exist before a payment command runs
- **AND** no fabricated historical payment rows are created

#### Scenario: A present v7 relation table repairs missing constraints

- **GIVEN** a v7 profile has forderung_zahlungen and legacy rows but its unique indexes are absent
- **WHEN** the profile opens
- **THEN** the migration creates the unique journal and non-null key constraints and preserves every row value
- **AND** the legacy AppDatabase.allTableNames count remains 39

#### Scenario: A duplicate legacy key rolls the migration back

- **GIVEN** a v7 profile has duplicate non-null legacy keys that cannot satisfy the new unique constraint
- **WHEN** migration attempts constraint repair
- **THEN** it returns typed schemaMigrationFailed, leaves PRAGMA user_version = 7, preserves the original columns and rows, and leaves no partial fingerprint columns or indexes

#### Scenario: A migration failure preserves the base table count

- **GIVEN** a v7 profile whose feature migration is forced to fail after a DDL step
- **WHEN** the profile open is rolled back
- **THEN** its 39 existing base tables, feature table, rows, and user_version remain at their pre-migration state
- **AND** no service is exposed

#### Scenario: AppDatabase post-DDL failure rolls back before startup side effects

- **GIVEN** a v7 profile with its 39 existing base tables and no forderung_zahlungen table, opened with an injected afterFeatureSchemaDdl callback that records feature DDL and throws
- **WHEN** AppDatabase.ensureOpen runs the v7-to-v8 migration
- **THEN** the callback observes the feature table before failure, no triggers or seed rows are installed, isOpen and service getters remain unavailable, PRAGMA user_version remains 7, and the feature table/columns/indexes are absent after rollback
- **AND** the failure is surfaced as typed schemaMigrationFailed without requiring raw SQL text in the public message

#### Scenario: A current v8 profile repairs a missing feature table transactionally

- **GIVEN** a profile at PRAGMA user_version 8 or later has the 39 existing base tables but no forderung_zahlungen table
- **WHEN** AppDatabase.ensureOpen is asked to run current-version feature repair
- **THEN** the pre-repair health check stops initialization before the repair transaction can create a replacement table
- **AND** the original database and user_version remain unchanged, the payment table remains absent, and no triggers, seeds, or services are exposed
- **AND** complete export remains unavailable until verified restore or repair because the missing table remains observable
- **AND** no empty replacement table is created automatically

#### Scenario: A current-version repair preserves a present payment table

- **GIVEN** a profile at PRAGMA user_version 8 or later has forderung_zahlungen present with legacy rows but is missing repairable fingerprint columns or unique constraints
- **WHEN** AppDatabase.ensureOpen runs the current-version feature repair
- **THEN** one repair transaction adds or repairs the declared schema while preserving all existing row values
- **AND** schema health passes only after columns and constraints are verified

#### Scenario: Fresh startup, schema upgrade, current-v8 repair, and rollback share the raw-BEGIN migration path

- **GIVEN** recording fixtures for an empty profile, a v7 profile with and without forderung_zahlungen, a v8-or-later profile with a present table needing repair, a v8-or-later profile with the table missing, and a feature-DDL failure after DDL but before commit
- **WHEN** each fixture opens through AppDatabase.ensureOpen
- **THEN** fresh creation, the v7 upgrade, and present-table repair use the shared raw BEGIN followed by COMMIT, while an injected DDL failure uses raw BEGIN followed by ROLLBACK
- **AND** the v8-or-later missing-table fixture stops before repair DDL, preserves its table absence and user_version, and exposes no triggers, seeds, or services
- **AND** no fixture requires BEGIN IMMEDIATE, a separate transaction factory, or an unsupported production delegate

#### Scenario: A request cannot claim a legacy key

- **GIVEN** a legacy row has idempotency key legacy-1 but no reconstructible fingerprint
- **WHEN** a new keyed payment uses legacy-1
- **THEN** the command returns typed legacyFingerprintUnknown and journal count, relation count, and Forderung balances remain unchanged
