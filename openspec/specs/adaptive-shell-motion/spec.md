# adaptive-shell-motion Specification

## Purpose
TBD - created by archiving change adaptive-shell-and-state-surfaces. Update Purpose after archive.

## Requirements

### Requirement: Width-aware shell motion

The shell SHALL choose drawer below 900 logical pixels, a 72 logical pixel centered rail from 900 through 1199, and a 240 logical pixel sidebar at 1200 or wider. Transitions SHALL complete within 250 ms, preserve the current route, and bypass motion when either `MediaQuery.disableAnimations` or the persisted reduced-motion preference is enabled.

#### Scenario: Rail expands without route loss
- **GIVEN** the active route is `/invoices` at 1024 logical pixels
- **WHEN** the window grows to 1280 logical pixels
- **THEN** the rail SHALL animate to 240 logical pixels, labels SHALL appear, and `/invoices` SHALL remain selected

#### Scenario: Breakpoint edges preserve route and filters
- **GIVEN** the active route is `/invoices?status=open` and the window is resized through 899, 900, 1199, and 1200 logical pixels
- **WHEN** each resize settles
- **THEN** the drawer/rail/sidebar widths SHALL be respectively selected at each boundary, the route and query SHALL be unchanged, and no content SHALL overflow

#### Scenario: Reduced motion bypasses animation
- **GIVEN** reduced motion is enabled
- **WHEN** the window crosses a shell breakpoint
- **THEN** the final layout SHALL apply without an animation and SHALL not duplicate or clip content

### Requirement: Stable persisted navigation lifecycle

The shell SHALL hydrate sidebar preference before the first rendered frame, center compact controls in 72 logical pixel hit targets, keep secondary actions bottom-pinned within the available height, and close the drawer after navigation. Preference read/write failures SHALL preserve the last confirmed state and expose a retryable localized message.

#### Scenario: Persisted compact state is first-frame stable
- **GIVEN** the stored sidebar preference is compact
- **WHEN** the app starts
- **THEN** the first shell frame SHALL use the 72 logical pixel rail without an expanded flash

#### Scenario: Invalid preference uses safe default
- **GIVEN** the stored preference is missing or invalid
- **WHEN** the app starts
- **THEN** the shell SHALL render the documented expanded default and remain usable without an exception

#### Scenario: Drawer navigation closes and preserves focus
- **GIVEN** a 320 logical pixel drawer is open and keyboard focus is on a destination
- **WHEN** the destination is activated with Enter or Space
- **THEN** the route SHALL change, the drawer SHALL close, the destination hit target SHALL remain at least 72 by 48 logical pixels, and focus SHALL move to the route heading

#### Scenario: Preference write failure is recoverable
- **GIVEN** a user changes the sidebar preference and the preference adapter fails to write
- **WHEN** the write completes with an error
- **THEN** the rendered preference SHALL stay at the last confirmed value, a localized retry action SHALL be available, and route selection SHALL remain intact
