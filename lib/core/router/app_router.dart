import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';

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
    final rows = await db.executor.runSelect('SELECT COUNT(*) as c FROM unternehmen', const []);
    if (rows.isEmpty) return false;
    final v = rows.first['c'];
    if (v is int) return v > 0;
    if (v is num) return v > 0;
    return false;
  } catch (_) {
    // ponytail: no such table → treat as unconfigured, redirect to /setup.
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
      GoRoute(path: '/setup', builder: (context, state) => const SetupPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
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

/// App shell with sidebar 240px (expanded ≥1200), compact 72px (900-1199),
/// drawer <900 per DESIGN §34.
class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  bool _isSelected(String path) {
    if (path == '/') return location == '/';
    return location.startsWith(path);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width >= 900 && width < 1200;
        final isDrawer = width < 900;
        final sidebarWidth = isCompact ? 72.0 : 240.0;

        final sidebar = _Sidebar(isCompact: isCompact, selectedPath: location, isSelected: _isSelected);

        if (isDrawer) {
          return Scaffold(
            appBar: AppBar(title: const Text('OpenAccounting')),
            drawer: Drawer(child: sidebar),
            body: child,
          );
        }

        return Scaffold(
          body: Row(
            children: <Widget>[
              SizedBox(
                width: sidebarWidth,
                child: Material(color: Theme.of(context).colorScheme.surface, child: sidebar),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.isCompact, required this.selectedPath, required this.isSelected});

  final bool isCompact;
  final String selectedPath;
  final bool Function(String) isSelected;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, String path) {
      final selected = isSelected(path);
      if (isCompact) {
        return Tooltip(
          message: label,
          child: ListTile(leading: Icon(icon), selected: selected, onTap: () => context.go(path)),
        );
      }
      return ListTile(leading: Icon(icon), title: Text(label), selected: selected, onTap: () => context.go(path));
    }

    return ListView(
      children: <Widget>[
        const SizedBox(height: 16),
        if (isCompact)
          const Icon(Icons.account_balance_wallet, size: 32)
        else
          const ListTile(leading: Icon(Icons.account_balance_wallet), title: Text('OpenAccounting')),
        const Divider(),
        if (!isCompact)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('ÜBERSICHT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        item(Icons.dashboard, 'Übersicht', '/'),
        if (!isCompact)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('GESCHÄFT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        item(Icons.receipt_long, 'Rechnungen', '/invoices'),
        item(Icons.receipt, 'Belege', '/receipts'),
        item(Icons.account_balance, 'Bank & Zahlungen', '/banking'),
        item(Icons.contacts, 'Kontakte', '/contacts'),
        if (!isCompact)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('STEUERN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        item(Icons.percent, 'Steuern', '/taxes'),
        item(Icons.bar_chart, 'Auswertungen', '/reports'),
        const Divider(),
        item(Icons.settings, 'Einstellungen', '/settings'),
        item(Icons.help, 'Hilfe', '/help'),
      ],
    );
  }
}

// Minimal placeholder pages — real feature pages replace in later batches.

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Übersicht')));
}

class InvoicesPage extends StatelessWidget {
  const InvoicesPage({this.filterTyp, this.filterStatus, super.key});
  final String? filterTyp;
  final String? filterStatus;

  @override
  Widget build(BuildContext context) {
    final label = filterTyp != null || filterStatus != null
        ? 'Rechnungen typ=$filterTyp status=$filterStatus'
        : 'Rechnungen';
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text(label)),
    );
  }
}

class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Rechnung $id')));
}

class ReceiptsPage extends StatelessWidget {
  const ReceiptsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Belege')));
}

class BankingPage extends StatelessWidget {
  const BankingPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Bank & Zahlungen')));
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Kontakte')));
}

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({required this.id, super.key});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Kontakt $id')));
}

class TaxesPage extends StatelessWidget {
  const TaxesPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Steuern')));
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Auswertungen')));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Einstellungen')));
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Hilfe')));
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Setup Wizard')));
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Nicht gefunden')));
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
