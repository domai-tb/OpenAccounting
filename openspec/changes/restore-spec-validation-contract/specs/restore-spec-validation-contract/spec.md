## ADDED Requirements

### Requirement: Maintained specifications are parseable under strict Anvil validation

The maintained specification set MUST contain the required Purpose and Requirements sections, valid requirement/scenario structure, and no malformed delta content so that strict validation passes for every maintained spec.

Implementation evidence: The current strict validation run reports 15 missing-section failures, while only 8 maintained specs pass.

#### Scenario: All maintained specs pass

- Given The repository contains the maintained specs and configured Anvil schema
- When the maintainer runs openspec validate --all --strict
- Then the command exits successfully and reports zero invalid maintained specifications

#### Scenario: Malformed spec blocks a release

- Given a spec is missing a required section or scenario
- When strict validation runs
- Then validation fails with the offending path and no release gate can treat the spec as valid

### Requirement: Conflicting normative requirements are reconciled

Each audited capability MUST have one unambiguous normative requirement for overlapping behavior, with obsolete duplicate wording removed or explicitly marked as historical context.

Implementation evidence: The setup specification contains duplicate cash-state requirements, and the repository has old/new requirement text that does not consistently describe the same contract.

#### Scenario: Duplicate behavior has one owner

- Given two maintained sections describe the same setup or accounting behavior differently
- When the spec set is reviewed
- Then one canonical requirement remains and its source and dependent changes are identified

#### Scenario: Unresolved conflict is visible

- Given a conflict cannot be resolved without a product decision
- When the proposal is validated
- Then the conflict is recorded as an open question and not silently encoded as two contradictory requirements
