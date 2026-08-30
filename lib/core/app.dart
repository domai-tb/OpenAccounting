import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Root app widget with Material3 seed #4F46E5, GoRouter, System/light/dark.
/// Locale de-DE with Du-Ansprache per DESIGN §23.
class OpenAccountingApp extends ConsumerWidget {
  const OpenAccountingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'OpenAccounting',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
