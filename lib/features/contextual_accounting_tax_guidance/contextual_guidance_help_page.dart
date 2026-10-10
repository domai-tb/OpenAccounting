import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_catalog.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_entry.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_help_button.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_providers.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_texts.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Workflow group order for the /help glossary.
const List<String> guidanceWorkflowOrder = <String>['/reports', '/taxes', '/invoices', '/banking'];

/// /help glossary of reviewed accounting/tax guidance, grouped by workflow.
///
/// Shows an honest empty state when no reviewed entry matches; never shows
/// unrelated or invented content. Missing/review-needed coverage stays in the
/// maintainer inventory only.
class ContextualGuidanceHelpPage extends ConsumerStatefulWidget {
  const ContextualGuidanceHelpPage({this.catalog, super.key});

  final ContextualGuidanceCatalog? catalog;

  @override
  ConsumerState<ContextualGuidanceHelpPage> createState() => _ContextualGuidanceHelpPageState();
}

class _ContextualGuidanceHelpPageState extends ConsumerState<ContextualGuidanceHelpPage> {
  late final TextEditingController _queryController = TextEditingController(
    text: ref.read(contextualGuidanceQueryProvider),
  );

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String _groupLabel(String route, AppLocalizations l10n) {
    return switch (route) {
      '/reports' => l10n.routeReports,
      '/taxes' => l10n.routeTaxes,
      '/invoices' => l10n.routeInvoices,
      '/banking' => l10n.routeBanking,
      _ => route,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final ContextualGuidanceCatalog catalog = widget.catalog ?? ref.watch(contextualGuidanceCatalogProvider);
    final String query = ref.watch(contextualGuidanceQueryProvider);
    final AppLocalizations german = lookupAppLocalizations(const Locale('de'));
    final AppLocalizations english = lookupAppLocalizations(const Locale('en'));
    final List<ContextualGuidanceEntry> results = catalog.search(query, german: german, english: english);
    return AppPage(
      maxWidth: 720,
      header: AppPageHeader(title: l10n.routeHelp, showFilterToolbar: false),
      child: ListView(
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('guidance_search_field'),
            controller: _queryController,
            decoration: InputDecoration(labelText: l10n.guidanceSearchHint, prefixIcon: const Icon(Icons.search)),
            onChanged: (String value) => ref.read(contextualGuidanceQueryProvider.notifier).query = value,
          ),
          const SizedBox(height: 16),
          if (results.isEmpty)
            Padding(
              key: const ValueKey<String>('guidance_empty_state'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.guidanceEmptyResults, textAlign: TextAlign.center),
            )
          else
            for (final String route in guidanceWorkflowOrder)
              if (results.any((ContextualGuidanceEntry entry) => entry.route == route)) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(_groupLabel(route, l10n), style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final ContextualGuidanceEntry entry in results.where(
                  (ContextualGuidanceEntry entry) => entry.route == route,
                ))
                  ListTile(
                    key: ValueKey<String>('guidance_entry_${entry.stableId}'),
                    title: Text(guidanceTitle(entry, l10n)),
                    subtitle: Text(l10n.guidanceLocationLabel(entry.route, entry.controlId)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => unawaited(showGuidanceDialog(context, entry)),
                  ),
              ],
        ],
      ),
    );
  }
}
