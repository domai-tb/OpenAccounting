import 'package:flutter/material.dart';
import 'package:openaccounting/design_system/components/app_sidebar.dart';

/// Desktop shell per DESIGN §3 — sidebar + header/canvas split, not black Container.
/// 240 px expanded ≥1200, 72 px rail 900–1199, drawer <900 via LayoutBuilder.
class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  bool _isSelected(String path) {
    if (path == '/') return location == '/';
    return location.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width >= 900 && width < 1200;
        final isDrawer = width < 900;
        final sidebarWidth = isCompact ? 72.0 : 240.0;
        final sidebar = AppSidebar(isCompact: isCompact, selectedPath: location, isSelected: _isSelected);
        if (isDrawer) {
          return Scaffold(
            appBar: AppBar(title: const Text('OpenAccounting')),
            drawer: Drawer(child: sidebar),
            body: child,
          );
        }
        return Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(
                width: sidebarWidth,
                child: Material(color: Theme.of(context).colorScheme.surface, child: sidebar),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
