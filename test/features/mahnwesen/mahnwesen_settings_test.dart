import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/dunning_exclusions_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_service.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_einstellungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

void main() {
  group('Mahnwesen settings singleton (dunning-workflow-integrity)', () {
    late AppDatabase db;
    late MahnwesenEinstellungenRepository settings;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      settings = MahnwesenEinstellungenRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedEligible() async {
      final int kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>['Settings Kunde', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
      final int rechnungId = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-SET', 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-01', '2026-01-01', '100.00', '100.00'],
      );
      await ForderungenRepository(db.executor)
          .create(typ: 'rechnung', betrag: 100, partnerTyp: 'kunde', partnerId: kundeId, rechnungId: rechnungId);
      return rechnungId;
    }

    DunningService buildService() {
      return DunningService(
        executor: db.executor,
        mahnungen: MahnungenRepository(db.executor),
        stufen: MahnstufenRepository(db.executor),
        balances: SettledBalanceSource(db.executor),
        exclusions: DunningExclusionsRepository(db.executor),
        sperrung: SperrungService(db.executor),
      );
    }

    test('test_mahnwesen_configure_grace_period', () async {
      // GIVEN stored initial_grace_days = 14 with stage 1 at 7 days after due.
      await settings.update(graceTage: 14);
      expect((await settings.get()).graceTage, 14);
      final int rechnungId = await seedEligible();
      final DunningService service = buildService();
      // WHEN eligibility is evaluated around the absolute threshold, THEN grace never defers it.
      final before = await service.previewRun(asOf: '2026-01-07');
      expect(before.eligible.where((e) => e.rechnungId == rechnungId), isEmpty);
      final onDay = await service.previewRun(asOf: '2026-01-08');
      expect(onDay.eligible.where((e) => e.rechnungId == rechnungId), hasLength(1));
      // AND the stored 14-day compatibility value is preserved untouched.
      expect((await settings.get()).graceTage, 14);
    });

    test('test_mahnwesen_default_settings_on_fresh_install', () async {
      // GIVEN a fresh database, WHEN initialized, THEN defaults hold with zero non-operative grace.
      final current = await settings.get();
      expect(current.graceTage, 0);
      final int rechnungId = await seedEligible();
      final DunningService service = buildService();
      final before = await service.previewRun(asOf: '2026-01-07');
      expect(before.eligible.where((e) => e.rechnungId == rechnungId), isEmpty);
      final onDay = await service.previewRun(asOf: '2026-01-08');
      expect(onDay.eligible.where((e) => e.rechnungId == rechnungId), hasLength(1));
    });
  });
}
