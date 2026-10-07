import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/app/app_drawer_scope.dart';
import 'package:openaccounting/app/sidebar_controller.dart';
import 'package:openaccounting/design_system/components/app_sidebar.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/features/desktop/desktop_shortcuts.dart';
import 'package:openaccounting/features/global_search/global_search_page.dart';

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
  bool _globalSearchShortcutAvailable = false;
  bool _globalSearchOpen = false;
  final GlobalKey<ScaffoldState> _drawerKey = GlobalKey<ScaffoldState>();
  late final DesktopShortcutsService _globalSearchShortcuts;

  @override
  void initState() {
    super.initState();
    _globalSearchShortcuts = ref.read(globalSearchShortcutServiceProvider);
    _globalSearchShortcuts.onGlobalSearch = _openGlobalSearchFromShortcut;
    unawaited(_registerGlobalSearchShortcut());
  }

  Future<void> _registerGlobalSearchShortcut() async {
    bool registered = false;
    try {
      registered = await _globalSearchShortcuts.registerGlobalSearch();
    } catch (_) {
      registered = false;
    }
    if (mounted) {
      setState(() => _globalSearchShortcutAvailable = registered);
    }
  }

  void _openGlobalSearchFromShortcut() {
    final BuildContext? focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return;
    }
    _showGlobalSearch();
  }

  void _showGlobalSearch() {
    if (!mounted || _globalSearchOpen) return;
    _globalSearchOpen = true;
    unawaited(
      showDialog<void>(context: context, builder: (_) => const GlobalSearchPage()).whenComplete(() {
        if (mounted) setState(() => _globalSearchOpen = false);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_globalSearchShortcuts.unregisterGlobalSearch());
    super.dispose();
  }

  bool _isSelected(String path) {
    if (path == '/') return widget.location == '/';
    return widget.location.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    assert(AppSpacing.lg == 16, 'tokens must be imported');
    final bool expanded = ref.watch(sidebarControllerProvider);
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final Duration animDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 250);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool isDrawer = width < 900;
        final bool isCompactByWidth = width >= 900 && width < 1200;

        if (isDrawer) {
          final AppSidebar sidebar = AppSidebar(
            isCompact: false,
            isSelected: _isSelected,
            onGlobalSearch: _showGlobalSearch,
            globalSearchShortcutAvailable: _globalSearchShortcutAvailable,
            onToggle: () {
              ref.read(sidebarControllerProvider.notifier).toggle();
            },
          );
          return Scaffold(
            key: _drawerKey,
            drawer: Drawer(child: sidebar),
            body: AppDrawerScope(openDrawer: () => _drawerKey.currentState?.openDrawer(), child: widget.child),
          );
        }

        if (isCompactByWidth) {
          final bool isCompact = !_tempExpanded;
          final double sidebarWidth = _tempExpanded ? 240.0 : 72.0;
          final AppSidebar sidebar = AppSidebar(
            isCompact: isCompact,
            isSelected: _isSelected,
            onGlobalSearch: _showGlobalSearch,
            globalSearchShortcutAvailable: _globalSearchShortcutAvailable,
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
                  child: AnimatedContainer(
                    duration: animDuration,
                    width: sidebarWidth,
                    child: Material(color: Theme.of(context).colorScheme.surface, child: sidebar),
                  ),
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
          onGlobalSearch: _showGlobalSearch,
          globalSearchShortcutAvailable: _globalSearchShortcutAvailable,
          onToggle: () {
            ref.read(sidebarControllerProvider.notifier).toggle();
          },
        );
        return Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(
                width: sidebarWidth,
                child: AnimatedContainer(
                  duration: animDuration,
                  width: sidebarWidth,
                  child: Material(color: Theme.of(context).colorScheme.surface, child: sidebar),
                ),
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
