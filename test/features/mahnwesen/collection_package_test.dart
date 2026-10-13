import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/collection_package_service.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/dunning_exclusions_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_service.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

void main() {
  group('Collection package (dunning-workflow-integrity)', () {
    late AppDatabase db;
    late DunningService service;
    late CollectionPackageService packages;
    late Directory tmp;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      final MahnungenRepository mahnungen = MahnungenRepository(db.executor, profileDir: '');
      final MahnstufenRepository stufen = MahnstufenRepository(db.executor);
      service = DunningService(
        executor: db.executor,
        mahnungen: mahnungen,
        stufen: stufen,
        balances: SettledBalanceSource(db.executor),
        exclusions: DunningExclusionsRepository(db.executor),
        sperrung: SperrungService(db.executor),
      );
      packages = CollectionPackageService(
        executor: db.executor,
        mahnungen: mahnungen,
        balances: SettledBalanceSource(db.executor),
        forderungen: ForderungenRepository(db.executor),
        profileDir: '',
      );
      tmp = Directory.systemTemp.createTempSync('collection-test-');
    });

    tearDown(() async {
      await db.close();
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<int> createKunde() async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>['Inkasso Kunde', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
    }

    Future<int> createRechnung({required int kundeId, required String nummer, String brutto = '500.00'}) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[nummer, 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-01', '2026-01-01', brutto, brutto],
      );
    }

    Future<void> writeInvoicePdf(int rechnungId, String nummer) async {
      final Directory dir = Directory('${tmp.path}/pdfs/documents')..createSync(recursive: true);
      final File file = File('${dir.path}/$rechnungId.pdf')..writeAsBytesSync(<int>[0x25, 0x50, 0x44, 0x46]);
      final String relative = 'pdfs/documents/$rechnungId.pdf';
      await db.executor.runUpdate('UPDATE rechnungen SET original_pdf_pfad = ? WHERE id = ?', <Object?>[
        relative,
        rechnungId,
      ]);
      expect(file.existsSync(), isTrue, reason: nummer);
    }

    CollectionPackageService packagesWithDir() {
      return CollectionPackageService(
        executor: db.executor,
        mahnungen: MahnungenRepository(db.executor, profileDir: tmp.path),
        balances: SettledBalanceSource(db.executor),
        forderungen: ForderungenRepository(db.executor),
        profileDir: tmp.path,
      );
    }

    test('test_mahnwesen_package_contains_selected_customer_evidence', () async {
      // GIVEN selected open invoices, prior Mahnungen, readable artifacts.
      final int kundeId = await createKunde();
      final int r1 = await createRechnung(kundeId: kundeId, nummer: 'RE-9001');
      final int r2 = await createRechnung(kundeId: kundeId, nummer: 'RE-9002', brutto: '300.00');
      final ForderungenRepository forderungen = ForderungenRepository(db.executor);
      for (final int id in <int>[r1, r2]) {
        final List<Map<String, Object?>> rows = await db.executor.runSelect(
          'SELECT kunde_id FROM rechnungen WHERE id = ?',
          <Object?>[id],
        );
        expect(rows.single['kunde_id'], kundeId);
      }
      await forderungen.create(typ: 'rechnung', betrag: 500, partnerTyp: 'kunde', partnerId: kundeId, rechnungId: r1);
      await forderungen.create(typ: 'rechnung', betrag: 300, partnerTyp: 'kunde', partnerId: kundeId, rechnungId: r2);
      await writeInvoicePdf(r1, 'RE-9001');
      await writeInvoicePdf(r2, 'RE-9002');
      final letter = await service.createForInvoice(rechnungId: r1, asOf: '2026-01-10');
      await MahnungenRepository(db.executor, profileDir: tmp.path).generatePdf(letter.id);
      // WHEN the user creates a collection package, THEN it links statement, invoices, reminders, balance.
      final CollectionPackageResult result = await packagesWithDir().create(
        kundeId: kundeId,
        rechnungIds: <int>[r1, r2],
        asOf: '2026-01-27',
      );
      expect(result, isA<CollectionPackageOk>());
      final CollectionPackage package = (result as CollectionPackageOk).package;
      expect(package.vollstaendig, isTrue);
      expect(package.fehlende, isEmpty);
      expect(package.rechnungen, hasLength(2));
      expect(package.mahnungen.map((m) => m.id), contains(letter.id));
      expect(package.saldoMomentaufnahme, '800.00');
      expect(package.nachweise.every((e) => e.lesbar), isTrue);
      expect(package.kontokorrent, isNotEmpty);
    });

    test('test_mahnwesen_missing_required_artifact_blocks_a_complete_package', () async {
      // GIVEN a prior Mahnung without readable artifact, THEN missing is reported, never complete.
      final int kundeId = await createKunde();
      final int r1 = await createRechnung(kundeId: kundeId, nummer: 'RE-9101');
      await ForderungenRepository(db.executor)
          .create(typ: 'rechnung', betrag: 500, partnerTyp: 'kunde', partnerId: kundeId, rechnungId: r1);
      await writeInvoicePdf(r1, 'RE-9101');
      await service.createForInvoice(rechnungId: r1, asOf: '2026-01-10');
      final CollectionPackageResult result = await packagesWithDir().create(
        kundeId: kundeId,
        rechnungIds: <int>[r1],
        asOf: '2026-01-27',
      );
      expect(result, isA<CollectionPackageOk>());
      final CollectionPackage package = (result as CollectionPackageOk).package;
      expect(package.vollstaendig, isFalse);
      expect(package.fehlende, isNotEmpty);
      expect(package.nachweise.where((e) => !e.lesbar), isNotEmpty);
    });

    test('test_mahnwesen_package_without_balance_source_is_unavailable', () async {
      // GIVEN an unavailable balance source, THEN creation blocks without writing an artifact.
      final int kundeId = await createKunde();
      final int r1 = await createRechnung(kundeId: kundeId, nummer: 'RE-9201');
      final CollectionPackageResult result = await packages.create(
        kundeId: kundeId,
        rechnungIds: <int>[r1],
        asOf: '2026-01-27',
      );
      expect(result, isA<CollectionPackageUnavailable>());
      expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
    });
  });
}
