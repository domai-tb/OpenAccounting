# Design: Make first-run setup complete, atomic, and accounting-safe

## Context

Setup skip and successful completion only show a snackbar, while the router treats the skip sentinel company Meine Firma as unconfigured and redirects back to setup. Completion writes company, accounts, cash, and categories independently; the opening cash journal is classified as income while the account saldo remains zero. The wizard also omits documented invoice numbering/payment terms, privacy, and backup concepts and uses fake IBAN fallback values.

## Goals

A first-run user can finish or defer setup without loops, partial data, or misleading accounting state.

## Non-Goals

Designing all settings screens; settings exposure remains a separate boundary.

## Decisions

Use a persisted explicit setup status rather than company-name heuristics, wrap writes in one transaction, and treat missing values as missing.

## Risks / Trade-offs

Changing skip policy affects router guard and existing widget expectations; update end-to-end tests first.

## Migration Plan

Add red tests for Finish/Skip, atomic rollback, cash/dashboard agreement, and no fake credentials; then migrate wizard and guard.

## Open Questions

Should Skip create a minimal valid profile or defer setup while allowing read-only dashboard access?
