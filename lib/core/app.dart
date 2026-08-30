import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root app widget. Batch 1: minimal MaterialApp.
/// Batch 2 will add Material 3 seed #4F46E5, GoRouter, themeMode.
// ponytail: no premature theming — keep lean until Batch 2 needs it.
class OpenAccountingApp extends ConsumerWidget {
  const OpenAccountingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'OpenAccounting',
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('OpenAccounting'))),
    );
  }
}
