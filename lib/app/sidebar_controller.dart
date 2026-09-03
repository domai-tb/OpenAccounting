import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sidebar expanded state persisted via SharedPreferences.
/// Key namespaced per DESIGN D2: openaccounting.sidebar_expanded.
class SidebarController extends Notifier<bool> {
  static const String key = 'openaccounting.sidebar_expanded';

  @override
  bool build() {
    Future.microtask(_load);
    return true;
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool? value = prefs.getBool(key);
      if (value != null) {
        state = value;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    final bool next = !state;
    state = next;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, next);
    } catch (_) {}
  }

  // ignore: avoid_positional_boolean_parameters
  Future<void> setExpanded(bool expanded) async {
    state = expanded;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, expanded);
    } catch (_) {}
  }
}

final NotifierProvider<SidebarController, bool> sidebarControllerProvider = NotifierProvider<SidebarController, bool>(
  SidebarController.new,
);
