import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';

Future<AppDatabase> _configuredDb() async {
  final db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
  return db;
}

Widget _wrap(GoRouter router, AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('test_desktop_workspace_shows_editor_and_preview', (WidgetTester tester) async {
    final db = await _configuredDb();
    addTearDown(db.close);
    final router = createRouter(db);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(router, db));
    await tester.pumpAndSettle();
    router.go('/invoices/new');
    await tester.pumpAndSettle();

    // Editor and preview are both visible in the same workspace.
    expect(find.text('Position hinzufügen'), findsOneWidget);
    expect(find.text('Vorschau'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('workspace_save')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace_preview_total')), findsOneWidget);
    // All controls carry localized accessible labels.
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel('Position hinzufügen'), findsWidgets);
    } finally {
      handle.dispose();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_narrow_german_workspace_has_tabs_without_overflow', (WidgetTester tester) async {
    final db = await _configuredDb();
    addTearDown(db.close);
    final router = createRouter(db);
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(router, db));
    await tester.pumpAndSettle();
    router.go('/invoices/new');
    await tester.pumpAndSettle();

    // Each panel is reachable through a localized tab.
    expect(find.text('Bearbeiten'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace_tab_preview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('workspace_tab_preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('workspace_preview_total')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('workspace_tab_editor')));
    await tester.pumpAndSettle();

    // No horizontal overflow; draft and lifecycle actions stay reachable.
    expect(find.text('Position hinzufügen'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace_save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
