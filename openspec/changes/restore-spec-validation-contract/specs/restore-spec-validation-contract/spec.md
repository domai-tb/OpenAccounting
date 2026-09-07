## ADDED Requirements

### Requirement: Maintained specs pass strict validation

The maintained specification set MUST contain the required Purpose and Requirements sections, valid requirement/scenario structure, and no malformed delta content so that strict validation passes for every maintained spec.

#### Scenario: Strict validation passes for all maintained specs

- Given the repository contains the maintained specs and configured Anvil schema
- When the maintainer runs `openspec validate --specs --strict`
- Then the command exits successfully and reports zero invalid maintained specifications

#### Scenario: Missing section fails validation

- Given a spec is missing a required section or scenario
- When strict validation runs
- Then validation fails with the offending path and no release gate can treat the spec as valid
