// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  group('Invoice accounting posting lifecycle', () {
    late AppDatabase db;
    late RechnungenDataSource ds;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      ds = RechnungenDataSource(db.executor);
    });

    tearDown(() async => db.close());

    Future<int> insertKunde() async {
      return db.executor.runInsert('INSERT INTO kunden (name, strasse, plz, ort) VALUES (?, ?, ?, ?)', const <Object?>[
        'Test Kunde',
        'Musterweg 1',
        '10115',
        'Berlin',
      ]);
    }

    Future<int> insertLieferant() async {
      return db.executor.runInsert('INSERT INTO lieferanten (name) VALUES (?)', const <Object?>['Test Lieferant']);
    }

    Future<int> createDraftWithPositions({required int kundeId, List<RechnungPositionItem>? positionen}) async {
      final pos =
          positionen ??
          const <RechnungPositionItem>[
            RechnungPositionItem(bezeichnung: 'Leistung', menge: 1, einzelpreis: 100, gesamt: 100),
          ];
      final int id = await ds.createDraftRechnung(datum: '2026-01-15', positionen: pos);
      await db.executor.runUpdate('UPDATE rechnungen SET kunde_id = ? WHERE id = ?', <Object?>[kundeId, id]);
      return id;
    }

    test('test_invoice_accounting_posting_lifecycle_1_1_outgoing_invoice_creates_a_receivable', () async {
      final int kundeId = await insertKunde();
      final int rechnungId = await createDraftWithPositions(kundeId: kundeId);

      await ds.finalizeRechnung(rechnungId: rechnungId);

      final rechnung = (await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ])).single;
      expect(rechnung['ist_entwurf'], 0);
      expect(rechnung['status'], 'offen');
      expect(rechnung['rechnungsnummer'], isNotNull);

      final journals = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(journals.length, 1, reason: 'outgoing must create one journal posting');
      expect(journals.single['beleg_typ'], 'Einnahme');
      expect(double.parse(journals.single['betrag'].toString()), closeTo(119.0, 0.001));
      expect(journals.single['gruppe_id'], journals.single['id']);

      final forderungen = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(forderungen.length, 1, reason: 'outgoing must create one receivable');
      expect(forderungen.single['typ'], 'rechnung');
      expect(forderungen.single['partner_typ'], 'kunde');
      expect(forderungen.single['partner_id'], kundeId);
      expect(double.parse(forderungen.single['betrag'].toString()), closeTo(119.0, 0.001));
      expect(forderungen.single['journal_id'], journals.single['id']);

      // Outgoing with VAT also creates tax claim in current minimal model — assert presence
      final taxes = await db.executor.runSelect('SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(taxes.length, 1);
      expect(double.parse(taxes.single['betrag'].toString()), closeTo(19.0, 0.001));
    });

    test('test_invoice_accounting_posting_lifecycle_1_2_incoming_invoice_creates_input_tax_state', () async {
      final int lieferantId = await insertLieferant();
      final int rechnungId = await ds.createDraftRechnung(
        datum: '2026-01-15',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Fremdleistung', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
      );
      await db.executor.runUpdate('UPDATE rechnungen SET lieferant_id = ? WHERE id = ?', <Object?>[
        lieferantId,
        rechnungId,
      ]);

      await ds.finalizeRechnung(rechnungId: rechnungId);

      final journals = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(journals.length, 1);
      expect(journals.single['beleg_typ'], 'Ausgabe');
      expect(double.parse(journals.single['betrag'].toString()), closeTo(119.0, 0.001));

      final forderungen = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(forderungen.length, 1);
      expect(forderungen.single['typ'], 'rechnung_eingang');
      expect(forderungen.single['partner_typ'], 'lieferant');
      expect(forderungen.single['partner_id'], lieferantId);

      final vorsteuer = await db.executor.runSelect(
        'SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      expect(vorsteuer.length, 1, reason: 'incoming must create input-tax claim');
      expect(double.parse(vorsteuer.single['betrag'].toString()), closeTo(19.0, 0.001));
      expect(vorsteuer.single['faelligkeit'], '2026-01-15');

      // No outgoing turnover created for incoming — beleg_typ is Ausgabe
      expect(journals.single['beleg_typ'] != 'Einnahme', isTrue);
    });

    test('test_invoice_accounting_posting_lifecycle_1_3_failure_leaves_no_partial_posting', () async {
      final int kundeId = await insertKunde();
      final int rechnungId = await createDraftWithPositions(kundeId: kundeId);

      final beforeKreis = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' LIMIT 1",
        const <Object?>[],
      )).single['naechste_nummer'];

      await expectLater(
        ds.finalizeRechnung(rechnungId: rechnungId, debugFailAt: 'receivable'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Induced'))),
      );

      final draft = (await db.executor.runSelect('SELECT ist_entwurf, status FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ])).single;
      expect(draft['ist_entwurf'], 1, reason: 'draft must remain draft after failure');
      expect(draft['status'], 'entwurf');

      final journals = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(journals, isEmpty, reason: 'no journal must remain after rollback');

      final forderungen = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(forderungen, isEmpty);

      final taxes = await db.executor.runSelect('SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(taxes, isEmpty);

      final afterKreis = (await db.executor.runSelect(
        "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' LIMIT 1",
        const <Object?>[],
      )).single['naechste_nummer'];
      expect(afterKreis, beforeKreis, reason: 'sequence must roll back');

      // Retry without fault must succeed and create all postings
      await ds.finalizeRechnung(rechnungId: rechnungId);
      final afterJournals = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(afterJournals.length, 1);
      final afterForderungen = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(afterForderungen.length, 1);
    });

    test('test_invoice_accounting_posting_lifecycle_2_1_retry_does_not_duplicate_accounting', () async {
      final int kundeId = await insertKunde();
      final int rechnungId = await createDraftWithPositions(kundeId: kundeId);

      await ds.finalizeRechnung(rechnungId: rechnungId);

      final countBeforeJournals = (await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM journal WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      )).single['c'];
      final countBeforeForderungen = (await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM forderungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      )).single['c'];
      final countBeforeTax = (await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      )).single['c'];

      await expectLater(
        ds.finalizeRechnung(rechnungId: rechnungId),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('bereits finalisiert'))),
      );

      final countAfterJournals = (await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM journal WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      )).single['c'];
      final countAfterForderungen = (await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM forderungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      )).single['c'];
      final countAfterTax = (await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      )).single['c'];

      expect(countAfterJournals, countBeforeJournals);
      expect(countAfterForderungen, countBeforeForderungen);
      expect(countAfterTax, countBeforeTax);

      final rows = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', <Object?>[rechnungId]);
      expect(rows.single['status'], 'offen');
    });

    test('test_invoice_accounting_posting_lifecycle_2_2_correction_can_find_its_source', () async {
      final int kundeId = await insertKunde();
      final int rechnungId = await createDraftWithPositions(kundeId: kundeId);

      await ds.finalizeRechnung(rechnungId: rechnungId);

      // Seed storno nummernkreis format
      await db.executor.runCustom("UPDATE nummernkreise SET format = 'ST-{NNN}' WHERE typ = 'stornorechnung'");

      // Verify source postings discoverable by stable rechnung_id linkage
      final journalBefore = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(journalBefore.length, 1);
      final forderungBefore = await db.executor.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(forderungBefore.length, 1);
      final taxBefore = await db.executor.runSelect(
        'SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      expect(taxBefore.length, 1);

      // Ensure journal grouping is stable after storno
      final originalGruppeId = journalBefore.single['gruppe_id'];
      final originalJournalId = journalBefore.single['id'];
      final originalBetrag = double.parse(journalBefore.single['betrag'].toString());
      final originalForBetrag = double.parse(forderungBefore.single['betrag'].toString());
      final originalTaxBetrag = double.parse(taxBefore.single['betrag'].toString());

      final int stornoId = await ds.stornoRechnung(rechnungId: rechnungId, grund: 'Korrektur');

      final stornoRow = (await db.executor.runSelect(
        'SELECT storno_von, status FROM rechnungen WHERE id = ?',
        <Object?>[stornoId],
      )).single;
      expect(stornoRow['storno_von'], rechnungId);
      // storno stores source via storno_von or status; verify source still traceable
      final sourceRow = (await db.executor.runSelect('SELECT status FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ])).single;
      expect(sourceRow['status'], 'storniert');

      final journalAfter = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      expect(journalAfter.length, 1, reason: 'original journal must not be orphaned by storno');
      expect(journalAfter.single['gruppe_id'], originalGruppeId);
      expect(journalAfter.single['rechnung_id'], rechnungId);

      // Reversal entries negated and linked to original
      final reversalJournals = await db.executor.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        stornoId,
      ]);
      expect(reversalJournals.length, 1, reason: 'storno must create one reversal journal');
      expect(reversalJournals.single['storno_von'], originalJournalId);
      expect(double.parse(reversalJournals.single['betrag'].toString()), closeTo(-originalBetrag, 0.001));
      expect(reversalJournals.single['beleg_typ'], journalBefore.single['beleg_typ']);
      expect(reversalJournals.single['gruppe_id'], reversalJournals.single['id']);

      final reversalForderungen = await db.executor.runSelect(
        'SELECT * FROM forderungen WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      expect(reversalForderungen.length, 1, reason: 'storno must create one reversal receivable');
      expect(double.parse(reversalForderungen.single['betrag'].toString()), closeTo(-originalForBetrag, 0.001));
      expect(reversalForderungen.single['partner_typ'], forderungBefore.single['partner_typ']);
      expect(reversalForderungen.single['partner_id'], forderungBefore.single['partner_id']);
      expect(reversalForderungen.single['journal_id'], reversalJournals.single['id']);

      final reversalTax = await db.executor.runSelect(
        'SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      expect(reversalTax.length, 1, reason: 'storno must create one reversal tax');
      expect(double.parse(reversalTax.single['betrag'].toString()), closeTo(-originalTaxBetrag, 0.001));

      // Net zero check
      final sumJournals = originalBetrag + double.parse(reversalJournals.single['betrag'].toString());
      expect(sumJournals, closeTo(0, 0.001));
    });

    test('test_invoice_accounting_posting_lifecycle_2_3_storno_retry_is_idempotent', () async {
      final int kundeId = await insertKunde();
      final int rechnungId = await createDraftWithPositions(kundeId: kundeId);
      await ds.finalizeRechnung(rechnungId: rechnungId);
      await db.executor.runCustom("UPDATE nummernkreise SET format = 'ST-{NNN}' WHERE typ = 'stornorechnung'");

      final int stornoId = await ds.stornoRechnung(rechnungId: rechnungId, grund: 'Erststorno');
      final beforeJournals = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM journal WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      final beforeForderungen = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM forderungen WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      final beforeTax = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );

      await expectLater(
        ds.stornoRechnung(rechnungId: rechnungId, grund: 'Zweitstorno'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('bereits storniert'))),
      );

      final afterJournals = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM journal WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      final afterForderungen = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM forderungen WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      final afterTax = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[stornoId],
      );
      expect(afterJournals.single['c'], beforeJournals.single['c']);
      expect(afterForderungen.single['c'], beforeForderungen.single['c']);
      expect(afterTax.single['c'], beforeTax.single['c']);

      // No second storno row created
      final stornoCount = await db.executor.runSelect(
        'SELECT COUNT(*) as c FROM rechnungen WHERE storno_von = ?',
        <Object?>[rechnungId],
      );
      expect(stornoCount.single['c'], 1);
    });
  });
}
