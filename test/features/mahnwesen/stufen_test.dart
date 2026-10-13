import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/dunning_exclusions_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_service.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_exception.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

void main() {
  group('Mahnstufen 4 Levels', () {
    late AppDatabase db;
    late MahnstufenRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MahnstufenRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('fresh DB has 4 standard levels system_stufe=true with gebuehr/zinssatz', () async {
      // Act: list via repository (ensures 4 levels idempotent).
      final levels = await repo.list();
      final system = levels.where((e) => e.systemStufe).toList(growable: false);

      // Assert: exactly 4 system levels with required names.
      expect(system, hasLength(4));
      expect(
        system.map((e) => e.bezeichnung).toList(),
        containsAll(<String>['Mahnung 1', 'Mahnung 2', 'Mahnung 3', 'Letzte Mahnung vor Inkasso']),
      );
      for (final l in system) {
        expect(l.gebuehr, isNotEmpty);
        expect(l.zinssatz, isNotEmpty);
      }
      final m1 = system.firstWhere((e) => e.bezeichnung == 'Mahnung 1');
      expect(m1.gebuehr, '5.00');
      expect(m1.stufe, 1);
      final m4 = system.firstWhere((e) => e.bezeichnung == 'Letzte Mahnung vor Inkasso');
      expect(m4.stufe, 4);
    });

    test('user cannot delete system level -> throws', () async {
      // Arrange: pick a system level.
      final levels = await repo.list();
      final system = levels.firstWhere((e) => e.systemStufe);

      // Act & Assert: delete is rejected with protection message.
      await expectLater(
        repo.delete(system.id),
        throwsA(isA<MahnstufeException>().having((e) => e.message, 'message', contains('Systemstufe'))),
      );
      final after = await repo.getById(system.id);
      expect(after, isNotNull);
    });

    test('edit system level gebuehr 5->10 applies to new mahnungen after edit', () async {
      // Arrange: Mahnung 1 has 5.00 initially.
      final levels = await repo.list();
      final m1 = levels.firstWhere((e) => e.bezeichnung == 'Mahnung 1');
      expect(m1.gebuehr, '5.00');

      // Act: edit gebuehr.
      await repo.update(m1.id, gebuehr: '10.00');
      final updated = await repo.getById(m1.id);

      // Assert: new value persists for future reads (new Mahnungen).
      expect(updated, isNotNull);
      expect(updated!.gebuehr, '10.00');
      final fresh = await repo.list();
      final m1Fresh = fresh.firstWhere((e) => e.id == m1.id);
      expect(m1Fresh.gebuehr, '10.00');
    });

    test('configure level with multiplier true includes prior, false ignores', () async {
      // Arrange: set level 2 to 10.00, level 3 own 5.00 multiplier false.
      final levels = await repo.list();
      final l2 = levels.firstWhere((e) => e.stufe == 2);
      final l3 = levels.firstWhere((e) => e.stufe == 3);
      await repo.update(l2.id, gebuehr: '10.00');
      await repo.update(l3.id, gebuehr: '5.00', multiplier: false);

      // Assert: multiplier false -> only own.
      expect(await repo.effektiveGebuehr(l3.id), '5.00');

      // Act: enable multiplier.
      await repo.update(l3.id, multiplier: true);

      // Assert: includes prior level gebuehr (10 + 5 = 15.00).
      expect(await repo.effektiveGebuehr(l3.id), '15.00');

      // Act: disable again.
      await repo.update(l3.id, multiplier: false);
      expect(await repo.effektiveGebuehr(l3.id), '5.00');
    });

    test('custom level creation appears and is deletable', () async {
      // Act: create custom level beyond 4 system levels.
      final custom = await repo.create(
        stufe: 5,
        bezeichnung: 'Mahnung 4 - Inkasso-Vorbereitung',
        gebuehr: '20.00',
        zinssatz: '8.00',
        tageNachFaelligkeit: 30,
      );

      // Assert: appears in list, not system protected.
      expect(custom.bezeichnung, 'Mahnung 4 - Inkasso-Vorbereitung');
      expect(custom.systemStufe, isFalse);
      final afterCreate = await repo.list();
      expect(afterCreate.any((e) => e.bezeichnung == 'Mahnung 4 - Inkasso-Vorbereitung'), isTrue);

      // Act: delete custom level.
      await repo.delete(custom.id);

      // Assert: removed.
      final afterDelete = await repo.list();
      expect(afterDelete.any((e) => e.id == custom.id), isFalse);
      expect(await repo.getById(custom.id), isNull);
    });
  });

  group('Dunning Level Configuration (dunning-workflow-integrity)', () {
    late AppDatabase db;
    late MahnstufenRepository repo;
    late MahnungenRepository mahnungen;
    late DunningService service;

    DunningService buildService() {
      return DunningService(
        executor: db.executor,
        mahnungen: mahnungen,
        stufen: repo,
        balances: SettledBalanceSource(db.executor),
        exclusions: DunningExclusionsRepository(db.executor),
        sperrung: SperrungService(db.executor),
      );
    }

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = MahnstufenRepository(db.executor);
      mahnungen = MahnungenRepository(db.executor);
      service = buildService();
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedForderung({required String faelligkeit, String brutto = '1000.00'}) async {
      final int kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>['Stufen Kunde', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
      final int rechnungId = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-STUFE', 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-01', faelligkeit, brutto, brutto],
      );
      await ForderungenRepository(db.executor).create(
        typ: 'rechnung',
        betrag: num.parse(brutto),
        partnerTyp: 'kunde',
        partnerId: kundeId,
        rechnungId: rechnungId,
      );
      return rechnungId;
    }

    test('test_mahnwesen_fresh_profile_seeds_the_documented_fixed_fee_model', () async {
      // GIVEN a new profile has no dunning levels, WHEN initialized, THEN defaults match.
      final levels = await repo.list();
      final system = levels.where((e) => e.systemStufe).toList(growable: false)
        ..sort((a, b) => a.stufe.compareTo(b.stufe));
      expect(system, hasLength(4));
      expect(system.map((e) => e.tageNachFaelligkeit).toList(), <int>[7, 21, 35, 49]);
      expect(system.map((e) => e.gebuehr).toList(), <String>['5.00', '10.00', '15.00', '25.00']);
      expect(system.map((e) => e.zinssatz).toList(), <String>['0.00', '5.00', '8.00', '8.00']);
      expect(system.every((e) => !e.multiplier), isTrue);
    });

    test('test_mahnwesen_configure_level_with_multiplier', () async {
      // GIVEN level 2 fee 10.00 and level 3 own fee 5.00 with multiplier, THEN level fee is 15.00, no percent.
      final levels = await repo.list();
      final l2 = levels.firstWhere((e) => e.stufe == 2);
      final l3 = levels.firstWhere((e) => e.stufe == 3);
      await repo.update(l2.id, gebuehr: '10.00');
      await repo.update(l3.id, gebuehr: '5.00', multiplier: true);
      expect(await repo.effektiveGebuehr(l3.id), '15.00');
    });

    test('test_mahnwesen_configure_level_without_multiplier', () async {
      // GIVEN level 3 fee 5.00 without multiplier, THEN fee is 5.00 ignoring prior level.
      final levels = await repo.list();
      final l3 = levels.firstWhere((e) => e.stufe == 3);
      await repo.update(l3.id, gebuehr: '5.00', multiplier: false);
      expect(await repo.effektiveGebuehr(l3.id), '5.00');
    });

    test('test_mahnwesen_editing_a_level_does_not_rewrite_prior_letters', () async {
      // GIVEN a Mahnung snapshotted fee/rate, WHEN config changes, THEN stored values stay.
      final rechnungId = await seedForderung(faelligkeit: '2026-01-01');
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      final levels = await repo.list();
      final stage1 = levels.firstWhere((e) => e.stufe == 1);
      await repo.update(stage1.id, gebuehr: '99.00', zinssatz: '9.00');
      final after = await mahnungen.getById(letter.id);
      expect(after, isNotNull);
      expect(after!.snapshotData!['gebuehr'], '5.00');
      final fresh = await repo.getById(stage1.id);
      expect(fresh!.gebuehr, '99.00');
    });

    test('test_mahnwesen_initialization_preserves_customized_levels', () async {
      // GIVEN a customized standard level, WHEN init runs again, THEN values stay.
      final levels = await repo.list();
      final stage1 = levels.firstWhere((e) => e.stufe == 1);
      await repo.update(stage1.id, gebuehr: '7.50');
      final reopened = MahnstufenRepository(db.executor);
      final again = await reopened.list();
      expect(again.firstWhere((e) => e.stufe == 1).gebuehr, '7.50');
    });

    test('test_mahnwesen_stage_date_uses_one_absolute_threshold', () async {
      // GIVEN due 2026-01-01, stage 1 at 7 days, grace 30 days (deprecated).
      final rechnungId = await seedForderung(faelligkeit: '2026-01-01');
      // WHEN evaluated 2026-01-07 and 2026-01-08, THEN ineligible before due+7, eligible on it.
      final before = await service.previewRun(asOf: '2026-01-07');
      expect(before.eligible.where((e) => e.rechnungId == rechnungId), isEmpty);
      final onDay = await service.previewRun(asOf: '2026-01-08');
      expect(onDay.eligible.where((e) => e.rechnungId == rechnungId), hasLength(1));
    });

    test('test_mahnwesen_invoice_at_level_2', () async {
      // GIVEN no level and transport accepts a level 1 Mahnung, THEN level becomes 1.
      final rechnungId = await seedForderung(faelligkeit: '2026-01-01');
      expect(await service.currentLevel(rechnungId), 0);
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      expect(await service.currentLevel(rechnungId), 0);
      final accepted = await service.markTransportAccepted(letter.id);
      expect(accepted.status, 'versendet');
      expect(await service.currentLevel(rechnungId), 1);
    });

    test('test_mahnwesen_failed_send_does_not_advance_the_level', () async {
      // GIVEN a draft for the next level, THEN the level stays unchanged.
      final rechnungId = await seedForderung(faelligkeit: '2026-01-01');
      await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      expect(await service.currentLevel(rechnungId), 0);
      final rows = await db.executor.runSelect('SELECT mahnstufe_aktuell FROM rechnungen WHERE id = ?', <Object?>[
        rechnungId,
      ]);
      expect(rows.single['mahnstufe_aktuell'], 0);
    });

    test('test_mahnwesen_invoice_payment_resets_level', () async {
      // GIVEN a level and full settlement, THEN the level is cleared.
      final rechnungId = await seedForderung(faelligkeit: '2026-01-01');
      final letter = await service.createForInvoice(rechnungId: rechnungId, asOf: '2026-01-10');
      await service.markTransportAccepted(letter.id);
      expect(await service.currentLevel(rechnungId), 1);
      final forderungen = ForderungenRepository(db.executor);
      final forderung = await forderungen.findByRechnungId(rechnungId);
      await forderungen.zahlungBuchen(forderungId: forderung!.id, betrag: 1000);
      await service.syncLevelAfterSettlement(rechnungId);
      expect(await service.currentLevel(rechnungId), 0);
    });
  });
}
