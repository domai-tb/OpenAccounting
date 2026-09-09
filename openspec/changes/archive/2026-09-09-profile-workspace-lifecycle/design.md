# Design: Connect profile management to startup and the workspace UI

## Context

ProfileManager can list/create/rename profiles but deleteProfile performs no deletion. Startup selects one profile directly, ProfileSelectionService returns hard-coded test-path data, and the setup/sidebar selection callbacks are no-ops. Switching therefore cannot reliably change the active database in a running or restarted app.

## Goals

Profiles are real isolated workspaces rather than display-only labels.

## Non-Goals

Cloud synchronization or multi-user permissions.

## Decisions

Use ProfileManager as the sole durable profile authority and make switching an application-graph transition, not a stale pointer write.

## Risks / Trade-offs

Switching databases while routes are active can expose stale providers; invalidate the graph and route state as one operation.

## Migration Plan

Add lifecycle service and CRUD tests, wire startup selection, then connect sidebar/settings and remove test-only selection branches.

## Open Questions

Should profile deletion remove the database bytes immediately or retain an explicit recoverable archive?
