import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_catalog.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_entry.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_providers.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_texts.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Labeled keyboard-accessible context-help affordance for a supported control.
///
/// Renders nothing when [controlId] has no reviewed entry: no warning, no
/// placeholder, no guessed guidance, and the underlying field stays usable.
class ContextGuidanceButton extends ConsumerStatefulWidget {
  const ContextGuidanceButton({required this.controlId, this.catalog, super.key});

  final String controlId;
  final ContextualGuidanceCatalog? catalog;

  @override
  ConsumerState<ContextGuidanceButton> createState() => _ContextGuidanceButtonState();
}

class _ContextGuidanceButtonState extends ConsumerState<ContextGuidanceButton> {
  final FocusNode _originNode = FocusNode();

  @override
  void dispose() {
    _originNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final ContextualGuidanceCatalog catalog = widget.catalog ?? ref.watch(contextualGuidanceCatalogProvider);
    final ContextualGuidanceEntry? entry = catalog.forControl(widget.controlId);
    if (entry == null) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      focusNode: _originNode,
      onPressed: () => unawaited(_open(context, entry)),
      icon: const Icon(Icons.help_outline),
      label: Text(l10n.guidanceExplainAction),
    );
  }

  Future<void> _open(BuildContext context, ContextualGuidanceEntry entry) async {
    await showGuidanceDialog(context, entry);
    // Focus returns to the originating help control per DESIGN §24/§33.
    if (mounted) {
      _originNode.requestFocus();
    }
  }
}

/// Shared detail surface for field affordances and the Help glossary, so both
/// always show identical content for the same entry.
Future<void> showGuidanceDialog(BuildContext context, ContextualGuidanceEntry entry) {
  final AppLocalizations l10n = appLocalizationsOf(context);
  final GuidanceProvenance? provenance = entry.provenance;
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      key: const ValueKey<String>('guidance_dialog'),
      title: Text(guidanceTitle(entry, l10n)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(guidanceBody(entry, l10n), key: const ValueKey<String>('guidance_dialog_body')),
              const SizedBox(height: 12),
              Text(l10n.guidanceLocationLabel(entry.route, entry.controlId)),
              const SizedBox(height: 4),
              Text(l10n.guidanceContractLabel(entry.owningContract, entry.contractRevision)),
              if (provenance != null) ...<Widget>[
                const SizedBox(height: 4),
                Text('${provenance.sourceTitle} · ${provenance.provision} · ${provenance.sourceVersion}'),
              ],
              const SizedBox(height: 12),
              Text(l10n.guidanceNoAdviceNote, style: Theme.of(dialogContext).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(autofocus: true, onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.actionClose)),
      ],
    ),
  );
}
