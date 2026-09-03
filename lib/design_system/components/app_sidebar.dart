import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistent sidebar per DESIGN §4.
/// 240 px expanded, 72 px rail with tooltip, drawer <900 handled by AppShell.
class AppSidebar extends StatelessWidget {
  const AppSidebar({required this.isCompact, required this.selectedPath, required this.isSelected, super.key});

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
        const Divider(),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('● Lokal')),
      ],
    );
  }
}
