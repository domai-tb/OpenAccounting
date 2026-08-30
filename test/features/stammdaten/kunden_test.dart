// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';

dynamic kundenRepository(AppDatabase db) {
  final dynamic database = db;
  return database.kundenRepository;
}

void main() {
  group('Kunden-Stammdaten', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    dynamic createCustomer(
      dynamic repository, {
      String anrede = 'Herr',
      required String name,
      String? firma = 'ACME GmbH',
      String strasse = 'Berliner Str.',
      String? hausnummer = '42',
      String plz = '10115',
      String ort = 'Berlin',
      String land = 'DE',
      String? ustIdNr = 'DE123456789',
      String? foreignTaxNumber,
      String? telefon = '+49 30 123456',
      String? email = 'info@acme.de',
      int zahlungsziel = 14,
      num skontoProzent = 3,
      int skontoTage = 10,
      num? kreditlimit,
      bool dunningBlocked = false,
      String? dunningBlockedUntil,
      String? dunningBlockedReason,
      bool zugferdAktiv = false,
      String? note = 'VIP-Kunde',
    }) {
      return repository.create(
        anrede: anrede,
        name: name,
        firma: firma,
        strasse: strasse,
        hausnummer: hausnummer,
        plz: plz,
        ort: ort,
        land: land,
        ustIdNr: ustIdNr,
        foreignTaxNumber: foreignTaxNumber,
        telefon: telefon,
        email: email,
        zahlungsziel: zahlungsziel,
        skontoProzent: skontoProzent,
        skontoTage: skontoTage,
        kreditlimit: kreditlimit,
        dunningBlocked: dunningBlocked,
        dunningBlockedUntil: dunningBlockedUntil,
        dunningBlockedReason: dunningBlockedReason,
        zugferdAktiv: zugferdAktiv,
        note: note,
      );
    }

    String errorMessage(Object error) {
      final dynamic candidate = error;
      try {
        return candidate.message as String;
      } on Object {
        return error.toString();
      }
    }

    Matcher exactError(String message) => throwsA(predicate<Object>((error) => errorMessage(error) == message));

    Future<void> setNextDebitorNumber(int number) async {
      // Arrange-only SQL fixture: configure the number range consumed by create.
      await db.executor.runCustom(
        "UPDATE nummernkreise SET format = '1####', naechste_nummer = ? WHERE typ = 'debitor'",
        <Object?>[number],
      );
    }

    Future<int> insertInvoiceReference({
      required int customerId,
      required String invoiceNumber,
      required num total,
      required String dueDate,
    }) async {
      // Arrange-only SQL fixture: finalized invoice with an open receivable.
      final invoiceId = await db.executor.runInsert(
        '''
INSERT INTO rechnungen (
  rechnungsnummer,
  typ,
  status,
  ist_entwurf,
  eingabemodus,
  kunde_id,
  datum,
  faelligkeit,
  brutto_betrag
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        <Object?>[invoiceNumber, 'rechnung', 'final', 0, 'netto', customerId, '2020-01-01', dueDate, total],
      );
      await db.executor.runCustom(
        '''
INSERT INTO forderungen (kunde_id, rechnung_id, betrag, status, faelligkeit)
VALUES (?, ?, ?, ?, ?)
''',
        <Object?>[customerId, invoiceId, total, 'offen', dueDate],
      );
      return invoiceId;
    }

    test('round-trips required and optional customer fields', () async {
      // Arrange: provide every required field and representative optional data.
      final repository = kundenRepository(db);
      final created = await createCustomer(
        repository,
        anrede: 'Frau',
        name: 'ACME GmbH',
        hausnummer: '42a',
        foreignTaxNumber: 'CHE-123.456.789 MWST',
        kreditlimit: 5000,
        dunningBlocked: true,
        dunningBlockedUntil: '2026-12-31',
        dunningBlockedReason: 'Streitfall',
        zugferdAktiv: true,
      );

      // Act: read the customer through its repository.
      final stored = await repository.findById(created.id);

      // Assert: required and optional fields survive the repository round-trip unchanged.
      expect(stored, isNotNull);
      expect(stored.id, created.id);
      expect(stored.debitorNr, isNotEmpty);
      expect(stored.anrede, 'Frau');
      expect(stored.name, 'ACME GmbH');
      expect(stored.firma, 'ACME GmbH');
      expect(stored.strasse, 'Berliner Str.');
      expect(stored.hausnummer, '42a');
      expect(stored.plz, '10115');
      expect(stored.ort, 'Berlin');
      expect(stored.land, 'DE');
      expect(stored.ustIdNr, 'DE123456789');
      expect(stored.foreignTaxNumber, 'CHE-123.456.789 MWST');
      expect(stored.telefon, '+49 30 123456');
      expect(stored.email, 'info@acme.de');
      expect(stored.zahlungsziel, 14);
      expect(stored.skontoProzent, 3);
      expect(stored.skontoTage, 10);
      expect(stored.kreditlimit, 5000);
      expect(stored.dunningBlocked, isTrue);
      expect(stored.dunningBlockedUntil, '2026-12-31');
      expect(stored.dunningBlockedReason, 'Streitfall');
      expect(stored.zugferdAktiv, isTrue);
      expect(stored.note, 'VIP-Kunde');
    });

    test('keeps omitted optional customer fields null', () async {
      // Arrange: create a valid customer while omitting nullable contact and tax fields.
      final repository = kundenRepository(db);
      final created = await createCustomer(
        repository,
        name: 'Nur Pflichtfelder',
        firma: null,
        hausnummer: null,
        ustIdNr: null,
        telefon: null,
        email: null,
        note: null,
      );

      // Act: fetch omitted optional values through the repository.
      final stored = await repository.findById(created.id);

      // Assert: omitted values remain null instead of being invented by the repository.
      expect(stored.firma, isNull);
      expect(stored.hausnummer, isNull);
      expect(stored.ustIdNr, isNull);
      expect(stored.foreignTaxNumber, isNull);
      expect(stored.telefon, isNull);
      expect(stored.email, isNull);
      expect(stored.kreditlimit, isNull);
      expect(stored.dunningBlockedUntil, isNull);
      expect(stored.dunningBlockedReason, isNull);
      expect(stored.note, isNull);
    });

    test('lists persisted customers', () async {
      // Arrange: create two customers through the repository.
      final repository = kundenRepository(db);
      await createCustomer(repository, name: 'Erster Kunde');
      await createCustomer(repository, name: 'Zweiter Kunde');

      // Act: load all customers through the repository.
      final customers = await repository.list();
      final names = customers.map((customer) => customer.name).toList();

      // Assert: list exposes every persisted customer.
      expect(names, containsAll(<String>['Erster Kunde', 'Zweiter Kunde']));
    });

    test('returns null for an unknown customer', () async {
      // Arrange: use an ID that is absent from the empty test database.
      final repository = kundenRepository(db);

      // Act: look up the unknown customer.
      final stored = await repository.findById(999999);

      // Assert: missing records are represented by null.
      expect(stored, isNull);
    });

    test('updates an existing customer and preserves its Debitor-Nr', () async {
      // Arrange: create a customer with an assigned Debitor-Nr.
      final repository = kundenRepository(db);
      final created = await createCustomer(repository, name: 'Alte Firma', email: 'alt@example.test');
      final originalDebitorNr = created.debitorNr;

      // Act: update mutable master-data fields through the repository.
      await repository.update(created.id, <String, dynamic>{
        'name': 'Neue Firma',
        'email': 'neu@example.test',
        'note': 'Aktualisiert',
        'kreditlimit': 7500,
      });
      final updated = await repository.findById(created.id);

      // Assert: update persists while the assigned Debitor-Nr remains stable.
      expect(updated.name, 'Neue Firma');
      expect(updated.email, 'neu@example.test');
      expect(updated.note, 'Aktualisiert');
      expect(updated.kreditlimit, 7500);
      expect(updated.debitorNr, originalDebitorNr);
    });

    test('assigns sequential Debitor-Nr values from the configured range', () async {
      // Arrange: make 10050 the next value consumed by the Debitor range.
      final repository = kundenRepository(db);
      await setNextDebitorNumber(10050);

      // Act: create two customers without supplying Debitor-Nr values.
      final first = await createCustomer(repository, name: 'Erster Kunde');
      final second = await createCustomer(repository, name: 'Zweiter Kunde');

      // Assert: each create receives the next sequential Debitor-Nr.
      expect(first.debitorNr, '10050');
      expect(second.debitorNr, '10051');
    });

    test('persists customer after database reload', () async {
      // Arrange: use a file-backed profile so a second database can reload it.
      final profile = await Directory.systemTemp.createTemp('openaccounting-kunden-');
      AppDatabase? persistentDb;
      AppDatabase? reloadedDb;

      try {
        persistentDb = AppDatabase.forProfile(profile.path);
        await persistentDb.ensureOpen();
        final repository = kundenRepository(persistentDb);

        // Act: persist a customer, close its database, then reopen the profile.
        final created = await createCustomer(repository, name: 'Dauerhafter Kunde', email: 'persist@example.test');
        await persistentDb.close();
        persistentDb = null;

        reloadedDb = AppDatabase.forProfile(profile.path);
        await reloadedDb.ensureOpen();
        final stored = await kundenRepository(reloadedDb).findById(created.id);

        // Assert: reload returns the same customer and persisted fields.
        expect(stored, isNotNull);
        expect(stored.id, created.id);
        expect(stored.name, 'Dauerhafter Kunde');
        expect(stored.email, 'persist@example.test');
      } finally {
        await persistentDb?.close();
        await reloadedDb?.close();
        await profile.delete(recursive: true);
      }
    });

    test('deletes an unreferenced customer', () async {
      // Arrange: create a customer with no linked document.
      final repository = kundenRepository(db);
      final created = await createCustomer(repository, name: 'Löschbarer Kunde');

      // Act: delete the customer through the repository.
      await repository.delete(created.id);

      // Assert: findById no longer returns the deleted customer.
      final deleted = await repository.findById(created.id);
      expect(deleted, isNull);
    });

    test('rejects deletion when Rechnung #2001 references the customer', () async {
      // Arrange: link Rechnung #2001 to Müller GmbH using an open receivable fixture.
      final repository = kundenRepository(db);
      final created = await createCustomer(repository, name: 'Müller GmbH');
      await insertInvoiceReference(customerId: created.id, invoiceNumber: '2001', total: 500, dueDate: '2020-01-15');

      // Act: attempt destructive deletion through the repository.
      final deletion = repository.delete(created.id);

      // Assert: exact referencing-document error is reported and the row remains.
      await expectLater(deletion, exactError('Kunde kann nicht gelöscht werden: Rechnung #2001'));
      final retained = await repository.findById(created.id);
      expect(retained, isNotNull);
      expect(retained.id, created.id);
      expect(retained.name, 'Müller GmbH');
    });

    test('rejects an invalid German USt-IdNr without persisting the customer', () async {
      // Arrange: submit a German USt-IdNr with too few digits.
      final repository = kundenRepository(db);

      // Act: attempt to create the invalid customer.
      final failure = createCustomer(repository, name: 'Ungültige USt-ID', ustIdNr: 'DE123');

      // Assert: exact validation message is returned and no customer is persisted.
      await expectLater(failure, exactError('USt-IdNr ungültig: Erwartet DE gefolgt von 9 Ziffern'));
      final persisted = await repository.list();
      expect(persisted, isEmpty);
    });

    test('accepts non-EU USt-IdNr free text', () async {
      // Arrange: use Switzerland, outside EU country-specific validation.
      final repository = kundenRepository(db);

      // Act: save the documented Swiss free-text USt-IdNr.
      final created = await createCustomer(repository, name: 'Schweizer Kunde', land: 'CH', ustIdNr: 'CHE-123.456.789');
      final stored = await repository.findById(created.id);

      // Assert: non-EU value is accepted unchanged.
      expect(stored.land, 'CH');
      expect(stored.ustIdNr, 'CHE-123.456.789');
    });

    test('warns and finalizes explicitly when invoice exceeds credit limit', () async {
      // Arrange: credit limit is 5000 EUR and open invoices total 4800 EUR.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'Kreditlimit Kunde', kreditlimit: 5000);
      await insertInvoiceReference(customerId: customer.id, invoiceNumber: '2002', total: 4800, dueDate: '2020-01-15');

      // Act: evaluate a further invoice and explicitly confirm the warning.
      final warning = await repository.checkCreditLimit(customerId: customer.id, invoiceTotal: 500);
      final finalized = await repository.confirmCreditLimitWarning(customerId: customer.id, invoiceTotal: 500);

      // Assert: warning has exact financial values, logs audit, and confirmation finalizes.
      expect(warning, isNotNull);
      expect(warning.outstanding, 4800);
      expect(warning.limit, 5000);
      expect(warning.requiresConfirmation, isTrue);
      expect(warning.auditLogged, isTrue);
      expect(finalized.status, 'final');
    });

    test('finalizes within credit limit without warning', () async {
      // Arrange: credit limit is 5000 EUR and open invoices total 3000 EUR.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'Kreditlimit Kunde', kreditlimit: 5000);
      await insertInvoiceReference(customerId: customer.id, invoiceNumber: '2003', total: 3000, dueDate: '2020-01-15');

      // Act: evaluate a 500 EUR invoice while remaining below the limit.
      final warning = await repository.checkCreditLimit(customerId: customer.id, invoiceTotal: 500);

      // Assert: within-limit finalization has no warning or confirmation requirement.
      expect(warning, isNull);
    });

    test('automated dunning skips blocked customers with a reason', () async {
      // Arrange: blocked and unblocked customers both have overdue open receivables.
      final repository = kundenRepository(db);
      final blocked = await createCustomer(repository, name: 'Schmidt KG', dunningBlocked: true);
      final allowed = await createCustomer(repository, name: 'Freie KG');
      await insertInvoiceReference(customerId: blocked.id, invoiceNumber: '2004', total: 250, dueDate: '2020-01-15');
      await insertInvoiceReference(customerId: allowed.id, invoiceNumber: '2005', total: 250, dueDate: '2020-01-15');

      // Act: run automated dunning.
      final result = await repository.runDunning();

      // Assert: only blocked customer is skipped and reason is logged exactly.
      expect(result.skippedCustomerIds, contains(blocked.id));
      expect(result.skippedReasons[blocked.id], 'Mahngesperrt');
      expect(result.skippedCustomerIds, isNot(contains(allowed.id)));
    });

    test('rejects manual dunning for Mahngesperrt customer', () async {
      // Arrange: blocked customer has an overdue unpaid invoice.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'Schmidt KG', dunningBlocked: true);
      await insertInvoiceReference(customerId: customer.id, invoiceNumber: '2006', total: 250, dueDate: '2020-01-15');

      // Act: attempt to generate the manual dunning letter.
      final dunning = repository.generateDunningLetter(customerId: customer.id);

      // Assert: blocked customer returns the required exact error message.
      await expectLater(dunning, exactError('Kunde ist mahngesperrt'));
    });

    test('generates manual dunning letter for an unblocked customer', () async {
      // Arrange: unblocked customer has an overdue unpaid invoice.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'Freie KG');
      await insertInvoiceReference(customerId: customer.id, invoiceNumber: '2007', total: 250, dueDate: '2020-01-15');

      // Act: generate the manual dunning letter.
      final dunning = repository.generateDunningLetter(customerId: customer.id);

      // Assert: unblocked customer is allowed to proceed.
      await expectLater(dunning, completes);
    });

    test('invoiceOptions reports ZUGFeRD enabled', () async {
      // Arrange: create a customer with ZUGFeRD enabled.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'ZUGFeRD Kunde', zugferdAktiv: true);

      // Act: read invoice options through the repository.
      final options = await repository.invoiceOptions(customerId: customer.id);

      // Assert: downstream invoice generation sees the enabled state.
      expect(options.zugferdEnabled, isTrue);
    });

    test('invoiceOptions reports ZUGFeRD disabled', () async {
      // Arrange: create a customer with ZUGFeRD disabled.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'Standard-PDF Kunde');

      // Act: read invoice options through the repository.
      final options = await repository.invoiceOptions(customerId: customer.id);

      // Assert: downstream invoice generation sees the disabled state.
      expect(options.zugferdEnabled, isFalse);
    });

    test('invoiceOptions exposes foreign tax number for a third-country customer', () async {
      // Arrange: Swiss customer stores USt-IdNr and foreign tax number independently.
      final repository = kundenRepository(db);
      final customer = await createCustomer(
        repository,
        name: 'Drittland Kunde',
        land: 'CH',
        ustIdNr: 'CHE-UID-123',
        foreignTaxNumber: 'CHE-123.456.789 MWST',
      );

      // Act: retrieve customer data consumed by downstream PDF generation.
      final options = await repository.invoiceOptions(customerId: customer.id);

      // Assert: both tax identifiers remain available to invoice generation.
      expect(options.foreignTaxNumber, 'CHE-123.456.789 MWST');
    });

    test('invoiceOptions omits foreign tax number for an EU customer', () async {
      // Arrange: German customer has no foreign tax number.
      final repository = kundenRepository(db);
      final customer = await createCustomer(repository, name: 'EU Kunde');

      // Act: retrieve invoice options for the customer.
      final options = await repository.invoiceOptions(customerId: customer.id);

      // Assert: downstream invoice data has no foreign tax number.
      expect(options.foreignTaxNumber, isNull);
    });
  });
}
