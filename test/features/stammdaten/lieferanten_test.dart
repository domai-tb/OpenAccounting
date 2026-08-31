// ignore_for_file: avoid_dynamic_calls

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';

dynamic lieferantenRepository(AppDatabase db) {
  final dynamic database = db;
  return database.lieferantenRepository;
}

void main() {
  group('Lieferanten-Stammdaten', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    dynamic createSupplier(
      dynamic repository, {
      String anrede = 'Herr',
      required String name,
      String? firma,
      required String strasse,
      String? hausnummer,
      required String plz,
      required String ort,
      String land = 'DE',
      String? ustIdNr,
      String? foreignTaxNumber,
      String? telefon,
      String? email,
      String? iban,
      int zahlungsziel = 14,
      num skontoProzent = 0,
      int skontoTage = 0,
      String? note,
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
        iban: iban,
        zahlungsziel: zahlungsziel,
        skontoProzent: skontoProzent,
        skontoTage: skontoTage,
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

    Matcher exactError(String message) => throwsA(
      predicate<Object>(
        (error) => error.runtimeType.toString() == 'LieferantenException' && errorMessage(error) == message,
      ),
    );

    Matcher referenceError(String table, int rowId) => throwsA(
      predicate<Object>(
        (error) =>
            error.runtimeType.toString() == 'LieferantenException' &&
            errorMessage(error).contains(table) &&
            errorMessage(error).contains('$rowId'),
      ),
    );

    Future<int> insertInvoiceReference({required int supplierId}) async {
      return db.executor.runInsert(
        '''
INSERT INTO rechnungen (
  rechnungsnummer,
  typ,
  status,
  ist_entwurf,
  eingabemodus,
  lieferant_id,
  datum,
  faelligkeit,
  brutto_betrag
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        <Object?>['ER-2001', 'rechnung_eingang', 'final', 0, 'netto', supplierId, '2026-08-31', '2026-09-30', 500],
      );
    }

    Future<int> insertJournalReference({required int supplierId}) async {
      return db.executor.runInsert(
        '''
INSERT INTO journal (datum, beleg_nr, betrag, beschreibung, lieferant_id)
VALUES (?, ?, ?, ?, ?)
''',
        <Object?>['2026-08-31', 'J-2002', 250, 'Lieferantenbuchung', supplierId],
      );
    }

    test('requires an open database before repository access', () async {
      // Arrange: construct a database without opening its connection.
      final unopened = AppDatabase.createTestDatabase();
      final dynamic database = unopened;
      addTearDown(unopened.close);

      // Act and assert: repository access cannot bypass database lifecycle setup.
      expect(() => database.lieferantenRepository, throwsA(isA<StateError>()));
    });

    test('round-trips required and optional supplier fields', () async {
      // Arrange: provide every supplier field with representative values.
      final repository = lieferantenRepository(db);
      final created = await createSupplier(
        repository,
        anrede: 'Frau',
        name: 'Bürobedarf AG',
        firma: 'Bürobedarf AG',
        strasse: 'Marktstraße 1',
        hausnummer: '1',
        plz: '10115',
        ort: 'Berlin',
        // ignore: avoid_redundant_argument_values
        land: 'DE',
        ustIdNr: 'DE123456789',
        // ignore: avoid_redundant_argument_values
        foreignTaxNumber: null,
        telefon: '+49 30 123456',
        email: 'rechnung@buerobedarf.de',
        iban: 'DE02120300000000202051',
        zahlungsziel: 30,
        skontoProzent: 2,
        skontoTage: 10,
        note: 'Papierlieferant',
      );

      // Act: reload supplier through its repository.
      final stored = await repository.findById(created.id);

      // Assert: every supplied field and generated Kreditor-Nr survives the round-trip.
      expect(stored, isNotNull);
      expect(stored.id, created.id);
      expect(stored.kreditorNr, isNotEmpty);
      expect(stored.anrede, 'Frau');
      expect(stored.name, 'Bürobedarf AG');
      expect(stored.firma, 'Bürobedarf AG');
      expect(stored.strasse, 'Marktstraße 1');
      expect(stored.hausnummer, '1');
      expect(stored.plz, '10115');
      expect(stored.ort, 'Berlin');
      expect(stored.land, 'DE');
      expect(stored.ustIdNr, 'DE123456789');
      expect(stored.foreignTaxNumber, isNull);
      expect(stored.telefon, '+49 30 123456');
      expect(stored.email, 'rechnung@buerobedarf.de');
      expect(stored.iban, 'DE02120300000000202051');
      expect(stored.zahlungsziel, 30);
      expect(stored.skontoProzent, 2);
      expect(stored.skontoTage, 10);
      expect(stored.note, 'Papierlieferant');
    });

    test('keeps omitted optional supplier fields null and applies defaults', () async {
      // Arrange: provide only required supplier fields.
      final repository = lieferantenRepository(db);

      // Act: create a supplier without nullable or payment fields.
      final created = await createSupplier(
        repository,
        name: 'Nur Pflichtfelder',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );
      final stored = await repository.findById(created.id);

      // Assert: omitted values remain null and documented defaults are applied.
      expect(stored.firma, isNull);
      expect(stored.hausnummer, isNull);
      expect(stored.ustIdNr, isNull);
      expect(stored.foreignTaxNumber, isNull);
      expect(stored.telefon, isNull);
      expect(stored.email, isNull);
      expect(stored.iban, isNull);
      expect(stored.note, isNull);
      expect(stored.anrede, 'Herr');
      expect(stored.land, 'DE');
      expect(stored.zahlungsziel, 14);
      expect(stored.skontoProzent, 0);
      expect(stored.skontoTage, 0);
    });

    test('updates a supplier and preserves its Kreditor-Nr', () async {
      // Arrange: create a supplier with an assigned Kreditor-Nr.
      final repository = lieferantenRepository(db);
      final created = await createSupplier(
        repository,
        name: 'Alte Firma',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );

      // Act: update a mutable master-data field.
      await repository.update(created.id, <String, dynamic>{'ort': 'Potsdam'});
      final updated = await repository.findById(created.id);

      // Assert: update persists while generated number remains stable.
      expect(updated.ort, 'Potsdam');
      expect(updated.kreditorNr, created.kreditorNr);
    });

    test('deletes an unreferenced supplier', () async {
      // Arrange: create a supplier without linked documents.
      final repository = lieferantenRepository(db);
      final created = await createSupplier(
        repository,
        name: 'Löschbarer Lieferant',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );

      // Act: delete supplier through repository.
      await repository.delete(created.id);

      // Assert: deleted supplier cannot be found.
      expect(await repository.findById(created.id), isNull);
    });

    test('lists persisted suppliers and returns null for unknown IDs', () async {
      // Arrange: persist two suppliers and choose an absent ID.
      final repository = lieferantenRepository(db);
      await createSupplier(repository, name: 'Erster Lieferant', strasse: 'Straße', plz: '10115', ort: 'Berlin');
      await createSupplier(repository, name: 'Zweiter Lieferant', strasse: 'Straße', plz: '10115', ort: 'Berlin');

      // Act: load list and missing record.
      final suppliers = await repository.list();
      final missing = await repository.findById(999999);

      // Assert: list exposes persisted rows and missing IDs return null.
      expect(
        suppliers.map((supplier) => supplier.name),
        containsAll(<String>['Erster Lieferant', 'Zweiter Lieferant']),
      );
      expect(missing, isNull);
    });

    test('assigns Kreditor-Nr from kreditor number range', () async {
      // Arrange: configure a seven-prefix range with next number 9.
      await db.executor.runCustom(
        '''UPDATE nummernkreise SET format = '7####', naechste_nummer = 9 WHERE typ = 'kreditor' ''',
      );
      final repository = lieferantenRepository(db);

      // Act: create supplier using configured number range.
      final supplier = await createSupplier(
        repository,
        name: 'Lieferant',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );

      // Assert: prefix and four-digit placeholder formatting are applied.
      expect(supplier.kreditorNr, '70009');
    });

    test('rejects invalid EU VAT and accepts non-EU free text', () async {
      // Arrange: prepare invalid Austrian and valid Swiss VAT values.
      final repository = lieferantenRepository(db);

      // Act: submit both country-specific VAT cases.
      final invalidEuVat = createSupplier(
        repository,
        name: 'AT',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Wien',
        land: 'AT',
        ustIdNr: 'AT12345678',
      );
      final swiss = await createSupplier(
        repository,
        name: 'CH',
        strasse: 'Straße',
        plz: '8000',
        ort: 'Zürich',
        land: 'CH',
        ustIdNr: 'CHE-123.456.789',
      );

      // Assert: EU pattern rejects invalid value while non-EU text is preserved.
      await expectLater(
        invalidEuVat,
        throwsA(predicate<Object>((error) => error.runtimeType.toString() == 'LieferantenException')),
      );
      expect(swiss.ustIdNr, 'CHE-123.456.789');
    });

    test('rejects blank required fields and overlong foreign tax numbers', () async {
      // Arrange: prepare blank required values and a 51-character foreign tax number.
      final repository = lieferantenRepository(db);
      final tooLongTaxNumber = List<String>.filled(51, 'x').join();

      // Act: submit each invalid boundary value through create.
      final blankAnrede = createSupplier(
        repository,
        anrede: '',
        name: 'Ungültig',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );
      final blankName = createSupplier(repository, name: '', strasse: 'Straße', plz: '10115', ort: 'Berlin');
      final blankStrasse = createSupplier(repository, name: 'Ungültig', strasse: '', plz: '10115', ort: 'Berlin');
      final blankPlz = createSupplier(repository, name: 'Ungültig', strasse: 'Straße', plz: '', ort: 'Berlin');
      final blankOrt = createSupplier(repository, name: 'Ungültig', strasse: 'Straße', plz: '10115', ort: '');
      final blankLand = createSupplier(
        repository,
        name: 'Ungültig',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
        land: '',
      );
      final overlongTaxNumber = createSupplier(
        repository,
        name: 'Ungültig',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
        foreignTaxNumber: tooLongTaxNumber,
      );

      // Assert: invalid values are rejected before persistence.
      await expectLater(blankAnrede, exactError('Anrede ist Pflicht'));
      await expectLater(blankName, exactError('Name ist Pflicht'));
      await expectLater(blankStrasse, exactError('Straße ist Pflicht'));
      await expectLater(blankPlz, exactError('PLZ ist Pflicht'));
      await expectLater(blankOrt, exactError('Ort ist Pflicht'));
      await expectLater(blankLand, exactError('Land ist Pflicht'));
      await expectLater(overlongTaxNumber, exactError('Steuernummer Ausland darf höchstens 50 Zeichen enthalten'));
      expect(await repository.list(), isEmpty);
    });

    test('rejects unknown update fields', () async {
      // Arrange: create a valid supplier before unsupported update.
      final repository = lieferantenRepository(db);
      final created = await createSupplier(
        repository,
        name: 'Bekannter Lieferant',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );

      // Act: submit a field outside supplier update allowlist.
      final update = repository.update(created.id, <String, dynamic>{'nicht_erlaubt': 'Wert'});

      // Assert: unknown field is rejected and supplier remains present.
      await expectLater(update, exactError('Unbekanntes Lieferantenfeld: nicht_erlaubt'));
      expect(await repository.findById(created.id), isNotNull);
    });

    test('rejects deletion when Rechnung reference exists and includes row ID', () async {
      // Arrange: link an invoice to supplier through parameterized SQL.
      final repository = lieferantenRepository(db);
      final created = await createSupplier(
        repository,
        name: 'Rechnungslieferant',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );
      final invoiceId = await insertInvoiceReference(supplierId: created.id);

      // Act: attempt destructive deletion.
      final deletion = repository.delete(created.id);

      // Assert: invoice reference blocks deletion and identifies its row.
      await expectLater(deletion, referenceError('Rechnung', invoiceId));
      expect(await repository.findById(created.id), isNotNull);
    });

    test('rejects deletion when Journal reference exists and includes row ID', () async {
      // Arrange: link a journal row to supplier through parameterized SQL.
      final repository = lieferantenRepository(db);
      final created = await createSupplier(
        repository,
        name: 'Journallieferant',
        strasse: 'Straße',
        plz: '10115',
        ort: 'Berlin',
      );
      final journalId = await insertJournalReference(supplierId: created.id);

      // Act: attempt destructive deletion.
      final deletion = repository.delete(created.id);

      // Assert: journal reference blocks deletion and identifies its row.
      await expectLater(deletion, referenceError('Journal', journalId));
      expect(await repository.findById(created.id), isNotNull);
    });
  });
}
