import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace.dart' show invoiceByIdProvider;
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

/// Draft output default from the customer ZUGFeRD preference.
///
/// True preselects ZUGFeRD, false (or a missing/unreadable customer) selects
/// PDF. The value is a default only; per-invoice changes never write back to
/// the customer.
final invoiceOutputDefaultProvider = FutureProvider.family<EInvoiceOutputFormat, int>((ref, invoiceId) async {
  final RechnungItem? invoice = await ref.watch(invoiceByIdProvider(invoiceId).future);
  final int? kundeId = invoice?.kundeId;
  if (kundeId == null) return EInvoiceOutputFormat.pdf;
  try {
    final options = await ref.watch(appServicesProvider).kunden.invoiceOptions(customerId: kundeId);
    return defaultOutputFormat(zugferdAktiv: options.zugferdAktiv);
  } catch (_) {
    return EInvoiceOutputFormat.pdf;
  }
});

/// Visible per-invoice output choice with validation/readiness state.
///
/// The customer ZUGFeRD preference only supplies the draft default via
/// [selected]; changing the choice never touches the saved customer value.
/// Diagnostics render as text with icons (never color-only). The XRechnung
/// export action is keyboard-reachable and hidden for drafts.
class InvoiceOutputFormatSelector extends StatelessWidget {
  const InvoiceOutputFormatSelector({
    required this.selected,
    required this.readiness,
    this.diagnostics = const <EInvoiceDiagnostic>[],
    this.onChanged,
    this.exportAvailable = false,
    this.exportPending = false,
    this.onExport,
    this.isDraft = true,
    super.key,
  });

  final EInvoiceOutputFormat selected;
  final EInvoiceReadiness readiness;
  final List<EInvoiceDiagnostic> diagnostics;
  final ValueChanged<EInvoiceOutputFormat>? onChanged;
  final bool exportAvailable;
  final bool exportPending;
  final VoidCallback? onExport;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.eInvoiceOutputTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<EInvoiceOutputFormat>(
          segments: <ButtonSegment<EInvoiceOutputFormat>>[
            ButtonSegment<EInvoiceOutputFormat>(
              value: EInvoiceOutputFormat.pdf,
              label: Text(l10n.eInvoiceFormatPdf),
              tooltip: l10n.eInvoiceFormatPdfDescription,
            ),
            ButtonSegment<EInvoiceOutputFormat>(
              value: EInvoiceOutputFormat.zugferd,
              label: Text(l10n.eInvoiceFormatZugferd),
              tooltip: l10n.eInvoiceFormatZugferdDescription,
            ),
            ButtonSegment<EInvoiceOutputFormat>(
              value: EInvoiceOutputFormat.xrechnung,
              label: Text(l10n.eInvoiceFormatXrechnung),
              tooltip: l10n.eInvoiceFormatXrechnungDescription,
            ),
          ],
          selected: <EInvoiceOutputFormat>{selected},
          onSelectionChanged: onChanged == null
              ? null
              : (Set<EInvoiceOutputFormat> selection) => onChanged!(selection.single),
        ),
        const SizedBox(height: AppSpacing.sm),
        _readinessRow(context, l10n),
        if (!isDraft && exportAvailable) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const ValueKey<String>('e_invoice_export_xrechnung'),
            onPressed: (exportPending || onExport == null) ? null : onExport,
            icon: exportPending
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined),
            label: Text(l10n.eInvoiceExportXrechnung),
          ),
        ],
        if (isDraft) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.eInvoiceDraftNoExport,
            key: const ValueKey<String>('e_invoice_draft_no_export'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (diagnostics.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.eInvoiceValidationTitle, style: Theme.of(context).textTheme.titleSmall),
          for (final EInvoiceDiagnostic diagnostic in diagnostics)
            Padding(
              key: ValueKey<String>('e_invoice_diagnostic_${diagnostic.ruleId}'),
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${diagnostic.ruleId}: ${diagnostic.messageFor(Localizations.localeOf(context).toString())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _readinessRow(BuildContext context, AppLocalizations l10n) {
    final (AppStatus status, String label, IconData icon) = switch (readiness) {
      EInvoiceReadiness.valid => (AppStatus.paid, l10n.eInvoiceReadinessValid, Icons.check_circle_outline),
      EInvoiceReadiness.xmlPresent => (AppStatus.info, l10n.eInvoiceReadinessXmlPresent, Icons.info_outline),
      EInvoiceReadiness.invalid => (AppStatus.warning, l10n.eInvoiceReadinessInvalid, Icons.error_outline),
      EInvoiceReadiness.unavailable => (AppStatus.neutral, l10n.eInvoiceReadinessUnavailable, Icons.cloud_off_outlined),
      EInvoiceReadiness.notValidated => (AppStatus.info, l10n.eInvoiceReadinessNotValidated, Icons.help_outline),
    };
    return Row(
      children: <Widget>[
        AppStatusChip(key: const ValueKey<String>('e_invoice_readiness'), status: status, label: label),
        const SizedBox(width: AppSpacing.xs),
        Icon(icon, size: 16, semanticLabel: label),
      ],
    );
  }
}
