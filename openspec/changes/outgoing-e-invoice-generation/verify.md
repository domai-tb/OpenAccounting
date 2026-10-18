## Verification Results

### Task Completion

- [ ] All tasks marked `[x]` in `tasks.md`
- Remaining open tasks: 38 of 128. The exact delivered base was 96/128 checked; this revision reopens tax tasks 7.1–7.6 because prior coverage does not prove persisted typed evidence, the named treatment mappings, or the revised mismatch/fail-closed behavior. Prerequisite 1.2 remains open pending independent acceptance of the named mapping and resolution of the §25a category/reason and disclosed-total relationship. Prerequisite 1.3 (offline validator packaged and demonstrated on Linux, Windows, and macOS) also remains open; dependent scenario tasks remain open.

### TDD Integrity

- [ ] Every test-plan entry exists as a real test or documented non-executable check
- [ ] Every test-plan row is green; unimplemented e-invoice and validator scenarios remain red
- [ ] Full suite passes
- [ ] Zero skipped, pending, or incomplete tests; no application tests were run for this spec-only revision, and the prior historical full-suite attempt left 73 tests incomplete after the test device crashed
- [ ] No test weakened or deleted without a removed requirement

This is a spec-only contract revision. No application code, schema, migration, tests, or validator assets were changed, and no tests were run. Task 1.2 remains open: the revised table names supported mappings and requires additive v26 evidence persistence, but §25a has no approved EN 16931 category/reason or VAT-breakdown/payable-total relationship. Tasks 7.1–7.6 were deliberately reopened because their prior coverage does not establish the full revised mapping, v26 persistence, or fail-closed §25a behavior. Task 1.3 remains open because this Linux-only environment cannot demonstrate Windows/macOS validator runs.

### Evidence

- Historical full-suite command from the prior implementation checkpoint: `rtk proxy fvm flutter test --dart-define=platform=vm`
- Historical result from that checkpoint: failed; 1,697 passed, 26 explicit failures, and 73 tests did not complete after the test device crashed. Failures include invoice/tax tests and desktop/runtime failures; this is not an acceptance pass and was not rerun for this spec-only revision.
- Historical analyzer from that checkpoint: `rtk proxy fvm flutter analyze` → `No issues found!`; it was not rerun for this spec-only revision.
- Focused tests from the prior customer-default checkpoint: 44 passed; prior focused changed-test set: 242 passed. These do not cover the remaining validator and tax-treatment gates.
- `openspec validate outgoing-e-invoice-generation --type change --strict --json` → `valid: true`, zero issues; `git diff --check` → clean. No application tests were run for this spec-only task.
- `openspec list --json` reports this change in progress with 90/128 tasks complete, matching `tasks.md` (90 checked, 38 unchecked).
- Rechecked after the round-7 §13b repair on 2026-10-18: strict change validation remains valid with zero issues; all 40 delta scenarios have named test-plan rows; `openspec list --json` still reports 90/128; `git diff --check` is clean. The four new §13b success/failure test cases are marked red and have matching open task coverage. These are structural checks only; no application tests were run.
- Official source review on 2026-10-18 records the pinned XRechnung Bundle 3.0.2 (2026-08-31), ZUGFeRD 2.5.2, and KoSIT configuration versions. This confirms target versions, not app packaging or three-platform runtime evidence: [XRechnung bundles](https://xeinkauf.de/xrechnung/versionen-und-bundles/), [KoSIT validator configuration](https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/tag/v2026-08-31), [FeRD ZUGFeRD downloads](https://www.ferd-net.de/en/download-zugferd).
- Official statute/source audit on 2026-10-18: §13b(1) requires a service taxable domestically under §3a(2) from an entrepreneur established in another EU Member State; §13b(7) treats an otherwise EU-established supplier as such for a transaction when its German establishment is not involved. §13b(2) no. 4 defines the supported construction-service subset; §13b(5) requires a qualifying entrepreneur recipient and provides a presumption from a valid authority-issued certificate at the time the service is performed. The BMF USt 1 TG form is specifically for construction and/or building-cleaning services. This revision supports only the certificate-backed §13b(2) construction path and keeps missing/unknown/inconsistent facts fail-closed: [UStG §3a(2)](https://www.gesetze-im-internet.de/ustg_1980/__3a.html), [UStG §13b(1), (2), (5), and (7)](https://www.gesetze-im-internet.de/ustg_1980/__13b.html), [BMF USt 1 TG form](https://www.bundesfinanzministerium.de/Content/DE/Downloads/BMF_Schreiben/Steuerarten/Umsatzsteuer/2026-04-10-bescheinigung-USt-1-TG.pdf).
- Linux validator proof on 2026-10-16 (manual, outside the app): KoSIT validator 1.6.3 standalone jar (`37cddce`, sha256 `799e64be…7a7c9`) plus configuration v2026-08-31 (`b436fc4`, sha256 `2530cd10…f01221a8`) runs on Linux Java 17. Serializer sample UBL reaches Schema Y; Schematron still rejects 3 rules: missing seller electronic address (PEPPOL-EN16931-R020), missing buyer electronic address (R010), and missing payment instructions BG-16 (BR-DE-1). Fixed during the run: seller VAT identifier (BR-S-02) and business process ProfileID (R001). Endpoint-ID sourcing is implemented (seller VAT/9930, buyer email/EM else buyerReference/0204); official re-run passes R020/R010. BR-DE-1 payment is fixed via company IBAN (BT-81 58 plus BG-17 account); official re-run passes it. Remaining: BR-DE-TMP-32 delivery date/period at information level (no Leistungsdatum model; needs sourcing decision). Round 5 APPROVE covers the payment delta; its 4 follow-ups are closed in this cycle: spec scenario rewritten around absent IBAN, design/proposal synced to IBAN sourcing, positive emit test added, company IBAN write path added (normalize map plus settings field with setup IBAN validation). Windows/macOS runs remain blocked with no runners identified.
- Tax evidence remains absent from persisted invoice positions: they store `ust_satz` but no typed treatment, legal basis, EN category, or exemption reason. This revision adds explicit v26 persistence for each listed §13b eligibility fact and separate red success/failure tests for the §13b(1) and §13b(2) paths. The design records the named S/Z/E/AE/K/G mappings and official sources; generic §4/§13b cases and legacy rows remain fail-closed. §25a stays unresolved and blocked because the category/reason pair and amount relationship have no accepted decision. Official guidance says tax codes serialize a treatment decision but do not make it: [EC tax-code guidance](https://ec.europa.eu/digital-building-blocks/sites/download/attachments/467108974/eInvoicing%20technical%20guidance%20document_v1.pdf?api=v2&modificationDate=1721117125403&version=2), [XRechnung 3.0.2 specification](https://xeinkauf.de/app/uploads/2024/07/302-XRechnung-2024-06-20.pdf), [XStandards UStG mapping](https://xeinkauf.de/xrechnung/ustg/).
- No packaged validator assets are present in the local application workspace. The prior Linux manual validator evidence was outside the app and does not prove package integration; Windows/macOS validator proof remains absent.
- Earlier full-suite evidence in the prior checkpoint was 1,712 passed and 30 failed on commit `9ed436e`; all suite and analyzer results in this file are historical evidence from earlier implementation checkpoints, not current proof for this spec-only revision.

### Review Integrity

- [x] Round 7 `review.md` records `VERDICT: REVISE` for checkpoint `969cfa605ffddb1bf2fbd9a104fb18d544d62a36`; its finding is the missing §13b eligibility evidence. This repair leaves reviewer-owned `review.md` unchanged.
- [ ] Proposal, design, and specs have a fresh independent review after this contract revision
- [x] `review.md` has not been updated to claim approval of this revised tax contract

### Change Delivery

- Delivery state: scoped local spec-only commit on the isolated branch; no task implementation, schema, or migration changes were made. This remains partial and not independently reviewed.

## Overall Decision

DECISION: FAIL
