import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/core/app_locale.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/dashboard/dashboard_page.dart';
import 'package:openaccounting/features/setup/wizard_page.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

export 'package:openaccounting/app/app_shell.dart';

/// DESIGN §3 App Shell, §4 Sidebar (240px), §34 Breakpoints, §8 Theme handling.
/// ponytail: single GoRouter + ShellRoute — no per-feature router explosion.
/// ponytail: hasUnternehmen probes raw table — survives missing-table state
/// before Batch 3 migrations create 38 tables.

/// Sidebar destinations — order per DESIGN §4.
enum AppRoute {
  dashboard('/'),
  invoices('/invoices'),
  receipts('/receipts'),
  banking('/banking'),
  contacts('/contacts'),
  taxes('/taxes'),
  reports('/reports'),
  settings('/settings'),
  setup('/setup'),
  help('/help');

  const AppRoute(this.path);
  final String path;
}

Future<bool> hasUnternehmen(AppDatabase db) async {
  try {
    final rows = await db.executor.runSelect('SELECT name FROM unternehmen', const []);
    if (rows.isEmpty) return false;
    for (final Map<String, Object?> row in rows) {
      final Object? rawName = row['name'];
      final String name = rawName is String ? rawName.trim() : '';
      if (name.isEmpty) continue;
      if (name != 'Meine Firma') return true;

      // A skipped wizard intentionally creates this placeholder plus the
      // opening Kasse account. A fresh empty database has neither.
      final defaults = await db.executor.runSelect("SELECT id FROM konten WHERE kontoart = 'Kasse' LIMIT 1", const []);
      if (defaults.isNotEmpty) return true;
    }
    return false;
  } catch (_) {
    // ponytail: no such table or not open → treat as unconfigured, redirect to /setup.
    return false;
  }
}

GoRouter createRouter(AppDatabase db) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.matchedLocation;
      // allow setup always, avoid loop.
      if (loc == '/setup') return null;
      final configured = await hasUnternehmen(db);
      if (!configured) return '/setup';
      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (context, state) => const DashboardPageImpl()),
          GoRoute(
            path: '/invoices',
            builder: (context, state) {
              final typ = state.uri.queryParameters['typ'];
              final status = state.uri.queryParameters['status'];
              return InvoicesPage(filterTyp: typ, filterStatus: status);
            },
            routes: <RouteBase>[
              GoRoute(path: 'new', builder: (context, state) => const InvoiceDraftPage()),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return InvoiceDetailPage(id: id);
                },
              ),
            ],
          ),
          GoRoute(path: '/receipts', builder: (context, state) => const ReceiptsPage()),
          GoRoute(path: '/banking', builder: (context, state) => const BankImportPage()),
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const ContactsPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ContactDetailPage(id: id);
                },
              ),
            ],
          ),
          GoRoute(path: '/taxes', builder: (context, state) => const TaxesPage()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsPage()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
          GoRoute(path: '/help', builder: (context, state) => const HelpPage()),
          GoRoute(path: '/setup', builder: (context, state) => const SetupPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryUnavailablePage()),
          // German alias per specs/app/spec.md deep-link scenario — preserve query.
          GoRoute(
            path: '/rechnungen',
            redirect: (BuildContext context, GoRouterState state) {
              final q = state.uri.query;
              return q.isEmpty ? '/invoices' : '/invoices?$q';
            },
          ),
          GoRoute(
            path: '/belege',
            redirect: (BuildContext context, GoRouterState state) {
              final q = state.uri.query;
              return q.isEmpty ? '/receipts' : '/receipts?$q';
            },
          ),
          GoRoute(path: '/bank', redirect: (BuildContext context, GoRouterState state) => '/banking'),
          GoRoute(path: '/kontakte', redirect: (BuildContext context, GoRouterState state) => '/contacts'),
          GoRoute(path: '/steuern', redirect: (BuildContext context, GoRouterState state) => '/taxes'),
          GoRoute(path: '/auswertungen', redirect: (BuildContext context, GoRouterState state) => '/reports'),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return createRouter(db);
});

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({this.filterTyp, this.filterStatus, super.key});

  final String? filterTyp;
  final String? filterStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> filters = <String>[
      if (filterTyp != null) 'Typ: $filterTyp',
      if (filterStatus != null) 'Status: $filterStatus',
    ];
    return ProductionRoutePage(
      title: 'Rechnungen',
      table: 'rechnungen',
      subtitle: filters.isEmpty ? null : filters.join(' · '),
      primaryActionLabel: 'Neue Rechnung',
      onPrimaryAction: () => context.go('/invoices/new'),
      filterTyp: filterTyp,
      filterStatus: filterStatus,
    );
  }
}

class InvoiceDraftPage extends ConsumerStatefulWidget {
  const InvoiceDraftPage({super.key});

  @override
  ConsumerState<InvoiceDraftPage> createState() => _InvoiceDraftPageState();
}

class _InvoiceDraftPageState extends ConsumerState<InvoiceDraftPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController(text: _todayIsoDate());
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final num quantity = _parseAmount(_quantityController.text)!;
    final num price = _parseAmount(_priceController.text)!;
    setState(() => _saving = true);
    try {
      final RechnungItem invoice = await ref
          .read(appServicesProvider)
          .rechnungen
          .createDraftRechnung(
            datum: _dateController.text.trim(),
            positionen: <RechnungPositionItem>[
              RechnungPositionItem(
                bezeichnung: _descriptionController.text.trim(),
                menge: quantity,
                einzelpreis: price,
                gesamt: quantity * price,
                // The domain default is 19%.
                position: 0,
              ),
            ],
          );
      ref.invalidate(routeRecordsProvider('rechnungen'));
      if (mounted) context.go('/invoices/${invoice.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Entwurf konnte nicht gespeichert werden: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateDate(String? value) {
    final String date = value?.trim() ?? '';
    final DateTime? parsed = DateTime.tryParse(date);
    if (parsed == null || date.length != 10 || parsed.toIso8601String().substring(0, 10) != date) {
      return 'Datum im Format JJJJ-MM-TT eingeben';
    }
    return null;
  }

  String? _validatePositiveAmount(String? value, String label) {
    final num? parsed = _parseAmount(value ?? '');
    if (parsed == null || parsed <= 0) return '$label muss größer als 0 sein';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: const AppPageHeader(title: 'Neue Rechnung', showFilterToolbar: false),
      child: Form(
        key: _formKey,
        child: ListView(
          children: <Widget>[
            Text('Rechnungsentwurf', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Speichere die erste Position als Entwurf. Weitere Positionen können anschließend ergänzt werden.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const ValueKey<String>('invoice_draft_date'),
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Datum', hintText: '2026-01-31'),
              validator: _validateDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey<String>('invoice_draft_description'),
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Position'),
              validator: (String? value) => value == null || value.trim().isEmpty ? 'Position ist erforderlich' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: const ValueKey<String>('invoice_draft_quantity'),
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Menge'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (String? value) => _validatePositiveAmount(value, 'Menge'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey<String>('invoice_draft_price'),
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Einzelpreis netto'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (String? value) => _validatePositiveAmount(value, 'Einzelpreis'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                OutlinedButton(
                  onPressed: _saving ? null : () => context.go('/invoices'),
                  child: const Text('Abbrechen'),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const ValueKey<String>('save_invoice_draft'),
                  onPressed: _saving ? null : _saveDraft,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Entwurf speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ProductionRecordDetailPage(table: 'rechnungen', title: 'Rechnung $id', id: id);
  }
}

class ReceiptsPage extends ConsumerWidget {
  const ReceiptsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProductionRoutePage(title: 'Belege', table: 'belege');
  }
}

class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProductionRoutePage(title: 'Kontakte', table: 'kunden');
  }
}

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ProductionRecordDetailPage(table: 'kunden', title: 'Kontakt $id', id: id);
  }
}

class TaxesPage extends ConsumerWidget {
  const TaxesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProductionRoutePage(title: 'Steuern', table: 'ustva_exporte');
  }
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProductionRoutePage(title: 'Auswertungen', table: 'journal');
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _SettingsContent();
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent();

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  final ProfileManager _profileManager = ProfileManager();
  late Future<_ProfileSnapshot> _profiles = _loadProfiles();

  Future<_ProfileSnapshot> _loadProfiles() async {
    final String active = await _profileManager.getActiveProfile();
    final List<String> profiles = await _profileManager.listProfiles();
    if (profiles.contains(active)) {
      return _ProfileSnapshot(active: active, profiles: profiles);
    }
    return _ProfileSnapshot(active: active, profiles: <String>[active, ...profiles]);
  }

  void _reloadProfiles() => setState(() => _profiles = _loadProfiles());

  Future<void> _selectProfile(String name) async {
    try {
      final bool restartRequired = await _profileManager.setActiveProfile(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restartRequired ? 'Profil gespeichert. Bitte OpenAccounting neu starten.' : 'Profil ist bereits aktiv.',
          ),
        ),
      );
      _reloadProfiles();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Profil konnte nicht gewählt werden: $error')));
      }
    }
  }

  Future<void> _createProfile() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Neues Profil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Profilname'),
          onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await _profileManager.createProfile(name);
      if (!mounted) return;
      _reloadProfiles();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil angelegt.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Profil konnte nicht angelegt werden: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Locale selectedLocale = ref.watch(appLocaleProvider);
    final ThemeMode selectedTheme = ref.watch(themeModeProvider);
    return AppPage(
      header: const AppPageHeader(title: 'Einstellungen', showFilterToolbar: false),
      child: ListView(
        children: <Widget>[
          Text('Darstellung', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<Locale>(
            key: ValueKey<String>('locale_${selectedLocale.languageCode}'),
            initialValue: selectedLocale,
            decoration: const InputDecoration(labelText: 'Sprache'),
            items: const <DropdownMenuItem<Locale>>[
              DropdownMenuItem<Locale>(value: Locale('de'), child: Text('Deutsch')),
              DropdownMenuItem<Locale>(value: Locale('en'), child: Text('English')),
            ],
            onChanged: (Locale? locale) {
              if (locale != null) {
                unawaited(ref.read(appLocaleProvider.notifier).setLocale(locale));
              }
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ThemeMode>(
            key: ValueKey<String>('theme_${selectedTheme.name}'),
            initialValue: selectedTheme,
            decoration: const InputDecoration(labelText: 'Farbschema'),
            items: const <DropdownMenuItem<ThemeMode>>[
              DropdownMenuItem<ThemeMode>(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem<ThemeMode>(value: ThemeMode.light, child: Text('Hell')),
              DropdownMenuItem<ThemeMode>(value: ThemeMode.dark, child: Text('Dunkel')),
            ],
            onChanged: (ThemeMode? mode) {
              if (mode != null) {
                unawaited(ref.read(themeModeProvider.notifier).setMode(mode));
              }
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Beträge ausblenden'),
            subtitle: const Text('Finanzbeträge im Dashboard maskieren'),
            value: ref.watch(privacyModeProvider),
            onChanged: (bool value) => unawaited(ref.read(privacyModeProvider.notifier).setEnabled(value)),
          ),
          const SizedBox(height: 32),
          Row(
            children: <Widget>[
              Expanded(child: Text('Profile', style: Theme.of(context).textTheme.titleMedium)),
              FilledButton.icon(
                onPressed: _createProfile,
                icon: const Icon(Icons.add),
                label: const Text('Neues Profil'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<_ProfileSnapshot>(
            future: _profiles,
            builder: (BuildContext context, AsyncSnapshot<_ProfileSnapshot> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Profile konnten nicht geladen werden: ${snapshot.error}');
              }
              final _ProfileSnapshot value = snapshot.data!;
              return RadioGroup<String>(
                groupValue: value.active,
                onChanged: (String? selected) {
                  if (selected != null) {
                    unawaited(_selectProfile(selected));
                  }
                },
                child: Column(
                  children: <Widget>[
                    for (final String profile in value.profiles)
                      RadioListTile<String>(
                        value: profile,
                        selected: profile == value.active,
                        title: Text(profile),
                        subtitle: profile == value.active ? const Text('Aktiv') : const Text('Neustart zum Wechseln'),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Profile haben getrennte Datenbanken. Nach einem Wechsel ist ein Neustart erforderlich.'),
        ],
      ),
    );
  }
}

class _ProfileSnapshot {
  const _ProfileSnapshot({required this.active, required this.profiles});

  final String active;
  final List<String> profiles;
}

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      header: const AppPageHeader(title: 'Hilfe', showFilterToolbar: false),
      child: ListView(
        children: const <Widget>[
          ListTile(
            leading: Icon(Icons.language),
            title: Text('Sprache und Darstellung'),
            subtitle: Text('Diese Optionen findest du in den Einstellungen.'),
          ),
          ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Lokale Daten'),
            subtitle: Text('Daten werden im aktiven Profil auf diesem Gerät gespeichert.'),
          ),
          ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Rechnungsentwurf'),
            subtitle: Text('Erstelle einen Entwurf über Rechnungen > Neue Rechnung.'),
          ),
        ],
      ),
    );
  }
}

class ProductionRoutePage extends ConsumerWidget {
  const ProductionRoutePage({
    required this.title,
    required this.table,
    this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.filterTyp,
    this.filterStatus,
    super.key,
  });

  final String title;
  final String table;
  final String? subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? filterTyp;
  final String? filterStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteRecordsQuery? query = filterTyp == null && filterStatus == null
        ? null
        : RouteRecordsQuery(table: table, typ: filterTyp, status: filterStatus);
    final FutureProvider<List<Map<String, Object?>>> source = query == null
        ? routeRecordsProvider(table)
        : routeRecordsQueryProvider(query);
    final AsyncValue<List<Map<String, Object?>>> records = ref.watch(source);
    return AppPage(
      maxWidth: 1100,
      header: AppPageHeader(
        title: title,
        subtitle: subtitle,
        showFilterToolbar: false,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
      ),
      child: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) =>
            _routeError(context, table, error, stackTrace, onRetry: () => ref.invalidate(source)),
        data: (List<Map<String, Object?>> rows) => _buildRecordList(context, ref, table, rows, source),
      ),
    );
  }
}

class ProductionRecordDetailPage extends ConsumerWidget {
  const ProductionRecordDetailPage({required this.table, required this.title, required this.id, super.key});

  final String table;
  final String title;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? recordId = int.tryParse(id);
    if (recordId == null) {
      return const NotFoundPage(message: 'Die Datensatz-ID ist ungültig.');
    }
    final RouteRecordKey key = RouteRecordKey(table: table, id: recordId);
    final AsyncValue<Map<String, Object?>?> record = ref.watch(routeRecordProvider(key));
    return record.when(
      loading: () => AppPage(
        header: AppPageHeader(title: title, showFilterToolbar: false),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => _routeError(
        context,
        '$table/$id',
        error,
        stackTrace,
        onRetry: () => ref.invalidate(routeRecordProvider(key)),
      ),
      data: (Map<String, Object?>? row) {
        if (row == null) {
          return NotFoundPage(message: 'Der Datensatz mit der ID $id wurde nicht gefunden.');
        }
        return AppPage(
          header: AppPageHeader(title: title, showFilterToolbar: false),
          child: ListView(
            children: <Widget>[
              Text('Datensatz-ID: $id', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final MapEntry<String, Object?> entry in row.entries)
                if (entry.key != 'id')
                  ListTile(
                    dense: true,
                    title: Text(_fieldLabel(entry.key)),
                    subtitle: Text(_displayValue(entry.value)),
                  ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _goBackOrHome(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Zurück'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildRecordList(
  BuildContext context,
  WidgetRef ref,
  String table,
  List<Map<String, Object?>> rows,
  FutureProvider<List<Map<String, Object?>>> source,
) {
  if (rows.isEmpty) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.inbox_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('Noch keine Datensätze vorhanden'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(source),
            icon: const Icon(Icons.refresh),
            label: const Text('Aktualisieren'),
          ),
        ],
      ),
    );
  }
  return ListView.separated(
    padding: const EdgeInsets.only(bottom: 24),
    itemCount: rows.length + 1,
    separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
    itemBuilder: (BuildContext context, int index) {
      if (index == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Text('${rows.length} Datensätze'),
              const Spacer(),
              IconButton(
                tooltip: 'Aktualisieren',
                onPressed: () => ref.invalidate(source),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      }
      final Map<String, Object?> row = rows[index - 1];
      final int? id = _recordId(row);
      return ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(_recordTitle(table, row)),
        subtitle: Text(_recordSubtitle(table, row)),
        trailing: id == null ? null : Text('#$id'),
        onTap: id == null ? null : () => _openRecord(context, table, id, row),
      );
    },
  );
}

void _openRecord(BuildContext context, String table, int id, Map<String, Object?> row) {
  if (table == 'rechnungen') {
    context.go('/invoices/$id');
    return;
  }
  if (table == 'kunden') {
    context.go('/contacts/$id');
    return;
  }
  _showRecordDialog(context, table, row);
}

void _showRecordDialog(BuildContext context, String table, Map<String, Object?> row) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(_recordTitle(table, row)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final MapEntry<String, Object?> entry in row.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${_fieldLabel(entry.key)}: ${_displayValue(entry.value)}'),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen'))],
    ),
  );
}

int? _recordId(Map<String, Object?> row) {
  final Object? value = row['id'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _recordTitle(String table, Map<String, Object?> row) {
  final Object? preferred = switch (table) {
    'rechnungen' => row['rechnungsnummer'] ?? row['typ'],
    'kunden' => row['name'] ?? row['firma'],
    'belege' => row['dateiname'] ?? row['beschreibung'],
    'journal' => row['beschreibung'] ?? row['beleg_typ'],
    _ => row['name'] ?? row['beschreibung'] ?? row['typ'],
  };
  final String value = _displayValue(preferred);
  return value == '—' ? 'Datensatz #${_recordId(row) ?? '?'}' : value;
}

String _recordSubtitle(String table, Map<String, Object?> row) {
  final List<String> fields = <String>[
    if (table == 'rechnungen') ...<String>[_displayValue(row['datum']), _displayValue(row['status'])],
    if (table == 'kunden') ...<String>[_displayValue(row['email']), _displayValue(row['ort'])],
    if (table == 'belege') ...<String>[_displayValue(row['datum']), _displayValue(row['betrag'])],
    if (table == 'journal') ...<String>[_displayValue(row['datum']), _displayValue(row['betrag'])],
    if (table != 'rechnungen' && table != 'kunden' && table != 'belege' && table != 'journal')
      _displayValue(row['status'] ?? row['datum']),
  ];
  return fields.where((String field) => field != '—').join(' · ');
}

String _fieldLabel(String key) {
  return key
      .replaceAll('_', ' ')
      .split(' ')
      .map((String part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _displayValue(Object? value) {
  if (value == null || value.toString().trim().isEmpty) return '—';
  return value.toString();
}

num? _parseAmount(String value) => num.tryParse(value.trim().replaceAll(',', '.'));

String _todayIsoDate() => DateTime.now().toIso8601String().substring(0, 10);

Widget _routeError(BuildContext context, String source, Object error, StackTrace stackTrace, {VoidCallback? onRetry}) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'OpenAccounting route data',
      context: ErrorDescription('while loading $source'),
    ),
  );
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('Daten konnten nicht geladen werden'),
            const SizedBox(height: 8),
            Text('Vorgang: $source'),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Erneut versuchen'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _goBackOrHome(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Zurück'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class SetupPage extends ConsumerWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the long-lived service from the composition scope. The
    // Riverpod fallback keeps isolated widget tests and embedders working
    // without a production root.
    final WizardService svc = AppScope.maybeOf(context)?.services.setup ?? ref.read(appServicesProvider).setup;
    return WizardPage(service: svc);
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({this.message = 'Seite nicht gefunden', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppPageHeader(title: 'Nicht gefunden', showFilterToolbar: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.search_off, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _goBackOrHome(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Zurück'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Zur Übersicht'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryUnavailablePage extends StatelessWidget {
  const InventoryUnavailablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: const AppPageHeader(title: 'Lager', showFilterToolbar: false),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Die Lagerverwaltung ist noch nicht verfügbar.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Zur Übersicht'),
            ),
          ],
        ),
      ),
    );
  }
}

void _goBackOrHome(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    return;
  }
  context.go('/');
}

/// Backend unreachable UI per DESIGN §46.
class BackendUnreachableScreen extends StatelessWidget {
  const BackendUnreachableScreen({required this.host, this.port, this.onRetry, super.key});

  final String host;
  final int? port;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final detail = port != null ? '$host:$port' : host;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            const Text('Backend nicht erreichbar'),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
          ],
        ),
      ),
    );
  }
}
