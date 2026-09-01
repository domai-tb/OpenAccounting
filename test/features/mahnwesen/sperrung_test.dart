import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/mahnwesen/kunden_sperrung_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_einstellungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

void main() {
  group('Kundensperrung at threshold', () {
    late AppDatabase db;
    late SperrungService service;
    late MahnwesenEinstellungenRepository einstellungenRepo;
    late MahnstufenRepository stufenRepo;
    late MahnungenRepository mahnungenRepo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      service = SperrungService(db.executor);
      einstellungenRepo = MahnwesenEinstellungenRepository(db.executor);
      stufenRepo = MahnstufenRepository(db.executor);
      mahnungenRepo = MahnungenRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> createKunde({String name = 'Sperr Kunde'}) async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[name, 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
    }

    Future<int> createRechnung({
      required int kundeId,
      String rechnungsnummer = 'RE-999',
      String brutto = '500.00',
    }) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          rechnungsnummer,
          'rechnung',
          'offen',
          0,
          'netto',
          kundeId,
          '2025-01-01',
          '2025-01-15',
          brutto,
          brutto,
        ],
      );
    }

    test('thresholds via mahnwesen_einstellungen singleton default and update', () async {
      final initial = await einstellungenRepo.get();
      expect(initial.schwelleWarnung, 2);
      expect(initial.schwelleSperrung, 3);
      final updated = await einstellungenRepo.setSchwellen(warnung: 2, sperrung: 3);
      expect(updated.schwelleWarnung, 2);
      expect(updated.schwelleSperrung, 3);
      final again = await einstellungenRepo.get();
      expect(again.schwelleWarnung, 2);
      // grace days defaults 0, update to 14 per spec singleton grace.
      final withGrace = await einstellungenRepo.update(graceTage: 14);
      expect(withGrace.graceTage, 14);
      expect((await einstellungenRepo.get()).graceTage, 14);
    });

    test('warnung_ab_stufe=2: kunde reaches level2 → isWarnung true, dashboard shows warning', () async {
      await einstellungenRepo.setSchwellen(warnung: 2, sperrung: 3);
      final kundeId = await createKunde(name: 'Warn Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-WARN-1');
      final levels = await stufenRepo.list();
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      // Before any dunning → no warning.
      expect(await service.isWarnung(kundeId), isFalse);
      expect(await service.isSperrung(kundeId), isFalse);
      expect(await service.canCreateInvoice(kundeId), isTrue);
      // Create level2 mahnung.
      await mahnungenRepo.create(rechnungId: rechnungId, stufeId: stufe2.id);
      expect(await service.isWarnung(kundeId), isTrue, reason: 'level2 should trigger warnung');
      // Dashboard shows warning via warnKunden.
      final warnKunden = await service.warnKunden();
      expect(warnKunden, contains(kundeId));
      // At level2, sperrung not yet.
      expect(await service.isSperrung(kundeId), isFalse);
      expect(await service.canCreateInvoice(kundeId), isTrue);
    });

    test('sperrung_ab_stufe=3: kunde reaches level3 → isSperrung true, canCreateInvoice false with error', () async {
      await einstellungenRepo.setSchwellen(warnung: 2, sperrung: 3);
      final kundeId = await createKunde(name: 'Sperr Kunde 2');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-SPERR-1');
      final levels = await stufenRepo.list();
      final stufe3 = levels.firstWhere((e) => e.stufe == 3);
      await mahnungenRepo.create(rechnungId: rechnungId, stufeId: stufe3.id);
      expect(await service.isSperrung(kundeId), isTrue);
      expect(await service.isWarnung(kundeId), isTrue, reason: 'level3 also >= warnung');
      expect(await service.canCreateInvoice(kundeId), isFalse);
      // assert throws with error.
      await expectLater(
        service.assertCanCreateInvoice(kundeId),
        throwsA(isA<KundenSperrungException>().having((e) => e.message, 'message', contains('gesperrt'))),
      );
      // Dashboard overdue grouped should contain stufe 3 count.
      final grouped = await service.overdueGrouped();
      // rechnung at mahnstufe_aktuell=3 should be counted.
      expect(grouped[3], greaterThanOrEqualTo(1));
    });

    test('recovery: after clearing, warnung/sperrung reset', () async {
      await einstellungenRepo.setSchwellen(warnung: 2, sperrung: 3);
      final kundeId = await createKunde(name: 'Recovery Kunde');
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-REC-1');
      final levels = await stufenRepo.list();
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      await mahnungenRepo.create(rechnungId: rechnungId, stufeId: stufe2.id);
      expect(await service.isWarnung(kundeId), isTrue);
      // Delete mahnungen → recovery.
      await db.executor.runDelete('DELETE FROM mahnungen WHERE kunde_id = ?', <Object?>[kundeId]);
      // Also fallback via rechnung.
      await db.executor.runDelete('DELETE FROM mahnungen WHERE rechnung_id = ?', <Object?>[rechnungId]);
      expect(await service.isWarnung(kundeId), isFalse);
      expect(await service.isSperrung(kundeId), isFalse);
      expect(await service.canCreateInvoice(kundeId), isTrue);
    });

    test('Manual Mahnsperre: set reason Streitfall bis 2026-12-31 → isMahngesperrt true until date, after 2027-01-01 false', () async {
      final kundeId = await createKunde(name: 'Mahngesperrt Kunde');
      expect(await service.isMahngesperrt(kundeId), isFalse);
      expect(await service.canCreateInvoice(kundeId), isTrue);
      await service.setMahnsperre(kundeId, 'Streitfall', bis: '2026-12-31');
      // Check DB stored reason.
      final rows = await db.executor.runSelect(
        'SELECT mahngesperrt, mahngesperrt_grund, mahngesperrt_bis FROM kunden WHERE id = ?',
        <Object?>[kundeId],
      );
      expect(rows.single['mahngesperrt'], 1);
      expect(rows.single['mahngesperrt_grund'], 'Streitfall');
      expect(rows.single['mahngesperrt_bis'], '2026-12-31');
      // isMahngesperrt true at 2026-06-01.
      expect(await service.isMahngesperrt(kundeId, asOf: DateTime(2026, 6, 1)), isTrue);
      expect(await service.isMahngesperrt(kundeId, asOf: DateTime(2026, 12, 31)), isTrue);
      // auto expiry after date.
      expect(await service.isMahngesperrt(kundeId, asOf: DateTime(2027, 1, 1)), isFalse);
      expect(await service.isMahngesperrt(kundeId, asOf: DateTime(2027, 6, 1)), isFalse);
      // canCreateInvoice respects Mahnsperre.
      expect(await service.canCreateInvoice(kundeId, asOf: DateTime(2026, 6, 1)), isFalse);
      expect(await service.canCreateInvoice(kundeId, asOf: DateTime(2027, 1, 1)), isTrue);
      await expectLater(
        service.assertCanCreateInvoice(kundeId, asOf: DateTime(2026, 6, 1)),
        throwsA(isA<KundenSperrungException>().having((e) => e.message, 'message', contains('mahngesperrt'))),
      );
      // After expiry, can create.
      await service.assertCanCreateInvoice(kundeId, asOf: DateTime(2027, 1, 1));
    });

    test('Manual Mahnsperre without date → persists, manual remove clears', () async {
      final kundeId = await createKunde(name: 'Persist Kunde');
      await service.setMahnsperre(kundeId, 'Streitfall');
      expect(await service.isMahngesperrt(kundeId), isTrue);
      expect(
        await service.isMahngesperrt(kundeId, asOf: DateTime(2030, 1, 1)),
        isTrue,
        reason: 'without date persists',
      );
      expect(await service.canCreateInvoice(kundeId), isFalse);
      // Manual remove clears.
      await service.removeMahnsperre(kundeId);
      expect(await service.isMahngesperrt(kundeId), isFalse);
      expect(await service.canCreateInvoice(kundeId), isTrue);
      final rows = await db.executor.runSelect(
        'SELECT mahngesperrt, mahngesperrt_bis, mahngesperrt_grund FROM kunden WHERE id = ?',
        <Object?>[kundeId],
      );
      expect(rows.single['mahngesperrt'], 0);
      expect(rows.single['mahngesperrt_bis'], isNull);
      expect(rows.single['mahngesperrt_grund'], isNull);
    });

    test('Audit: view history chronological list, empty state', () async {
      final kundeId = await createKunde(name: 'Audit Kunde');
      // Empty state.
      final empty = await service.getHistory(kundeId);
      expect(empty, isEmpty);
      // Create 2 mahnungen at different times — ensure chronological.
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-AUDIT-1');
      final levels = await stufenRepo.list();
      final stufe1 = levels.firstWhere((e) => e.stufe == 1);
      final stufe2 = levels.firstWhere((e) => e.stufe == 2);
      final m1 = await mahnungenRepo.create(rechnungId: rechnungId, stufeId: stufe1.id);
      // small delay to ensure distinct datum order — but we rely on id order fallback.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final m2 = await mahnungenRepo.create(rechnungId: rechnungId, stufeId: stufe2.id);
      final history = await service.getHistory(kundeId);
      expect(history, hasLength(2));
      expect(history.first.id, m1.id);
      expect(history.last.id, m2.id);
      // Verify chronological via datum/id.
      expect(history[0].datum.compareTo(history[1].datum) <= 0, isTrue);
      // History contains snapshot data.
      expect(history.first.snapshot, isNotNull);
    });

    test('combined blocking: Mahnsperre overrides, Sperrung independent', () async {
      await einstellungenRepo.setSchwellen(warnung: 2, sperrung: 3);
      final kundeId = await createKunde(name: 'Combined Kunde');
      // Set Mahnsperre → blocked even without dunning level.
      await service.setMahnsperre(kundeId, 'Streitfall', bis: '2026-12-31');
      expect(await service.canCreateInvoice(kundeId, asOf: DateTime(2026, 6, 1)), isFalse);
      // Remove Mahnsperre but add sperrung level.
      await service.removeMahnsperre(kundeId);
      final rechnungId = await createRechnung(kundeId: kundeId, rechnungsnummer: 'RE-COMB-1');
      final levels = await stufenRepo.list();
      final stufe3 = levels.firstWhere((e) => e.stufe == 3);
      await mahnungenRepo.create(rechnungId: rechnungId, stufeId: stufe3.id);
      expect(await service.isSperrung(kundeId), isTrue);
      expect(await service.canCreateInvoice(kundeId), isFalse);
      // Clear dunning → can create again (if no Mahnsperre).
      await db.executor.runDelete('DELETE FROM mahnungen WHERE kunde_id = ?', <Object?>[kundeId]);
      await db.executor.runDelete('DELETE FROM mahnungen WHERE rechnung_id = ?', <Object?>[rechnungId]);
      expect(await service.canCreateInvoice(kundeId), isTrue);
    });
  });
}
