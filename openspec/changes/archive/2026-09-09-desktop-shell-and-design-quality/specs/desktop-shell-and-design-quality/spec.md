## ADDED Requirements

### Requirement: Responsive shell controls are context-appropriate

At each documented width breakpoint, the shell MUST use the correct sidebar mode, bottom-pin secondary navigation, and render search/filter/header controls only when backed by an actionable page contract.

Implementation evidence: The compact rail retains local-status text, Settings/Help are ordinary list children, and AppPageHeader enables inert controls by default.

#### Scenario: Breakpoints preserve usable navigation

- Given the window is rendered at 900, 1024, 1199, and 1280 pixels
- When the shell lays out
- Then sidebar widths/modes, tooltips, secondary-item placement, and content constraints match the design without overflow

#### Scenario: A page without filters has no inert toolbar

- Given a page does not provide search/filter callbacks
- When its header renders
- Then the corresponding controls are omitted or disabled with an explanatory state rather than appearing actionable

### Requirement: Financial and interactive components are accessible

Money display MUST not truncate meaningful financial values, privacy masking MUST use the active currency/settings, and every control advertised as interactive MUST support keyboard activation and focus traversal including inspector focus return.

Implementation evidence: MoneyText uses ellipsis and hardcodes EUR masking; dashboard bypasses it; status chip uses button semantics without Enter/Space; inspector lacks closed traversal/restoration.

#### Scenario: Long and private amounts remain legible

- Given a long amount, non-EUR currency, and privacy mode are rendered
- When the shared component displays them
- Then the value remains readable or wraps predictably, uses the correct currency, and masks consistently across surfaces

#### Scenario: Keyboard focus completes the interaction

- Given the inspector or status chip has focus
- When the user tabs/presses Enter/Space/Esc
- Then focus stays within the intended loop, activates the control, or returns to the invoking control as specified

### Requirement: Dialogs and page states explain the next action

Destructive dialogs and loading/empty/error states MUST name the operation, affected data, consequence, and recovery action with appropriate semantic styling; raw host details and generic one-line errors MUST not be the only guidance.

Implementation evidence: Generic confirmation defaults to Löschen, dashboard errors collapse to Fehler beim Laden, and empty states lack action guidance.

#### Scenario: Destructive confirmation is specific

- Given the user attempts delete, archive, or a non-destructive confirmation
- When the dialog opens
- Then copy, button emphasis, affected-record summary, and irreversible warning match that operation

#### Scenario: Failure and empty state are actionable

- Given a data source fails or returns no records
- When the page renders the state
- Then the user sees what is affected and can retry, configure, create, or open help without raw infrastructure leakage
