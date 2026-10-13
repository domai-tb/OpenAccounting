## 1. Draft editor

- [x] 1.1 Write failing test `test_invoice_draft_multiple_positions_round_trip` (assert it fails for the right reason)
- [x] 1.2 Implement editable multi-position draft persistence and ordering to pass 1.1
- [x] 1.3 Refactor draft editor and persistence; full suite stays green
- [x] 1.4 Write failing test `test_rejected_draft_edit_preserves_saved_values` (assert it fails for the right reason)
- [x] 1.5 Implement rejected-edit preservation and field feedback to pass 1.4
- [x] 1.6 Refactor validation feedback; full suite stays green

## 2. Authoritative preview

- [x] 2.1 Write failing test `test_preview_result_is_shared_by_editor_and_document_preview` (assert it fails for the right reason)
- [x] 2.2 Implement display of one authoritative preview result in editor and document preview to pass 2.1
- [x] 2.3 Refactor preview state flow; full suite stays green
- [x] 2.4 Write failing test `test_invalid_preview_does_not_present_stale_totals` (assert it fails for the right reason)
- [x] 2.5 Implement stale-total invalidation and localized validation state to pass 2.4
- [x] 2.6 Refactor preview failure handling; full suite stays green

## 3. Lifecycle actions

- [x] 3.1 Write failing test `test_eligible_credit_note_invokes_use_case_once` (assert it fails for the right reason)
- [x] 3.2 Implement eligible Gutschrift action with omitted date and positions to pass 3.1
- [x] 3.3 Refactor correction action flow; full suite stays green
- [x] 3.4 Write failing test `test_storno_invokes_use_case_with_trimmed_reason` (assert it fails for the right reason)
- [x] 3.5 Implement Storno reason collection and trimmed use-case call to pass 3.4
- [x] 3.6 Refactor Storno action flow; full suite stays green
- [x] 3.7 Write failing test `test_eligible_storno_offers_replacement_action` (assert it fails for the right reason)
- [x] 3.8 Implement eligible replacement action and reciprocal refresh to pass 3.7
- [x] 3.9 Refactor replacement action flow; full suite stays green
- [x] 3.10 Write failing test `test_permitted_conversion_requires_confirmation` (assert it fails for the right reason)
- [x] 3.11 Implement confirmed supported conversion action to pass 3.10
- [x] 3.12 Refactor conversion action flow; full suite stays green
- [x] 3.13 Write failing test `test_lifecycle_action_revalidates_state_before_writes` (assert it fails for the right reason)
- [x] 3.14 Implement transactional state revalidation before side effects to pass 3.13
- [x] 3.15 Refactor lifecycle guards; full suite stays green
- [x] 3.16 Write failing test `test_blank_storno_reason_is_rejected_before_use_case` (assert it fails for the right reason)
- [x] 3.17 Implement required localized Storno reason validation to pass 3.16
- [x] 3.18 Refactor reason validation; full suite stays green
- [x] 3.19 Write failing test `test_finalization_confirms_with_active_locale` (assert it fails for the right reason)
- [x] 3.20 Implement finalization confirmation and active-locale use-case call to pass 3.19
- [x] 3.21 Refactor finalization confirmation; full suite stays green
- [x] 3.22 Write failing test `test_cancelled_finalization_preserves_editable_draft` (assert it fails for the right reason)
- [x] 3.23 Implement cancellation with no number or lifecycle side effects to pass 3.22
- [x] 3.24 Refactor cancellation handling; full suite stays green
- [x] 3.25 Write failing test `test_ineligible_document_cannot_be_finalized` (assert it fails for the right reason)
- [x] 3.26 Implement disabled and use-case-rejected ineligible finalization to pass 3.25
- [x] 3.27 Refactor eligibility presentation; full suite stays green
- [x] 3.28 Write failing test `test_correction_actions_wait_for_artifact_transaction` (assert it fails for the right reason)
- [x] 3.29 Implement correction-action gating on the artifact transaction prerequisite to pass 3.28
- [x] 3.30 Refactor prerequisite gating; full suite stays green
- [x] 3.31 Write failing test `test_invalid_preview_blocks_finalization_confirmation` (assert it fails for the right reason)
- [x] 3.32 Implement preview validation gate before finalization confirmation to pass 3.31
- [x] 3.33 Refactor finalization guards; full suite stays green

## 4. Lifecycle relationships

- [x] 4.1 Write failing test `test_detail_shows_reciprocal_lifecycle_relationships` (assert it fails for the right reason)
- [x] 4.2 Implement typed reciprocal relationship projections and navigable links to pass 4.1
- [x] 4.3 Refactor relationship loading; full suite stays green
- [x] 4.4 Write failing test `test_missing_relationship_target_is_unavailable` (assert it fails for the right reason)
- [x] 4.5 Implement explicit missing-target state without a fabricated document to pass 4.4
- [x] 4.6 Refactor relationship error state; full suite stays green

## 5. Responsive and accessible workspace

- [x] 5.1 Write failing test `test_desktop_workspace_shows_editor_and_preview` (assert it fails for the right reason)
- [x] 5.2 Implement desktop editor and preview layout with localized accessible labels to pass 5.1
- [x] 5.3 Refactor desktop layout; full suite stays green
- [x] 5.4 Write failing test `test_narrow_german_workspace_has_tabs_without_overflow` (assert it fails for the right reason)
- [x] 5.5 Implement narrow-window tabs, text expansion, keyboard navigation, visible focus, and reachable actions to pass 5.4
- [x] 5.6 Refactor responsive and focus behavior; full suite stays green
