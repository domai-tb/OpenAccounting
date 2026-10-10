import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/core/app_locale.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_repository.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_settings_section.dart';
import 'package:openaccounting/features/feature_modules/feature_module_repository.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';
import 'package:openaccounting/features/feature_modules/feature_module_settings_section.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_availability.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_schedules_view.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/core/router/typed_workspace_search.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/finance_list_surface.dart';
import 'package:openaccounting/design_system/components/typed_workspace_surface.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_help_page.dart';
import 'package:openaccounting/features/dashboard/dashboard_page.dart';
import 'package:openaccounting/features/setup/profile_data_section.dart';
import 'package:openaccounting/features/setup/profile_export_service.dart';
import 'package:openaccounting/features/setup/wizard_page.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:openaccounting/pages/rechnungen/invoice_document_page.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/stammdaten/contact_create_page.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';

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
  help('/help'),
  inventory('/inventory');

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
  } catch (error) {
    final String msg = error.toString().toLowerCase();
    if (msg.contains('no such table') || msg.contains('not open') || msg.contains('no such file')) {
      return false;
    }
    // DatabaseUnavailable or Schema failure — do not redirect to setup, preserve route
    rethrow;
  }
}

GoRouter createRouter(AppDatabase db) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.matchedLocation;
      // allow setup always, avoid loop.
      if (loc == '/setup') return null;
      try {
        final configured = await hasUnternehmen(db);
        if (!configured) return '/setup';
      } catch (_) {
        // DatabaseUnavailable / SchemaOrDataFailure — stay on requested route with retry UI
        return null;
      }
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
              return InvoicesPage(
                filterTyp: typ,
                filterStatus: status,
                routeParameters: state.uri.queryParameters,
                workspaceParse: parseTypedWorkspaceRouteCriteria(
                  TypedWorkspaceDomain.invoices,
                  state.uri.queryParameters,
                ),
              );
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
          GoRoute(
            path: '/receipts',
            builder: (context, state) => ReceiptsPage(
              routeParameters: state.uri.queryParameters,
              workspaceParse: parseTypedWorkspaceRouteCriteria(
                TypedWorkspaceDomain.receipts,
                state.uri.queryParameters,
              ),
            ),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (context, state) => ProductionRecordDetailPage(
                  table: 'belege',
                  title: appLocalizationsOf(context).receiptDetailTitle(state.pathParameters['id']!),
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/banking',
            builder: (context, state) => BankImportPage(routeUri: state.uri),
          ),
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const ContactsPage(),
            routes: <RouteBase>[
              GoRoute(path: 'new', builder: (context, state) => const ContactCreatePage()),
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
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':id',
                builder: (context, state) => ProductionRecordDetailPage(
                  table: 'journal',
                  title: appLocalizationsOf(context).journalDetailTitle(state.pathParameters['id']!),
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
          GoRoute(path: '/help', builder: (context, state) => const HelpPage()),
          GoRoute(path: '/setup', builder: (context, state) => const SetupPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const InventoryUnavailablePage()),
          // German alias per specs/app/spec.md deep-link scenario — preserve query and id.
          GoRoute(
            path: '/rechnungen',
            redirect: (BuildContext context, GoRouterState state) {
              final q = state.uri.query;
              return q.isEmpty ? '/invoices' : '/invoices?$q';
            },
          ),
          GoRoute(
            path: '/rechnungen/:id',
            redirect: (BuildContext context, GoRouterState state) {
              final String id = state.pathParameters['id']!;
              final String q = state.uri.query;
              return q.isEmpty ? '/invoices/$id' : '/invoices/$id?$q';
            },
          ),
          GoRoute(
            path: '/belege',
            redirect: (BuildContext context, GoRouterState state) {
              final q = state.uri.query;
              return q.isEmpty ? '/receipts' : '/receipts?$q';
            },
          ),
          GoRoute(
            path: '/belege/:id',
            redirect: (BuildContext context, GoRouterState state) {
              final String id = state.pathParameters['id']!;
              final String q = state.uri.query;
              return q.isEmpty ? '/receipts/$id' : '/receipts/$id?$q';
            },
          ),
          GoRoute(
            path: '/bank',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/banking' : '/banking?$q';
            },
          ),
          GoRoute(
            path: '/kontakte',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/contacts' : '/contacts?$q';
            },
          ),
          GoRoute(
            path: '/steuern',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/taxes' : '/taxes?$q';
            },
          ),
          GoRoute(
            path: '/auswertungen',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/reports' : '/reports?$q';
            },
          ),
          GoRoute(
            path: '/einrichtung',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/setup' : '/setup?$q';
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
}

final profileManagerProvider = Provider<ProfileManager>((ref) => ProfileManager());

final appRouterProvider = Provider<GoRouter>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return createRouter(db);
});

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({
    this.filterTyp,
    this.filterStatus,
    this.routeParameters = const <String, String>{},
    this.workspaceParse,
    super.key,
  });

  final String? filterTyp;
  final String? filterStatus;
  final Map<String, String> routeParameters;
  final TypedWorkspaceCriteriaParseResult? workspaceParse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final List<String> filters = <String>[
      if (filterTyp != null) l10n.filterTypeLabel(filterTyp!),
      if (filterStatus != null) l10n.filterStatusLabel(filterStatus!),
    ];
    return ProductionRoutePage(
      title: l10n.routeInvoices,
      table: 'rechnungen',
      icon: Icons.receipt_long,
      subtitle: filters.isEmpty ? null : filters.join(' · '),
      primaryActionLabel: l10n.actionNewInvoice,
      onPrimaryAction: () => context.go('/invoices/new'),
      filterTyp: filterTyp,
      filterStatus: filterStatus,
      workspaceCriteria:
          workspaceParse?.criteria ??
          TypedWorkspaceSearchCriteria(
            domain: TypedWorkspaceDomain.invoices,
            status: filterStatus,
            invoiceType: filterTyp,
          ),
      workspaceInvalidFields: workspaceParse?.invalidFields ?? const <TypedWorkspaceFilterField>{},
      onWorkspaceCriteriaChanged: (TypedWorkspaceSearchCriteria criteria) =>
          context.go(typedWorkspaceRoute('/invoices', typedWorkspaceRouteParameters(routeParameters, criteria))),
      onOpenWorkspaceRecord: (TypedWorkspaceRecord record) => context.go(
        typedWorkspaceRoute(
          '/invoices/${record.id}',
          typedWorkspaceRouteParameters(routeParameters, workspaceParse?.criteria ?? criteriaFromFilters()),
        ),
      ),
    );
  }

  TypedWorkspaceSearchCriteria criteriaFromFilters() =>
      TypedWorkspaceSearchCriteria(domain: TypedWorkspaceDomain.invoices, status: filterStatus, invoiceType: filterTyp);
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
  List<Kunde> _customers = const <Kunde>[];
  int? _selectedCustomerId;
  String? _customerError;
  bool _customersLoading = true;
  bool _saving = false;

  bool get _isDirty =>
      _dateController.text.trim() != _todayIsoDate() ||
      _descriptionController.text.trim().isNotEmpty ||
      _quantityController.text.trim() != '1' ||
      _priceController.text.trim().isNotEmpty ||
      _selectedCustomerId != null;

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.draftDiscardTitle),
        content: Text(l10n.draftDiscardMessage),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionKeepEditing)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionDiscard)),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _cancelDraft() async {
    if (_saving || !await _confirmDiscard() || !mounted) return;
    context.go('/invoices');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadCustomers());
  }

  Future<void> _loadCustomers() async {
    try {
      final List<Kunde> customers = await ref.read(appServicesProvider).kunden.list();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _customersLoading = false;
        _customerError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _customersLoading = false;
        _customerError = error.toString();
      });
    }
  }

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
            kundeId: _selectedCustomerId,
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
          .showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).draftSaveFailed('$error'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateDate(String? value) {
    final String date = value?.trim() ?? '';
    final DateTime? parsed = DateTime.tryParse(date);
    if (parsed == null || date.length != 10 || parsed.toIso8601String().substring(0, 10) != date) {
      return appLocalizationsOf(context).errorDateFormat;
    }
    return null;
  }

  String? _validatePositiveAmount(String? value, String label) {
    final num? parsed = _parseAmount(value ?? '');
    if (parsed == null || parsed <= 0) return appLocalizationsOf(context).errorPositiveAmount(label);
    return null;
  }

  String _customerLabel(Kunde customer) {
    final String company = customer.firma?.trim() ?? '';
    final String name = customer.name.trim();
    final String displayName = company.isEmpty ? name : '$company · $name';
    return '${customer.debitorNr} · $displayName';
  }

  Widget _buildCustomerSelector(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (_customersLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[Text(l10n.customersLoading), const SizedBox(height: 8), const LinearProgressIndicator()],
      );
    }
    if (_customerError != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(l10n.customersLoadFailed),
          subtitle: Text(_customerError!),
          trailing: TextButton(onPressed: _loadCustomers, child: Text(l10n.actionReload)),
        ),
      );
    }
    if (_customers.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(l10n.invoiceDraftNoCustomerTitle),
          subtitle: Text(l10n.invoiceDraftNoCustomerMessage),
          trailing: TextButton(onPressed: () => context.go('/contacts/new'), child: Text(l10n.actionCreateCustomer)),
        ),
      );
    }
    return DropdownButtonFormField<int>(
      key: const ValueKey<String>('invoice_draft_customer'),
      isExpanded: true,
      initialValue: _customers.any((Kunde customer) => customer.id == _selectedCustomerId) ? _selectedCustomerId : null,
      decoration: InputDecoration(labelText: l10n.invoiceDraftCustomerLabel),
      hint: Text(l10n.invoiceDraftCustomerHint),
      items: _customers
          .map(
            (Kunde customer) => DropdownMenuItem<int>(
              value: customer.id,
              child: Text(_customerLabel(customer), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (int? value) => setState(() {
              _selectedCustomerId = value;
            }),
      validator: (int? value) => value == null ? l10n.errorCustomerRequired : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_cancelDraft());
      },
      child: AppPage(
        header: AppPageHeader(
          title: l10n.actionNewInvoice,
          leading: IconButton(
            onPressed: _saving ? null : () => unawaited(_cancelDraft()),
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.actionBack,
          ),
          showFilterToolbar: false,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              Text(l10n.invoiceDraftTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(l10n.invoiceDraftDescription),
              const SizedBox(height: 24),
              _buildCustomerSelector(context),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('invoice_draft_date'),
                controller: _dateController,
                decoration: InputDecoration(labelText: l10n.dateLabel, hintText: '2026-01-31'),
                validator: _validateDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey<String>('invoice_draft_description'),
                controller: _descriptionController,
                decoration: InputDecoration(labelText: l10n.invoiceDraftPositionLabel),
                validator: (String? value) => value == null || value.trim().isEmpty ? l10n.errorPositionRequired : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey<String>('invoice_draft_quantity'),
                      controller: _quantityController,
                      decoration: InputDecoration(labelText: l10n.pdfQuantity),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (String? value) => _validatePositiveAmount(value, l10n.pdfQuantity),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey<String>('invoice_draft_price'),
                      controller: _priceController,
                      decoration: InputDecoration(labelText: l10n.invoiceDraftUnitPriceLabel),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (String? value) => _validatePositiveAmount(value, l10n.pdfUnitPrice),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _saving ? null : () => unawaited(_cancelDraft()),
                    child: Text(l10n.actionCancel),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey<String>('save_invoice_draft'),
                    onPressed: _saving || _customersLoading || _customerError != null || _customers.isEmpty
                        ? null
                        : _saveDraft,
                    icon: _saving
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.actionSaveDraft),
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

class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final int? recordId = int.tryParse(id);
    if (recordId == null) {
      return NotFoundPage(message: appLocalizationsOf(context).errorInvoiceIdInvalid);
    }
    return InvoiceDocumentPage(id: recordId);
  }
}

class ReceiptsPage extends ConsumerWidget {
  const ReceiptsPage({this.routeParameters = const <String, String>{}, this.workspaceParse, super.key});

  final Map<String, String> routeParameters;
  final TypedWorkspaceCriteriaParseResult? workspaceParse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return ProductionRoutePage(
      title: l10n.routeReceipts,
      table: 'belege',
      icon: Icons.receipt_outlined,
      subtitle: l10n.receiptsSubtitle,
      emptyTitle: l10n.emptyEntries,
      emptyMessage: l10n.receiptsSubtitle,
      workspaceCriteria:
          workspaceParse?.criteria ?? const TypedWorkspaceSearchCriteria(domain: TypedWorkspaceDomain.receipts),
      workspaceInvalidFields: workspaceParse?.invalidFields ?? const <TypedWorkspaceFilterField>{},
      onWorkspaceCriteriaChanged: (TypedWorkspaceSearchCriteria criteria) =>
          context.go(typedWorkspaceRoute('/receipts', typedWorkspaceRouteParameters(routeParameters, criteria))),
      onOpenWorkspaceRecord: (TypedWorkspaceRecord record) => context.go(
        typedWorkspaceRoute(
          '/receipts/${record.id}',
          typedWorkspaceRouteParameters(
            routeParameters,
            workspaceParse?.criteria ?? const TypedWorkspaceSearchCriteria(domain: TypedWorkspaceDomain.receipts),
          ),
        ),
      ),
    );
  }
}

class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return ProductionRoutePage(
      title: l10n.routeContacts,
      table: 'kunden',
      icon: Icons.people_outline,
      subtitle: l10n.contactsSubtitle,
      primaryActionLabel: l10n.actionSave,
      onPrimaryAction: () => context.go('/contacts/new'),
      emptyTitle: l10n.emptyEntries,
      emptyMessage: l10n.contactsSubtitle,
      emptyActionLabel: l10n.actionSave,
      onEmptyAction: () => context.go('/contacts/new'),
    );
  }
}

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ProductionRecordDetailPage(
      table: 'kunden',
      title: appLocalizationsOf(context).contactDetailTitle(id),
      id: id,
    );
  }
}

class TaxesPage extends ConsumerWidget {
  const TaxesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Uri uri = GoRouterState.of(context).uri;
    final Map<String, String> query = uri.queryParameters;
    if (query['view'] == 'income-tax-schedules') {
      final AppScope? scope = AppScope.maybeOf(context);
      if (scope == null) {
        return AppPage(
          header: AppPageHeader(title: l10n.routeTaxes, showFilterToolbar: false),
          child: Text(l10n.incomeTaxUnavailable),
        );
      }
      final IncomeTaxSchedule? schedule = IncomeTaxScheduleAvailabilityUseCase.parseSchedule(query['schedule']);
      return IncomeTaxSchedulesView(
        useCase: scope.services.incomeTax,
        initialSchedule: schedule,
        onScheduleChanged: (IncomeTaxSchedule? value) {
          final Map<String, List<String>> next = Map<String, List<String>>.from(uri.queryParametersAll);
          if (value == null) {
            next.remove('schedule');
          } else {
            next['schedule'] = <String>[value.name];
          }
          context.go(uri.replace(queryParameters: next).toString());
        },
      );
    }
    return ProductionRoutePage(
      title: l10n.routeTaxes,
      table: 'ustva_exporte',
      icon: Icons.percent,
      subtitle: l10n.taxesSubtitle,
      emptyTitle: l10n.emptyEntries,
      emptyMessage: l10n.taxesSubtitle,
    );
  }
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return ProductionRoutePage(
      title: l10n.routeReports,
      table: 'journal',
      icon: Icons.bar_chart,
      subtitle: l10n.reportsSubtitle,
      emptyTitle: l10n.emptyEntries,
      emptyMessage: l10n.reportsSubtitle,
    );
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

const Duration _profileLoadTimeout = Duration(seconds: 2);

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  late ProfileManager _profileManager;
  late Future<_ProfileSnapshot> _profiles;

  @override
  void initState() {
    super.initState();
    _profileManager = ref.read(profileManagerProvider);
    _profiles = _loadProfiles();
  }

  Future<_ProfileSnapshot> _loadProfiles() async {
    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _profileManager.getActiveProfile(),
      _profileManager.listProfiles(),
    ]).timeout(_profileLoadTimeout);
    final String active = results[0] as String;
    final List<String> profiles = (results[1] as List).cast<String>();
    if (profiles.contains(active)) {
      return _ProfileSnapshot(active: active, profiles: profiles);
    }
    return _ProfileSnapshot(active: active, profiles: <String>[active, ...profiles]);
  }

  void _reloadProfiles() {
    setState(() {
      _profiles = _loadProfiles();
    });
  }

  Future<void> _selectProfile(String name) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      final bool restartRequired = await _profileManager.setActiveProfile(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(restartRequired ? l10n.profileSavedRestartHint : l10n.profileAlreadyActive)),
      );
      _reloadProfiles();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileSelectFailed('$error'))));
      }
    }
  }

  ProfileExportService? _resolveProfileExportService() {
    try {
      final AppScope? scope = AppScope.maybeOf(context);
      if (scope != null) {
        return scope.services.profileExport;
      }
      return ref.read(appServicesProvider).profileExport;
    } catch (_) {
      return null;
    }
  }

  Future<void> _createProfile() async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.profileCreateTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.profileNameLabel),
          onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.actionCreate),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileCreated)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileCreateFailed('$error'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Locale selectedLocale = ref.watch(appLocaleProvider);
    final ThemeMode selectedTheme = ref.watch(themeModeProvider);
    return AppPage(
      header: AppPageHeader(title: l10n.settingsTitle, showFilterToolbar: false),
      child: ListView(
        children: <Widget>[
          Text(l10n.settingsAppearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<Locale>(
            key: ValueKey<String>('locale_${selectedLocale.languageCode}'),
            initialValue: selectedLocale,
            decoration: InputDecoration(labelText: l10n.settingsLanguage),
            items: <DropdownMenuItem<Locale>>[
              DropdownMenuItem<Locale>(value: const Locale('de'), child: Text(l10n.languageGerman)),
              DropdownMenuItem<Locale>(value: const Locale('en'), child: Text(l10n.languageEnglish)),
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
            decoration: InputDecoration(labelText: l10n.settingsTheme),
            items: <DropdownMenuItem<ThemeMode>>[
              DropdownMenuItem<ThemeMode>(value: ThemeMode.system, child: Text(l10n.themeSystem)),
              DropdownMenuItem<ThemeMode>(value: ThemeMode.light, child: Text(l10n.themeLight)),
              DropdownMenuItem<ThemeMode>(value: ThemeMode.dark, child: Text(l10n.themeDark)),
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
            title: Text(l10n.amountHidden),
            subtitle: Text(l10n.settingsPrivacyDescription),
            value: ref.watch(privacyModeProvider),
            onChanged: (bool value) => unawaited(ref.read(privacyModeProvider.notifier).setEnabled(enabled: value)),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 32),
          Row(
            children: <Widget>[
              Expanded(child: Text(l10n.settingsProfiles, style: Theme.of(context).textTheme.titleMedium)),
              FilledButton.icon(onPressed: _createProfile, icon: const Icon(Icons.add), label: Text(l10n.actionSave)),
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
                final AppLocalizations? localizations = AppLocalizations.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(localizations?.settingsProfileLoadError ?? l10n.settingsProfileLoadError),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _reloadProfiles,
                      child: Text(localizations?.settingsProfileRetry ?? l10n.actionRetry),
                    ),
                  ],
                );
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
                        subtitle: profile == value.active ? Text(l10n.setupSaved) : Text(l10n.setupRetry),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          FiscalYearSettingsSection(repository: FiscalYearRepository(ref.read(appDatabaseProvider).executor)),
          const SizedBox(height: 16),
          FeatureModuleSettingsSection(
            service: FeatureModuleService(repository: FeatureModuleRepository(ref.read(appDatabaseProvider).executor)),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          ProfileDataSection(exportService: _resolveProfileExportService()),
          const SizedBox(height: 16),
          Text(l10n.settingsPrivacyDescription),
          const SizedBox(height: 16),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storage_outlined),
              title: Text(l10n.localTitle),
              subtitle: Text(l10n.localDescription),
            ),
          ),
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
    return const ContextualGuidanceHelpPage();
  }
}

class ProductionRoutePage extends ConsumerWidget {
  const ProductionRoutePage({
    required this.title,
    required this.table,
    required this.icon,
    this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.filterTyp,
    this.filterStatus,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.workspaceCriteria,
    this.workspaceInvalidFields = const <TypedWorkspaceFilterField>{},
    this.onWorkspaceCriteriaChanged,
    this.onOpenWorkspaceRecord,
    super.key,
  });

  final String title;
  final String table;
  final IconData icon;
  final String? subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? filterTyp;
  final String? filterStatus;
  final String? emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final TypedWorkspaceSearchCriteria? workspaceCriteria;
  final Set<TypedWorkspaceFilterField> workspaceInvalidFields;
  final ValueChanged<TypedWorkspaceSearchCriteria>? onWorkspaceCriteriaChanged;
  final ValueChanged<TypedWorkspaceRecord>? onOpenWorkspaceRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TypedWorkspaceSearchCriteria? criteria = workspaceCriteria;
    if (criteria != null) {
      return TypedWorkspaceSurface(
        title: title,
        icon: icon,
        subtitle: subtitle,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
        criteria: criteria,
        invalidFields: workspaceInvalidFields,
        onCriteriaChanged: onWorkspaceCriteriaChanged ?? (_) {},
        onOpen: onOpenWorkspaceRecord,
      );
    }
    return FinanceListSurface(
      table: table,
      title: title,
      icon: icon,
      subtitle: subtitle,
      primaryActionLabel: primaryActionLabel,
      onPrimaryAction: onPrimaryAction,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      emptyActionLabel: emptyActionLabel,
      onEmptyAction: onEmptyAction,
      filterTyp: filterTyp,
      filterStatus: filterStatus,
      onOpen: (int id, Map<String, Object?> row) => _openRecord(context, table, id, row),
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
    final AppLocalizations l10n = appLocalizationsOf(context);
    final int? recordId = int.tryParse(id);
    if (recordId == null) {
      return NotFoundPage(message: l10n.errorRecordIdInvalid);
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
          return NotFoundPage(message: l10n.errorRecordNotFound(id));
        }
        final String recordTitle = _recordTitle(table, row, l10n);
        final List<_DetailField> fields = _detailFields(table, row);
        return AppPage(
          maxWidth: 860,
          header: AppPageHeader(
            title: recordTitle,
            showFilterToolbar: false,
            leading: IconButton(
              onPressed: () => _goBackOrHome(context),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.actionBack,
            ),
          ),
          child: ListView(
            children: <Widget>[
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                      child: Icon(table == 'kunden' ? Icons.person_outline : Icons.menu_book_outlined),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(recordTitle, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(l10n.recordIdLabel(id), style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int index = 0; index < fields.length; index++) ...<Widget>[
                      ListTile(title: Text(fields[index].label), subtitle: Text(fields[index].value), dense: true),
                      if (index < fields.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailField {
  const _DetailField(this.label, this.value);

  final String label;
  final String value;
}

List<_DetailField> _detailFields(String table, Map<String, Object?> row) {
  final List<String> keys = switch (table) {
    'kunden' => <String>[
      'firma',
      'strasse',
      'hausnummer',
      'plz',
      'ort',
      'land',
      'email',
      'telefon',
      'ust_idnr',
      'zahlungsziel',
    ],
    'journal' => <String>['datum', 'beleg_nr', 'beleg_typ', 'beschreibung', 'betrag', 'soll', 'haben', 'ust_satz'],
    _ => row.keys.where((String key) => key != 'id').take(12).toList(),
  };
  return <_DetailField>[
    for (final String key in keys)
      if (row.containsKey(key) && _displayValue(row[key]) != '—')
        _DetailField(_fieldLabel(key), _displayValue(row[key])),
  ];
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
  if (table == 'journal') {
    context.go('/reports/$id');
    return;
  }
  _showRecordDialog(context, table, row);
}

void _showRecordDialog(BuildContext context, String table, Map<String, Object?> row) {
  final AppLocalizations l10n = appLocalizationsOf(context);
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(_recordTitle(table, row, l10n)),
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
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionClose))],
    ),
  );
}

int? _recordId(Map<String, Object?> row) {
  final Object? value = row['id'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _recordTitle(String table, Map<String, Object?> row, AppLocalizations l10n) {
  final Object? preferred = switch (table) {
    'rechnungen' => row['rechnungsnummer'] ?? row['typ'],
    'kunden' => row['name'] ?? row['firma'],
    'belege' => row['dateiname'] ?? row['beschreibung'],
    'journal' => row['beschreibung'] ?? row['beleg_typ'],
    _ => row['name'] ?? row['beschreibung'] ?? row['typ'],
  };
  final String value = _displayValue(preferred);
  final String fallbackId = '${_recordId(row) ?? '?'}';
  return value == '—' ? l10n.recordFallbackTitle(fallbackId) : value;
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
            Text(AppLocalizations.of(context)?.dataLoadError ?? 'Data could not be loaded'),
            const SizedBox(height: 8),
            Text(appLocalizationsOf(context).routeErrorSource(source)),
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
                    label: Text(AppLocalizations.of(context)?.actionRetry ?? 'Retry'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _goBackOrHome(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(AppLocalizations.of(context)?.actionBack ?? 'Back'),
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
  const NotFoundPage({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return Scaffold(
      appBar: AppPageHeader(title: l10n.notFound, showFilterToolbar: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.search_off, size: 48),
              const SizedBox(height: 12),
              Text(message ?? l10n.notFoundDescription, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => _goBackOrHome(context),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(l10n.actionBack),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(l10n.actionBackOverview),
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
    final AppLocalizations l10n = appLocalizationsOf(context);
    return FinanceListSurface(
      table: 'inventory',
      title: l10n.inventoryTitle,
      icon: Icons.inventory_2_outlined,
      subtitle: l10n.inventoryUnavailableDescription,
      contentBuilder: (BuildContext contentContext, AppLocalizations contentL10n) => AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.inventory_2_outlined, size: 48),
              const SizedBox(height: 12),
              Text(contentL10n.inventoryUnavailable, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(contentL10n.inventoryUnavailableDescription, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(contentL10n.inventoryReadOnly, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => contentContext.go('/inventory'),
                    icon: const Icon(Icons.refresh),
                    label: Text(contentL10n.inventoryRetry),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => contentContext.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(contentL10n.inventoryBack),
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
