# Design: Restore strict validation contract

## Context

Fifteen maintained specifications fail `openspec validate --specs --strict` because they lack `## Purpose` sections and use `## ADDED Requirements` instead of `## Requirements`. One spec (`stammdaten`) also has RFC 2119 keyword gaps and an over-long requirement.

## Goals / Non-Goals

**Goals:** All 25 maintained specs pass strict validation.

**Non-Goals:** Semantic reconciliation of conflicting specs (owned by other changes). Runtime behavior changes.

## Decisions

Edit each failing spec in-place: add a brief `## Purpose` section derived from the spec title and first requirement, replace `## ADDED Requirements` with `## Requirements`, and fix structural issues in `stammdaten`.

## Risks / Trade-offs

Purpose text is derived, not product-reviewed. It can be refined later without breaking validation.

## Migration Plan

Mechanical spec edits. No data migration, no code changes.

## Open Questions

None.
