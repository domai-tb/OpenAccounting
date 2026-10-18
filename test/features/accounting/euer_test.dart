import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/money.dart';
import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/accounting/posting_group_service.dart';
import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';
import 'package:openaccounting/features/mileage/mileage_entry_repository.dart';
import 'package:openaccounting/features/mileage/mileage_entry_usecases.dart';

void main() {
  group('EÜR Anlage 2025 — EÜR output matches line items', () {
    late AppDatabase db;
    late EuerService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      service = EuerService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertKategorie({required int id, required int zeile, String bezeichnung = 'Test Kategorie'}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[id, bezeichnung, '800$zeile', '400$zeile', zeile, 'catalog_verified', 'TEST-EUER', '2026-test.1'],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String art = 'Einnahme',
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, art],
      );
    }

    test('Zeile 12 — Kleinunternehmer §19 sums brutto_betrag', () async {
      await insertKategorie(id: 901, zeile: 12, bezeichnung: 'Kleinunternehmer');
      await insertJournal(kategorieId: 901, betrag: '1000.00', datum: '2025-02-15');
      await insertJournal(kategorieId: 901, betrag: '500.50', datum: '2025-06-01');

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(12), '1500.50');
      expect(result.zeilen[12], '1500.50');
    });

    test('Zeile 15 — 19% + 7% Betriebseinnahmen combined', () async {
      await insertKategorie(id: 902, zeile: 15, bezeichnung: 'Ust-pflichtig');
      await insertJournal(kategorieId: 902, betrag: '2000.00', datum: '2025-03-10');
      await insertJournal(kategorieId: 902, betrag: '300.00', datum: '2025-04-20');

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(15), '2300.00');
    });

    test('Zeile 16 — Steuerfreie Betriebseinnahmen §4', () async {
      await insertKategorie(id: 903, zeile: 16, bezeichnung: 'Steuerfrei');
      await insertJournal(kategorieId: 903, betrag: '750.25', datum: '2025-05-05');

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(16), '750.25');
    });

    test('Zeile 33 — Abschreibungen AfA via anlageverzeichnis not journal', () async {
      await insertKategorie(id: 904, zeile: 33, bezeichnung: 'AfA Kategorie');
      // Journal entry for 33 must be ignored.
      await insertJournal(kategorieId: 904, betrag: '9999.99', datum: '2025-07-01');

      // Anlageverzeichnis: 1200 / 3 = 400.00 linear, no privat.
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'privatanteil, status, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, '
        'privat_anteil_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Laptop', '2022-01-01', '1200.00', 3, '0', 'aktiv', 'EDV', '1200.00', 3, 'linear', '0'],
      );

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(33), '400.00');
      expect(result.zeile(33) != '9999.99', isTrue);
    });

    test('Zeile 60 — Sonstige Betriebsausgaben 13b', () async {
      await insertKategorie(id: 905, zeile: 60, bezeichnung: 'Bauleistung 13b');
      await insertJournal(kategorieId: 905, betrag: '420.00', datum: '2025-08-12', art: 'Ausgabe');

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(60), '420.00');
    });

    test('Zeile 106/107 — Privatentnahme/Privateinlage Hinweis without Gewinn impact', () async {
      await insertKategorie(id: 906, zeile: 12, bezeichnung: 'Einnahme');
      await insertKategorie(id: 907, zeile: 60, bezeichnung: 'Ausgabe');
      await insertKategorie(id: 908, zeile: 106, bezeichnung: 'Privatentnahme');
      await insertKategorie(id: 909, zeile: 107, bezeichnung: 'Privateinlage');

      await insertJournal(kategorieId: 906, betrag: '1000.00', datum: '2025-01-10');
      await insertJournal(kategorieId: 907, betrag: '200.00', datum: '2025-02-10', art: 'Ausgabe');
      await insertJournal(kategorieId: 908, betrag: '500.00', datum: '2025-03-10', art: 'Ausgabe');
      await insertJournal(kategorieId: 909, betrag: '300.00', datum: '2025-04-10');

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(106), '500.00');
      expect(result.zeile(107), '300.00');
      expect(result.hinweise[106], '500.00');
      expect(result.hinweise[107], '300.00');
      // Gewinn = Einnahmen(1000) - Ausgaben(200) = 800, Hinweis excluded.
      expect(result.gewinn, '800.00');
    });

    test('Vorsteuer Soll-Prinzip uses vorsteuer_ansprueche not journal.vorsteuer_betrag after cutover', () async {
      const String cutover = '2025-01-01';
      final DateTime cutoverDatum = DateTime(2025);

      // Vorsteuer Anspruch Soll: two entries 190 + 19 = 209.
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status) VALUES (?, ?, ?)',
        <Object?>['190.00', '2025-03-15', 'offen'],
      );
      await db.executor.runInsert(
        'INSERT INTO vorsteuer_ansprueche (betrag, faelligkeit, status) VALUES (?, ?, ?)',
        <Object?>['19.00', '2025-04-10', 'offen'],
      );

      // Journal entry that would be Zahlungsprinzip if used — ensure not counted after cutover.
      await insertKategorie(id: 910, zeile: 15, bezeichnung: 'Umsatz');
      await insertJournal(kategorieId: 910, betrag: '1000.00', datum: '2025-05-01');

      // Try to insert journal.vorsteuer_betrag if column exists — should be ignored after cutover.
      try {
        await db.executor.runCustom(
          'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, vorsteuer_betrag, immutable) VALUES (?, ?, ?, ?, ?, ?, 0)',
          <Object?>['2025-05-01', 'Mit Vorsteuer', 910, '1000.00', 'Ausgabe', '999.99'],
        );
      } catch (_) {
        // Column missing is expected in current DDL — ponytail fallback keeps 0.
      }

      final result = await service.generate(jahr: 2025, cutoverDatum: cutoverDatum);

      // Must equal ansprueche sum, not journal's 999.99.
      expect(result.vorsteuerBetrag, '209.00');
      expect(cutover, isNotEmpty); // keep CUTOVER_DATUM reference for spec trace
    });

    test('empty period all 0 and Gewinn 0', () async {
      final result = await service.generate(jahr: 2024);

      expect(result.gewinn, '0.00');
      expect(result.vorsteuerBetrag, '0.00');
      expect(result.zeile(12), '0.00');
      expect(result.zeile(15), '0.00');
      expect(result.zeile(33), '0.00');
      expect(result.zeile(60), '0.00');
      expect(result.hinweise[106], '0.00');
      expect(result.hinweise[107], '0.00');
      // All zeilen present as 0.00
      for (int z = 12; z <= 107; z++) {
        expect(result.zeilen.containsKey(z), isTrue, reason: 'Zeile $z missing');
      }
    });

    test('60+ Zeilen coverage and string money 0.00', () async {
      final result = await service.generate(jahr: 2025);

      expect(result.zeilen.length, greaterThanOrEqualTo(60));
      expect(result.zeilen.containsKey(12), isTrue);
      expect(result.zeilen.containsKey(107), isTrue);
      // Spot check formatting — string with 2 decimals.
      for (final entry in result.zeilen.entries) {
        expect(entry.value, matches(RegExp(r'^-?\d+\.\d{2}$')), reason: 'Zeile ${entry.key} not 0.00 format');
      }
    });

    test('AfA privatanteil reduces business portion', () async {
      // 1200 / 4 =300, privat 30% => 210.00
      await db.executor.runInsert(
        'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
        'privatanteil, status, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, afa_methode, '
        'privat_anteil_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['KFZ', '2022-01-01', '1200.00', 4, '30', 'aktiv', 'KFZ', '1200.00', 4, 'linear', '30'],
      );

      final result = await service.generate(jahr: 2025);

      expect(result.zeile(33), '210.00');
    });
  });

  group('mileage posting and EÜR integration', () {
    late AppDatabase db;
    late EuerService mileageEuer;
    late MileageEntryRepository mileageRepository;
    late MileageEntryUseCases mileageUseCases;
    late PostingGroupService postingService;
    late int expenseAccountId;
    late int contributionAccountId;
    late int incomeAccountId;
    late int cashAccountId;
    late int expenseCategoryId;
    late int contributionCategoryId;
    late int incomeCategoryId;

    Future<int> insertCategory({required String label, required String art, required int euerLine}) async {
      final int categoryId = await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, art, konto_skr03, konto_skr04, euer_zeile, aktiv, mapping_status, '
        'catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[label, art, '700$euerLine', '400$euerLine', euerLine, 'catalog_verified', 'TEST-MILEAGE', '1'],
      );
      await db.executor.runInsert(
        'INSERT INTO category_mapping_history (kategorie_id, geaendert_am, aktion, vorher_mapping_json, '
        'nachher_mapping_json, katalog_quelle, katalog_version) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          categoryId,
          DateTime.now().toUtc().toIso8601String(),
          'catalog_import',
          null,
          jsonEncode(<String, Object?>{'mapping_status': 'catalog_verified', 'euer_zeile': euerLine}),
          'TEST-MILEAGE',
          '1',
        ],
      );
      return categoryId;
    }

    Future<void> configureMapping() => postingService.configureMileagePostingRoles(
      travelExpenseKontoId: expenseAccountId,
      travelExpenseKategorieId: expenseCategoryId,
      privateContributionKontoId: contributionAccountId,
      privateContributionKategorieId: contributionCategoryId,
    );

    Future<MileageTrip> createCalculatedTrip() async {
      final MileageTrip trip = await mileageUseCases.recordBusinessTrip(
        tripDate: '2025-05-12',
        purpose: 'Kundenbesuch',
        businessContext: 'Testprojekt',
        distanceHundredthsKm: 1000,
        tripKind: MileageTripKind.businessTrip,
        vehicleSource: MileageVehicleSource.private,
        vehicleClass: MileageVehicleClass.kraftwagen,
      );
      return mileageUseCases.calculateTrip(trip.id);
    }

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      mileageEuer = EuerService(db.executor);
      mileageRepository = MileageEntryRepository(db.executor);
      mileageUseCases = MileageEntryUseCases(mileageRepository);
      postingService = PostingGroupService(db.executor);

      expenseAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Mileage expense Sachkonto', 'Sachkonto'],
      );
      contributionAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Mileage private contribution Sachkonto', 'Sachkonto'],
      );
      incomeAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart) VALUES (?, ?)',
        const <Object?>['Settlement income Sachkonto', 'Sachkonto'],
      );
      cashAccountId = await db.executor.runInsert('INSERT INTO konten (name, kontoart) VALUES (?, ?)', const <Object?>[
        'Test cash account',
        'Kasse',
      ]);
      expenseCategoryId = await insertCategory(label: 'Travel expense', art: 'ausgabe', euerLine: 71);
      contributionCategoryId = await insertCategory(label: 'Private contribution', art: 'einnahme', euerLine: 107);
      incomeCategoryId = await insertCategory(label: 'Cash receipt', art: 'einnahme', euerLine: 12);
    });

    tearDown(() async {
      await db.close();
    });

    test('posting stays unavailable until both explicit account-role mappings exist', () async {
      final MileageTrip trip = await createCalculatedTrip();

      await expectLater(() => mileageUseCases.postTrip(trip.id), throwsA(isA<PostingException>()));

      final MileageTrip unchanged = (await mileageRepository.getById(trip.id))!;
      expect(unchanged.state, MileageTripState.calculated);
      expect(unchanged.postingEventId, isNull);
      final List<Map<String, Object?>> legs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
        <Object?>[PostingSource.mileageTrip, trip.id],
      );
      expect(legs, isEmpty);
    });

    test('direct SQL cannot post a two-leg mileage group without complete snapshots', () async {
      await configureMapping();
      final MileageTrip trip = await createCalculatedTrip();

      final int rootId = await db.executor.runInsert(
        'INSERT INTO journal (datum, kategorie_id, konto_id, betrag, soll, haben, beschreibung, immutable, beleg_typ, '
        'soll_konto_id, source_kind, source_id, legacy_unverified) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, 0)',
        <Object?>[
          trip.tripDate,
          expenseCategoryId,
          expenseAccountId,
          3.00,
          3.00,
          0.00,
          'Fahrt',
          'Ausgabe',
          expenseAccountId,
          PostingSource.mileageTrip,
          trip.id,
        ],
      );
      await db.executor.runUpdate('UPDATE journal SET gruppe_id = ? WHERE id = ?', <Object?>[rootId, rootId]);
      final int contributionId = await db.executor.runInsert(
        'INSERT INTO journal (datum, kategorie_id, konto_id, betrag, soll, haben, beschreibung, immutable, beleg_typ, '
        'haben_konto_id, gruppe_id, source_kind, source_id, legacy_unverified) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, 0)',
        <Object?>[
          trip.tripDate,
          contributionCategoryId,
          contributionAccountId,
          -3.00,
          0.00,
          3.00,
          'Fahrt',
          'Ausgabe',
          contributionAccountId,
          rootId,
          PostingSource.mileageTrip,
          trip.id,
        ],
      );
      await db.executor.runUpdate('UPDATE journal SET immutable = 1 WHERE id IN (?, ?)', <Object?>[
        rootId,
        contributionId,
      ]);

      await expectLater(
        () => db.executor.runCustom(
          "UPDATE mileage_trips SET state = 'posted', posting_event_id = "
          "'de305d54-75b4-431b-adb2-eb6b9e546014' WHERE id = ?",
          <Object?>[trip.id],
        ),
        throwsA(isA<Exception>()),
      );
      final MileageTrip unchanged = (await mileageRepository.getById(trip.id))!;
      expect(unchanged.state, MileageTripState.calculated);
      expect(unchanged.postingEventId, isNull);
    });

    test('direct SQL cannot apply a mileage correction with a fabricated accounting event id', () async {
      await configureMapping();
      final MileageTrip voidedSource = await createCalculatedTrip();
      final MileageTrip replacedSource = await createCalculatedTrip();
      final MileageTrip replacement = await createCalculatedTrip();
      for (final MileageTrip trip in <MileageTrip>[voidedSource, replacedSource, replacement]) {
        await mileageUseCases.postTrip(trip.id);
      }

      final List<String> attemptedTerminalStates = <String>[];
      for (final ({MileageTrip source, String kind, MileageTrip? replacement, String terminalState}) correction
          in <({MileageTrip source, String kind, MileageTrip? replacement, String terminalState})>[
            (source: voidedSource, kind: 'void', replacement: null, terminalState: 'voided'),
            (source: replacedSource, kind: 'replace', replacement: replacement, terminalState: 'corrected'),
          ]) {
        final String correctionId = 'fake-correction-${correction.kind}';
        await db.executor.runInsert(
          'INSERT INTO mileage_trip_corrections '
          '(id, trip_id, kind, replacement_trip_id, reason, state, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            correctionId,
            correction.source.id,
            correction.kind,
            correction.replacement?.id,
            'Test correction',
            'draft',
            '2026-10-18T12:00:00Z',
          ],
        );
        try {
          await db.executor.runUpdate(
            "UPDATE mileage_trip_corrections SET state = 'applied', accounting_correction_id = ?, "
            'applied_at = ? WHERE id = ?',
            <Object?>['fabricated-accounting-id', '2026-10-18T12:01:00Z', correctionId],
          );
          attemptedTerminalStates.add(correction.terminalState);
        } catch (_) {}
        try {
          await db.executor.runUpdate('UPDATE mileage_trips SET state = ? WHERE id = ?', <Object?>[
            correction.terminalState,
            correction.source.id,
          ]);
          attemptedTerminalStates.add('trip:${correction.terminalState}');
        } catch (_) {}
      }

      final List<Map<String, Object?>> corrections = await db.executor.runSelect(
        'SELECT state, accounting_correction_id FROM mileage_trip_corrections ORDER BY id',
        const <Object?>[],
      );
      final List<Map<String, Object?>> trips = await db.executor.runSelect(
        'SELECT state, posting_event_id FROM mileage_trips WHERE id IN (?, ?, ?) ORDER BY id',
        <Object?>[voidedSource.id, replacedSource.id, replacement.id],
      );
      expect(attemptedTerminalStates, isEmpty);
      expect(corrections, everyElement(<String, Object?>{'state': 'draft', 'accounting_correction_id': null}));
      expect(
        trips,
        everyElement(
          predicate<Map<String, Object?>>(
            (Map<String, Object?> row) => row['state'] == 'posted' && row['posting_event_id'] != null,
          ),
        ),
      );
    });

    test('posting fails closed when the trip date is in a closed range', () async {
      await configureMapping();
      final MileageTrip trip = await createCalculatedTrip();
      await expectLater(
        () => db.executor.runInsert(
          'INSERT INTO mileage_posting_period_closures (closed_from, closed_through, closed_at) VALUES (?, ?, ?)',
          <Object?>['not-a-date', 'not-a-date', '2026-10-18T12:00:00Z'],
        ),
        throwsA(isA<Exception>()),
      );
      await db.executor.runInsert(
        'INSERT INTO mileage_posting_period_closures (closed_from, closed_through, closed_at) VALUES (?, ?, ?)',
        <Object?>[trip.tripDate, trip.tripDate, '2026-10-18T12:00:00Z'],
      );

      await expectLater(() => mileageUseCases.postTrip(trip.id), throwsA(isA<PostingException>()));

      final MileageTrip unchanged = (await mileageRepository.getById(trip.id))!;
      expect(unchanged.state, MileageTripState.calculated);
      expect(unchanged.postingEventId, isNull);
      final List<Map<String, Object?>> legs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
        <Object?>[PostingSource.mileageTrip, trip.id],
      );
      expect(legs, isEmpty);
    });

    test('posting is atomic, idempotent, rejects conflicting retry, and snapshots both legs', () async {
      await configureMapping();
      final MileageTrip trip = await createCalculatedTrip();

      await db.executor.runCustom('''
CREATE TRIGGER fail_test_mileage_post
BEFORE UPDATE ON mileage_trips
WHEN NEW.state = 'posted'
BEGIN
  SELECT RAISE(ABORT, 'forced mileage state update failure');
END''');

      await expectLater(() => mileageUseCases.postTrip(trip.id), throwsA(isA<PostingException>()));
      final MileageTrip rolledBack = (await mileageRepository.getById(trip.id))!;
      expect(rolledBack.state, MileageTripState.calculated);
      expect(rolledBack.postingEventId, isNull);
      final List<Map<String, Object?>> rolledBackLegs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
        <Object?>[PostingSource.mileageTrip, trip.id],
      );
      expect(rolledBackLegs, isEmpty);

      await db.executor.runCustom('DROP TRIGGER fail_test_mileage_post');
      await mileageUseCases.postTrip(trip.id);
      final MileageTrip posted = (await mileageRepository.getById(trip.id))!;
      expect(posted.state, MileageTripState.posted);
      expect(posted.postingEventId, matches(RegExp(r'^[0-9a-fA-F-]{36}$')));

      final List<Map<String, Object?>> legs = await db.executor.runSelect(
        'SELECT id, source_kind, source_id, konto_id, soll_konto_id, haben_konto_id, soll, haben, gruppe_id, '
        'immutable, legacy_unverified, mileage_role_snapshot, mileage_kategorie_id_snapshot, '
        'mileage_kategorie_name_snapshot, mileage_euer_zeile_snapshot '
        'FROM journal WHERE source_kind = ? AND source_id = ? ORDER BY id',
        <Object?>[PostingSource.mileageTrip, trip.id],
      );
      expect(legs, hasLength(2));
      final int rootId = (legs.first['id']! as num).toInt();
      expect(legs.map((Map<String, Object?> row) => row['mileage_role_snapshot']).toSet(), <String>{
        'travel_expense',
        'private_contribution',
      });
      expect(legs.every((Map<String, Object?> row) => row['source_id'] == trip.id), isTrue);
      expect(legs.every((Map<String, Object?> row) => row['source_kind'] == PostingSource.mileageTrip), isTrue);
      expect(legs.every((Map<String, Object?> row) => row['gruppe_id'] == rootId), isTrue);
      expect(legs.every((Map<String, Object?> row) => row['immutable'] == 1), isTrue);
      expect(legs.every((Map<String, Object?> row) => row['legacy_unverified'] == 0), isTrue);
      expect(legs.map((Map<String, Object?> row) => (row['konto_id']! as num).toInt()).toSet(), <int>{
        expenseAccountId,
        contributionAccountId,
      });
      expect(legs.every((Map<String, Object?> row) => row['konto_id'] != cashAccountId), isTrue);
      expect(
        legs.map((Map<String, Object?> row) => (row['mileage_kategorie_id_snapshot']! as num).toInt()).toSet(),
        <int>{expenseCategoryId, contributionCategoryId},
      );
      expect(legs.map((Map<String, Object?> row) => row['mileage_kategorie_name_snapshot']).toSet(), <String>{
        'Travel expense',
        'Private contribution',
      });
      expect(
        legs.map((Map<String, Object?> row) => (row['mileage_euer_zeile_snapshot']! as num).toInt()).toSet(),
        <int>{71, 107},
      );

      final String eventId = posted.postingEventId!;
      await mileageUseCases.postTrip(trip.id);
      final MileageTrip retried = (await mileageRepository.getById(trip.id))!;
      expect(retried.postingEventId, eventId);
      final List<Map<String, Object?>> retryLegs = await db.executor.runSelect(
        'SELECT id FROM journal WHERE source_kind = ? AND source_id = ?',
        <Object?>[PostingSource.mileageTrip, trip.id],
      );
      expect(retryLegs, hasLength(2));

      final MileageTrip conflicting = MileageTrip(
        id: posted.id,
        tripDate: posted.tripDate,
        purpose: 'Different purpose',
        businessContext: posted.businessContext,
        distanceHundredthsKm: posted.distanceHundredthsKm,
        tripKind: posted.tripKind,
        vehicleSource: posted.vehicleSource,
        vehicleClass: posted.vehicleClass,
        state: posted.state,
        createdAt: posted.createdAt,
        updatedAt: posted.updatedAt,
        policyId: posted.policyId,
        policySource: posted.policySource,
        policyVersion: posted.policyVersion,
        policyEffectiveFrom: posted.policyEffectiveFrom,
        policyEffectiveTo: posted.policyEffectiveTo,
        calculatedAmount: posted.calculatedAmount,
        calculatedAt: posted.calculatedAt,
        postingEventId: posted.postingEventId,
      );
      await expectLater(() => postingService.postMileage(trip: conflicting), throwsA(isA<PostingException>()));

      final EuerResult legacyReport = await mileageEuer.generate(jahr: 2025);
      expect(legacyReport.zeile(71), '3.00');
      expect(legacyReport.zeile(107), '3.00');
      expect(legacyReport.gewinn, '-3.00');
      final List<Object?> legacySources = legacyReport.provenanceSnapshot['mileage_sources']! as List<Object?>;
      expect(legacySources, hasLength(1));
      final Map<String, Object?> legacySource = (legacySources.single! as Map<Object?, Object?>)
          .cast<String, Object?>();
      final List<Object?> legacyLegSnapshots = legacySource['legs']! as List<Object?>;
      expect(legacyLegSnapshots.map((Object? leg) => (leg! as Map<Object?, Object?>)['euer_line']).toSet(), <Object?>{
        71,
        107,
      });
    });

    test('settlement EÜR includes mileage once and keeps stored mapping after category edits', () async {
      await configureMapping();
      final MileageTrip trip = await createCalculatedTrip();
      await mileageUseCases.postTrip(trip.id);

      final EuerResult legacyReport = await mileageEuer.generate(jahr: 2025);
      expect(legacyReport.zeile(71), '3.00');
      expect(legacyReport.gewinn, '-3.00');

      await postingService.postSettlement(
        sourceKind: PostingSource.cashPayment,
        sourceId: 'mileage-euer-test-cash-receipt',
        signedAmountCents: 500,
        settlementDate: '2025-05-13',
        bankKontoId: cashAccountId,
        counterKontoId: incomeAccountId,
        allocations: <SettlementAllocationInput>[
          SettlementAllocationInput(appliedCents: 500, kategorieId: incomeCategoryId, euerZeile: 12),
        ],
        beschreibung: 'Test cash receipt',
      );

      final EuerResult settlementReport = await mileageEuer.generate(jahr: 2025);
      expect(settlementReport.provenanceSnapshot['settlement_basis'], isTrue);
      expect(settlementReport.zeile(12), '5.00');
      expect(settlementReport.zeile(60), '0.00');
      expect(settlementReport.zeile(71), '3.00');
      expect(settlementReport.zeile(107), '3.00');
      expect(settlementReport.gewinn, '2.00');
      final List<Object?> storedSources = settlementReport.provenanceSnapshot['mileage_sources']! as List<Object?>;
      final Map<String, Object?> storedSource = (storedSources.single! as Map<Object?, Object?>)
          .cast<String, Object?>();
      final Map<String, Object?> firstSnapshot = <String, Object?>{
        'trip_id': storedSource['trip_id'],
        'trip_date': storedSource['trip_date'],
        'event_id': storedSource['event_id'],
        'amount_cents': storedSource['amount_cents'],
        'legs': storedSource['legs'],
      };

      for (final int categoryId in <int>[expenseCategoryId, contributionCategoryId]) {
        await db.executor.runUpdate(
          'UPDATE kategorien SET bezeichnung = ?, euer_zeile = ?, mapping_status = ?, '
          'catalog_source_reference = ?, catalog_source_version = ? WHERE id = ?',
          <Object?>['Edited after posting', 60, 'review_required', 'EDITED-MILEAGE', '2', categoryId],
        );
        await db.executor.runInsert(
          'INSERT INTO category_mapping_history (kategorie_id, geaendert_am, aktion, vorher_mapping_json, '
          'nachher_mapping_json, katalog_quelle, katalog_version) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            categoryId,
            DateTime.now().toUtc().toIso8601String(),
            'mapping_edit',
            jsonEncode(<String, Object?>{'mapping_status': 'catalog_verified'}),
            jsonEncode(<String, Object?>{'mapping_status': 'review_required', 'euer_zeile': 60}),
            'EDITED-MILEAGE',
            '2',
          ],
        );
      }

      final EuerResult reportAfterCategoryEdits = await mileageEuer.generate(jahr: 2025);
      expect(reportAfterCategoryEdits.provenanceSnapshot['settlement_basis'], isTrue);
      expect(reportAfterCategoryEdits.zeile(12), '5.00');
      expect(reportAfterCategoryEdits.zeile(60), '0.00');
      expect(reportAfterCategoryEdits.zeile(71), '3.00');
      expect(reportAfterCategoryEdits.zeile(107), '3.00');
      expect(reportAfterCategoryEdits.gewinn, '2.00');
      final List<Object?> editedSources =
          reportAfterCategoryEdits.provenanceSnapshot['mileage_sources']! as List<Object?>;
      final Map<String, Object?> editedSource = (editedSources.single! as Map<Object?, Object?>)
          .cast<String, Object?>();
      expect(editedSource, firstSnapshot);
    });
  });

  test('test_proportional_cent_equal_remainders_use_stable_key', () {
    final Map<String, int> allocations = allocateProportionally<String>(
      amount: 1,
      weights: const <String, int>{'b': 1, 'a': 1},
      compareKeys: (String a, String b) => a.compareTo(b),
    );

    expect(allocations, <String, int>{'b': 0, 'a': 1});
    expect(allocations.values.reduce((int a, int b) => a + b), 1);
  });

  test('test_proportional_cent_largest_remainder_precedes_stable_key', () {
    final Map<String, int> allocations = allocateProportionally<String>(
      amount: 2,
      weights: const <String, int>{'a': 2, 'b': 3, 'c': 5},
      compareKeys: (String a, String b) => a.compareTo(b),
    );

    expect(allocations, <String, int>{'a': 0, 'b': 1, 'c': 1});
    expect(allocations.values.reduce((int a, int b) => a + b), 2);
  });

  test('test_proportional_cent_allocation_rejects_positive_amount_with_zero_weights', () {
    expect(
      () => allocateProportionally<String>(
        amount: 1,
        weights: const <String, int>{'a': 0, 'b': 0},
        compareKeys: (String a, String b) => a.compareTo(b),
      ),
      throwsA(isA<MoneyParseException>()),
    );
  });
}
