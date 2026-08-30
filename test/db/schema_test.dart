import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:openaccounting/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Initialize the database in memory for testing
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() {
    db.close();
  });

  test('money columns should use NUMERIC(12,2) precision', () async {
    // SQLite stores the declared type in PRAGMA table_info.
    // We verify that the total_amount column in the invoices table is defined as NUMERIC(12,2).
    final results = await db.customSelect('PRAGMA table_info(invoices)').get();

    final totalAmountCol = results.firstWhere(
      (row) => row.column0 == 'total_amount',
      orElse: () => throw Exception('Column total_amount not found in invoices table'),
    );

    final type = totalAmountCol.column1 as String;

    expect(
      type,
      contains('NUMERIC(12,2)'),
      reason: 'Money columns must use NUMERIC(12,2) for financial precision and GoBD compliance',
    );
  });

  test('vk_netto should use NUMERIC(12,4) precision', () async {
    // We verify that the vk_netto column in the invoice_items table is defined as NUMERIC(12,4).
    final results = await db.customSelect('PRAGMA table_info(invoice_items)').get();

    final vkNettoCol = results.firstWhere(
      (row) => row.column0 == 'vk_netto',
      orElse: () => throw Exception('Column vk_netto not found in invoice_items table'),
    );

    final type = vkNettoCol.column1 as String;

    expect(
      type,
      contains('NUMERIC(12,4)'),
      reason: 'Unit prices (vk_netto) must use NUMERIC(12,4) to prevent rounding errors in calculations',
    );
  });
}
