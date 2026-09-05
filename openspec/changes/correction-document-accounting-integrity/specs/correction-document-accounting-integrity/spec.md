## ADDED Requirements

### Requirement: Correction totals preserve signed VAT mathematics

Storno and Gutschrift documents MUST derive net, VAT, and gross totals from signed source positions using each position's tax rate, and the persisted header totals MUST equal the sum of those positions.

Implementation evidence: Current Gutschrift code copies position rates but persists ust_betrag 0.00 and gross equal to net.

#### Scenario: Mixed-rate credit note reverses tax

- Given the source contains 19 percent, 7 percent, and zero-rate positions
- When a linked credit note is created
- Then each signed position and the header net/VAT/gross totals reverse the corresponding source amounts exactly

#### Scenario: Invalid source totals are not copied

- Given source header totals disagree with its positions
- When a correction is requested
- Then the operation rejects or recalculates from the authoritative positions and never persists a contradictory zero-tax header

### Requirement: Replacement and reversal links are complete and unique

Correction workflows MUST persist both sides of their source link, reject a second replacement when the contract permits only one, and retain immutable references to the original finalized document and postings.

Implementation evidence: The replacement guard cannot see ersatzrechnung_id because the field is absent from the selected source row.

#### Scenario: Second replacement is rejected

- Given a finalized invoice already has a replacement document
- When the user requests another replacement
- Then the command returns a domain conflict and creates no new document or posting

#### Scenario: A valid correction is traceable

- Given a finalized source has no correction yet
- When Storno or Gutschrift succeeds
- Then source and correction records reference each other and the audit view can traverse the chain
