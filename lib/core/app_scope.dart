import 'package:flutter/widgets.dart';
import 'package:openaccounting/core/app_services.dart';

/// Composition boundary for pages that need application services.
///
/// The production root owns one [AppServices] instance for the selected
/// profile. Riverpod remains available for reactive providers and test
/// overrides, while pages can resolve long-lived services without constructing
/// repositories or raw database executors themselves.
class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppScope of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope must be provided above this context');
    return scope!;
  }

  static AppScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>();

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
