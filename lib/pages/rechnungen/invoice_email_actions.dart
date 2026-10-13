import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';

// Send action for the production `/invoices/:id` detail route. The control is
// rendered only when the owning surface reports an eligible finalized
// document; deferred types (`Lieferschein`, `Mahnung`) get no control.
// Narrow-safe: wraps instead of overflowing; outcome is text + icon, never
// color-only. Sending stays a user action: this widget never submits on
// build, finalize, or background work.

enum InvoiceEmailOutcome { accepted, rejected, unknown }

class InvoiceEmailActions extends StatelessWidget {
  const InvoiceEmailActions({
    required this.sendAvailable,
    required this.sending,
    required this.lastOutcome,
    required this.onSend,
    super.key,
  });

  final bool sendAvailable;
  final bool sending;
  final InvoiceEmailOutcome? lastOutcome;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (!sendAvailable) {
      return Semantics(
        label: l10n.docEmailNoSendControl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              const Icon(Icons.mail_outline),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l10n.docEmailNoSendControl)),
            ],
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: !sending,
      label: l10n.docEmailSend,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Text(l10n.docEmailSend),
          ),
          if (lastOutcome != null) _OutcomeChip(outcome: lastOutcome!),
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.outcome});

  final InvoiceEmailOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final (IconData icon, String label) = switch (outcome) {
      InvoiceEmailOutcome.accepted => (Icons.mark_email_read_outlined, l10n.docEmailAccepted),
      InvoiceEmailOutcome.rejected => (Icons.mark_email_unread_outlined, l10n.docEmailRejected),
      InvoiceEmailOutcome.unknown => (Icons.help_outline, l10n.docEmailUnknown),
    };
    return Semantics(
      label: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

/// History list for recorded attempts: text + icon per row, keyboard
/// navigable ListTiles, no color-only cues.
class InvoiceEmailHistory extends StatelessWidget {
  const InvoiceEmailHistory({required this.entries, super.key});

  final List<InvoiceEmailHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: l10n.docEmailHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.docEmailHistory, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final InvoiceEmailHistoryEntry entry in entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (entry.outcome) {
                InvoiceEmailOutcome.accepted => Icons.mark_email_read_outlined,
                InvoiceEmailOutcome.rejected => Icons.mark_email_unread_outlined,
                InvoiceEmailOutcome.unknown => Icons.help_outline,
              }),
              title: Text(switch (entry.outcome) {
                InvoiceEmailOutcome.accepted => l10n.docEmailAccepted,
                InvoiceEmailOutcome.rejected => l10n.docEmailRejected,
                InvoiceEmailOutcome.unknown => l10n.docEmailUnknown,
              }),
              subtitle: Text('${entry.recipient} · ${entry.timestamp}'),
            ),
        ],
      ),
    );
  }
}

class InvoiceEmailHistoryEntry {
  const InvoiceEmailHistoryEntry({required this.outcome, required this.recipient, required this.timestamp});

  final InvoiceEmailOutcome outcome;
  final String recipient;
  final String timestamp;
}
