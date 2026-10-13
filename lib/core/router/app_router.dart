import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_availability.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_schedules_view.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_workspace_page.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/core/router/typed_workspace_search.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/finance_list_surface.dart';
import 'package:openaccounting/design_system/components/typed_workspace_surface.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/inventory/stocktake_page.dart';
import 'package:openaccounting/features/recurring/recurring_booking_page.dart';
import 'package:openaccounting/features/assets/assets_page.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_help_page.dart';
import 'package:openaccounting/features/dashboard/dashboard_page.dart';
import 'package:openaccounting/features/setup/wizard_page.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:openaccounting/features/settings/settings_workspace.dart';
import 'package:openaccounting/features/accounting/gobd_export_page.dart';
import 'package:openaccounting/features/documents/dokumentenpaket_page.dart';
import 'package:openaccounting/features/receipts/receipt_inbox_page.dart';
import 'package:openaccounting/features/incoming_invoices/incoming_invoice_capture_page.dart';
import 'package:openaccounting/pages/rechnungen/invoice_document_page.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace.dart';
import 'package:openaccounting/pages/stammdaten/master_data_more_pages.dart';
import 'package:openaccounting/pages/stammdaten/master_data_pages.dart';

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
  mahnwesen('/mahnwesen'),
  contacts('/contacts'),
  taxes('/taxes'),
  reports('/reports'),
  assets('/assets'),
  settings('/settings'),
  setup('/setup'),
  help('/help'),
  inventory('/inventory'),
  recurring('/recurring');

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
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => InvoiceEditPage(id: state.pathParameters['id']!),
                  ),
                ],
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
              GoRoute(path: 'inbox', builder: (context, state) => const ReceiptInboxPage()),
              GoRoute(
                path: ':id',
                builder: (context, state) => ProductionRecordDetailPage(
                  table: 'belege',
                  title: appLocalizationsOf(context).receiptDetailTitle(state.pathParameters['id']!),
                  id: state.pathParameters['id']!,
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'capture',
                    builder: (context, state) =>
                        IncomingInvoiceCapturePage(belegId: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: '/packages', builder: (context, state) => const DokumentenpaketPage()),
          GoRoute(path: '/gobd-export', builder: (context, state) => const GobdExportPage()),
          GoRoute(
            path: '/banking',
            builder: (context, state) => BankImportPage(routeUri: state.uri),
          ),
          GoRoute(
            path: '/mahnwesen',
            builder: (context, state) => MahnwesenWorkspacePage(routeUri: state.uri),
          ),
          GoRoute(
            path: '/mahnungen',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/mahnwesen' : '/mahnwesen?$q';
            },
          ),
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const ContactsPage(),
            routes: <RouteBase>[
              GoRoute(path: 'new', builder: (context, state) => const ContactCreateRoute()),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ContactDetailPage(id: id);
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => ContactFormRoute(recordId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/articles',
            builder: (context, state) => const ArticlesPage(),
            routes: <RouteBase>[
              GoRoute(path: 'new', builder: (context, state) => const ArticleCreateRoute()),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ArticleDetailRoute(id: id);
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => ArticleEditRoute(recordId: state.pathParameters['id']!),
                  ),
                ],
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
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
            routes: <RouteBase>[
              GoRoute(path: 'company', builder: (context, state) => const CompanySettingsRoute()),
              GoRoute(path: 'categories', builder: (context, state) => const CategoriesRoute()),
              GoRoute(path: 'accounts', builder: (context, state) => const BankAccountsRoute()),
              GoRoute(path: 'tax-rates', builder: (context, state) => const TaxRatesRoute()),
              GoRoute(path: 'number-ranges', builder: (context, state) => const NumberRangesRoute()),
            ],
          ),
          GoRoute(path: '/help', builder: (context, state) => const HelpPage()),
          GoRoute(
            path: '/assets',
            builder: (context, state) => AssetsPage(routeUri: state.uri),
          ),
          GoRoute(path: '/setup', builder: (context, state) => const SetupPage()),
          GoRoute(path: '/inventory', builder: (context, state) => const StocktakeWorkspacePage()),
          GoRoute(
            path: '/recurring',
            builder: (context, state) => RecurringBookingPage(routeUri: state.uri),
          ),
          GoRoute(
            path: '/wiederkehrend',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/recurring' : '/recurring?$q';
            },
          ),
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
          GoRoute(
            path: '/anlagen',
            redirect: (BuildContext context, GoRouterState state) {
              final String q = state.uri.query;
              return q.isEmpty ? '/assets' : '/assets?$q';
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

/// Create route for outgoing-invoice drafts. Uses the shared workspace editor.
class InvoiceDraftPage extends StatelessWidget {
  const InvoiceDraftPage({super.key});

  @override
  Widget build(BuildContext context) => const InvoiceWorkspace();
}

/// Edit route for saved outgoing-invoice drafts. Same editor model and
/// presentation components as the create route.
class InvoiceEditPage extends StatelessWidget {
  const InvoiceEditPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final int? recordId = int.tryParse(id);
    if (recordId == null) {
      return NotFoundPage(message: appLocalizationsOf(context).errorInvoiceIdInvalid);
    }
    return InvoiceWorkspace(draftId: recordId);
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
    return const ContactsWorkspaceView();
  }
}

class ContactCreateRoute extends ConsumerWidget {
  const ContactCreateRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ContactFormView();
  }
}

class ContactFormRoute extends ConsumerWidget {
  const ContactFormRoute({this.recordId, super.key});

  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContactFormView(recordId: recordId);
  }
}

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return ContactRecordView(id: id);
  }
}

class ArticlesPage extends ConsumerWidget {
  const ArticlesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ArticlesWorkspaceView();
  }
}

class ArticleCreateRoute extends ConsumerWidget {
  const ArticleCreateRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ArticleFormView();
  }
}

class ArticleDetailRoute extends ConsumerWidget {
  const ArticleDetailRoute({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ArticleRecordView(id: id);
  }
}

class ArticleEditRoute extends ConsumerWidget {
  const ArticleEditRoute({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? id = int.tryParse(recordId);
    if (id == null) return ArticleRecordView(id: recordId);
    return ArticleFormView(recordId: id);
  }
}

class CompanySettingsRoute extends ConsumerWidget {
  const CompanySettingsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CompanySettingsView();
  }
}

class CategoriesRoute extends ConsumerWidget {
  const CategoriesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CategoriesView();
  }
}

class BankAccountsRoute extends ConsumerWidget {
  const BankAccountsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const BankAccountsView();
  }
}

class TaxRatesRoute extends ConsumerWidget {
  const TaxRatesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const TaxRatesView();
  }
}

class NumberRangesRoute extends ConsumerWidget {
  const NumberRangesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const NumberRangesView();
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

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  @override
  Widget build(BuildContext context) {
    return const SettingsWorkspace();
  }
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
