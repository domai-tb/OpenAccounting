import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/app/sidebar_controller.dart';
import 'package:openaccounting/design_system/components/app_sidebar.dart';

/// Desktop shell per DESIGN §3 — sidebar + header/canvas split, not black Container.
/// 240 px expanded ≥1200, 72 px rail 900–1199, drawer <900 via LayoutBuilder.
/// Persisted expanded respected only at ≥1200 per D2; 900–1199 is temporary expand.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _tempExpanded = false;

  bool _isSelected(String path) {
    if (path == '/') return widget.location == '/';
    return widget.location.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    final bool expanded = ref.watch(sidebarControllerProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool isDrawer = width < 900;
        final bool isCompactByWidth = width >= 900 && width < 1200;

        if (isDrawer) {
          final AppSidebar sidebar = AppSidebar(
            isCompact: false,
            isSelected: _isSelected,
            onToggle: () {
              ref.read(sidebarControllerProvider.notifier).toggle();
            },
          );
          return Scaffold(
            appBar: AppBar(title: const Text('OpenAccounting')),
            drawer: Drawer(child: sidebar),
            body: widget.child,
          );
        }

        if (isCompactByWidth) {
          final bool isCompact = !_tempExpanded;
          final double sidebarWidth = _tempExpanded ? 240.0 : 72.0;
          final AppSidebar sidebar = AppSidebar(
            isCompact: isCompact,
            isSelected: _isSelected,
            onToggle: () {
              setState(() {
                _tempExpanded = !_tempExpanded;
              });
            },
          );
          return Scaffold(
            body: Row(
              children: <Widget>[
                SizedBox(
                  width: sidebarWidth,
                  child: Material(color: Theme.of(context).colorScheme.surface, child: sidebar),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: widget.child),
              ],
            ),
          );
        }

        final bool isCompact = !expanded;
        final double sidebarWidth = expanded ? 240.0 : 72.0;
        final AppSidebar sidebar = AppSidebar(
          isCompact: isCompact,
          isSelected: _isSelected,
          onToggle: () {
            ref.read(sidebarControllerProvider.notifier).toggle();
          },
        );
        return Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(
                width: sidebarWidth,
                child: Material(color: Theme.of(context).colorScheme.surface, child: sidebar),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}
