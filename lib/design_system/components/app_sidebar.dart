import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Persistent sidebar per DESIGN §4.
/// 240 px expanded, 72 px rail with tooltip, drawer <900 handled by AppShell.
class AppSidebar extends StatelessWidget {
  const AppSidebar({required this.isCompact, required this.isSelected, required this.onToggle, super.key});

  final bool isCompact;
  final bool Function(String) isSelected;
  final VoidCallback onToggle;

  Widget _header(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String menuLabel = l10n?.sidebarMenu ?? 'Menü';
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: Column(
          children: <Widget>[
            const Icon(Icons.account_balance_wallet, size: 32),
            const SizedBox(height: AppSpacing.sm),
            IconButton(icon: const Icon(Icons.menu), tooltip: menuLabel, onPressed: onToggle),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          const Icon(Icons.account_balance_wallet, size: 32),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('OpenAccounting', overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.menu), tooltip: menuLabel, onPressed: onToggle),
        ],
      ),
    );
  }

  Widget _workspaceSelector(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: PopupMenuButton<String>(
        key: const ValueKey<String>('workspace_selector'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!isCompact)
              Expanded(child: Text(l10n?.workspaceLocalProfile ?? 'Lokales Profil', overflow: TextOverflow.ellipsis))
            else
              const Icon(Icons.business, size: 20),
            if (!isCompact) const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
        onSelected: (String value) => context.go(value),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: '/settings', child: Text(l10n?.workspaceManage ?? 'Profil verwalten')),
        ],
      ),
    );
  }

  Widget _lokalIndicator(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l10n?.localTitle ?? 'Lokal'),
            content: Text(l10n?.localDescription ?? 'Alle Daten werden lokal gespeichert — kein Cloud-Zugriff.'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n?.close ?? 'Schließen')),
            ],
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Text('● ${l10n?.localTitle ?? 'Lokal'}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
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
        const SizedBox(height: AppSpacing.sm),
        _header(context),
        const Divider(),
        _workspaceSelector(context),
        const Divider(),
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Text(
              l10n?.sidebarSectionOverview ?? 'ÜBERSICHT',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        item(Icons.dashboard, l10n?.sidebarOverview ?? 'Übersicht', '/'),
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Text(
              l10n?.sidebarSectionBusiness ?? 'GESCHÄFT',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        item(Icons.receipt_long, l10n?.sidebarInvoices ?? 'Rechnungen', '/invoices'),
        item(Icons.receipt, l10n?.sidebarReceipts ?? 'Belege', '/receipts'),
        item(Icons.account_balance, l10n?.sidebarBanking ?? 'Bank & Zahlungen', '/banking'),
        item(Icons.contacts, l10n?.sidebarContacts ?? 'Kontakte', '/contacts'),
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Text(
              l10n?.sidebarSectionTaxes ?? 'STEUERN',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        item(Icons.percent, l10n?.sidebarTaxes ?? 'Steuern', '/taxes'),
        item(Icons.bar_chart, l10n?.sidebarReports ?? 'Auswertungen', '/reports'),
        const Divider(),
        item(Icons.settings, l10n?.sidebarSettings ?? 'Einstellungen', '/settings'),
        item(Icons.help, l10n?.sidebarHelp ?? 'Hilfe', '/help'),
        const Divider(),
        _lokalIndicator(context),
      ],
    );
  }
}
