import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_execution.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_repository.dart';

class _AcceptingPort implements QuickBookingPostingPort {
  _AcceptingPort({this.postingIdentity = 'posting-1'});

  final List<Map<String, Object?>> received = <Map<String, Object?>>[];
  final String postingIdentity;

  @override
  bool get isAvailable => true;

  @override
  Future<String> submit({
    required QuickBookingPreset preset,
    required String businessDate,
    required String betrag,
  }) async {
    received.add(<String, Object?>{
      'presetId': preset.id,
      'direction': preset.direction?.db,
      'kontoId': preset.kontoId,
      'kategorieId': preset.kategorieId,
      'ustSatzId': preset.ustSatzId,
      'modus': preset.modus?.db,
      'businessDate': businessDate,
      'betrag': betrag,
    });
    return postingIdentity;
  }
}

/// Execution through the posting port: exact handoff, gate, no direct writes.
void main() {
  group('Quick-booking execution', () {
    late AppDatabase db;
    late QuickBookingRepository repo;
    late int kontoId;
    late int kategorieId;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = QuickBookingRepository(db.executor);
      kontoId = await db.executor.runInsert('INSERT INTO konten (name, iban) VALUES (?, ?)', const <Object?>[
        'Giro',
        'DE001',
      ]);
      kategorieId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Execkat', 1)",
        const <Object?>[],
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<QuickBookingPreset> completePreset() {
      return repo.create(
        name: 'Honorar',
        direction: QuickBookingDirection.einnahme,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.netto,
        betrag: '100.00',
      );
    }

    Future<int> journalCount() async {
      final rows = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      return ((rows.single['c']! as num)).toInt();
    }

    test('test_quick_booking_preset', () async {
      final preset = await repo.create(
        name: 'Standard',
        direction: QuickBookingDirection.einnahme,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.netto,
        betrag: '50.00',
        beschreibung: 'Std',
      );
      expect(preset.direction, QuickBookingDirection.einnahme);
      expect(preset.modus, QuickBookingModus.netto);
      final stored = await repo.findById(preset.id);
      expect(stored?.kontoId, kontoId);
      expect(stored?.kategorieId, kategorieId);
    });

    test('test_quick_booking_execution', () async {
      final preset = await completePreset();
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: _AcceptingPort(),
        presetId: preset.id,
        businessDate: '2026-05-10',
      );
      expect(execution.executed, isTrue);
      expect(execution.postingIdentity, isNotNull);
    });

    test('test_quick_booking_with_invalid_preset', () async {
      final legacy = await repo.create(name: 'Unvollständig');
      expect(legacy.needsReview, isTrue);
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: _AcceptingPort(),
        presetId: legacy.id,
        businessDate: '2026-05-10',
      );
      expect(execution.executed, isFalse);
      expect(await journalCount(), 0);
    });

    test('test_posting_service_accepts_the_preset', () async {
      final preset = await completePreset();
      final port = _AcceptingPort();
      final before = await journalCount();
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: port,
        presetId: preset.id,
        businessDate: '2026-05-10',
      );
      expect(execution.executed, isTrue);
      expect(execution.postingIdentity, 'posting-1');
      expect(port.received.single['presetId'], preset.id);
      expect(port.received.single['direction'], 'einnahme');
      expect(port.received.single['businessDate'], '2026-05-10');
      expect(num.parse(port.received.single['betrag'].toString()), 100);
      expect(await journalCount(), before, reason: 'no direct journal insert');
    });

    test('test_quick_booking_rejects_empty_or_malformed_override_amount', () async {
      final preset = await completePreset();
      final port = _AcceptingPort();
      for (final String betrag in <String>['', '   ', 'not-an-amount']) {
        final execution = await executePreset(
          executor: db.executor,
          repository: repo,
          port: port,
          presetId: preset.id,
          businessDate: '2026-05-10',
          betrag: betrag,
        );
        expect(execution.executed, isFalse, reason: 'Rejected override: "$betrag"');
        expect(execution.unavailableReason, contains('Betrag'));
      }
      expect(port.received, isEmpty);
      expect(await journalCount(), 0);
    });

    test('test_quick_booking_requires_committed_posting_identity', () async {
      final preset = await completePreset();
      final before = await journalCount();
      for (final String identity in <String>['', '   ']) {
        final execution = await executePreset(
          executor: db.executor,
          repository: repo,
          port: _AcceptingPort(postingIdentity: identity),
          presetId: preset.id,
          businessDate: '2026-05-10',
        );
        expect(execution.executed, isFalse, reason: 'Rejected identity: "$identity"');
        expect(execution.postingIdentity, isNull);
      }
      expect(await journalCount(), before);
    });

    test('test_posting_contract_is_unavailable', () async {
      final preset = await completePreset();
      final before = await journalCount();
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: const UnavailableQuickBookingPosting(),
        presetId: preset.id,
        businessDate: '2026-05-10',
      );
      expect(execution.executed, isFalse);
      expect(execution.unavailableReason, contains('nicht verfügbar'));
      expect(await journalCount(), before);
      final journals = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      expect(journals.single['c'], 0);
    });

    test('test_preset_has_no_default_amount', () async {
      final preset = await repo.create(
        name: 'Ohne Betrag',
        direction: QuickBookingDirection.einnahme,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.netto,
      );
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: _AcceptingPort(),
        presetId: preset.id,
        businessDate: '2026-05-10',
      );
      expect(execution.executed, isFalse);
      expect(execution.unavailableReason, contains('Betrag'));
      expect(await journalCount(), 0);
    });
  });
}
