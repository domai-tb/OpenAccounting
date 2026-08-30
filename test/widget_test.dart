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
    expect(find.text('OpenAccounting'), findsOneWidget);
    await db.close();
  });
}
