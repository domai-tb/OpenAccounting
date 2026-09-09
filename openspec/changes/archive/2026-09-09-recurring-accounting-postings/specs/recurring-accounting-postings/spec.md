## ADDED Requirements

### Requirement: Recurring invoices preserve position tax rates

Generating an invoice from a recurring template MUST calculate each position and the header from its configured tax rate, including mixed-rate and zero-rate templates, without forcing 19 percent.

Implementation evidence: The current generator stores ust_satz=19 and calculates brutto from netto*1.19 for every generated position.

#### Scenario: Mixed-rate template generates correct totals

- Given a template contains 19 percent, 7 percent, and zero-rate positions
- When the scheduled invoice is generated
- Then each position retains its rate and header net/VAT/gross equals the per-position sum

#### Scenario: Invalid template rate is handled

- Given a recurring position has an unsupported or missing tax rate
- When generation runs
- Then generation fails with a reviewable error and does not create a misleading finalized document

### Requirement: Recurring bookings calculate input tax from tax semantics

A recurring expense booking MUST store input tax derived from its explicit tax rate and gross/net contract, never treat the entire gross amount as Vorsteuer, and expose the result to downstream tax reporting.

Implementation evidence: The direct recurring path writes the whole template amount into vorsteuer_betrag and lacks a tax rate.

#### Scenario: Gross expense yields only its tax component

- Given a 119 euro gross expense uses a 19 percent rate
- When the recurring booking is posted
- Then input tax is 19 euro, the booking direction is Ausgabe, and UStVA sees the claim once

#### Scenario: Retry is idempotent

- Given the scheduled occurrence has already posted
- When the scheduler retries the same occurrence
- Then no duplicate journal or input-tax claim is created
