import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';

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
  final TextEditingController _kasseCtrl = TextEditingController(text: '0.00');
  String? _nameError;
  String? _ibanError;
  String? _kategorieError;
  String? _kasseError;
  final Set<int> _selectedKategorien = <int>{1};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _strasseCtrl.dispose();
    _plzCtrl.dispose();
    _ortCtrl.dispose();
    _ibanCtrl.dispose();
    _bicCtrl.dispose();
    _kasseCtrl.dispose();
    super.dispose();
  }

  WizardStep get _step => _service.currentStep;

  Future<void> _handleWeiter() async {
    setState(() {
      _nameError = null;
      _ibanError = null;
      _kategorieError = null;
      _kasseError = null;
    });
    if (_step == WizardStep.stammdaten) {
      final String? err = _service.validateStammdaten(name: _nameCtrl.text);
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
          : <BankAccount>[BankAccount(name: 'Giro', iban: iban, bic: _bicCtrl.text.trim())];
      final String? err = _service.validateKonten(accounts: accounts, kassenbestand: _kasseCtrl.text);
      if (err != null) {
        if (err.contains('Kassenbestand')) {
          setState(() => _kasseError = err);
        } else {
          setState(() => _ibanError = err);
        }
        return;
      }
      final String? kErr = _service.validateKassenbestand(_kasseCtrl.text);
      if (kErr != null) {
        setState(() => _kasseError = kErr);
        return;
      }
      setState(() => _service.next());
      return;
    }
    if (_step == WizardStep.kategorien) {
      final String? err = _service.validateKategorien(selectedIds: _selectedKategorien.toList());
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
    try {
      final String iban = _ibanCtrl.text.trim();
      final List<BankAccount> accounts = iban.isEmpty
          ? <BankAccount>[const BankAccount(name: 'Giro', iban: 'DE89370400440532013000', bic: 'COBADEFFXXX')]
          : <BankAccount>[BankAccount(name: 'Giro', iban: iban, bic: _bicCtrl.text.trim())];
      await _service.completeWizard(
        companyName: _nameCtrl.text.trim().isEmpty ? 'Meine Firma' : _nameCtrl.text.trim(),
        strasse: _strasseCtrl.text,
        plz: _plzCtrl.text,
        ort: _ortCtrl.text,
        accounts: accounts,
        kassenbestand: _kasseCtrl.text.trim().isEmpty ? '0.00' : _kasseCtrl.text.trim(),
        kategorieIds: _selectedKategorien.toList(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setup abgeschlossen')));
    } on SetupException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _skip() async {
    await _service.skipWizard();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Setup übersprungen')));
  }

  void _handleZurueck() {
    setState(() => _service.back());
  }

  @override
  Widget build(BuildContext context) {
    final int stepIndex = WizardStep.values.indexOf(_step);
    return AppPage(
      header: const AppPageHeader(title: 'Setup Wizard'),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LinearProgressIndicator(value: (stepIndex + 1) / WizardStep.values.length),
            const SizedBox(height: 12),
            Text(
              'Schritt ${stepIndex + 1} von ${WizardStep.values.length}',
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
                        s.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: s == _step ? FontWeight.w600 : FontWeight.w400, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _buildStepContent(),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                if (_step != WizardStep.stammdaten)
                  OutlinedButton(onPressed: _handleZurueck, child: const Text('Zurück')),
                const Spacer(),
                TextButton(onPressed: _skip, child: const Text('Überspringen')),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _handleWeiter,
                  child: Text(_step == WizardStep.abschluss ? 'Fertig' : 'Weiter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case WizardStep.stammdaten:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Stammdaten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Firmenname *',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _strasseCtrl,
              decoration: const InputDecoration(labelText: 'Straße', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _plzCtrl,
                    decoration: const InputDecoration(labelText: 'PLZ', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _ortCtrl,
                    decoration: const InputDecoration(labelText: 'Ort', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
        );
      case WizardStep.konten:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Konten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _ibanCtrl,
              decoration: InputDecoration(
                labelText: 'IBAN *',
                errorText: _ibanError,
                border: const OutlineInputBorder(),
                hintText: 'DE89 3704 0044 0532 0130 00',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bicCtrl,
              decoration: const InputDecoration(labelText: 'BIC', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kasseCtrl,
              decoration: InputDecoration(
                labelText: 'Kassenbestand (EUR)',
                errorText: _kasseError,
                border: const OutlineInputBorder(),
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        );
      case WizardStep.kategorien:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Kategorien', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (int i = 1; i <= 6; i++)
                  FilterChip(
                    label: Text('Kategorie $i'),
                    selected: _selectedKategorien.contains(i),
                    onSelected: (bool v) {
                      setState(() {
                        if (v) {
                          _selectedKategorien.add(i);
                        } else {
                          _selectedKategorien.remove(i);
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Abschluss', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Firma: ${_nameCtrl.text.isEmpty ? "Meine Firma" : _nameCtrl.text}'),
                    Text('IBAN: ${_ibanCtrl.text.isEmpty ? "—" : _ibanCtrl.text}'),
                    Text('Kassenbestand: ${_kasseCtrl.text} €'),
                    Text('Kategorien: ${_selectedKategorien.join(", ")}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Prüfe deine Angaben und klicke auf Fertig.'),
          ],
        );
    }
  }
}

/// Profil-Auswahl Widget — DESIGN §36, spec Profilwahl.
/// Zeigt "Profil wählen" + "Zuletzt verwendet" Markierung.
class ProfileSelectionWidget extends StatelessWidget {
  const ProfileSelectionWidget({required this.profiles, this.lastUsed, super.key});
  final List<String> profiles;
  final String? lastUsed;
  @override
  Widget build(BuildContext context) {
    final String? effectiveLast = lastUsed ?? (profiles.isNotEmpty ? profiles.first : null);
    return Scaffold(
      appBar: AppBar(title: const Text(profileSelectionTitle)),
      body: ListView.builder(
        itemCount: profiles.length,
        itemBuilder: (BuildContext context, int i) {
          final String name = profiles[i];
          final bool isLast = name == effectiveLast;
          return ListTile(
            title: Text(name),
            subtitle: isLast ? const Text(lastUsedLabel) : null,
            selected: isLast,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            onTap: () {},
            trailing: isLast ? const Icon(Icons.check) : null,
          );
        },
      ),
    );
  }
}
