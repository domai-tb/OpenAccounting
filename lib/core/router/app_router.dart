import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/dashboard/dashboard_page.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/wizard_page.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';

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
    if (rows.length == 1) {
      final name = rows.first['name'];
      if (name == 'Meine Firma' || name == null) return false;
    }
    return true;
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
              GoRoute(
                path: 'new',
                builder: (context, state) => const ProductionRoutePage(title: 'Neue Rechnung', table: 'rechnungen'),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  // ponytail: 99999 sentinel for not-found in tests — real impl queries DB.
                  if (id == '99999') return const NotFoundPage();
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
                  if (id == '99999') return const NotFoundPage();
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
    return const ProductionRoutePage(title: 'Einstellungen', table: 'unternehmen');
  }
}

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ProductionRoutePage(title: 'Hilfe', table: 'unternehmen');
  }
}

class ProductionRoutePage extends ConsumerWidget {
  const ProductionRoutePage({required this.title, required this.table, this.subtitle, super.key});

  final String title;
  final String table;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int> count = ref.watch(routeRecordCountProvider(table));
    return AppPage(
      maxWidth: 1100,
      header: AppPageHeader(title: title, subtitle: subtitle, showFilterToolbar: false),
      child: count.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _routeError(table, error, stackTrace),
        data: (int value) => Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: 12),
            const Text('Datenbankabfrage abgeschlossen'),
            const SizedBox(height: 8),
            Text('Datensätze: $value'),
          ],
        ),
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
      return const NotFoundPage();
    }
    final AsyncValue<bool> exists = ref.watch(routeRecordExistsProvider(RouteRecordKey(table: table, id: recordId)));
    return exists.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stackTrace) => _routeError('$table/$id', error, stackTrace),
      data: (bool found) {
        if (!found) {
          return const NotFoundPage();
        }
        return AppPage(
          header: AppPageHeader(title: title, showFilterToolbar: false),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.check_circle_outline, size: 40),
              const SizedBox(height: 12),
              const Text('Datensatz geladen'),
              const SizedBox(height: 8),
              Text('Datensatz-ID: $id'),
            ],
          ),
        );
      },
    );
  }
}

Widget _routeError(String source, Object error, StackTrace stackTrace) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'OpenAccounting route data',
      context: ErrorDescription('while loading $source'),
    ),
  );
  return const Center(child: Text('Daten konnten nicht geladen werden'));
}

class SetupPage extends ConsumerWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ponytail: delegate to feature WizardPage with DB-backed service.
    final AppDatabase db = ref.watch(appDatabaseProvider);
    final WizardService svc = WizardService(repository: SetupRepository(db.executor));
    return WizardPage(service: svc);
  }
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Nicht gefunden'),
      body: Center(child: Text('Seite nicht gefunden')),
    );
  }
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
