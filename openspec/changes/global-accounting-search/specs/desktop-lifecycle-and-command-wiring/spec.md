## ADDED Requirements

### Requirement: Global search shortcut has one production intent

The desktop command registry SHALL bind `Ctrl+K` on Windows/Linux and `Cmd+K` on macOS to the global search palette. The intent SHALL be registered through the production shortcut service, invoke the palette exactly once, and respect text-input focus rules without stealing typed characters.

#### Scenario: Global search shortcut opens the palette
- **GIVEN** a normal application page has focus
- **WHEN** the user invokes the platform's global search shortcut
- **THEN** the registered global-search intent SHALL open the palette exactly once

#### Scenario: Shortcut does not consume text input
- **GIVEN** a text editor owns focus and the platform shortcut conflicts with text entry
- **WHEN** the user invokes the shortcut
- **THEN** the command SHALL follow the documented focus guard and SHALL NOT discard or alter text

#### Scenario: Shortcut registration is unavailable
- **GIVEN** the shortcut cannot be registered on the current platform
- **WHEN** desktop commands initialize
- **THEN** the application SHALL keep the visible search entry point usable and report the registration failure without claiming the shortcut is active
