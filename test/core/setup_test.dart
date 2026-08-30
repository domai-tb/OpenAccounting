import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/database.dart';

void main() {
  test('app creates database connection on startup', () async {
    final db = createTestDatabase();
    await db.ensureOpen();
    expect(db.isOpen, isTrue, reason: 'AppDatabase should be open after ensureOpen on startup');
    await db.close();
  });

  test('provider creates database instance', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(db.executor, isNotNull);
    await db.close();
  });
}
