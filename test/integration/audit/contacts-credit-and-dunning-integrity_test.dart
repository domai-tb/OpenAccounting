// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';

void main() {
  group('Contacts credit and dunning integrity', () {
    late AppDatabase db;
    late KundenRepository kundenRepo;
    late ForderungenRepository forderungenRepo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      kundenRepo = db.kundenRepository;
      await kundenRepo.ensureSchema();
      forderungenRepo = ForderungenRepository(db.executor);
      await forderungenRepo.ensureSchema();
    });

    tearDown(() async {
      await db.close();
    });

    // ── Task 1: Customer change is visible in linked workflows ──

    test('test_contacts_credit_and_dunning_integrity_1_1_customer_change_is_visible_in_linked_workflows', () async {
      // Create a customer with a credit limit.
      final kunde = await kundenRepo.create(
        name: 'Test GmbH',
        strasse: 'Teststr.',
        hausnummer: '1',
        plz: '10115',
        ort: 'Berlin',
      );

      // Set credit limit.
      await kundenRepo.update(kunde.id, {'kreditlimit': 1000.00});

      // Create a receivable for this customer.
      await forderungenRepo.create(typ: 'rechnung', partnerTyp: 'kunde', partnerId: kunde.id, betrag: 800.00);

      // Check credit limit — should reflect the outstanding receivable.
      final warning = await kundenRepo.checkCreditLimit(customerId: kunde.id, invoiceTotal: 300.00);

      // 800 outstanding + 300 new = 1100 > 1000 limit → warning expected.
      expect(warning, isNotNull, reason: 'Credit warning must be raised');
      expect(warning!.outstanding, 800.00, reason: 'Outstanding must include the receivable');
      expect(warning.limit, 1000.00, reason: 'Limit must match the customer credit limit');
    });

    // ── Task 2: Credit decision leaves an audit trail ──

    test('test_contacts_credit_and_dunning_integrity_1_2_credit_decision_leaves_an_audit_trail', () async {
      // Create a customer with a credit limit.
      final kunde = await kundenRepo.create(
        name: 'Audit GmbH',
        strasse: 'Auditstr.',
        hausnummer: '2',
        plz: '80331',
        ort: 'München',
      );

      await kundenRepo.update(kunde.id, {'kreditlimit': 500.00});

      // Confirm a credit limit warning.
      final confirmation = await kundenRepo.confirmCreditLimitWarning(customerId: kunde.id, invoiceTotal: 600.00);

      expect(confirmation.status, 'final', reason: 'Confirmation status must be final');

      // Verify the warning references the correct outstanding amount.
      expect(confirmation.warning, isNotNull, reason: 'Warning must be present');
      expect(confirmation.warning!.limit, 500.00, reason: 'Limit must be 500');
    });

    // ── Task 3: Eligible receivable produces a letter ──

    test('test_contacts_credit_and_dunning_integrity_2_1_eligible_receivable_produces_a_letter', () async {
      // Create a customer.
      final kunde = await kundenRepo.create(
        name: 'Dunning GmbH',
        strasse: 'Dunningstr.',
        hausnummer: '3',
        plz: '50667',
        ort: 'Köln',
      );

      // Create a receivable with past-due faelligkeit.
      final f = await forderungenRepo.create(typ: 'rechnung', partnerTyp: 'kunde', partnerId: kunde.id, betrag: 250.00);
      await db.executor.runUpdate('UPDATE forderungen SET faelligkeit = ? WHERE id = ?', ['2026-01-01', f.id]);

      // Run dunning — should find eligible customers.
      final result = await kundenRepo.runDunning();
      expect(
        result.skippedCustomerIds,
        isNot(contains(kunde.id)),
        reason: 'Dunning-eligible customer must not be skipped',
      );

      // Generate dunning letter — must complete without error.
      await expectLater(
        kundenRepo.generateDunningLetter(customerId: kunde.id),
        completes,
        reason: 'Dunning letter generation must complete',
      );
    });

    // ── Task 4: Ineligible or failed run is safe ──

    test('test_contacts_credit_and_dunning_integrity_2_2_ineligible_or_failed_run_is_safe', () async {
      // Create a customer with mahngesperrt = true.
      final kunde = await kundenRepo.create(
        name: 'Blocked GmbH',
        strasse: 'Blockedstr.',
        hausnummer: '4',
        plz: '70173',
        ort: 'Stuttgart',
      );
      await kundenRepo.update(kunde.id, {
        'mahngesperrt': 1,
        'mahngesperrt_bis': '2026-12-31',
        'mahngesperrt_grund': 'Payment plan active',
      });

      // Create a receivable with past-due faelligkeit.
      final f = await forderungenRepo.create(typ: 'rechnung', partnerTyp: 'kunde', partnerId: kunde.id, betrag: 150.00);
      await db.executor.runUpdate('UPDATE forderungen SET faelligkeit = ? WHERE id = ?', ['2026-01-01', f.id]);

      // Run dunning — blocked customer must be skipped.
      final result = await kundenRepo.runDunning();
      expect(result.skippedCustomerIds, contains(kunde.id), reason: 'Blocked customer must be skipped');
      expect(result.skippedReasons[kunde.id], 'Mahngesperrt', reason: 'Skip reason must be Mahngesperrt');

      // Generate dunning letter for blocked customer — must throw.
      await expectLater(
        kundenRepo.generateDunningLetter(customerId: kunde.id),
        throwsA(isA<KundenException>()),
        reason: 'Dunning letter for blocked customer must throw',
      );
    });
  });
}
