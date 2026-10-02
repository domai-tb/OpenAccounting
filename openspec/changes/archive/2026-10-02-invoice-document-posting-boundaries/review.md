## Review Metadata

- **Review round**: 2
- **Prior round**: Round 1 — REVISE: unsafe PDF identity/cleanup (C1), an unguarded receivable entry point (M1), ambiguous legacy stock (M2), repeated-line stock inconsistency (M3), incomplete late rollback scenarios (M4), and incomplete type/range boundaries (M5).
- **Reviewer context**: fresh-context independent subagent; no authoring transcript read. The prior on-disk review was read to adjudicate its findings.
- **Tool restrictions**: read-only inspection and structural validation; the reviewer's only write is this `review.md`. No source edits, tests, test-plan, or tasks were created or run by the reviewer.
- **Review method**: full second review of the proposal, design, all delta specs, relevant main-spec requirements, source callers, transaction paths, PDF persistence, and existing tests. Author changes made before this verdict were re-read as a complete final artifact set; resolution is based on their on-disk contents.
- **Source baseline**: branch `dev`, commit `7089e866ef606fbf8767d2acd715f4958ad8ef06`.
- **Structural check**: `openspec validate invoice-document-posting-boundaries --type change --strict --json` passed on the final reviewed contents. This establishes artifact structure, not runtime correctness.
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/documents/spec.md`, `specs/accounting/spec.md`, and `specs/inventory/spec.md` in this change. `openspec/project.md` is absent.
- **Relevant main specs**: `openspec/specs/documents/spec.md`, `openspec/specs/accounting/spec.md`, and `openspec/specs/inventory/spec.md`.
- **Relevant source inspected**: `RechnungTyp`; `RechnungenDataSource` finalization, numbering, PDF snapshot, correction, replacement, and conversion paths; invoice use-case/repository/UI callers; `AppServices`; `ForderungenRepository.createForRechnung`; `VorschauService`; PDF models; inventory/article repositories; database tables, seeds, and invoice triggers.
- **Existing tests inspected**: invoice accounting posting lifecycle, finalized document artifact lifecycle, correction document accounting integrity, inventory stock/movement cases, and finalization failure cases. No test execution was performed.

### Reviewed artifact fingerprints

Paths below are relative to this change directory. The verdict applies to these exact contents.

| Artifact | SHA-256 |
| --- | --- |
| `proposal.md` | `124fcee80c75ffea5908f820be2b55597d4a72fd1d0d054d27fc1a16703a75ce` |
| `design.md` | `15a12b0795ec3e775f622e072ffbbf6af7e842bab96ba0e4aa0b458f8bfb6865` |
| `specs/documents/spec.md` | `68660618249e0e978cc34af048027894c9dbad74e226fe53be552aeb8d1e2f96` |
| `specs/accounting/spec.md` | `bfcf8dfa3ac6fc1cbd28a703e7695e7ec94f079d4cf2de2cc6843701704f264c` |
| `specs/inventory/spec.md` | `d84136d6ab46fbee8cde0f63b67cf5925e3d4223209c5669380b5d910ccfcfd2` |

Later edits to the proposal, design, or delta specs void this verdict and require review before downstream work proceeds.

## Findings

### 🔴 Critical (blocking)

None open. C1 is resolved in the reviewed plan; implementation remains subject to the acceptance scenarios below.

### 🟡 Moderate

None open. M1–M5 are resolved in the reviewed plan. The final artifact set also reconciles the original main-spec prohibition on all disabled-stock operations with the explicitly retained legacy exception.

### 📌 Suggestions

When implementing the accepted failure scenarios, use a real profile directory for incoming rollback as well as outgoing/document-only rollback, and compare pre-existing PDF bytes before and after the collision cases. An in-memory database alone cannot demonstrate the specified file ownership behavior. This is guidance for executing the existing requirements, not an additional artifact change.

## Rebuttals and Prior-Finding Adjudication

### C1 — PDF identity and cleanup: fixed; accepted by reviewer

`design.md:28` selects `pdfs/documents/<rechnung-id>.pdf`, refuses an occupied final target, and establishes final-file ownership only after successful rename. `proposal.md:11` limits cleanup to files created by the failed operation. `specs/documents/spec.md:104–116` requires distinct paths for identical display numbers, preservation of both existing files on a refused target, and preservation of historical stored paths.

This directly removes the source counterexample: seeded invoice ranges can both produce the same number (`lib/core/db/seed.dart:29–46`), while current finalization derives the path from that number and assigns cleanup ownership before generation (`lib/pages/rechnungen/rechnungen_datasource.dart:406–438`, `569–573`). A stable row ID already exists before finalization, so the proposed correction needs no registry, schema migration, or global numbering policy. The late-failure scenarios separately require removal of the newly created artifact on rollback.

### M1 — Invoice-derived receivable entry point: fixed; accepted by reviewer

`proposal.md:7`, `25`, and `30`, `design.md:25–26`, and `specs/documents/spec.md:118–130` now explicitly include `ForderungenRepository.createForRechnung`, restrict eligibility before partner resolution, reject a finalized offer, and require an incoming alias to create the supplier payable.

This covers the actual public bypass at `lib/features/einkommen/forderungen_repository.dart:345–373`, exposed by `lib/core/app_services.dart:32`. The same direction decision controls partner selection and receivable type, including supplier precedence and the no-supplier incoming case. Unrelated manual receivable creation is outside this change's claim.

### M2 — Legacy and disabled stock: fixed; accepted by reviewer

`design.md:29–30` and `specs/inventory/spec.md:3–21`, `64–85`, and `120–125` state the exact compatibility predicate: false tracking flag, zero current stock, and nonzero legacy stock. They define use of the legacy balance, writes to both stock columns, and enabling tracking. Disabled rows outside the predicate stay unchanged, including during Storno with a historical source movement.

The delta now modifies `Per-article inventory activation` itself, so the unchanged main requirement at `openspec/specs/inventory/spec.md:9–17` will not continue prohibiting the intended exception after synchronization. Its disabled scenario and the multiple-line scenario explicitly use a non-legacy row. This reconciles the policy with the two existing compatibility branches at `rechnungen_datasource.dart:358–364` and `716–729` without silently treating every false flag as permission to migrate stock.

### M3 — Repeated article lines: fixed; accepted by reviewer

`design.md:29` requires aggregation before validation and a single update/movement per article. `specs/inventory/spec.md:50–62` gives the active-stock success and combined-insufficiency counterexamples. Lines `70–75` now give the missing legacy round trip: quantities 3 and 4 take both stock columns from the legacy starting balance 20 to 13, produce one -7 movement, and Storno restores both to 20 with one +7 movement.

These outcomes distinguish the planned behavior from the current cached-per-line legacy writes at `rechnungen_datasource.dart:350–401`, which can overwrite one another while recording the full combined movement. The plan establishes that newly produced movement sums equal actual deductions before using the ledger for restoration.

### M4 — Late failure and rollback branches: fixed; accepted by reviewer

The final delta has concrete outgoing rollback after stock, PDF, journal, and receivable writes (`specs/documents/spec.md:39–44`), incoming rollback after input-tax insertion (`92–96` and `specs/accounting/spec.md:22–25`), document-only rollback after rename/document update (`98–102`), and Storno rollback after restoration (`specs/inventory/spec.md:127–132`). They require the relevant draft/source state, counter, stock, postings, movements, and operation-created artifact to roll back, followed by a successful single-effect retry.

`design.md:31` provides an observable failure point for the new document-only branch and uses a database-trigger failure for Storno after restoration. Existing outgoing/incoming posting fault points are after the relevant writes (`rechnungen_datasource.dart:503`, `557`, `565`); Storno reversal writes follow restoration (`742–823`). This closes the gap in the existing outgoing failure test, which currently has neither an inventory article nor a real PDF directory (`test/integration/audit/invoice-accounting-posting-lifecycle_test.dart:127–177`).

### M5 — Type, range, and partner boundaries: fixed; accepted by reviewer

`design.md:25–28` and `specs/documents/spec.md:31`, `46–90` cover all three incoming aliases, canonicalized spelling, supplier-linked legacy Rechnung, incoming invoices with only a customer, document-only records, correction types, unknown values, raw outgoing range labels, and missing/inactive/malformed selected ranges without fallback. The counterparty/PDF scenario at `58–61` requires an incoming document with both partners to render the supplier in the existing invoice layout.

The source supports the proposed reuse: `RechnungTyp.canonicalize` already trims, lowercases, and resolves these aliases (`lib/features/accounting/rechnung_typ.dart:14–20`). The finalizer's number lookup and PDF builder currently use separate raw-type/partner decisions (`rechnungen_datasource.dart:276–326`, `1363–1387`); the design explicitly joins those decisions at the resolved direction. Unsupported records are rejected before they can reach either numbering or the PDF fallback. The optional-partner rule is explicit and does not accidentally create a customer receivable for an incoming invoice.

### Prior suggestions and additional second-round checks

- **Movement filtering/aggregation — fixed; accepted by reviewer.** `specs/inventory/spec.md:85` and `113–118` require the exact source ID/reference type and negative-diff filter, aggregate -2.000 and -3.500 to one +5.500 restoration, and exclude positive and unrelated movements. The no-source-movement and currently disabled cases are also explicit. Stock restoration no longer depends on line-item quantities.
- **Preserve correction tax-reversal coverage — fixed; accepted by reviewer.** `specs/accounting/spec.md:27–30` explicitly retains a linked negative claim through the dedicated Storno operation. This supplies a replacement acceptance case when the existing outgoing-tax assumptions at `test/integration/audit/invoice-accounting-posting-lifecycle_test.dart:243–254` and `297–302` are updated. The preserved source path is `rechnungen_datasource.dart:807–818`; the incoming-only condition belongs to generic creation, not to that reversal loop. Historical claims and correction signs remain outside generic creation eligibility.
- **Reuse shared classification — accepted by reviewer.** `design.md:25–26` reuses the existing canonicalizer and one resolved direction rather than introducing a new registry. The API and PDF counterparty decisions are included in that boundary.
- **Delta operations — fixed; accepted by reviewer.** The new generic-effects, PDF-identity, and invoice-derived-receivable requirements are under `ADDED Requirements`. Existing stock and activation requirements use their exact main-spec names under `MODIFIED Requirements`.
- **Proposal consistency — fixed; accepted by reviewer.** `proposal.md:25` now correctly distinguishes incoming-only input-tax claims from receivables allowed for either supported invoice direction.
- **Scope and trust boundaries — no new blocker found.** The plan validates document types and selected ranges before their side effects, uses persisted row identity for artifact paths, and retains the existing transaction boundary. It does not require new dependencies, a schema migration, changed correction signs, or reconstruction of historically inconsistent records. The review does not certify those explicitly deferred areas.

No Critical or Moderate finding was accepted solely on an author's rebuttal. Each resolution above was checked against the final on-disk artifact set and the relevant current source.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

The reviewed files contain requirements, design choices, and source/test comments. No embedded instruction attempted to override reviewer constraints or force a verdict. File contents were treated as evidence to critique.

## Verdict

VERDICT: APPROVE

The final planning artifacts resolve the first-round findings and define a bounded, testable implementation. Test-plan and tasks may proceed for the fingerprinted contents. This approval is of the plan; source implementation and runtime verification remain outstanding.

## Required Changes

None.

CHANGES_APPLIED: n/a
