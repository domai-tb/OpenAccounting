import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/setup/catalog_provenance.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Provider für WizardService — DB via appDatabaseProvider.
final wizardServiceProvider = Provider<WizardService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return WizardService(repository: SetupRepository(db.executor));
});

/// 4-Schritt Setup Wizard Seite — DESIGN §45, §3-5 Shell, Material3.
/// Ponytail: State in Service, UI nur dünne Schicht.
class WizardPage extends StatefulWidget {
  const WizardPage({this.service, super.key});
  final WizardService? service;
  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  late final WizardService _service = widget.service ?? WizardService();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _strasseCtrl = TextEditingController();
  final TextEditingController _plzCtrl = TextEditingController();
  final TextEditingController _ortCtrl = TextEditingController();
  final TextEditingController _ibanCtrl = TextEditingController();
  final TextEditingController _bicCtrl = TextEditingController();
  final TextEditingController _inhaberCtrl = TextEditingController();
  final TextEditingController _steuerNrCtrl = TextEditingController();
  final TextEditingController _ustIdCtrl = TextEditingController();
  final TextEditingController _rechtsformCtrl = TextEditingController();
  final TextEditingController _kasseCtrl = TextEditingController(text: '0.00');
  String? _nameError;
  String? _ibanError;
  String? _kategorieError;
  String? _kasseError;
  final Set<int> _selectedKategorien = <int>{};
  bool _busy = false;
  bool _catalogVerified = false;
  List<({int id, String name})> _verifiedKategorien = const <({int id, String name})>[];
  bool _catalogLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  Future<void> _loadCatalog() async {
    try {
      final CatalogProvenanceState state = await _service.loadProvenance();
      if (!mounted) return;
      setState(() {
        _catalogVerified = state.verified;
        _verifiedKategorien = state.verifiedNames;
        _catalogLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _catalogLoaded = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strasseCtrl.dispose();
    _plzCtrl.dispose();
    _ortCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    _inhaberCtrl.dispose();
    _steuerNrCtrl.dispose();
    _ustIdCtrl.dispose();
    _rechtsformCtrl.dispose();
    _kasseCtrl.dispose();
    super.dispose();
  }

  WizardStep get _step => _service.currentStep;

  /// Active locale tag for the service validation messages, mirroring the
  /// catalog resolution used for this page's copy (German when isolated).
  String get _activeLocale {
    final AppLocalizations? provided = AppLocalizations.of(context);
    if (provided == null) return localeTag(const Locale('de'));
    return localeTag(Localizations.localeOf(context));
  }

  Future<void> _handleWeiter() async {
    if (_busy) return;
    setState(() {
      _nameError = null;
      _ibanError = null;
      _kategorieError = null;
      _kasseError = null;
    });
    if (_step == WizardStep.stammdaten) {
      final String? err = _service.validateStammdaten(name: _nameCtrl.text, locale: _activeLocale);
      if (err != null) {
        setState(() => _nameError = err);
        return;
      }
      _service.updateStammdaten(
        name: _nameCtrl.text,
        strasse: _strasseCtrl.text,
        plz: _plzCtrl.text,
        ort: _ortCtrl.text,
      );
      setState(() => _service.next());
      return;
    }
    if (_step == WizardStep.konten) {
      final String iban = _ibanCtrl.text.trim();
      final List<BankAccount> accounts = iban.isEmpty
          ? const <BankAccount>[]
          : <BankAccount>[
              BankAccount(
                name: 'Giro',
                iban: iban,
                bic: _bicCtrl.text.trim(),
                inhaber: _inhaberCtrl.text.trim().isEmpty ? null : _inhaberCtrl.text.trim(),
              ),
            ];
      // Cash-balance feedback owns its field, so validate it before the
      // account rules instead of routing by message content.
      final String? kErr = _service.validateKassenbestand(_kasseCtrl.text, locale: _activeLocale);
      if (kErr != null) {
        setState(() => _kasseError = kErr);
        return;
      }
      final String? err = _service.validateKonten(
        accounts: accounts,
        kassenbestand: _kasseCtrl.text,
        locale: _activeLocale,
      );
      if (err != null) {
        setState(() => _ibanError = err);
        return;
      }
      setState(() => _service.next());
      return;
    }
    if (_step == WizardStep.kategorien) {
      final String? err = _service.validateKategorien(
        selectedIds: _selectedKategorien.toList(),
        locale: _activeLocale,
        catalogVerified: _catalogVerified,
      );
      if (err != null) {
        setState(() => _kategorieError = err);
        return;
      }
      setState(() => _service.next());
      return;
    }
    if (_step == WizardStep.abschluss) {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final String iban = _ibanCtrl.text.trim();
      final List<BankAccount> accounts = iban.isEmpty
          ? const <BankAccount>[]
          : <BankAccount>[
              BankAccount(
                name: 'Giro',
                iban: iban,
                bic: _bicCtrl.text.trim(),
                inhaber: _inhaberCtrl.text.trim().isEmpty ? null : _inhaberCtrl.text.trim(),
              ),
            ];
      final bool deferred = !_catalogVerified;
      await _service.completeWizard(
        companyName: _nameCtrl.text.trim().isEmpty ? 'Meine Firma' : _nameCtrl.text.trim(),
        strasse: _strasseCtrl.text,
        plz: _plzCtrl.text,
        ort: _ortCtrl.text,
        steuernummer: _steuerNrCtrl.text.trim().isEmpty ? null : _steuerNrCtrl.text.trim(),
        ustIdnr: _ustIdCtrl.text.trim().isEmpty ? null : _ustIdCtrl.text.trim(),
        rechtsform: _rechtsformCtrl.text.trim().isEmpty ? null : _rechtsformCtrl.text.trim(),
        accounts: accounts,
        kassenbestand: _kasseCtrl.text.trim().isEmpty ? '0.00' : _kasseCtrl.text.trim(),
        kategorieIds: _selectedKategorien.toList(),
        categoriesDeferred: deferred,
        locale: _activeLocale,
      );
      if (mounted) {
        final GoRouter? router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go('/');
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).setupComplete)));
        }
      }
    } on SetupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).setupDatabaseError}: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.skipWizard();
      if (mounted) {
        final GoRouter? router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go('/');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).actionSkip)));
        }
      }
    } on SetupException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).setupDatabaseError}: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleZurueck() {
    if (_busy) return;
    setState(() => _service.back());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final int stepIndex = WizardStep.values.indexOf(_step);
    return AppPage(
      header: AppPageHeader(title: l10n.setupWizardTitle),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              label: l10n.setupStep,
              value: '${l10n.setupStep} ${stepIndex + 1} / ${WizardStep.values.length}',
              child: LinearProgressIndicator(value: (stepIndex + 1) / WizardStep.values.length),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.setupStep} ${stepIndex + 1} / ${WizardStep.values.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (final WizardStep s in WizardStep.values)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: s == _step ? Theme.of(context).colorScheme.primaryContainer : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Text(
                        _localizedStepLabel(l10n, s),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: s == _step ? FontWeight.w600 : FontWeight.w400, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildStepContent(l10n),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                if (_step != WizardStep.stammdaten)
                  OutlinedButton(onPressed: _busy ? null : _handleZurueck, child: Text(l10n.actionBack)),
                const Spacer(),
                TextButton(onPressed: _busy ? null : _skip, child: Text(l10n.actionSkip)),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _handleWeiter,
                  child: Text(
                    _busy
                        ? l10n.setupSaving
                        : (_step == WizardStep.abschluss ? l10n.setupComplete : l10n.actionContinue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n) {
    switch (_step) {
      case WizardStep.stammdaten:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.setupCompanyName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '${l10n.setupCompanyName} *',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _strasseCtrl,
              decoration: InputDecoration(labelText: l10n.setupCompanyNameHint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _plzCtrl,
                    decoration: InputDecoration(labelText: l10n.pdfCustomerNumber, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _ortCtrl,
                    decoration: InputDecoration(labelText: l10n.pdfTo, border: const OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _steuerNrCtrl,
              decoration: InputDecoration(labelText: l10n.pdfTaxNumber, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ustIdCtrl,
              decoration: InputDecoration(labelText: l10n.pdfVatId, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rechtsformCtrl,
              decoration: const InputDecoration(labelText: 'Rechtsform', border: OutlineInputBorder()),
            ),
          ],
        );
      case WizardStep.konten:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.sidebarBanking, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _ibanCtrl,
              decoration: InputDecoration(
                labelText: '${l10n.setupIban} *',
                errorText: _ibanError,
                border: const OutlineInputBorder(),
                hintText: 'DE89 3704 0044 0532 0130 00',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bicCtrl,
              decoration: InputDecoration(labelText: l10n.pdfBic, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inhaberCtrl,
              decoration: const InputDecoration(labelText: 'Kontoinhaber', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kasseCtrl,
              decoration: InputDecoration(
                labelText: l10n.setupCashBalance,
                errorText: _kasseError,
                border: const OutlineInputBorder(),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        );
      case WizardStep.kategorien:
        if (!_catalogLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!_catalogVerified) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l10n.setupCategories, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(l10n.setupCategoriesHint),
              const SizedBox(height: 8),
              Text(l10n.setupRequired),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.setupCategories, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final entry in _verifiedKategorien)
                  if (!isSyntheticCategoryLabel(entry.name))
                    FilterChip(
                      label: Text(entry.name),
                      selected: _selectedKategorien.contains(entry.id),
                      onSelected: (bool v) {
                        setState(() {
                          if (v) {
                            _selectedKategorien.add(entry.id);
                          } else {
                            _selectedKategorien.remove(entry.id);
                          }
                        });
                      },
                    ),
              ],
            ),
            if (_kategorieError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _kategorieError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        );
      case WizardStep.abschluss:
        final String holder = _inhaberCtrl.text.trim().isEmpty ? '—' : _inhaberCtrl.text.trim();
        final String categorySummary = _catalogVerified
            ? _verifiedKategorien
                  .where((entry) => _selectedKategorien.contains(entry.id))
                  .map((entry) => entry.name)
                  .join(', ')
            : l10n.setupRequired;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.setupComplete, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${l10n.setupCompanyName}: ${_nameCtrl.text.isEmpty ? l10n.setupCompanyName : _nameCtrl.text}',
                    ),
                    Text('${l10n.setupIban}: ${_ibanCtrl.text.trim().isEmpty ? '—' : _ibanCtrl.text.trim()}'),
                    Text('Kontoinhaber: $holder'),
                    Text('${l10n.setupCashBalance}: ${_kasseCtrl.text} €'),
                    Text('${l10n.setupCategories}: ${categorySummary.isEmpty ? l10n.setupRequired : categorySummary}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.setupRequired),
          ],
        );
    }
  }

  String _localizedStepLabel(AppLocalizations l10n, WizardStep step) {
    return switch (step) {
      WizardStep.stammdaten => l10n.setupStepCompany,
      WizardStep.konten => l10n.setupStepAccounts,
      WizardStep.kategorien => l10n.setupStepCategories,
      WizardStep.abschluss => l10n.setupStepCompletion,
    };
  }
}

/// Profil-Auswahl Widget — DESIGN §36, spec Profilwahl.
/// Zeigt "Profil wählen" + "Zuletzt verwendet" Markierung.
class ProfileSelectionWidget extends StatelessWidget {
  const ProfileSelectionWidget({required this.profiles, this.lastUsed, this.onSelected, super.key});
  final List<String> profiles;
  final String? lastUsed;
  final ValueChanged<String>? onSelected;

  Future<void> _selectProfile(BuildContext context, String name) async {
    try {
      final bool restartRequired = await ProfileManager().setActiveProfile(name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restartRequired
                ? appLocalizationsOf(context).setupSaved
                : appLocalizationsOf(context).workspaceLocalProfile,
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).loadError}: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? effectiveLast = lastUsed;
    return Scaffold(
      appBar: AppBar(title: Text(appLocalizationsOf(context).profileSelectionTitle)),
      body: ListView.builder(
        itemCount: profiles.length,
        itemBuilder: (BuildContext context, int i) {
          final String name = profiles[i];
          final bool isLast = name == effectiveLast;
          return ListTile(
            title: Text(name),
            subtitle: isLast ? Text(appLocalizationsOf(context).profileLastUsed) : null,
            selected: isLast,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            onTap: onSelected == null ? () => unawaited(_selectProfile(context, name)) : () => onSelected!(name),
            trailing: isLast ? const Icon(Icons.check) : null,
          );
        },
      ),
    );
  }
}
