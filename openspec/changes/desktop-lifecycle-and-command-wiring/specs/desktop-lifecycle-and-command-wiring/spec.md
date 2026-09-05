## ADDED Requirements

### Requirement: Window state has one lifecycle owner

The desktop application MUST persist and restore one canonical window-state format across resize, move, maximize, close-to-tray, and restart, enforce the resolved minimum size, and recover off-screen bounds.

Implementation evidence: Main uses window_bounds while WindowStateService uses individual keys; saveCurrent has no production caller and the specs disagree on minimum size.

#### Scenario: Window state survives restart

- Given the user resizes, moves, or maximizes the window and closes normally
- When the app restarts
- Then the same valid state is restored from the canonical keys

#### Scenario: Invalid/off-screen state is repaired

- Given stored bounds are below minimum or outside all monitors
- When startup restores them
- Then the app clamps/recenters them and persists the repaired state without an unusable window

### Requirement: Commands and shortcuts invoke real intents

All documented keyboard and tray commands MUST be registered through the production service, respect focus/guard rules, invoke non-empty callbacks, and target valid route intents such as invoice creation.

Implementation evidence: The test defines its own shortcut helper, production registers only a subset with empty callbacks, and /invoices/new is not a valid creation route.

#### Scenario: Shortcut opens the intended workflow

- Given the app is focused on a normal page
- When the user invokes new invoice, search, save, or command-palette shortcuts
- Then the production command handler runs exactly once and opens or performs the intended action

#### Scenario: Shortcut is guarded in text input

- Given a text field owns focus
- When a global shortcut would interfere
- Then the command is not invoked unless explicitly allowed and no text is lost

### Requirement: Updater verifies and installs authentic releases

The updater MUST download to a controlled location, verify an actual Ed25519 signature against trusted metadata, reject tampered artifacts, invoke the platform install operation, and schedule the documented retry interval.

Implementation evidence: Production download/install are empty, signature verification accepts only valid, and install calls checkForUpdates.

#### Scenario: Authentic update installs

- Given a signed release is available and its artifact downloads successfully
- When the user confirms installation
- Then signature verification succeeds, the artifact is persisted, and the platform installer is invoked

#### Scenario: Tampering or failure is rejected

- Given a signature, download, or install step fails
- When the updater runs
- Then no unverified artifact is installed, the failure is visible, and retry follows the configured schedule
