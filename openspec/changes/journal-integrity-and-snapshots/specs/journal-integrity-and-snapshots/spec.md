## ADDED Requirements

### Requirement: Storno enforces immutable finalized journal rules

Journal Storno MUST accept only a finalized immutable source, create an immutable signed reversal linked to that source, reject duplicates, and preserve the booking group.

Implementation evidence: The current Storno path checks existence/duplicates but not original.immutable and inserts immutable=0.

#### Scenario: Finalized source can be reversed once

- Given an immutable finalized journal entry has no reversal
- When Storno is requested
- Then one immutable reversal is created with inverse values, source link, and shared gruppe_id

#### Scenario: Mutable or already reversed source is rejected

- Given the source is mutable or already has a reversal
- When Storno is requested
- Then the command fails without a new row and the original remains unchanged

### Requirement: Journal rows carry audit-stable snapshots

Creating and reading a journal entry MUST preserve the resolved account/category and tax snapshot fields needed to interpret the historical booking even if master data later changes.

Implementation evidence: Creation accepts optional snapshot values and JournalEntry exposes neither the tax fields nor complete group information.

#### Scenario: Missing snapshots are resolved

- Given a booking selects a valid category without explicitly supplied snapshot values
- When the booking is created
- Then account number/name, tax rate/special case, and reporting mappings are copied into the journal row

#### Scenario: Historical read is stable after master-data edit

- Given the category is renamed or remapped after booking
- When the journal entry is read
- Then its stored snapshots and gruppe_id remain unchanged and complete
