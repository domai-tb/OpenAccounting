import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app.dart';
import 'package:openaccounting/core/database.dart';

void main() {
  testWidgets('app renders placeholder', (tester) async {
    final db = createTestDatabase();
    await db.ensureOpen();
    await tester.pumpWidget(
      ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const OpenAccountingApp()),
    );
    await tester.pumpAndSettle();
    // Batch 2: router with setup guard — empty DB shows Setup Wizard.
    expect(find.text('Setup Wizard'), findsOneWidget);
    await db.close();
  });

  testWidgets('app shows dashboard when configured', (tester) async {
    final db = createTestDatabase();
    await db.ensureOpen();
    await db.executor.runCustom('CREATE TABLE IF NOT EXISTS unternehmen (id INTEGER PRIMARY KEY, name TEXT)');
    await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test')");
    await tester.pumpWidget(
      ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db)], child: const OpenAccountingApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Übersicht'), findsOneWidget);
    await db.close();
  });
}
