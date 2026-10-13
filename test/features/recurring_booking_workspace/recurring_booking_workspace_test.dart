// Fixed scenario dates keep due-date behavior deterministic; kept explicit intentionally.
// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/recurring_booking_wiring.dart';
import 'package:openaccounting/features/recurring/recurring_booking_workspace_usecases.dart';

/// Workspace behavior at the canonical `/recurring` route
/// (specs/specs/recurring-booking-workspace): review-first due instances,
/// shared-boundary direct execution, and invoice-draft handoff.
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

class _FakeBelegDrafts implements BelegDraftGateway {
  _FakeBelegDrafts({required this.available});

  final bool available;
  int calls = 0;
  int nextId = 501;
  int? lastVorlageId;
  String? lastFaelligkeit;
  final Map<String, int> drafts = <String, int>{};

  @override
  bool get isAvailable => available;

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
    final int id = nextId++;
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
}) {
  return buildTestRecurringBookingUseCases(db.executor, sharedPosting: sharedPosting, belegDrafts: belegDrafts);
}

void main() {
  group('Recurring booking workspace', () {
    late AppDatabase db;

    setUp(() async {
      db = await _openDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    test('test_create_and_review_a_scheduled_template', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage created = await useCases.createTemplate(
        name: 'Miete Büro',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
        beschreibung: 'Monatliche Büromiete',
      );

      final BuchungsVorlage? detail = await useCases.getTemplate(created.id);
      expect(detail, isNotNull);
      expect(detail!.name, 'Miete Büro');
      expect(detail.art, 'Ausgabe');
      expect(detail.modus, 'direkt');
      expect(detail.intervall, 'monatlich');
      expect(detail.naechsteFaelligkeit, '2026-02-01');
      expect(detail.betrag, '800.00');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      expect(await _count(db, 'rechnungen'), 0);
    });

    test('test_reject_an_invalid_template_schedule', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      Matcher fieldError(String field) {
        return throwsA(
          isA<BuchungsVorlagenException>().having(
            (BuchungsVorlagenException e) => e.message,
            'message',
            contains(field),
          ),
        );
      }

      Future<void> expectField(Future<void> Function() call, String field) {
        return expectLater(call(), fieldError(field));
      }

      await expectField(
        () => useCases.createTemplate(
          name: 'Miete',
          art: 'Ausgabe',
          modus: 'direkt',
          intervall: 'wöchentlich',
          naechsteFaelligkeit: '2026-02-01',
        ),
        'Intervall',
      );
      await expectField(
        () => useCases.createTemplate(
          name: '   ',
          art: 'Ausgabe',
          modus: 'direkt',
          intervall: 'monatlich',
          naechsteFaelligkeit: '2026-02-01',
        ),
        'Name',
      );
      await expectField(
        () => useCases.createTemplate(
          name: 'Miete',
          art: 'Ausgabe',
          modus: 'direkt',
          intervall: 'monatlich',
          naechsteFaelligkeit: '   ',
        ),
        'Fälligkeit',
      );
      await expectField(
        () => useCases.createTemplate(
          name: 'Miete',
          art: 'Unbekannt',
          modus: 'direkt',
          intervall: 'monatlich',
          naechsteFaelligkeit: '2026-02-01',
        ),
        'art',
      );
      await expectField(
        () => useCases.createTemplate(
          name: 'Miete',
          art: 'Ausgabe',
          modus: 'falsch',
          intervall: 'monatlich',
          naechsteFaelligkeit: '2026-02-01',
        ),
        'modus',
      );
      expect(await useCases.listTemplates(), isEmpty);
    });

    test('test_review_a_due_instance', () async {
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
      expect(due.single.modus, 'direkt');
      expect(due.single.effektiverBetrag, '800.00');
      expect(due.single.reviewStatus, 'pending');
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
      expect(await _count(db, 'rechnungen'), 0);
    });

    test('test_repeated_refresh_does_not_duplicate_a_due_instance', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
      );

      final List<DueInstanceView> first = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      final List<DueInstanceView> second = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(first.length, 1);
      expect(second.length, 1);
      expect(second.single.occurrence.id, first.single.occurrence.id);
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);
      expect((await repo.listAllOccurrences()).length, 1);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);
    });

    test('test_paused_template_has_no_actionable_due_instance', () async {
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

      final List<DueInstanceView> due = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(due, isEmpty);
      final BuchungsVorlagenRepository repo = BuchungsVorlagenRepository(db.executor);
      expect(await repo.listAllOccurrences(), isEmpty);
      expect(await _count(db, 'journal'), 0);
    });

    test('test_confirm_a_ready_direct_mode_instance', () async {
      final _FakeSharedPosting gateway = _FakeSharedPosting(available: true, journalId: 81);
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db, sharedPosting: gateway);
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Miete',
        art: 'Ausgabe',
        modus: 'direkt',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '800.00',
      );
      await db.executor.runInsert(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (81, '2026-02-01', 800, 1, 'Seed')",
        const <Object?>[],
      );
      final int journalBefore = await _count(db, 'journal');
      await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));

      final DueInstanceView confirmed = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(gateway.calls, 1);
      expect(gateway.lastVorlageId, template.id);
      expect(gateway.lastFaelligkeit, '2026-02-01');
      expect(confirmed.reviewStatus, 'posted');
      expect(confirmed.journalId, 81);

      // A successful posting advances the stored date by one interval step.
      final BuchungsVorlage advanced = (await useCases.getTemplate(template.id))!;
      expect(advanced.naechsteFaelligkeit, '2026-03-01');
      final DueInstanceView repeated = await useCases.requestDirectExecution(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(repeated.reviewStatus, 'posted');
      expect(gateway.calls, 1);
      expect(await _count(db, 'journal'), journalBefore);
    });

    test('test_keep_direct_mode_pending_without_the_shared_contract', () async {
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

      // The display reads the persisted non-terminal state without changing it.
      final List<DueInstanceView> shown = await useCases.refreshDueInstances(heute: DateTime(2026, 2, 1));
      expect(shown.single.reviewStatus, 'pending');
      expect(shown.single.blockReason, contains('Gemeinsamer Buchungsvertrag'));
      final BuchungsVorlage unchanged = (await useCases.getTemplate(template.id))!;
      expect(unchanged.naechsteFaelligkeit, '2026-02-01');
    });

    test('test_create_an_incoming_invoice_draft_from_a_reviewed_instance', () async {
      final _FakeBelegDrafts drafts = _FakeBelegDrafts(available: true);
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db, belegDrafts: drafts);
      await db.executor.runInsert(
        "INSERT INTO rechnungen (id, rechnungsnummer, typ, datum) VALUES (501, 'E-501', 'rechnung', '2026-02-01')",
        const <Object?>[],
      );
      await db.executor.runInsert(
        "INSERT INTO rechnungen (id, rechnungsnummer, typ, datum) VALUES (777, 'E-777', 'rechnung', '2026-02-01')",
        const <Object?>[],
      );
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Büromaterial',
        art: 'Ausgabe',
        modus: 'beleg',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '200.00',
        lieferantId: 1,
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
      expect(handedOff.rechnungId, drafts.drafts['${template.id}/2026-02-01']);
      expect(await _count(db, 'journal'), 0);
      expect(await _count(db, 'vorsteuer_ansprueche'), 0);

      // The stored date advances by one interval step; repeats reuse the draft.
      final BuchungsVorlage advanced = (await useCases.getTemplate(template.id))!;
      expect(advanced.naechsteFaelligkeit, '2026-03-01');
      final DueInstanceView repeated = await useCases.requestBelegHandoff(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(repeated.rechnungId, handedOff.rechnungId);
      expect(drafts.calls, 1);

      // Recovery attaches a draft created before the link was saved.
      final _FakeBelegDrafts recovering = _FakeBelegDrafts(available: true);
      final RecurringBookingWorkspaceUseCases recoveringUseCases = _useCases(db, belegDrafts: recovering);
      final BuchungsVorlage second = await recoveringUseCases.createTemplate(
        name: 'Reinigung',
        art: 'Ausgabe',
        modus: 'beleg',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '90.00',
        lieferantId: 1,
      );
      recovering.drafts['${second.id}/2026-02-01'] = 777;
      final DueInstanceView recovered = await recoveringUseCases.requestBelegHandoff(
        vorlageId: second.id,
        faelligkeit: '2026-02-01',
      );
      expect(recovered.reviewStatus, 'handed_off');
      expect(recovered.rechnungId, 777);
      expect(recovering.calls, 0);
    });

    test('test_keep_beleg_mode_reviewable_when_draft_handoff_is_unavailable', () async {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(db);
      final BuchungsVorlage template = await useCases.createTemplate(
        name: 'Büromaterial',
        art: 'Ausgabe',
        modus: 'beleg',
        intervall: 'monatlich',
        naechsteFaelligkeit: '2026-02-01',
        kontoId: 1,
        betrag: '200.00',
        lieferantId: 1,
      );

      final DueInstanceView reviewable = await useCases.requestBelegHandoff(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(reviewable.reviewStatus, 'failed');
      expect(reviewable.handoffError, contains('Übergabe'));
      expect(await _count(db, 'rechnungen'), 0);
      expect(await _count(db, 'journal'), 0);
      final BuchungsVorlage unchanged = (await useCases.getTemplate(template.id))!;
      expect(unchanged.naechsteFaelligkeit, '2026-02-01');

      // The instance stays reviewable with its persisted failure shown.
      final DueInstanceView again = await useCases.reviewInstance(
        vorlageId: template.id,
        faelligkeit: '2026-02-01',
      );
      expect(again.reviewStatus, 'failed');
      expect(again.handoffError, contains('Übergabe'));
    });
  });
}
