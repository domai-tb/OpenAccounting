// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  group(
    'Correction document accounting integrity',
    skip: 'pending correction-document implementation (0/12 tasks)',
    () {
      late AppDatabase db;
      late RechnungenDataSource ds;

      setUp(() async {
        db = AppDatabase.createTestDatabase();
        await db.ensureOpen();
        ds = RechnungenDataSource(db.executor);

        // Ensure gutschrift nummernkreis has a usable format and is active
        await db.executor.runCustom(
          "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1, aktiv = 1 "
          "WHERE typ = 'gutschrift'",
        );
      });

      tearDown(() async => db.close());

      // ── Task 1: Correction totals preserve signed VAT mathematics ──

      test('test_correction_document_accounting_integrity_1_1_mixed_rate_credit_note_reverses_tax', () async {
        // Create source invoice with mixed VAT rates
        final int srcId = await ds.createDraftRechnung(
          datum: '2025-07-01',
          positionen: [
            const RechnungPositionItem(bezeichnung: '19% Artikel', menge: 1, einzelpreis: 119, gesamt: 119),
            const RechnungPositionItem(bezeichnung: '7% Artikel', menge: 1, einzelpreis: 107, gesamt: 107, ustSatz: 7),
            const RechnungPositionItem(bezeichnung: '0% Artikel', menge: 1, einzelpreis: 100, gesamt: 100, ustSatz: 0),
          ],
          eingabemodus: 'brutto',
        );

        // Finalize the invoice
        await ds.finalizeRechnung(rechnungId: srcId);

        // Create credit note (Gutschrift)
        final int gsId = await ds.createGutschrift(vonRechnungId: srcId);

        // Read the credit note header
        final rows = await db.executor.runSelect(
          'SELECT netto_betrag, brutto_betrag, ust_betrag FROM rechnungen WHERE id = ?',
          <Object?>[gsId],
        );
        final row = rows.single;

        // Netto: -(100 + 100 + 100) = -300.00
        expect(row['netto_betrag'].toString(), '-300.00', reason: 'netto must sum signed position nets');
        // USt: -(19 + 7 + 0) = -26.00
        expect(row['ust_betrag'].toString(), '-26.00', reason: 'ust must calculate from signed positions');
        // Brutto: -(119 + 107 + 100) = -326.00
        expect(row['brutto_betrag'].toString(), '-326.00', reason: 'brutto must sum signed position gross');
      });

      test('test_correction_document_accounting_integrity_1_2_invalid_source_totals_are_not_copied', () async {
        // Create a valid invoice
        final int srcId = await ds.createDraftRechnung(
          datum: '2025-07-01',
          positionen: [const RechnungPositionItem(bezeichnung: 'Artikel', menge: 2, einzelpreis: 100, gesamt: 200)],
        );
        await ds.finalizeRechnung(rechnungId: srcId);

        // Corrupt the source header totals (simulate bad data)
        await db.executor.runCustom(
          'UPDATE rechnungen SET netto_betrag = 999.00, ust_betrag = 0.00, brutto_betrag = 999.00 WHERE id = ?',
          <Object?>[srcId],
        );

        // Create credit note — should recalculate from positions, not copy corrupted header
        final int gsId = await ds.createGutschrift(vonRechnungId: srcId);

        final rows = await db.executor.runSelect(
          'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
          <Object?>[gsId],
        );
        final row = rows.single;

        // Must use position amounts, not corrupted header
        expect(row['netto_betrag'].toString(), '-200.00', reason: 'netto must come from positions');
        expect(row['ust_betrag'].toString(), '-38.00', reason: 'ust must be calculated');
        expect(row['brutto_betrag'].toString(), '-238.00', reason: 'brutto must come from positions');
      });

      // ── Task 2: Replacement and reversal links are complete and unique ──

      test('test_correction_document_accounting_integrity_2_1_second_replacement_is_rejected', () async {
        // Create and finalize invoice
        final int srcId = await ds.createDraftRechnung(
          datum: '2025-07-01',
          positionen: [const RechnungPositionItem(bezeichnung: 'Artikel', menge: 1, einzelpreis: 100, gesamt: 100)],
        );
        await ds.finalizeRechnung(rechnungId: srcId);

        // Storno the invoice
        await ds.stornoRechnung(rechnungId: srcId, grund: 'Fehlerhaft');

        // Create first replacement
        final int ersatz1 = await ds.createErsatzRechnung(vonRechnungId: srcId);
        expect(ersatz1, greaterThan(0));

        // Second replacement must be rejected
        expect(
          () => ds.createErsatzRechnung(vonRechnungId: srcId),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('bereits vorhanden'))),
        );
      });

      test('test_correction_document_accounting_integrity_2_2_a_valid_correction_is_traceable', () async {
        // Create and finalize invoice
        final int srcId = await ds.createDraftRechnung(
          datum: '2025-07-01',
          positionen: [const RechnungPositionItem(bezeichnung: 'Artikel', menge: 1, einzelpreis: 100, gesamt: 100)],
        );
        await ds.finalizeRechnung(rechnungId: srcId);

        // Storno
        await ds.stornoRechnung(rechnungId: srcId, grund: 'Fehlerhaft');

        // Create replacement
        final int ersatzId = await ds.createErsatzRechnung(vonRechnungId: srcId);

        // Verify bidirectional link
        final srcRow = (await db.executor.runSelect('SELECT ersatzrechnung_id FROM rechnungen WHERE id = ?', <Object?>[
          srcId,
        ])).single;
        expect(srcRow['ersatzrechnung_id'], equals(ersatzId), reason: 'source must point to replacement');

        final ersatzRow = (await db.executor.runSelect('SELECT ersatz_fuer FROM rechnungen WHERE id = ?', <Object?>[
          ersatzId,
        ])).single;
        expect(ersatzRow['ersatz_fuer'], equals(srcId), reason: 'replacement must point to source');
      });
    },
  );
}
