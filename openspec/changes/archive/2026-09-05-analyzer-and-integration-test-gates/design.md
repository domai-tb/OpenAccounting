# Design: Restore trustworthy static analysis and application-level test gates

## Context

fvm flutter analyze exits non-zero with 255 diagnostics, including deprecated lint configuration and unused production code. The suite can report all tests passing while dashboard providers log LateInitializationError, route tests assert placeholder text, and shortcut/update tests replace the production services with local fakes.

## Goals

Green checks mean the shipped code is clean and the application composition works.

## Non-Goals

Building a full CI platform; this change defines local/release gates and leaves workflow hosting explicit.

## Decisions

Treat analyzer zero and production-composition integration tests as required gates; preserve domain unit tests but label helper/fake-only tests as non-release evidence.

## Risks / Trade-offs

Cleaning all 255 diagnostics can create broad formatting/import churn; keep behavior changes separate and review lint-only commits.

## Migration Plan

Add red composition/runtime tests, clean analyzer findings, replace false-green helpers, then document the exact release commands.

## Open Questions

Should the project add a GitHub Actions Flutter analyze/test workflow alongside the existing wiki workflow?
