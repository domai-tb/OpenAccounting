import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:openaccounting/features/setup/wizard_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _db() => AppDatabase.createTestDatabase();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Setup Wizard - Validierung & Ablauf', () {
    test('Schritt 1: Firmenname ist Pflichtfeld', () {
      final service = WizardService();
      expect(service.validateStammdaten(name: '', locale: 'de_DE'), isNotNull);
      expect(service.validateStammdaten(name: '   ', locale: 'de_DE'), isNotNull);
      expect(service.validateStammdaten(name: 'Muster GmbH', locale: 'de_DE'), isNull);
    });

    test('Schritt 2: mindestens ein Konto mit gültiger IBAN erforderlich', () {
      final service = WizardService();
      expect(service.validateKonten(accounts: const <BankAccount>[], locale: 'de_DE'), isNotNull);
      expect(
        service.validateKonten(
          accounts: <BankAccount>[const BankAccount(name: 'Giro', iban: 'INVALID', bic: '')],
          locale: 'de_DE',
        ),
        isNotNull,
      );
      expect(
        service.validateKonten(
          accounts: <BankAccount>[const BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')],
          locale: 'de_DE',
        ),
        isNull,
      );
    });

    test('Schritt 2: IBAN-Format validiert (DE)', () {
      expect(SetupRepository.isValidIban('DE89370400440532013000'), isTrue);
      expect(SetupRepository.isValidIban('de89 3704 0044 0532 0130 00'), isTrue);
      expect(SetupRepository.isValidIban('INVALID'), isFalse);
      expect(SetupRepository.isValidIban(''), isFalse);
    });

    test('Schritt 3: mindestens eine Kategorie erforderlich', () {
      final service = WizardService();
      expect(service.validateKategorien(selectedIds: const <int>[], locale: 'de_DE'), isNotNull);
      expect(service.validateKategorien(selectedIds: <int>[1], locale: 'de_DE'), isNull);
    });

    test('Kassenbestand: negativer Betrag abgelehnt', () {
      final service = WizardService();
      expect(service.validateKassenbestand('-10.00', locale: 'de_DE'), isNotNull);
      expect(service.validateKassenbestand('-0.01', locale: 'de_DE'), isNotNull);
      expect(service.validateKassenbestand('0.00', locale: 'de_DE'), isNull);
      expect(service.validateKassenbestand('150.00', locale: 'de_DE'), isNull);
      expect(service.validateKassenbestand('', locale: 'de_DE'), isNull);
    });

    test('Wizard hat genau 4 Schritte in korrekter Reihenfolge', () {
      expect(WizardStep.values.length, 4);
      expect(WizardStep.values[0], WizardStep.stammdaten);
      expect(WizardStep.values[1], WizardStep.konten);
      expect(WizardStep.values[2], WizardStep.kategorien);
      expect(WizardStep.values[3], WizardStep.abschluss);
    });

    test('Schrittbezeichnungen auf Deutsch', () {
      expect(WizardStep.stammdaten.label, 'Stammdaten');
      expect(WizardStep.konten.label, 'Konten');
      expect(WizardStep.kategorien.label, 'Kategorien');
      expect(WizardStep.abschluss.label, 'Abschluss');
    });

    test('Vollständiger Wizard-Ablauf persistiert Daten', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      await db.kategorienRepository.create(bezeichnung: 'Kat 1');
      await db.kategorienRepository.create(bezeichnung: 'Kat 2');
      final repo = SetupRepository(db.executor);
      final service = WizardService(repository: repo);

      await service.completeWizard(
        companyName: 'Muster GmbH',
        strasse: 'Hauptstr. 1',
        plz: '10115',
        ort: 'Berlin',
        accounts: <BankAccount>[const BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')],
        kategorieIds: <int>[1, 2],
        locale: 'de_DE',
      );

      final rows = await db.executor.runSelect('SELECT name FROM unternehmen WHERE id = 1', const []);
      expect(rows.single['name'], 'Muster GmbH');

      final selectedCategories = await db.executor.runSelect(
        'SELECT setup_kategorie_ids FROM unternehmen WHERE id = 1',
        const [],
      );
      expect(selectedCategories.single['setup_kategorie_ids'], '1,2');

      final konten = await db.executor.runSelect('SELECT * FROM konten WHERE kontoart = ?', const ['Kasse']);
      expect(konten.length, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('setup_completed'), isTrue);

      await db.close();
    });

    test('Zurück-Navigation erhält Daten', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final service = WizardService(repository: SetupRepository(db.executor));
      service.updateStammdaten(name: 'Test GmbH', strasse: 'Str 1');
      service.goTo(WizardStep.konten);
      expect(service.currentStep, WizardStep.konten);
      service.goTo(WizardStep.stammdaten);
      expect(service.stammdatenName, 'Test GmbH');
      await db.close();
    });

    test('Überspringen erstellt Minimal-Defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final repo = SetupRepository(db.executor);
      final service = WizardService(repository: repo);

      await service.skipWizard();

      final unternehmen = await db.executor.runSelect('SELECT name FROM unternehmen WHERE id = 1', const []);
      expect(unternehmen.isNotEmpty, isTrue);

      final konten = await db.executor.runSelect('SELECT * FROM konten WHERE kontoart = ?', const ['Kasse']);
      expect(konten.length, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('setup_completed'), isTrue);

      await db.close();
    });

    test('Empty-Database-Erkennung triggert Wizard', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      final service = WizardService(repository: SetupRepository(db.executor));
      // fresh DB empty or 'Meine Firma' -> should require setup
      expect(await service.isSetupRequired(db, locale: 'de_DE'), isTrue);

      // insert real company (ensure row exists first)
      await db.executor.runInsert('INSERT OR REPLACE INTO unternehmen (id, name) VALUES (1, ?)', const [
        'Echte Firma GmbH',
      ]);
      expect(await service.isSetupRequired(db, locale: 'de_DE'), isFalse);
      await db.close();
    });

    test('Completion-Flag persistiert', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final service = WizardService();
      expect(await service.isCompleted(), isFalse);
      await service.markCompleted();
      expect(await service.isCompleted(), isTrue);
      await service.clearCompleted();
      expect(await service.isCompleted(), isFalse);
    });

    test('Setup retry does not duplicate an account with the same IBAN', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      await db.kategorienRepository.create(bezeichnung: 'Kat 1');
      final service = WizardService(repository: SetupRepository(db.executor));
      const account = BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX');

      await service.completeWizard(companyName: 'Muster GmbH', accounts: <BankAccount>[account], locale: 'de_DE');
      await service.completeWizard(companyName: 'Muster GmbH', accounts: <BankAccount>[account], locale: 'de_DE');

      final accounts = await db.executor.runSelect('SELECT id FROM konten WHERE iban = ?', const <Object?>[
        'DE89370400440532013000',
      ]);
      expect(accounts, hasLength(1));
      await db.close();
    });

    test('Setup status surfaces database errors instead of treating them as first run', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = _db();
      await db.ensureOpen();
      await db.executor.runCustom('DROP TABLE unternehmen');
      final service = WizardService(repository: SetupRepository(db.executor));

      await expectLater(service.isSetupRequired(db, locale: 'de_DE'), throwsA(isA<SetupDatabaseException>()));
      await db.close();
    });
  });

  group('Profil-Auswahl', () {
    test('Profil-Labels auf Deutsch', () {
      expect(profileSelectionTitle, 'Profil wählen');
      expect(lastUsedLabel, 'Zuletzt verwendet');
    });

    test('Single-Profil wird automatisch geladen (kein Auswahl nötig)', () async {
      final Directory base = await Directory.systemTemp.createTemp('openaccounting_profile_selection_');
      addTearDown(() => base.delete(recursive: true));
      await Directory('${base.path}/profiles/Firma').create(recursive: true);
      final svc = ProfileSelectionService(baseDir: base.path);
      expect(await svc.needsSelection(), isFalse);
    });
  });

  group('WizardPage Widget', () {
    testWidgets('zeigt 4 Schritte, Weiter/Zurück, Überspringen und Fortschritt', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(const MaterialApp(home: WizardPage()));
      await tester.pumpAndSettle();

      expect(find.text('Stammdaten'), findsWidgets);
      expect(find.text('Konten'), findsWidgets);
      expect(find.text('Kategorien'), findsWidgets);
      expect(find.text('Abschluss'), findsWidgets);

      expect(find.text('Weiter'), findsOneWidget);
      expect(find.text('Überspringen'), findsOneWidget);
      // Fortschritt 1/4
      expect(find.textContaining('1'), findsWidgets);
    });

    testWidgets('Schritt 1 Validierung blockiert Weiter bei leerem Namen', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(const MaterialApp(home: WizardPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Name ist Pflicht'), findsOneWidget);
    });

    testWidgets('Navigation Guard: SetupPage zeigt Wizard bei leerer DB', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(const MaterialApp(home: WizardPage()));
      await tester.pumpAndSettle();
      expect(find.byType(WizardPage), findsOneWidget);
    });

    testWidgets('Profil-Auswahl Widget zeigt Profil wählen und Zuletzt verwendet', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'last_used_profile': 'Firma A'});
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSelectionWidget(profiles: ['Firma A', 'Firma B'], lastUsed: 'Firma A'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profil wählen'), findsOneWidget);
      // last used highlighted
      expect(find.textContaining('Zuletzt verwendet'), findsOneWidget);
    });
  });
}
