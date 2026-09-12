// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal in-memory SharedPreferences for testing.
class _MockPrefs implements SharedPreferences {
  final Map<String, Object?> _store = {};

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  Object? get(String key) => _store[key];

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  double? getDouble(String key) => (_store[key] as num?)?.toDouble();

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  Set<String> getKeys() => _store.keys.toSet();

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  List<String>? getStringList(String key) => (_store[key] as List<dynamic>?)?.cast<String>();

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _store[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Setup onboarding integrity', () {
    late AppDatabase db;
    late SetupRepository repo;
    late WizardService wizard;
    late _MockPrefs prefs;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = SetupRepository(db.executor);
      prefs = _MockPrefs();
      wizard = WizardService(repository: repo, prefs: prefs);
    });

    tearDown(() async {
      await db.close();
    });

    // ── Task 1: Finish reaches the dashboard ──

    test('test_setup_onboarding_integrity_1_1_finish_reaches_the_dashboard', () async {
      // Complete the wizard with a real company name.
      await wizard.completeWizard(
        companyName: 'Echte GmbH',
        accounts: [const BankAccount(name: 'Girokonto', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')],
        kassenbestand: '1000.00',
      );

      // After completion, hasUnternehmen must return true.
      // (This is what the router checks to decide whether to redirect to /setup.)
      final configured = await hasUnternehmen(db);
      expect(configured, isTrue, reason: 'Router must see the company as configured after wizard completion');
    });

    // ── Task 2: Skip follows its documented policy ──

    test('test_setup_onboarding_integrity_1_2_skip_follows_its_documented_policy', () async {
      // Skip the wizard.
      await wizard.skipWizard();

      // After skip, the wizard is marked completed.
      expect(await wizard.isCompleted(), isTrue, reason: 'Wizard must be marked completed after skip');

      // But hasUnternehmen should still return false (skip creates defaults, not real config).
      // The router should NOT redirect back to setup — skip means "use defaults, go to dashboard".
      // The key invariant: isCompleted must be true so the router doesn't loop.
      expect(await wizard.isSetupRequired(db), isFalse, reason: 'Setup must not be required after skip');
    });

    // ── Task 3: Opening cash agrees across sources ──

    test('test_setup_onboarding_integrity_2_1_opening_cash_agrees_across_sources', () async {
      await wizard.completeWizard(
        companyName: 'Cash GmbH',
        accounts: [const BankAccount(name: 'Kasse', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')],
        kassenbestand: '500.00',
      );

      // Check that the kassenkonto exists.
      final kontoRows = await db.executor.runSelect(
        "SELECT saldo FROM konten WHERE name = 'Kasse' OR name = 'Kassenbestand' LIMIT 1",
        const [],
      );
      expect(kontoRows, isNotEmpty, reason: 'Kassenkonto must exist');
      expect(kontoRows.first['saldo'], 500.00, reason: 'Kassenkonto saldo must reflect the opening balance');

      // Check the journal entry for the opening balance.
      final journalRows = await db.executor.runSelect(
        "SELECT betrag FROM journal WHERE beschreibung LIKE '%Kasse%' LIMIT 1",
        const [],
      );
      expect(journalRows, isNotEmpty, reason: 'Opening cash journal entry must exist');
      final journalBetrag = (journalRows.first['betrag'] as num?) ?? 0;
      expect(journalBetrag, 500.00, reason: 'Opening cash journal must reflect 500.00');
    });

    // ── Task 4: Intermediate failure rolls back ──

    test('test_setup_onboarding_integrity_2_2_intermediate_failure_rolls_back', () async {
      // Attempt to complete with invalid data (empty company name).
      expect(
        () => wizard.completeWizard(companyName: '', accounts: []),
        throwsA(isA<SetupException>()),
        reason: 'Empty company name must throw SetupException',
      );

      // After failed completion, no unternehmen should exist.
      final rows = await db.executor.runSelect('SELECT COUNT(*) AS cnt FROM unternehmen', const []);
      final count = rows.first['cnt']! as int;
      expect(count, 0, reason: 'No company should exist after failed wizard completion');
    });

    // ── Task 5: Required first-run decisions are visible ──

    test('test_setup_onboarding_integrity_3_1_required_first_run_decisions_are_visible', () async {
      // The wizard must have steps for stammdaten, konten, kassenbestand, and kategorien.
      // Verify the wizard step enum covers all required concepts.
      expect(WizardStep.values.length, greaterThanOrEqualTo(4), reason: 'Wizard must have at least 4 steps');

      final stepNames = WizardStep.values.map((s) => s.name).toList();
      expect(stepNames, contains('stammdaten'), reason: 'Wizard must have stammdaten step');
      expect(stepNames, contains('konten'), reason: 'Wizard must have konten step');
      expect(stepNames, contains('kategorien'), reason: 'Wizard must have kategorien step');
      expect(stepNames, contains('abschluss'), reason: 'Wizard must have abschluss step');
    });

    // ── Task 6: Blank identity is handled honestly ──

    test('test_setup_onboarding_integrity_3_2_blank_identity_is_handled_honestly', () async {
      // Skip creates "Meine Firma" — this must NOT cause a redirect loop.
      await wizard.skipWizard();

      // The router uses hasUnternehmen to decide.
      // After skip, isCompleted is true, so setup is not required.
      expect(await wizard.isSetupRequired(db), isFalse, reason: 'Skip must prevent setup redirect loop');

      // Complete with real name — must be configured.
      await wizard.completeWizard(
        companyName: 'Real GmbH',
        accounts: [const BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')],
      );
      final configured = await hasUnternehmen(db);
      expect(configured, isTrue, reason: 'Real company name must be recognized as configured');
    });

    // ── Task 7: Stable opening marker, idempotent, unrelated rows untouched ──

    test('test_setup_onboarding_integrity_4_1_opening_marker_is_stable_and_idempotent', () async {
      await wizard.completeWizard(
        companyName: 'Marker GmbH',
        accounts: [const BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')],
        kassenbestand: '500.00',
      );

      final openingRows = await db.executor.runSelect(
        'SELECT id, betrag, beleg_typ, is_opening_balance, konto_id FROM journal WHERE is_opening_balance = 1 LIMIT 1',
        const [],
      );
      expect(openingRows, isNotEmpty, reason: 'Opening entry must carry is_opening_balance=1');
      expect(openingRows.single['beleg_typ'], BelegTyp.eroeffnung, reason: 'Opening must be Eroeffnung not Einnahme');
      expect(openingRows.single['is_opening_balance'], 1);
      final int openingId = (openingRows.single['id']! as num).toInt();

      // column survives PRAGMA
      final cols = await db.executor.runSelect('PRAGMA table_info(journal)', const []);
      expect(cols.any((Map<String, Object?> c) => c['name'] == 'is_opening_balance'), isTrue);

      // insert unrelated journal on same Kasse konto — previous bug would clobber this row
      final List<Map<String, Object?>> kasseRows = await db.executor.runSelect(
        "SELECT id FROM konten WHERE kontoart = 'Kasse' OR name = 'Kasse' LIMIT 1",
        const [],
      );
      final int kasseId = (kasseRows.single['id']! as num).toInt();
      final String today = DateTime.now().toIso8601String().substring(0, 10);
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[today, 'Barverkauf', 1, '100.00', BelegTyp.einnahme, kasseId],
      );

      // re-run setup with new amount — must update same stable row, not duplicate or clobber unrelated
      await repo.ensureKassenKonto(betrag: '750.00');

      final List<Map<String, Object?>> openingRows2 = await db.executor.runSelect(
        'SELECT id, betrag, is_opening_balance FROM journal WHERE is_opening_balance = 1',
        const [],
      );
      expect(openingRows2.length, 1, reason: 'exactly one opening entry must remain after rerun');
      expect((openingRows2.single['id']! as num).toInt(), openingId, reason: 'opening id stable');
      expect((openingRows2.single['betrag']! as num).toDouble(), closeTo(750.00, 0.001));
      expect(openingRows2.single['is_opening_balance'], 1);

      final List<Map<String, Object?>> unrelated = await db.executor.runSelect(
        "SELECT betrag FROM journal WHERE beschreibung = 'Barverkauf' LIMIT 1",
        const [],
      );
      expect(unrelated.single['betrag'], isNotNull);
      expect(
        (unrelated.single['betrag']! as num).toDouble(),
        closeTo(100.00, 0.001),
        reason: 'unrelated must not be overwritten',
      );

      // excluded from revenue per subtask 04 predicate: force opening kategorie to euer-relevant and prove ignored
      await db.executor.runUpdate('UPDATE journal SET kategorie_id = 1 WHERE id = ?', <Object?>[openingId]);
      // ensure kategorie 1 has euer line (seeded); if not, set it
      await db.executor.runUpdate('UPDATE kategorien SET euer_zeile = 12 WHERE id = 1', const []);
      final EuerService euer = EuerService(db.executor);
      final int jahr = DateTime.now().year;
      final result = await euer.generate(jahr: jahr);
      // opening (Eroeffnung) forced to zeile 12 must still be 0 or only 100 from Barverkauf, not 850
      // Barverkauf is Einnahme 100 on same kategorie, opening 750 must be excluded => zeile 12 = 100
      expect(result.zeile(12), '100.00', reason: 'Eroeffnung must be excluded even when forced to revenue kategorie');
      expect(result.gewinn, '100.00');
    });
  });
}
