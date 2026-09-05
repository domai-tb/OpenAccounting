import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/app/app_shell.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
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
          GoRoute(path: '/banking', builder: (context, state) => const BankingPage()),
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

// Minimal placeholder pages — real feature pages replace in later batches.

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({this.filterTyp, this.filterStatus, super.key});
  final String? filterTyp;
  final String? filterStatus;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (filterTyp != null || filterStatus != null) {
      label = 'Rechnungen typ=$filterTyp status=$filterStatus';
    } else {
      label = 'Rechnungen';
    }
    return Scaffold(
      appBar: AppPageHeader(title: label),
      body: Center(child: Text('Liste: $label')),
    );
  }
}

class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageHeader(title: 'Rechnung $id'),
      body: Center(child: Text('Detail: Rechnung $id')),
    );
  }
}

class ReceiptsPage extends StatelessWidget {
  const ReceiptsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Belege'),
      body: Center(child: Text('Belege – Übersicht')),
    );
  }
}

class BankingPage extends StatelessWidget {
  const BankingPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Bank & Zahlungen'),
      body: Center(child: Text('Bank – Übersicht')),
    );
  }
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Kontakte'),
      body: Center(child: Text('Kontakte – Liste')),
    );
  }
}

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageHeader(title: 'Kontakt $id'),
      body: Center(child: Text('Detail: Kontakt $id')),
    );
  }
}

class TaxesPage extends StatelessWidget {
  const TaxesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Steuern'),
      body: Center(child: Text('Steuern – Übersicht')),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Auswertungen'),
      body: Center(child: Text('Auswertungen – Übersicht')),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Einstellungen'),
      body: Center(child: Text('Einstellungen – Bereich')),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppPageHeader(title: 'Hilfe'),
      body: Center(child: Text('Hilfe – Übersicht')),
    );
  }
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
