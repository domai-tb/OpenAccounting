# Proposal: Bring shared desktop surfaces into the design and accessibility contract

## Why

The compact sidebar keeps full local-status text and does not bottom-pin Settings/Help, headers render inert search/filter controls on placeholders, monetary values can ellipsize or bypass privacy formatting, inspectors lack closed focus traversal, status chips advertise buttons without keyboard activation, and generic dialogs/error states are not action-specific.

Evidence: lib/design_system/components/app_sidebar.dart:66-139; app_page_header.dart:22 and :124-194; app_money.dart:45-54; app_inspector.dart:36; app_status_chip.dart:153-176; app_dialog.dart:20-44; dashboard_page.dart:54 and :234; dashboard_widgets.dart:112.

## What Changes

- Implement responsive sidebar/header/filter behavior at the documented breakpoints.
- Make financial display/privacy and keyboard/accessibility semantics consistent across shared components.
- Make dialogs, empty/error/loading states, and dashboard cards explicit and actionable.

## Capabilities

- Bring shared desktop surfaces into the design and accessibility contract
- Priority: Medium
- Dependencies: runtime-composition-and-database-lifecycle; localization-settings-and-data-protection; primary-workspace-exposure.

## Impact

lib/app/app_shell.dart, design_system components, dashboard surfaces, localization keys, and widget/accessibility tests.
