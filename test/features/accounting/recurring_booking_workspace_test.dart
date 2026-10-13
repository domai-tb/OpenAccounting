// Fixed scenario dates keep due-date behavior deterministic; kept explicit intentionally.
// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/recurring_booking_wiring.dart';
import 'package:openaccounting/features/recurring/recurring_booking_workspace_usecases.dart';

/// Accounting boundary for recurring templates (specs/specs/accounting).
/// Saving or staging never posts; execution needs the shared contract.
class _FakeSharedPosting implements SharedPostingGateway {
  _FakeSharedPosting({required this.available, this.journalId = 91});

  final bool available;
  final int journalId;
  int calls = 0;
  int? lastVorlageId;
  String? lastFaelligkeit;

  @override
  bool get isAvailable => available;

  @override
  String get unavailableReason => 'Gemeinsamer Buchungsvertrag ist nicht verfügbar';

  @override
  Future<SharedPostingResult> postDirect({
    required int vorlageId,
    required String faelligkeit,
    required BuchungsVorlage vorlage,
    required String effektiverBetrag,
  }) async {
    calls++;
    lastVorlageId = vorlageId;
    lastFaelligkeit = faelligkeit;
    return SharedPostingResult(journalId: journalId, sourceId: '$vorlageId/$faelligkeit');
  }
}

Future<AppDatabase> _openDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO konten (id, name, iban) VALUES (?, ?, ?)', const <Object?>[
    1,
    'Bank',
    'DE00111111111111111111',
  ]);
  await db.executor.runInsert('INSERT INTO lieferanten (id, name, strasse) VALUES (?, ?, ?)', const <Object?>[
    1,
    'Vermieter',
    'Hauptstr. 1',
  ]);
  return db;
}

Future<int> _count(AppDatabase db, String table) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT COUNT(*) AS c FROM $table',
    const <Object?>[],
  );
  return ((rows.single['c'] as num?) ?? 0).toInt();
}

RecurringBookingWorkspaceUseCases _useCases(
  AppDatabase db, {
  SharedPostingGateway? sharedPosting,
  RecurringCategoryLookup? kategorien,
  RecurringArticlePriceLookup? artikelpreise,
}) {
  return buildTestRecurringBookingUseCases(
    db.executor,
    sharedPosting: sharedPosting,
    kategorien: kategorien,
    artikelpreise: artikelpreise,
  );
}

void main() {
  group('Recurring booking workspace — accounting boundary', () {
    late AppDatabase db;

    setUp(() async {
      db = await _openDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('test_template_creation', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage created = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
        beschreibung: 'Monatliche Miete',
        positionen: const <Map<String, dynamic>>[
          <String, dynamic>{'bezeichnung': 'Kaltmiete', 'menge': 1, 'einzelpreis': 800.00, 'ust_satz': 19},
        ],
      );

      expect(created.art, 'Ausgabe');
      expect(created.modus, 'direkt');
      expect(created.intervall, 'monatlich');
      expect(created.naechsteFaelligkeit, '2026-02-01');
      expect(created.positionen.single['bezeichnung'], 'Kaltmiete');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      expect(await _count(db, 'rechnungen'), 0);
    });

    test('test_due_template_is_staged_for_review', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
      );

      final List<DueInstanceView> due = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(due.length, 1);
      expect(due.single.vorlage.id, template.id);
      expect(due.single.faelligkeit, '2026-02-01');
      expect(due.single.reviewStatus, 'pending');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);

      // Overdue catch-up exposes only the oldest uncompleted occurrence.
      await db.executor.runUpdate('UPDATE buchungsvorlagen SET naechste_faelligkeit = ? WHERE id = ?', <Object?>[
        '2026-01-01',
        template.id,
      ]);
      final List<DueInstanceView> overdue = await useCases.refreshDueInstances(heute: DateTime(2026, 3, 1));
      expect(overdue.length, 1);
      expect(overdue.single.faelligkeit, '2026-02-01');
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);
      expect((await repo.listOccurrences(template.id)).length, 1);
    });

    test('test_template_execution', () async {
      final _FakeSharedPosting gateway = _FakeSharedPosting(available: true, journalId: 77);
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db, sharedPosting: gateway);
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);
      await db.executor.runInsert(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (77, '2026-02-01', 800, 1, 'Seed')",
        const <Object?>[],
      );
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
      );
      await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));

      final DueInstanceView posted = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(posted.reviewStatus, 'posted');
      expect(posted.journalId, 77);
      expect(gateway.calls, 1);
      expect(gateway.lastVorlageId, template.id);
      expect(gateway.lastFaelligkeit, '2026-02-01');
      final BuchungsVorlage advanced = (await useCases.getTemplate(template.id))!;
      expect(advanced.naechsteFaelligkeit, '2026-03-01');

      // A completed occurrence never posts twice.
      final DueInstanceView repeated = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(repeated.reviewStatus, 'posted');
      expect(gateway.calls, 1);

      // Month-end clamping for the one-step advancement.
      expect(repo.advanceDueDate(DateTime(2026, 1, 31), 'monatlich'), DateTime(2026, 2, 28));
      expect(repo.advanceDueDate(DateTime(2024, 1, 31), 'monatlich'), DateTime(2024, 2, 29));
      expect(repo.advanceDueDate(DateTime(2024, 2, 29), 'jährlich'), DateTime(2025, 2, 28));
    });

    test('test_template_with_article', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(
        db,
        artikelpreise: (int artikelId) async => artikelId == 42 ? '12.34' : null,
      );
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Wartung',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '100.00',
        positionen: const <Map<String, dynamic>>[
          <String, dynamic>{
            'bezeichnung': 'Service',
            'menge': 1,
            'einzelpreis': 100.00,
            'ust_satz': 19,
            'artikel_id': 42,
          },
        ],
      );
      await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));

      final DueInstanceView review = await useCases.reviewInstance(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(review.effektiverBetrag, contains('12.34'));
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_template_lifecycle', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
      );

      await useCases.pauseTemplate(template.id);
      final BuchungsVorlage paused = (await useCases.getTemplate(template.id))!;
      expect(paused.aktiv, isFalse);
      final List<DueInstanceView> silent = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(silent, isEmpty);
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);
      expect(await repo.listAllOccurrences(), isEmpty);

      await useCases.resumeTemplate(template.id);
      final List<DueInstanceView> back = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(back.length, 1);
      expect(back.single.faelligkeit, '2026-02-01');
    });

    test('test_unavailable_mapping_or_shared_contract_fails_closed', () async {
      // Missing shared contract keeps the instance pending with its reason.
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
      );
      final DueInstanceView pending = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(pending.reviewStatus, 'pending');
      expect(pending.blockReason, contains('Gemeinsamer Buchungsvertrag'));
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      final BuchungsVorlage unchanged = (await useCases.getTemplate(template.id))!;
      expect(unchanged.naechsteFaelligkeit, '2026-02-01');

      // An unresolved mapping blocks even with an available contract.
      final _FakeSharedPosting gateway = _FakeSharedPosting(available: true);
      final RecurringBookingWorkspaceUseCases gated = _useCases(
        db,
        sharedPosting: gateway,
        kategorien: (int? _) async => const RecurringCategoryProbe(aktiv: true, mappingStatus: 'review_required'),
      );
      await db.executor.runInsert("INSERT INTO kategorien (id, bezeichnung) VALUES (3, 'Büro Kat')", const <Object?>[]);
      await db.executor.runInsert("INSERT INTO kategorien (id, bezeichnung) VALUES (4, 'Alt Kat')", const <Object?>[]);
      final BuchungsVorlage mapped = await gated.createTemplate(
        name: 'Büro',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kategorieId: 3,
        kontoId: 1,
        betrag: '50.00',
      );
      final DueInstanceView blocked = await gated.requestDirectExecution(
        vorlageId: mapped.id,
        faelligkeit: '2026-02-01',
      );
      expect(blocked.reviewStatus, 'blocked');
      expect(blocked.blockReason, contains('Prüfung'));
      expect(gateway.calls, 0);
      expect(await _count(db, 'journal'), 0);

      // A deactivated category with unresolved provenance stays blocked.
      final RecurringBookingWorkspaceUseCases legacy = _useCases(
        db,
        sharedPosting: gateway,
        kategorien: (int? _) async => const RecurringCategoryProbe(aktiv: false, mappingStatus: 'legacy_unverified'),
      );
      final BuchungsVorlage old = await legacy.createTemplate(
        name: 'Alt',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kategorieId: 4,
        kontoId: 1,
        betrag: '50.00',
      );
      final DueInstanceView legacyBlocked = await legacy.requestDirectExecution(
        vorlageId: old.id,
        faelligkeit: '2026-02-01',
      );
      expect(legacyBlocked.reviewStatus, 'blocked');
      expect(legacyBlocked.blockReason, contains('Prüfung'));
      expect(gateway.calls, 0);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_template_with_deleted_category', () async {
      final _FakeSharedPosting gateway = _FakeSharedPosting(available: true, journalId: 78);
      final RecurringBookingWorkspaceUseCases useCases = _useCases(
        db,
        sharedPosting: gateway,
        kategorien: (int? _) async => const RecurringCategoryProbe(aktiv: false, mappingStatus: 'catalog_verified'),
      );
      await db.executor.runInsert(
        "INSERT INTO kategorien (id, bezeichnung) VALUES (5, 'Miete Kat')",
        const <Object?>[],
      );
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kategorieId: 5,
        kontoId: 1,
        betrag: '119.00',
      );
      await db.executor.runInsert(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (78, '2026-02-01', 119, 1, 'Seed')",
        const <Object?>[],
      );
      final int journalBefore = await _count(db, 'journal');

      final DueInstanceView posted = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(posted.reviewStatus, 'posted');
      expect(posted.journalId, 78);
      expect(posted.warnung, contains('Deaktivierte'));
      expect(gateway.calls, 1);
      expect(await _count(db, 'journal'), journalBefore);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });
  });
}
