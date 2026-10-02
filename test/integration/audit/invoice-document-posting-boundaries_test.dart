// ignore_for_file: file_names

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  group('Invoice document posting boundaries', () {
    late AppDatabase db;
    late RechnungenDataSource ds;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      ds = RechnungenDataSource(db.executor);
    });

    tearDown(() async => db.close());

    Future<int> addCustomer() => db.executor.runInsert(
      'INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)',
      const <Object?>['Boundary Customer', 'Main Street 1', '10115', 'Berlin'],
    );

    Future<int> addSupplier() =>
        db.executor.runInsert('INSERT INTO lieferanten (name) VALUES (?)', const <Object?>['Boundary Supplier']);

    Future<int> addArticle({required num stock, bool allowNegative = false}) async =>
        (await db.artikelRepository.create(
          bezeichnung: 'Boundary Article',
          vkBrutto: 119,
          lagerAktiv: true,
          bestandAktuell: stock,
          minusbestandErlaubt: allowNegative,
        )).id;

    Future<int> createDocument({
      required String type,
      int? customerId,
      int? supplierId,
      int? articleId,
      num quantity = 1,
    }) async {
      final id = await ds.createDraftRechnung(
        datum: '2026-01-15',
        positionen: <RechnungPositionItem>[
          RechnungPositionItem(
            bezeichnung: 'Boundary item',
            menge: quantity,
            einzelpreis: 100,
            gesamt: 100 * quantity,
            artikelId: articleId,
          ),
        ],
      );
      await db.executor.runUpdate(
        'UPDATE rechnungen SET typ = ?, kunde_id = ?, lieferant_id = ? WHERE id = ?',
        <Object?>[type, customerId, supplierId, id],
      );
      return id;
    }

    Future<Map<String, Object?>> document(int id) async =>
        (await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', <Object?>[id])).single;

    String pdfText(Uint8List bytes) => String.fromCharCodes(bytes);

    bool pdfContains(Uint8List bytes, String value) {
      final content = pdfText(bytes);
      final pdfTextRuns = RegExp(r'\(([^)]*)\)\]TJ').allMatches(content).map((match) => match.group(1)).join();
      return pdfTextRuns.replaceAll(' ', '').contains(value.replaceAll(' ', ''));
    }

    Future<List<File>> pdfFiles(Directory directory) async => directory.existsSync()
        ? directory.list(recursive: true).where((entity) => entity is File).cast<File>().toList()
        : <File>[];

    test('test_outgoing_invoice_posts_receivable_without_input_tax', () async {
      final customerId = await addCustomer();
      final invoiceId = await createDocument(type: 'rechnung', customerId: customerId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

      final journal = (await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).single;
      final receivable = (await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).single;
      final claims = await db.executor.runSelect('SELECT id FROM vorsteuer_ansprueche WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ]);
      expect(journal['beleg_typ'], 'Einnahme');
      expect(receivable['typ'], 'rechnung');
      expect(receivable['partner_id'], customerId);
      expect(claims, isEmpty);
    });

    test('test_incoming_aliases_use_purchase_range_and_accounting', () async {
      final supplierId = await addSupplier();
      final articleId = await addArticle(stock: 20);
      final incomingRangeId = (await db.executor.runSelect(
        "SELECT id FROM nummernkreise WHERE typ = 'rechnung_eingang' AND aktiv = 1 LIMIT 1",
        const <Object?>[],
      )).single['id'];

      for (final type in <String>['rechnung_eingang', 'eingangsrechnung', 'eingang']) {
        final invoiceId = await createDocument(type: type, supplierId: supplierId, articleId: articleId);
        await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

        final finalized = await document(invoiceId);
        final journals = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
          invoiceId,
        ]);
        final receivables = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
          invoiceId,
        ]);
        final taxClaims = await db.executor.runSelect(
          'SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
          <Object?>[invoiceId],
        );
        expect(finalized['nummernkreis_id'], incomingRangeId);
        expect(finalized['ist_entwurf'], 0);
        expect(journals.single['beleg_typ'], 'Ausgabe');
        expect(receivables.single['typ'], 'rechnung_eingang');
        expect(receivables.single['partner_typ'], 'lieferant');
        expect(num.parse(taxClaims.single['betrag'].toString()), closeTo(19, 0.001));
      }

      final article = await db.artikelRepository.findById(articleId);
      final movements = await db.executor.runSelect('SELECT id FROM inventarbewegungen WHERE artikel_id = ?', <Object?>[
        articleId,
      ]);
      expect(article!.bestandAktuell, 20);
      expect(movements, isEmpty);
    });

    test('test_incoming_type_is_canonicalized', () async {
      final supplierId = await addSupplier();
      final invoiceId = await createDocument(type: ' EingangsRechnung ', supplierId: supplierId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

      final finalized = await document(invoiceId);
      final journal = (await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).single;
      expect(
        finalized['nummernkreis_id'],
        (await db.executor.runSelect(
          "SELECT id FROM nummernkreise WHERE typ = 'rechnung_eingang' LIMIT 1",
          const <Object?>[],
        )).single['id'],
      );
      expect(journal['beleg_typ'], 'Ausgabe');
    });

    test('test_supplier_linked_legacy_rechnung_is_incoming', () async {
      final supplierId = await addSupplier();
      final articleId = await addArticle(stock: 20);
      final invoiceId = await createDocument(type: 'rechnung', supplierId: supplierId, articleId: articleId);
      final incomingRangeId = (await db.executor.runSelect(
        "SELECT id FROM nummernkreise WHERE typ = 'rechnung_eingang' LIMIT 1",
        const <Object?>[],
      )).single['id'];

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

      final finalized = await document(invoiceId);
      final journal = (await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).single;
      final payable = (await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).single;
      expect(finalized['nummernkreis_id'], incomingRangeId);
      expect(journal['beleg_typ'], 'Ausgabe');
      expect(payable['partner_typ'], 'lieferant');
      expect(payable['partner_id'], supplierId);
      expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 20);
    });

    test('test_incoming_customer_without_supplier_has_no_receivable', () async {
      final customerId = await addCustomer();
      final articleId = await addArticle(stock: 20);
      final invoiceId = await createDocument(type: 'rechnung_eingang', customerId: customerId, articleId: articleId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

      final journal = (await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ])).single;
      final receivables = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        invoiceId,
      ]);
      final taxClaims = await db.executor.runSelect(
        'SELECT id FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      );
      expect(journal['beleg_typ'], 'Ausgabe');
      expect(receivables, isEmpty);
      expect(taxClaims, hasLength(1));
      expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 20);
    });

    test('test_supplier_linked_offer_has_no_invoice_effects', () async {
      final supplierId = await addSupplier();
      final articleId = await addArticle(stock: 2);
      final offerId = await createDocument(type: 'angebot', supplierId: supplierId, articleId: articleId, quantity: 5);

      await ds.finalizeRechnung(rechnungId: offerId, locale: 'de_DE');

      final finalized = await document(offerId);
      expect(finalized['ist_entwurf'], 0);
      expect(finalized['nummernkreis_id'], isNotNull);
      expect(await db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[offerId]), isEmpty);
      expect(
        await db.executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ?', <Object?>[offerId]),
        isEmpty,
      );
      expect(
        await db.executor.runSelect('SELECT id FROM vorsteuer_ansprueche WHERE rechnung_id = ?', <Object?>[offerId]),
        isEmpty,
      );
      expect(
        await db.executor.runSelect('SELECT id FROM inventarbewegungen WHERE artikel_id = ?', <Object?>[articleId]),
        isEmpty,
      );
      expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 2);
    });

    test('test_incoming_invoice_creates_input_tax_claim', () async {
      final supplierId = await addSupplier();
      final invoiceId = await createDocument(type: 'eingangsrechnung', supplierId: supplierId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

      final claims = await db.executor.runSelect(
        'SELECT betrag, faelligkeit FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      );
      expect(claims, hasLength(1));
      expect(num.parse(claims.single['betrag'].toString()), closeTo(19, 0.001));
      expect(claims.single['faelligkeit'], '2026-01-15');
    });

    test('test_outgoing_vat_does_not_create_input_tax_claim', () async {
      final customerId = await addCustomer();
      final invoiceId = await createDocument(type: 'rechnung', customerId: customerId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');

      expect(
        await db.executor.runSelect('SELECT id FROM vorsteuer_ansprueche WHERE rechnung_id = ?', <Object?>[invoiceId]),
        isEmpty,
      );
    });

    test('test_incoming_input_tax_failure_rolls_back', () async {
      final supplierId = await addSupplier();
      final invoiceId = await createDocument(type: 'eingangsrechnung', supplierId: supplierId);
      final rangeBefore = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_eingang' LIMIT 1",
        const <Object?>[],
      )).single['naechste_nummer'];
      final profileDir = await Directory.systemTemp.createTemp('incoming-tax-rollback-');

      try {
        await expectLater(
          ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir, debugFailAt: 'tax'),
          throwsA(isA<StateError>().having((error) => error.message, 'message', contains('Induced failure after tax'))),
        );

        final persisted = await document(invoiceId);
        expect(persisted['ist_entwurf'], 1);
        expect(persisted['rechnungsnummer'], isNull);
        expect(
          await db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[invoiceId]),
          isEmpty,
        );
        expect(
          await db.executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ?', <Object?>[invoiceId]),
          isEmpty,
        );
        expect(
          await db.executor.runSelect('SELECT id FROM vorsteuer_ansprueche WHERE rechnung_id = ?', <Object?>[
            invoiceId,
          ]),
          isEmpty,
        );
        expect(
          (await db.executor.runSelect(
            "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_eingang' LIMIT 1",
            const <Object?>[],
          )).single['naechste_nummer'],
          rangeBefore,
        );
        final pdfDir = Directory('${profileDir.path}/pdfs');
        expect(await pdfFiles(pdfDir), isEmpty);
      } finally {
        if (profileDir.existsSync()) profileDir.deleteSync(recursive: true);
      }
    });

    test('test_incoming_pdf_uses_supplier_as_counterparty', () async {
      final customerId = await addCustomer();
      final supplierId = await addSupplier();
      final invoiceId = await createDocument(type: 'eingang', customerId: customerId, supplierId: supplierId);
      final profileDir = await Directory.systemTemp.createTemp('incoming-pdf-counterparty-');

      try {
        await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir);

        final path = (await document(invoiceId))['original_pdf_pfad']! as String;
        final bytes = await File(path).readAsBytes();
        expect(pdfContains(bytes, 'Boundary Supplier'), isTrue);
        expect(pdfContains(bytes, 'Boundary Customer'), isFalse);
      } finally {
        await profileDir.delete(recursive: true);
      }
    });

    test('test_same_display_number_keeps_distinct_pdf_artifacts', () async {
      await db.executor.runCustom(
        "UPDATE nummernkreise SET format = 'SH-YY####', naechste_nummer = 1 WHERE typ IN ('rechnung_ausgang', 'rechnung_eingang')",
      );
      final customerId = await addCustomer();
      final supplierId = await addSupplier();
      final outgoingId = await createDocument(type: 'rechnung', customerId: customerId);
      final incomingId = await createDocument(type: 'rechnung_eingang', supplierId: supplierId);
      final profileDir = await Directory.systemTemp.createTemp('document-row-pdf-identity-');

      try {
        await ds.finalizeRechnung(rechnungId: outgoingId, locale: 'de_DE', profileDir: profileDir);
        await ds.finalizeRechnung(rechnungId: incomingId, locale: 'de_DE', profileDir: profileDir);

        final outgoing = await document(outgoingId);
        final incoming = await document(incomingId);
        expect(outgoing['rechnungsnummer'], incoming['rechnungsnummer']);
        expect(outgoing['original_pdf_pfad'], isNot(incoming['original_pdf_pfad']));
        expect(File(outgoing['original_pdf_pfad']! as String).existsSync(), isTrue);
        expect(File(incoming['original_pdf_pfad']! as String).existsSync(), isTrue);
      } finally {
        await profileDir.delete(recursive: true);
      }
    });

    test('test_preexisting_pdf_target_is_not_overwritten_or_deleted', () async {
      await db.executor.runCustom(
        "UPDATE nummernkreise SET format = 'SH-YY####', naechste_nummer = 1 WHERE typ IN ('rechnung_ausgang', 'rechnung_eingang')",
      );
      final customerId = await addCustomer();
      final supplierId = await addSupplier();
      final outgoingId = await createDocument(type: 'rechnung', customerId: customerId);
      final incomingId = await createDocument(type: 'rechnung_eingang', supplierId: supplierId);
      final profileDir = await Directory.systemTemp.createTemp('occupied-document-pdf-');
      final pdfDirectory = Directory('${profileDir.path}/pdfs/documents');
      await pdfDirectory.create(recursive: true);
      final occupiedTarget = File('${pdfDirectory.path}/$incomingId.pdf');
      final originalBytes = <int>[37, 80, 68, 70, 45, 111, 99, 99, 117, 112, 105, 101, 100];
      await occupiedTarget.writeAsBytes(originalBytes);

      try {
        await ds.finalizeRechnung(rechnungId: outgoingId, locale: 'de_DE', profileDir: profileDir);
        final outgoingPath = (await document(outgoingId))['original_pdf_pfad']! as String;
        final outgoingBytes = await File(outgoingPath).readAsBytes();
        final incomingCounterBefore = (await db.executor.runSelect(
          "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_eingang'",
          const <Object?>[],
        )).single['naechste_nummer'];

        await expectLater(
          ds.finalizeRechnung(rechnungId: incomingId, locale: 'de_DE', profileDir: profileDir),
          throwsA(isA<FileSystemException>()),
        );

        expect(await occupiedTarget.readAsBytes(), originalBytes);
        expect(await File(outgoingPath).readAsBytes(), outgoingBytes);
        expect((await document(incomingId))['ist_entwurf'], 1);
        expect(
          (await db.executor.runSelect(
            "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_eingang'",
            const <Object?>[],
          )).single['naechste_nummer'],
          incomingCounterBefore,
        );
      } finally {
        await profileDir.delete(recursive: true);
      }
    });

    test('test_outgoing_late_failure_rolls_back_stock_and_pdf', () async {
      final customerId = await addCustomer();
      final articleId = await addArticle(stock: 20);
      final invoiceId = await createDocument(
        type: 'rechnung',
        customerId: customerId,
        articleId: articleId,
        quantity: 3,
      );
      final profileDir = await Directory.systemTemp.createTemp('outgoing-finalization-rollback-');
      final rangeBefore = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang'",
        const <Object?>[],
      )).single['naechste_nummer'];

      try {
        await expectLater(
          ds.finalizeRechnung(
            rechnungId: invoiceId,
            locale: 'de_DE',
            profileDir: profileDir,
            debugFailAt: 'receivable',
          ),
          throwsA(isA<StateError>()),
        );

        expect((await document(invoiceId))['ist_entwurf'], 1);
        expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 20);
        expect(
          await db.executor.runSelect('SELECT id FROM inventarbewegungen WHERE referenz_id = ?', <Object?>[invoiceId]),
          isEmpty,
        );
        expect(
          await db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[invoiceId]),
          isEmpty,
        );
        expect(
          await db.executor.runSelect('SELECT id FROM forderungen WHERE rechnung_id = ?', <Object?>[invoiceId]),
          isEmpty,
        );
        expect(
          (await db.executor.runSelect(
            "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang'",
            const <Object?>[],
          )).single['naechste_nummer'],
          rangeBefore,
        );
        final pdfDirectory = Directory('${profileDir.path}/pdfs');
        expect(await pdfFiles(pdfDirectory), isEmpty);

        await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE', profileDir: profileDir);
        expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 17);
        expect(
          await db.executor.runSelect('SELECT id FROM inventarbewegungen WHERE referenz_id = ?', <Object?>[invoiceId]),
          hasLength(1),
        );
      } finally {
        await profileDir.delete(recursive: true);
      }
    });

    test('test_document_only_failure_rolls_back_pdf_and_number', () async {
      final supplierId = await addSupplier();
      final articleId = await addArticle(stock: 2);
      final offerId = await createDocument(type: 'angebot', supplierId: supplierId, articleId: articleId, quantity: 5);
      final profileDir = await Directory.systemTemp.createTemp('document-only-rollback-');
      final rangeBefore = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'angebot'",
        const <Object?>[],
      )).single['naechste_nummer'];

      try {
        await expectLater(
          ds.finalizeRechnung(rechnungId: offerId, locale: 'de_DE', profileDir: profileDir, debugFailAt: 'document'),
          throwsA(isA<StateError>()),
        );

        expect((await document(offerId))['ist_entwurf'], 1);
        expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 2);
        expect(
          await db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[offerId]),
          isEmpty,
        );
        expect(
          (await db.executor.runSelect(
            "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'angebot'",
            const [],
          )).single['naechste_nummer'],
          rangeBefore,
        );
        final pdfDirectory = Directory('${profileDir.path}/pdfs');
        expect(await pdfFiles(pdfDirectory), isEmpty);

        await ds.finalizeRechnung(rechnungId: offerId, locale: 'de_DE', profileDir: profileDir);
        expect((await document(offerId))['ist_entwurf'], 0);
        expect((await db.artikelRepository.findById(articleId))!.bestandAktuell, 2);
      } finally {
        await profileDir.delete(recursive: true);
      }
    });

    test('test_incoming_storno_reverses_existing_input_tax_claim', () async {
      final supplierId = await addSupplier();
      final invoiceId = await createDocument(type: 'rechnung_eingang', supplierId: supplierId);

      await ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE');
      final original = (await db.executor.runSelect(
        'SELECT betrag FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[invoiceId],
      )).single;
      final stornoId = await ds.stornoRechnung(rechnungId: invoiceId, grund: 'Tax reversal regression');

      final reversals = await db.executor.runSelect(
        'SELECT betrag FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      expect(reversals, hasLength(1));
      expect(
        num.parse(reversals.single['betrag'].toString()),
        closeTo(-num.parse(original['betrag'].toString()), 0.001),
      );
    });

    test('test_unsupported_raw_types_are_rejected', () async {
      for (final type in <String>['rechnung_ausgang', 'gutschrift', 'storno', 'unsupported']) {
        final invoiceId = await createDocument(type: type);
        final outgoingCounterBefore = (await db.executor.runSelect(
          "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' LIMIT 1",
          const <Object?>[],
        )).single['naechste_nummer'];
        await expectLater(ds.finalizeRechnung(rechnungId: invoiceId, locale: 'de_DE'), throwsA(isA<StateError>()));
        final persisted = await document(invoiceId);
        expect(persisted['ist_entwurf'], 1);
        expect(persisted['rechnungsnummer'], isNull);
        expect(
          await db.executor.runSelect('SELECT id FROM journal WHERE rechnung_id = ?', <Object?>[invoiceId]),
          isEmpty,
        );
        expect(
          (await db.executor.runSelect(
            "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' LIMIT 1",
            const <Object?>[],
          )).single['naechste_nummer'],
          outgoingCounterBefore,
        );
      }
    });

    test('test_incoming_range_failures_do_not_fallback', () async {
      final supplierId = await addSupplier();
      final range = (await db.executor.runSelect(
        "SELECT id, typ, format, naechste_nummer, aktiv FROM nummernkreise WHERE typ = 'rechnung_eingang' LIMIT 1",
        const <Object?>[],
      )).single;
      final outgoingCounter = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' LIMIT 1",
        const <Object?>[],
      )).single['naechste_nummer'];

      await db.executor.runCustom('DELETE FROM nummernkreise WHERE id = ${range['id']}');
      final absentRangeDraft = await createDocument(type: 'eingang', supplierId: supplierId);
      await expectLater(ds.finalizeRechnung(rechnungId: absentRangeDraft, locale: 'de_DE'), throwsA(isA<StateError>()));
      await db.executor.runInsert(
        'INSERT INTO nummernkreise (id, typ, format, naechste_nummer, aktiv) VALUES (?, ?, ?, ?, ?)',
        <Object?>[range['id'], range['typ'], range['format'], range['naechste_nummer'], range['aktiv']],
      );

      await db.executor.runUpdate('UPDATE nummernkreise SET aktiv = 0 WHERE id = ?', <Object?>[range['id']]);
      final inactiveRangeDraft = await createDocument(type: 'eingangsrechnung', supplierId: supplierId);
      await expectLater(
        ds.finalizeRechnung(rechnungId: inactiveRangeDraft, locale: 'de_DE'),
        throwsA(isA<StateError>()),
      );

      await db.executor.runUpdate('UPDATE nummernkreise SET aktiv = 1, format = ? WHERE id = ?', <Object?>[
        'invalid-no-sequence',
        range['id'],
      ]);
      final malformedRangeDraft = await createDocument(type: 'rechnung_eingang', supplierId: supplierId);
      await expectLater(
        ds.finalizeRechnung(rechnungId: malformedRangeDraft, locale: 'de_DE'),
        throwsA(isA<StateError>()),
      );

      expect(
        (await db.executor.runSelect(
          "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' LIMIT 1",
          const <Object?>[],
        )).single['naechste_nummer'],
        outgoingCounter,
      );
      for (final id in <int>[absentRangeDraft, inactiveRangeDraft, malformedRangeDraft]) {
        final persisted = await document(id);
        expect(persisted['ist_entwurf'], 1);
        expect(persisted['rechnungsnummer'], isNull);
      }
    });
  });
}
