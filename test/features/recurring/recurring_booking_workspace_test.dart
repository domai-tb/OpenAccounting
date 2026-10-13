// Fixed scenario dates keep due-date behavior deterministic; kept explicit intentionally.
// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/recurring_booking_wiring.dart';
import 'package:openaccounting/features/recurring/recurring_booking_workspace_usecases.dart';

/// Template mode, direction, and review-first auto-generation
/// (specs/specs/recurring): detection never posts, the shared contract gates
/// every financial effect, and scans stay idempotent.
class _FakeSharedPosting implements SharedPostingGateway {
  _FakeSharedPosting({required this.available});

  final bool available;
  final int journalId = 91;
  int calls = 0;

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
    return SharedPostingResult(journalId: journalId, sourceId: '$vorlageId/$faelligkeit');
  }
}

class _FakeBelegDrafts implements BelegDraftGateway {
  int calls = 0;
  int? lastVorlageId;
  String? lastFaelligkeit;
  final Map<String, int> drafts = <String, int>{};

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => 'Entwurfs-Übergabe ist nicht verfügbar';

  @override
  Future<int> createDraft({
    required int vorlageId,
    required String faelligkeit,
    required String datum,
    required List<BelegDraftPosition> positionen,
    required String eingabemodus,
    int? lieferantId,
  }) async {
    calls++;
    lastVorlageId = vorlageId;
    lastFaelligkeit = faelligkeit;
    const int id = 601;
    drafts['$vorlageId/$faelligkeit'] = id;
    return id;
  }

  @override
  Future<int?> findByIdentity(int vorlageId, String faelligkeit) async => drafts['$vorlageId/$faelligkeit'];
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
  BelegDraftGateway? belegDrafts,
  RecurringCategoryLookup? kategorien,
}) {
  return buildTestRecurringBookingUseCases(
    db.executor,
    sharedPosting: sharedPosting,
    belegDrafts: belegDrafts,
    kategorien: kategorien,
  );
}

Future<BuchungsVorlage> _createTemplate(
  RecurringBookingWorkspaceUseCases useCases, {
  String name = 'Vorlage',
  String art = 'Ausgabe',
  String modus = 'direkt',
  String faelligkeit = '2026-02-01',
  int? kategorieId,
  String betrag = '119.00',
}) {
  return useCases.createTemplate(
    name: name,
    art: art,
    modus: modus,
    intervall: 'monatlich',
    naechsteFaelligkeit: faelligkeit,
    kategorieId: kategorieId,
    kontoId: 1,
    betrag: betrag,
  );
}

void main() {
  group('Recurring booking templates — mode, direction, auto-generation', () {
    late AppDatabase db;

    setUp(() async {
      db = await _openDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('test_direkt_mode', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await _createTemplate(useCases, name: 'Miete');
      final List<DueInstanceView> due = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));

      expect(due.length, 1);
      expect(due.single.modus, 'direkt');
      expect(due.single.reviewStatus, 'pending');
      expect(due.single.vorlage.id, template.id);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      expect(await _count(db, 'rechnungen'), 0);
    });

    test('test_beleg_mode', () async {
      final _FakeBelegDrafts drafts = _FakeBelegDrafts();
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db, belegDrafts: drafts);
      await db.executor.runInsert(
        "INSERT INTO rechnungen (id, rechnungsnummer, typ, datum) VALUES (601, 'E-601', 'rechnung', '2026-02-01')",
        const <Object?>[],
      );
      final BuchungsVorlage template = await _createTemplate(
        useCases,
        name: 'Büromaterial',
        modus: 'beleg',
        betrag: '200.00',
      );
      await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));

      final DueInstanceView handedOff = await useCases.requestBelegHandoff(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(drafts.calls, 1);
      expect(drafts.lastVorlageId, template.id);
      expect(drafts.lastFaelligkeit, '2026-02-01');
      expect(handedOff.reviewStatus, 'handed_off');
      expect(handedOff.rechnungId, 601);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_financial_effect_is_blocked_without_the_shared_contract', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await _createTemplate(useCases, name: 'Miete');

      final DueInstanceView pending = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(pending.reviewStatus, 'pending');
      expect(pending.blockReason, contains('Gemeinsamer Buchungsvertrag'));
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      expect(await _count(db, 'rechnungen'), 0);
      final BuchungsVorlage unchanged = (await useCases.getTemplate(template.id))!;
      expect(unchanged.naechsteFaelligkeit, '2026-02-01');
    });

    test('test_ausgabe_direction', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      await _createTemplate(useCases, name: 'Miete');

      final List<DueInstanceView> due = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(due.single.art, 'Ausgabe');
      // The direction alone infers no VAT amount or account effect.
      expect(due.single.effektiverBetrag, '119.00');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_einnahme_direction', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      await _createTemplate(useCases, name: 'Honorare', art: 'Einnahme', betrag: '238.00');

      final List<DueInstanceView> due = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(due.single.art, 'Einnahme');
      expect(due.single.effektiverBetrag, '238.00');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_reject_an_unresolved_tax_or_account_interpretation', () async {
      final _FakeSharedPosting gateway = _FakeSharedPosting(available: true);
      final RecurringBookingWorkspaceUseCases useCases = _useCases(
        db,
        sharedPosting: gateway,
        kategorien: (int? _) async => const RecurringCategoryProbe(aktiv: true, mappingStatus: 'review_required'),
      );
      await db.executor.runInsert("INSERT INTO kategorien (id, bezeichnung) VALUES (3, 'Büro Kat')", const <Object?>[]);
      await db.executor.runInsert("INSERT INTO kategorien (id, bezeichnung) VALUES (6, 'Ohne Kat')", const <Object?>[]);
      final BuchungsVorlage template = await _createTemplate(useCases, name: 'Büro', kategorieId: 3);

      final DueInstanceView blocked = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(blocked.reviewStatus, 'blocked');
      expect(blocked.blockReason, contains('Prüfung'));
      expect(gateway.calls, 0);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);

      // Without independent account and tax data, `unmapped` stays blocked too.
      final RecurringBookingWorkspaceUseCases unmapped = _useCases(
        db,
        sharedPosting: gateway,
        kategorien: (int? _) async => const RecurringCategoryProbe(aktiv: true, mappingStatus: 'unmapped'),
      );
      final BuchungsVorlage bare = await unmapped.createTemplate(
        name: 'Ohne Konto',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kategorieId: 6,
      );
      final DueInstanceView bareBlocked = await unmapped.requestDirectExecution(
        vorlageId: bare.id,
        faelligkeit: '2026-02-01',
      );
      expect(bareBlocked.reviewStatus, 'blocked');
      expect(gateway.calls, 0);
      expect(await _count(db, 'journal'), 0);
    });

    test('test_auto_generate_journal_entry', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await _createTemplate(useCases, name: 'Miete');
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);

      final List<BuchungsOccurrence> staged = await repo.stageDueInstances(heute: DateTime(2026, 2, 1));
      expect(staged.length, 1);
      expect(staged.single.vorlageId, template.id);
      expect(staged.single.faelligkeit, '2026-02-01');
      expect(staged.single.reviewStatus, 'pending');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      expect(await _count(db, 'rechnungen'), 0);

      // The scan itself never advances the stored due date.
      final BuchungsVorlage unchanged = (await useCases.getTemplate(template.id))!;
      expect(unchanged.naechsteFaelligkeit, '2026-02-01');
    });

    test('test_repeated_scan_is_idempotent', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      await _createTemplate(useCases, name: 'Miete');
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);

      final List<BuchungsOccurrence> first = await repo.stageDueInstances(heute: DateTime(2026, 2, 1));
      final List<BuchungsOccurrence> second = await repo.stageDueInstances(heute: DateTime(2026, 2, 1));
      expect(first.length, 1);
      expect(second.length, 1);
      expect(second.single.id, first.single.id);
      expect((await repo.listAllOccurrences()).length, 1);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_inactive_template_skipped', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await _createTemplate(useCases, name: 'Miete');
      await useCases.pauseTemplate(template.id);
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);

      final List<BuchungsOccurrence> staged = await repo.stageDueInstances(heute: DateTime(2026, 2, 1));
      expect(staged, isEmpty);
      expect(await repo.listAllOccurrences(), isEmpty);
      expect(await _count(db, 'journal'), 0);
      final BuchungsVorlage paused = (await useCases.getTemplate(template.id))!;
      await expectLater(repo.stageDueInstance(paused), throwsA(isA<BuchungsVorlagenException>()));
    });

    test('test_missing_posting_contract_blocks_execution', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await _createTemplate(useCases, name: 'Miete');
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);
      await repo.stageDueInstances(heute: DateTime(2026, 2, 1));

      final DueInstanceView pending = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(pending.reviewStatus, 'pending');
      expect(pending.blockReason, contains('Gemeinsamer Buchungsvertrag'));
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);

      // The blocked attempt leaves the date unchanged and stays retryable.
      final BuchungsVorlage unchanged = (await useCases.getTemplate(template.id))!;
      expect(unchanged.naechsteFaelligkeit, '2026-02-01');
      final DueInstanceView retry = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(retry.reviewStatus, 'pending');
      expect((await repo.listOccurrences(template.id)).length, 1);
    });
  });
}
