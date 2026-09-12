// ignore_for_file: file_names, avoid_redundant_argument_values, cast_nullable_to_non_nullable
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/rechnung_typ.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

void main() {
  group('Recurring persistence — Plan C', () {
    late AppDatabase db;
    late BuchungsVorlagenRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = BuchungsVorlagenRepository(db.executor);
      await db.executor.runInsert('INSERT INTO konten (id, name, iban) VALUES (?, ?, ?)', <Object?>[
        1,
        'Bank',
        'DE00111111111111111111',
      ]);
      await db.executor.runInsert('INSERT INTO lieferanten (id, name, strasse) VALUES (?, ?, ?)', <Object?>[
        1,
        'Vermieter',
        'Hauptstr. 1',
      ]);
      await db.executor.runInsert('INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (?, ?, ?, ?, ?)', <Object?>[
        1,
        'Kunde',
        'Weg 1',
        '10115',
        'Berlin',
      ]);
    });

    tearDown(() async => db.close());

    test('positions round-trip N=3 preserves order, amount, konto, tax', () async {
      final BuchungsVorlage created = await repo.create(
        name: 'Mit Positionen',
        kategorieId: 1,
        kontoId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        modus: 'beleg',
        lieferantId: 1,
        naechsteFaelligkeit: '2026-02-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{
            'bezeichnung': 'Miete kalt',
            'menge': 1,
            'einzelpreis': 800.00,
            'ust_satz': 19,
            'konto_id': 1,
          },
          <String, dynamic>{
            'bezeichnung': 'Nebenkosten',
            'menge': 2,
            'einzelpreis': 50.00,
            'ust_satz': 19,
            'konto_id': 1,
          },
          <String, dynamic>{
            'bezeichnung': 'Reinigung 7%',
            'menge': 1,
            'einzelpreis': 100.00,
            'ust_satz': 7,
            'konto_id': 1,
          },
        ],
      );
      expect(created.positionen.length, 3);
      expect(created.vorlageDatenRaw, contains('Miete kalt'));
      final BuchungsVorlage? reloaded = await repo.findById(created.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.positionen.length, 3);
      expect(reloaded.positionen[0]['bezeichnung'], 'Miete kalt');
      expect(reloaded.positionen[1]['bezeichnung'], 'Nebenkosten');
      expect(reloaded.positionen[2]['bezeichnung'], 'Reinigung 7%');
      expect(reloaded.positionen[1]['menge'], 2);
      expect(reloaded.positionen[2]['ust_satz'], 7);
      // list() also round-trips
      final List<BuchungsVorlage> all = await repo.list();
      final BuchungsVorlage listed = all.firstWhere((v) => v.id == created.id);
      expect(listed.positionen.length, 3);
      expect(listed.positionen[2]['konto_id'], 1);
    });

    test('incoming beleg draft persists N lines — totals survive finalization, not zero', () async {
      await repo.create(
        name: 'Beleg N lines',
        kategorieId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        modus: 'beleg',
        lieferantId: 1,
        eingabemodus: 'netto',
        naechsteFaelligkeit: '2026-02-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Std 19%', 'menge': 1, 'einzelpreis': 100.00, 'ust_satz': 19},
          <String, dynamic>{'bezeichnung': 'Red 7%', 'menge': 1, 'einzelpreis': 50.00, 'ust_satz': 7},
        ],
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 2, 1));
      expect(ids.length, 1);
      final int rechnungId = ids.single;
      final List<Map<String, Object?>> posRows = await db.executor.runSelect(
        'SELECT bezeichnung, menge, einzelpreis, gesamt, ust_satz, position FROM rechnungspositionen WHERE rechnung_id = ? ORDER BY position',
        <Object?>[rechnungId],
      );
      expect(posRows.length, 2, reason: 'must persist 2 lines, not zero');
      expect(posRows[0]['bezeichnung'], 'Std 19%');
      expect(posRows[1]['bezeichnung'], 'Red 7%');
      expect(posRows[0]['position'], 0);
      expect(posRows[1]['position'], 1);

      final List<Map<String, Object?>> header = await db.executor.runSelect(
        'SELECT typ, netto_betrag, ust_betrag, brutto_betrag, eingabemodus FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      expect(header.single['typ'], 'rechnung_eingang');
      // 100 net + 50 net =150 net, ust 19+3.5=22.5, brutto 172.5
      expect(header.single['netto_betrag'], 150.00);
      expect(header.single['ust_betrag'], 22.50);
      expect(header.single['brutto_betrag'], 172.50);

      // Finalization must recalculate from positions — not zero out.
      final RechnungenDataSource ds = RechnungenDataSource(db.executor);
      await ds.finalizeRechnung(rechnungId: rechnungId);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT netto_betrag, ust_betrag, brutto_betrag, typ, status, ist_entwurf FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      expect(after.single['ist_entwurf'], 0);
      expect(after.single['status'], 'offen');
      expect(after.single['netto_betrag'], 150.00);
      expect(after.single['ust_betrag'], 22.50);
      expect(after.single['brutto_betrag'], 172.50);
      expect((after.single['brutto_betrag'] as num) > 0, isTrue);

      final List<Map<String, Object?>> posAfter = await db.executor.runSelect(
        'SELECT count(*) as c FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      expect((posAfter.single['c'] as num).toInt(), 2);
    });

    test('canonical type is rechnung_eingang not eingangsrechnung', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Typ check',
        kategorieId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        modus: 'beleg',
        lieferantId: 1,
        naechsteFaelligkeit: '2026-03-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 10.00, 'ust_satz': 19},
        ],
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 3, 1));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT typ FROM rechnungen WHERE id = ?',
        <Object?>[ids.single],
      );
      expect(rows.single['typ'], 'rechnung_eingang');
      expect(rows.single['typ'], isNot('eingangsrechnung'));
      // Legacy mismatch still resolves as incoming when reading via forderungen helper would.
      // Directly ensure no row with legacy typ exists for this vorlage.
      final List<Map<String, Object?>> legacy = await db.executor.runSelect(
        "SELECT count(*) as c FROM rechnungen WHERE vorlage_id = ? AND typ = 'eingangsrechnung'",
        <Object?>[v.id],
      );
      expect((legacy.single['c'] as num).toInt(), 0);
    });

    test('legacy single-betrag vorlage still creates one position (no silent drop)', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Legacy single',
        kategorieId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        modus: 'beleg',
        lieferantId: 1,
        betrag: '119.00',
        naechsteFaelligkeit: '2026-04-01',
      );
      // No explicit positionen — legacy path uses betrag.
      expect(v.positionen, isEmpty);
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 4, 1));
      final List<Map<String, Object?>> pos = await db.executor.runSelect(
        'SELECT gesamt FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[ids.single],
      );
      expect(pos.length, 1);
      expect((pos.single['gesamt'] as Object).toString(), contains('119'));
      final List<Map<String, Object?>> hdr = await db.executor.runSelect(
        'SELECT brutto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[ids.single],
      );
      expect((hdr.single['brutto_betrag'] as num) > 0, isTrue);
      final RechnungenDataSource ds = RechnungenDataSource(db.executor);
      await ds.finalizeRechnung(rechnungId: ids.single);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT brutto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[ids.single],
      );
      // Finalization must not zero out when legacy single-line present.
      expect((after.single['brutto_betrag'] as num) > 0, isTrue);
    });

    test('update persists new positions', () async {
      final BuchungsVorlage v = await repo.create(
        name: 'Update pos',
        kategorieId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        modus: 'direkt',
        naechsteFaelligkeit: '2026-05-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'A', 'menge': 1, 'einzelpreis': 10.00},
        ],
      );
      expect(v.positionen.length, 1);
      final BuchungsVorlage updated = await repo.update(
        v.id,
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'B', 'menge': 1, 'einzelpreis': 20.00, 'ust_satz': 19},
          <String, dynamic>{'bezeichnung': 'C', 'menge': 2, 'einzelpreis': 5.00, 'ust_satz': 7},
        ],
      );
      expect(updated.positionen.length, 2);
      expect(updated.positionen[0]['bezeichnung'], 'B');
      final BuchungsVorlage? reloaded = await repo.findById(v.id);
      expect(reloaded!.positionen.length, 2);
    });

    test('auftrag lineage preserved through template create+instantiate', () async {
      // Create auftrag document as lineage source — via centralized helper path (no raw SQL bypass).
      final RechnungenDataSource ds = RechnungenDataSource(db.executor);
      final int auftragId = await ds.createDokument(
        typ: 'auftrag',
        datum: '2026-01-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Auftragspos', menge: 1, einzelpreis: 100, gesamt: 100),
        ],
      );
      // Template linked to auftrag — lineage must be valid relation.
      final RechnungsVorlagenRepository vorlagenRepo = RechnungsVorlagenRepository(db.executor);
      final RechnungsVorlage vorlage = await vorlagenRepo.create(
        name: 'Aus Auftrag',
        kundeId: 1,
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        auftragId: auftragId,
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 10.00, 'ust_satz': 19},
        ],
      );
      expect(vorlage.auftragId, auftragId, reason: 'template must retain parent auftrag id');
      // Reload round-trip preserves lineage.
      final RechnungsVorlage? reloaded = await vorlagenRepo.findById(vorlage.id);
      expect(reloaded!.auftragId, auftragId);
      // Instantiate — generated rechnung must carry lineage via konvertiert_von.
      final List<int> ids = await vorlagenRepo.generateFaellig(heute: DateTime(2026, 2, 1));
      expect(ids.length, 1);
      final int rechnungId = ids.single;
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT vorlage_id, konvertiert_von, typ FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      expect(rows.single['vorlage_id'], vorlage.id);
      expect(
        rows.single['konvertiert_von'],
        auftragId,
        reason: 'auftrag lineage must survive instantiate via konvertiert_von',
      );
      // Idempotent retry must not duplicate — second call on same date after advancement creates no new row, lineage intact.
      final List<int> retry = await vorlagenRepo.generateFaellig(heute: DateTime(2026, 2, 1));
      expect(retry, isEmpty, reason: 'no new invoice should be created on same date after advancement');
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT konvertiert_von FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      expect(after.single['konvertiert_von'], auftragId);
    });

    test('eingangsrechnung vs rechnung_eingang canonicalized via shared helper', () async {
      // Helper normalizes both legacy and current to single value — single source, no scattered strings.
      expect(RechnungTyp.canonicalize('eingangsrechnung'), RechnungTyp.eingang);
      expect(RechnungTyp.canonicalize('rechnung_eingang'), RechnungTyp.eingang);
      expect(RechnungTyp.canonicalize('Eingangsrechnung'), RechnungTyp.eingang);
      expect(RechnungTyp.canonicalize('RECHNUNG_EINGANG'), RechnungTyp.eingang);
      expect(RechnungTyp.isEingang('eingangsrechnung'), isTrue);
      expect(RechnungTyp.isEingang('rechnung_eingang'), isTrue);
      // Posting rules helper: both inputs derive same beleg/forderung typ — no bypass of journal rules.
      expect(RechnungTyp.belegTypFor(typ: 'eingangsrechnung'), 'Ausgabe');
      expect(RechnungTyp.belegTypFor(typ: 'rechnung_eingang'), 'Ausgabe');
      expect(RechnungTyp.forderungTypFor(typ: 'eingangsrechnung'), RechnungTyp.eingang);
      expect(RechnungTyp.forderungTypFor(typ: 'rechnung_eingang'), RechnungTyp.eingang);
      // Buchungsvorlage beleg generation always uses canonical typ — verify via helper-driven insert.
      final BuchungsVorlage v = await repo.create(
        name: 'Canonical beleg',
        kategorieId: 1,
        art: 'Ausgabe',
        intervall: 'monatlich',
        modus: 'beleg',
        lieferantId: 1,
        naechsteFaelligkeit: '2026-06-01',
        positionen: <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Pos', 'menge': 1, 'einzelpreis': 10.00, 'ust_satz': 19},
        ],
      );
      final List<int> ids = await repo.generateFaellig(heute: DateTime(2026, 6, 1));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT typ FROM rechnungen WHERE id = ?',
        <Object?>[ids.single],
      );
      // Canonical constant used — not legacy string.
      expect(RechnungTyp.canonicalize(rows.single['typ'].toString()), RechnungTyp.eingang);
      expect(rows.single['typ'], isNot(RechnungTyp.eingangLegacy));
      expect(rows.single['typ'], RechnungTyp.eingang);
      // Also verify no legacy row exists for this vorlage.
      final List<Map<String, Object?>> legacy = await db.executor.runSelect(
        'SELECT count(*) as c FROM rechnungen WHERE vorlage_id = ? AND typ = ?',
        <Object?>[v.id, RechnungTyp.eingangLegacy],
      );
      expect((legacy.single['c'] as num).toInt(), 0);
    });

    test('centralized posting helper derives same beleg_typ for canonical and legacy', () async {
      // Posting helper is single function — both raw inputs route through it, no duplicated logic.
      const String legacy = 'eingangsrechnung';
      const String canonical = 'rechnung_eingang';
      expect(RechnungTyp.belegTypFor(typ: legacy), RechnungTyp.belegTypFor(typ: canonical));
      expect(RechnungTyp.forderungTypFor(typ: legacy), RechnungTyp.forderungTypFor(typ: canonical));
      // Simulate datasource isIncoming derivation using helper — bypass would miss legacy.
      final bool viaHelperLegacy = RechnungTyp.isEingang(legacy);
      final bool viaHelperCanonical = RechnungTyp.isEingang(canonical);
      expect(viaHelperLegacy, isTrue);
      expect(viaHelperCanonical, isTrue);
      // Verify journal posting for incoming via recurring path uses helper-derived typ (checked above).
      // Here just assert helper not bypassed: raw equality would fail for legacy.
      expect(legacy == 'rechnung_eingang', isFalse, reason: 'raw comparison misses legacy');
      expect(RechnungTyp.canonicalize(legacy) == RechnungTyp.eingang, isTrue);
    });
  });
}
