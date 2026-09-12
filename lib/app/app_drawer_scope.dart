import 'package:flutter/widgets.dart';

/// Provides the shell drawer opener to page headers when the window is narrow.
///
/// The shell owns the drawer while each destination owns its own app bar. This
/// keeps one visible header and still gives every destination a reliable menu
/// affordance in drawer mode.
class AppDrawerScope extends InheritedWidget {
  const AppDrawerScope({required this.openDrawer, required super.child, super.key});

  final VoidCallback openDrawer;

  static AppDrawerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppDrawerScope>();
  }

  @override
  bool updateShouldNotify(AppDrawerScope oldWidget) => false;
}
