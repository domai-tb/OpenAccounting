import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TODO(l10n): replace hardcoded labels with AppLocalizations.

/// Persistent sidebar per DESIGN §4.
/// 240 px expanded, 72 px rail with tooltip, drawer <900 handled by AppShell.
class AppSidebar extends StatelessWidget {
  const AppSidebar({required this.isCompact, required this.isSelected, required this.onToggle, super.key});

  final bool isCompact;
  final bool Function(String) isSelected;
  final VoidCallback onToggle;

  Widget _header(BuildContext context) {
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          children: <Widget>[
            const Icon(Icons.account_balance_wallet, size: 32),
            const SizedBox(height: 8),
            IconButton(icon: const Icon(Icons.menu), tooltip: 'Menü', onPressed: onToggle),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.account_balance_wallet, size: 32),
          const SizedBox(width: 8),
          const Expanded(child: Text('OpenAccounting', overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.menu), tooltip: 'Menü', onPressed: onToggle),
        ],
      ),
    );
  }

  Widget _workspaceSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: PopupMenuButton<String>(
        key: const ValueKey<String>('workspace_selector'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isCompact)
              const Expanded(child: Text('ACME Studio ▾', overflow: TextOverflow.ellipsis))
            else
              const Icon(Icons.business, size: 20),
            if (!isCompact) const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
        onSelected: (String value) {},
        itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'acme', child: Text('ACME Studio')),
          PopupMenuItem<String>(value: 'demo', child: Text('Demo GmbH')),
        ],
      ),
    );
  }

  Widget _lokalIndicator(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Lokal'),
            content: const Text('Alle Daten werden lokal gespeichert — kein Cloud-Zugriff.'),
            actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Schließen'))],
          ),
        );
      },
      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('● Lokal')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color selectedTileColor = scheme.secondaryContainer;
    final Color selectedColor = scheme.onSecondaryContainer;

    Widget item(IconData icon, String label, String path) {
      final bool selected = isSelected(path);
      final ListTile tile = ListTile(
        leading: Icon(icon, color: selected ? selectedColor : null),
        title: isCompact ? null : Text(label),
        selected: selected,
        selectedTileColor: selectedTileColor,
        selectedColor: selectedColor,
        onTap: () => context.go(path),
      );
      final Widget withFocus = Focus(child: tile);
      if (isCompact) {
        return Tooltip(message: label, child: withFocus);
      }
      return withFocus;
    }

    return ListView(
      children: <Widget>[
        const SizedBox(height: 8),
        _header(context),
        const Divider(),
        _workspaceSelector(context),
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
        _lokalIndicator(context),
      ],
    );
  }
}
