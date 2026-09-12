import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appLocalePreferenceKey = 'openaccounting.locale';

Locale parseAppLocale(String? raw) {
  return raw == 'en' ? const Locale('en') : const Locale('de');
}

/// Persists the language selected in Settings and applies it immediately.
class AppLocaleNotifier extends Notifier<Locale> {
  bool _selectionMade = false;

  @override
  Locale build() {
    Future<void>.microtask(_loadAsync);
    return const Locale('de');
  }

  Future<void> _loadAsync() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!_selectionMade) {
        state = parseAppLocale(prefs.getString(appLocalePreferenceKey));
      }
    } catch (_) {
      // Keep the German default when preferences are unavailable or corrupt.
    }
  }

  Future<void> setLocale(Locale locale) async {
    final Locale supported = parseAppLocale(locale.languageCode);
    _selectionMade = true;
    state = supported;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(appLocalePreferenceKey, supported.languageCode);
    } catch (_) {
      // The current session remains usable even when persistence fails.
    }
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(AppLocaleNotifier.new);
