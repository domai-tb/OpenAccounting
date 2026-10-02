## Why

Document lifecycle requirements describe correction PDFs, attached source evidence, document packages, and a GoBD audit export, but the current implementation does not consistently produce or expose those artifacts. Receipts also lack a production import/review workflow, leaving the original evidence disconnected from the accounting record it is meant to support.

## What Changes

- Require finalized Storno, Gutschrift, replacement, and finalized conversion results to have readable, profile-local artifacts generated from the persisted document snapshot and committed with their document relationships and applicable lifecycle side effects. Draft results remain drafts without a claimed final artifact.
- Preserve source context and relationship integrity when creating correction and converted documents, including the required source links and fields already defined by the maintained document contract. This change does not define monetary formulas or correction signs.
- Provide a receipt inbox for importing supporting files, retaining the original bytes and verifiable metadata, reviewing or correcting extracted suggestions, associating evidence with accounting records and contacts, and viewing source files in their processing workflow.
- Extend existing document package membership to supporting evidence while preserving `dokumentenpaket_id`, `dokumentenpaket_belege`, and existing batch operations.
- Complete the GoBD export workflow with a selected-period export, records and evidence inventory, integrity manifest and verification, and a human-readable result that reports missing artifacts rather than silently presenting an incomplete export as complete.
- Align `docs/06-dokumente.md` with implemented receipt deletion and retention behavior so it does not promise an automatic purge that has no accepted policy.
- Apply `DESIGN.md` to the receipt and export surfaces: desktop-first responsive layouts, narrow-window behavior, localization, keyboard and assistive-technology access, and established design tokens/components.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `documents`: Strengthen correction/conversion source-context guarantees and modify the existing package and Beleg contracts for validated source intake, review, preview, deletion, and evidence membership.
- `document-artifact-transaction`: Extend the atomic artifact contract to finalized correction and conversion results.
- `receipts-and-payment-reconciliation`: Define durable file intake, review-only recognition assistance, and source preview for receipts.
- `accounting`: Define complete, verifiable GoBD export contents and outcomes for selected periods, including missing source or generated artifacts.

## Impact

Affected areas include invoice lifecycle use cases and persistence, PDF snapshot rendering and profile-local artifact storage, receipt storage/import and review services, document/package repositories and routes, GoBD export generation and verification, `docs/06-dokumente.md`, localization resources, and the associated design-system UI. The separate `invoice-authoring-and-lifecycle-workspace` proposal owns the invoice editor and user-facing correction/conversion action entry points; this change owns their domain data and artifact guarantees plus the receipt and audit-export workflows. GoBD report contents depend on `accounting-reporting-workspaces`; any new posting or payment allocation depends on `balanced-journal-postings-and-settlement-events` and explicit user confirmation. Correction calculations remain blocked on the accepted `invoice-money-invariants` contract.

OCR engine/provider and confidence policy, PDF/A conformance, statutory retention/deletion intervals, and the export delivery/encryption provider remain open decisions. Supported source formats are PDF, PNG, JPEG, XRechnung XML, and ZUGFeRD/Factur-X within the specified 50 MiB bound. Until retention policy is accepted, `loeschdatum` is informational and does not trigger automatic deletion. This proposal makes no legal-compliance claim and does not choose those policies or providers.
