import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Package workspace: group documents and receipt evidence, export a ZIP
/// snapshot. Batch print and email are deferred and never shown as available
/// actions.
class DokumentenpaketPage extends ConsumerWidget {
  const DokumentenpaketPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      header: AppPageHeader(
        title: l10n.paketWorkspaceTitle,
        subtitle: l10n.paketWorkspaceSubtitle,
        showFilterToolbar: false,
      ),
      maxWidth: 1000,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            label: l10n.paketCreateAction,
            child: FilledButton(onPressed: () {}, child: Text(l10n.paketCreateAction)),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.paketWorkspaceSubtitle,
            semanticsLabel: l10n.paketWorkspaceSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
