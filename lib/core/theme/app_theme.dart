import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN §7 seed #4F46E5, §8 Theme Behavior, §10 radius/borders.
abstract final class AppTheme {
  static const seed = Color(0xFF4F46E5);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      brightness: Brightness.light,
      fontFamily: 'Inter',
      extensions: const <ThemeExtension<dynamic>>[AccountingColors.light],
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: Color(0xFFE1E4E8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF17181C),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        filled: false,
      ),
      textTheme: _textTheme(Brightness.light),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF101217),
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      extensions: const <ThemeExtension<dynamic>>[AccountingColors.dark],
      cardTheme: CardThemeData(
        color: const Color(0xFF171A21),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: Color(0xFF2B3039)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF171A21),
        foregroundColor: Color(0xFFF1F2F4),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
        filled: false,
      ),
      textTheme: _textTheme(Brightness.dark),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    // Inter fallback to system sans-serif; keep quiet dense scale per §9.
    final base = brightness == Brightness.light ? Typography.blackMountainView : Typography.whiteMountainView;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w400),
      labelSmall: base.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
    );
  }
}

/// DESIGN §42 tokens — spacing, radius, duration.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadius {
  static const double control = 8;
  static const double card = 12;
  static const double menu = 10;
  static const double dialog = 14;
}

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 240);
}

/// ThemeMode persistence via SharedPreferences.
/// Immediate apply (state update) + async persistence; tolerates prefs failure.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() {
    // ponytail: immediate apply + async persistence — return system synchronously
    // to avoid blocking build; microtask loads saved mode without flash beyond
    // one frame if saved != system (AsyncNotifier would need loading state).
    Future.microtask(_loadAsync);
    return ThemeMode.system;
  }

  Future<void> _loadAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        state = ThemeMode.values.firstWhere((e) => e.name == raw, orElse: () => ThemeMode.system);
      }
    } catch (_) {
      // ponytail: corrupted prefs → keep default, no crash per spec.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // ponytail: persistence failure → current session keeps mode, no crash.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
