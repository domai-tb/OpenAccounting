// ignore_for_file: prefer_initializing_formals

import 'dart:io';

import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const String profileSelectionTitle = 'Profil wählen';
const String lastUsedLabel = 'Zuletzt verwendet';
const String _setupCompletedKey = 'setup_completed';
const String _lastUsedProfileKey = 'last_used_profile';

/// Bankkonto-Daten für Schritt 2.
class BankAccount {
  const BankAccount({required this.name, required this.iban, required this.bic, this.inhaber});

  final String name;
  final String iban;
  final String bic;
  final String? inhaber;
}

/// 4-Schritt Wizard: Stammdaten → Konten → Kategorien → Abschluss.
enum WizardStep {
  stammdaten('Stammdaten'),
  konten('Konten'),
  kategorien('Kategorien'),
  abschluss('Abschluss');

  const WizardStep(this.label);
  final String label;
}

/// Wizard Service — Validierung, Navigation, Persistenz.
/// ponytail: kein BLoC, synchron Validierung + async Persistenz minimal.
class WizardService {
  WizardService({SetupRepository? repository, SharedPreferences? prefs, String? profileId})
    : _repository = repository,
      _prefsOverride = prefs,
      _profileId = profileId;

  final SetupRepository? _repository;
  final SharedPreferences? _prefsOverride;
  final String? _profileId;

  String get _completionKey {
    final String? profileId = _profileId;
    if (profileId == null || profileId.trim().isEmpty) return _setupCompletedKey;
    return '$_setupCompletedKey.${profileId.trim()}';
  }

  WizardStep currentStep = WizardStep.stammdaten;

  // Stammdaten Felder
  String _stammdatenName = '';
  String get stammdatenName => _stammdatenName;
  String _stammdatenStrasse = '';
  String get stammdatenStrasse => _stammdatenStrasse;
  String _stammdatenPlz = '';
  String get stammdatenPlz => _stammdatenPlz;
  String _stammdatenOrt = '';
  String get stammdatenOrt => _stammdatenOrt;

  void updateStammdaten({required String name, String? strasse, String? plz, String? ort}) {
    _stammdatenName = name;
    if (strasse != null) _stammdatenStrasse = strasse;
    if (plz != null) _stammdatenPlz = plz;
    if (ort != null) _stammdatenOrt = ort;
  }

  // Compatibility method retained for callers that do not use the public state field.
  // ignore: use_setters_to_change_properties
  void goTo(WizardStep step) => currentStep = step;

  void next() {
    final int idx = WizardStep.values.indexOf(currentStep);
    if (idx < WizardStep.values.length - 1) {
      currentStep = WizardStep.values[idx + 1];
    }
  }

  void back() {
    final int idx = WizardStep.values.indexOf(currentStep);
    if (idx > 0) currentStep = WizardStep.values[idx - 1];
  }

  // ---------------------------------------------------------------------------
  // Validierung
  // ---------------------------------------------------------------------------

  String? validateStammdaten({required String name}) {
    if (name.trim().isEmpty) return 'Name ist Pflicht';
    return null;
  }

  String? validateKonten({required List<BankAccount> accounts, String? kassenbestand}) {
    // kassenbestand negativ check delegates
    final String? kErr = validateKassenbestand(kassenbestand ?? '');
    if (kErr != null) return kErr;
    if (accounts.isEmpty) return 'Mindestens ein Konto erforderlich';
    for (final BankAccount a in accounts) {
      if (!SetupRepository.isValidIban(a.iban)) {
        return 'IBAN ungültig: ${a.iban}';
      }
    }
    return null;
  }

  String? validateKassenbestand(String raw) {
    final String t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    if (t.startsWith('-')) return 'Kassenbestand darf nicht negativ sein';
    // numeric check
    final double? v = double.tryParse(t);
    if (v == null) return 'Kassenbestand ungültig';
    if (v < 0) return 'Kassenbestand darf nicht negativ sein';
    return null;
  }

  String? validateKategorien({required List<int> selectedIds}) {
    if (selectedIds.isEmpty) return 'Mindestens eine Kategorie erforderlich';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Persistenz
  // ---------------------------------------------------------------------------

  Future<SharedPreferences> _prefs() async {
    if (_prefsOverride != null) return _prefsOverride;
    return SharedPreferences.getInstance();
  }

  Future<bool> isCompleted() async {
    final SharedPreferences p = await _prefs();
    return p.getBool(_completionKey) ?? false;
  }

  Future<void> markCompleted() async {
    final SharedPreferences p = await _prefs();
    await p.setBool(_completionKey, true);
  }

  Future<void> clearCompleted() async {
    final SharedPreferences p = await _prefs();
    await p.remove(_completionKey);
  }

  /// Prüft ob Setup erforderlich (leere DB).
  Future<bool> isSetupRequired(AppDatabase db) async {
    try {
      final List<Map<String, Object?>> rows = await db.executor.runSelect('SELECT name FROM unternehmen', const []);
      if (rows.isEmpty) return true;
      final hasRealCompany = rows.any((row) {
        final rawName = row['name'];
        final name = rawName is String ? rawName.trim() : '';
        return name.isNotEmpty && name != 'Meine Firma';
      });
      if (hasRealCompany) return false;
      // The completion flag is written only after the database transaction
      // commits. It is valid for an intentional skip only after the row exists.
      return !(await isCompleted());
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SetupDatabaseException('Datenbank konnte für den Setup-Status nicht gelesen werden', cause: error),
        stackTrace,
      );
    }
  }

  Future<void> completeWizard({
    required String companyName,
    String? strasse,
    String? plz,
    String? ort,
    String? steuernummer,
    String? ustIdnr,
    String? rechtsform,
    List<BankAccount> accounts = const <BankAccount>[],
    String kassenbestand = '0.00',
    List<int> kategorieIds = const <int>[1],
  }) async {
    final String? err1 = validateStammdaten(name: companyName);
    if (err1 != null) throw SetupException(err1);
    final String? err2 = validateKonten(accounts: accounts, kassenbestand: kassenbestand);
    if (err2 != null) throw SetupException(err2);
    final String? err3 = validateKategorien(selectedIds: kategorieIds);
    if (err3 != null) throw SetupException(err3);

    if (_repository != null) {
      await _repository.runInTransaction<void>((SetupRepository repository) async {
        await repository.saveUnternehmen(
          name: companyName,
          strasse: strasse,
          plz: plz,
          ort: ort,
          steuernummer: steuernummer,
          ustIdnr: ustIdnr,
          rechtsform: rechtsform,
        );
        for (final BankAccount a in accounts) {
          await repository.createKonto(name: a.name, iban: a.iban, bic: a.bic);
        }
        final String kb = kassenbestand.trim().isEmpty ? '0.00' : kassenbestand;
        await repository.ensureKassenKonto(betrag: kb);
        await repository.ensureKategorienSelected(kategorieIds);
      });
    } else {
      // fallback when no repo injected (pure validation test) — still mark completed
    }
    await markCompleted();
  }

  Future<void> skipWizard() async {
    if (_repository != null) {
      await _repository.createMinimalDefaults();
    }
    await markCompleted();
  }
}

/// Profilauswahl-Service — steuert Startup-Entscheidung.
class ProfileSelectionService {
  ProfileSelectionService({String? baseDir, SharedPreferences? prefs}) : _baseDir = baseDir, _prefsOverride = prefs;

  final String? _baseDir;
  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> _prefs() async {
    if (_prefsOverride != null) return _prefsOverride;
    return SharedPreferences.getInstance();
  }

  Future<String?> getLastUsedProfile() async {
    final SharedPreferences p = await _prefs();
    return p.getString(_lastUsedProfileKey);
  }

  Future<void> setLastUsedProfile(String name) async {
    final SharedPreferences p = await _prefs();
    await p.setString(_lastUsedProfileKey, name);
  }

  /// Ob Auswahl nötig: mehr als ein tatsächlich angelegtes Profil.
  Future<bool> needsSelection() async => (await listProfiles()).length > 1;

  Future<List<String>> listProfiles() async {
    final Directory root = Directory(p.join(_baseDir ?? ProfileManager.getDefaultBaseDir(), 'profiles'));
    if (!root.existsSync()) return <String>[];
    final List<FileSystemEntity> entries = await root.list().toList();
    final List<String> profiles = <String>[];
    for (final FileSystemEntity entry in entries) {
      if (entry is Directory) profiles.add(p.basename(entry.path));
    }
    profiles.sort();
    return profiles;
  }
}
