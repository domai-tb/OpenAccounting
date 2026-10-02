import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/design_system/components/skeleton.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:path/path.dart' as p;

final invoiceByIdProvider = FutureProvider.family<RechnungItem?, int>((ref, id) {
  return ref.watch(appServicesProvider).rechnungen.findById(id);
});

/// Invoice detail designed as a document workspace rather than a database
/// inspector. The preview mirrors the printed hierarchy and keeps lifecycle
/// actions beside the document state.
class InvoiceDocumentPage extends ConsumerStatefulWidget {
  const InvoiceDocumentPage({required this.id, super.key});

  final int id;

  @override
  ConsumerState<InvoiceDocumentPage> createState() => _InvoiceDocumentPageState();
}

class _InvoiceDocumentPageState extends ConsumerState<InvoiceDocumentPage> {
  bool _finalizing = false;

  Future<void> _finalize() async {
    if (_finalizing) return;
    setState(() => _finalizing = true);
    try {
      final String locale = localeTag(Localizations.localeOf(context));
      await ref.read(appServicesProvider).rechnungen.finalizeRechnung(rechnungId: widget.id, locale: locale);
      ref.invalidate(invoiceByIdProvider(widget.id));
      ref.invalidate(routeRecordsProvider('rechnungen'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).setupSaved)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${appLocalizationsOf(context).loadError}: $error')));
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  Future<void> _savePdf(RechnungItem invoice) async {
    final String? profileDir = ref.read(appDatabaseProvider).profileDir;
    final String? relativePath = invoice.originalPdfPath;
    if (profileDir == null || relativePath == null || relativePath.trim().isEmpty) {
      _showMessage(appLocalizationsOf(context).dataLoadError);
      return;
    }
    final String basePath = p.normalize(p.absolute(profileDir));
    final String sourcePath = p.normalize(p.join(basePath, relativePath));
    if (!p.isWithin(basePath, sourcePath)) {
      _showMessage(appLocalizationsOf(context).dataLoadError);
      return;
    }
    final File source = File(sourcePath);
    if (!source.existsSync()) {
      _showMessage(appLocalizationsOf(context).dataLoadError);
      return;
    }
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      final FileSaveLocation? location = await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'PDF', extensions: <String>['pdf']),
        ],
        suggestedName: '${invoice.rechnungsnummer ?? 'rechnung-${invoice.id}'}.pdf',
        confirmButtonText: l10n.actionSave,
      );
      if (location == null) return;
      await source.copy(location.path);
      _showMessage(l10n.setupSaved);
    } catch (error) {
      _showMessage('${l10n.loadError}: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RechnungItem?> invoice = ref.watch(invoiceByIdProvider(widget.id));
    return invoice.when(
      loading: () => _loadingPage(context),
      error: (Object error, StackTrace stackTrace) => _errorPage(context, error, stackTrace),
      data: (RechnungItem? value) {
        if (value == null) {
          final AppLocalizations l10n = appLocalizationsOf(context);
          return _InvoiceStatePage(title: l10n.notFound, message: l10n.notFoundDescription);
        }
        return _documentPage(context, value);
      },
    );
  }

  Widget _loadingPage(BuildContext context) {
    return AppPage(
      header: AppPageHeader(
        leading: _backButton(context),
        title: appLocalizationsOf(context).pdfInvoice,
        showFilterToolbar: false,
      ),
      child: const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonBox(width: 180, height: 28),
            SizedBox(height: AppSpacing.xl),
            SkeletonBox(width: double.infinity, height: 18),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: double.infinity, height: 18),
            SizedBox(height: AppSpacing.xl),
            SkeletonBox(width: double.infinity, height: 180),
          ],
        ),
      ),
    );
  }

  Widget _errorPage(BuildContext context, Object error, StackTrace stackTrace) {
    debugPrint('invoice ${widget.id} failed: $error\n$stackTrace');
    return _InvoiceStatePage(
      title: appLocalizationsOf(context).loadError,
      message: appLocalizationsOf(context).dataLoadError,
      actionLabel: appLocalizationsOf(context).actionRetry,
      onAction: () => ref.invalidate(invoiceByIdProvider(widget.id)),
    );
  }

  Widget _documentPage(BuildContext context, RechnungItem invoice) {
    final String locale = localeTag(Localizations.localeOf(context));
    final String heading = invoice.rechnungsnummer ?? appLocalizationsOf(context).invoiceDraftNumber(invoice.id);
    final num total = invoice.positionen.fold<num>(0, (num sum, RechnungPositionItem p) => sum + p.gesamt);
    final bool isDraft = invoice.istEntwurf || invoice.status.toLowerCase() == 'entwurf';
    return AppPage(
      maxWidth: 1100,
      header: AppPageHeader(
        leading: _backButton(context),
        title: '${appLocalizationsOf(context).pdfInvoice} ${invoice.id}',
        subtitle:
            '$heading · ${_documentLabel(invoice.typ, appLocalizationsOf(context))} · ${_formatDate(invoice.datum, locale)}',
        showFilterToolbar: false,
        actions: <Widget>[
          if (isDraft)
            FilledButton.icon(
              onPressed: _finalizing ? null : _finalize,
              icon: _finalizing
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.task_alt),
              label: Text(
                _finalizing ? appLocalizationsOf(context).setupSaving : appLocalizationsOf(context).actionContinue,
              ),
            )
          else ...<Widget>[
            OutlinedButton.icon(
              onPressed: () => _savePdf(invoice),
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(appLocalizationsOf(context).actionSave),
            ),
            FilledButton.icon(
              onPressed: () => _showPreview(context, invoice),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(appLocalizationsOf(context).pdfInvoice),
            ),
          ],
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _summaryCard(context, invoice, total, isDraft),
            const SizedBox(height: AppSpacing.lg),
            _previewCard(context, invoice, total, isDraft),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, RechnungItem invoice, num total, bool isDraft) {
    final String locale = localeTag(Localizations.localeOf(context));
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppCard(
      child: Wrap(
        spacing: AppSpacing.xxl,
        runSpacing: AppSpacing.lg,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.statusUnknown, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              AppStatusChip(status: _statusFor(invoice.status), label: _statusLabel(invoice.status, l10n)),
            ],
          ),
          _SummaryMetric(label: l10n.pdfDate, value: _formatDate(invoice.datum, locale)),
          _SummaryMetric(label: l10n.pdfPosition, value: '${invoice.positionen.length}'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.pdfTotal, style: Theme.of(context).textTheme.bodySmall),
              MoneyText(total, textAlign: TextAlign.left, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          if (!isDraft)
            TextButton.icon(
              onPressed: () => _showPreview(context, invoice),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l10n.pdfInvoice),
            ),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context, RechnungItem invoice, num total, bool isDraft) {
    final Color pageBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF20242C)
        : Colors.white;
    final Color pageText = Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF17181C);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.picture_as_pdf_outlined),
              const SizedBox(width: AppSpacing.sm),
              Text(appLocalizationsOf(context).pdfInvoice, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (isDraft) Text(appLocalizationsOf(context).setupSaving, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            constraints: const BoxConstraints(minHeight: 560, maxWidth: 780),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: pageBackground,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
            ),
            child: DefaultTextStyle(
              style: TextStyle(color: pageText, fontSize: 13),
              child: _InvoicePaper(invoice: invoice, total: total),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context, RechnungItem invoice) {
    final num total = invoice.positionen.fold<num>(0, (num sum, RechnungPositionItem p) => sum + p.gesamt);
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        appLocalizationsOf(dialogContext).pdfInvoice,
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(dialogContext).pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _InvoicePaper(invoice: invoice, total: total),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return IconButton(
      onPressed: () => context.go('/invoices'),
      icon: const Icon(Icons.arrow_back),
      tooltip: appLocalizationsOf(context).actionBack,
    );
  }
}

class _InvoicePaper extends StatelessWidget {
  const _InvoicePaper({required this.invoice, required this.total});

  final RechnungItem invoice;
  final num total;

  @override
  Widget build(BuildContext context) {
    final String locale = localeTag(Localizations.localeOf(context));
    final AppLocalizations l10n = appLocalizationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Text('OpenAccounting', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _documentLabel(invoice.typ, l10n),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(invoice.rechnungsnummer ?? l10n.invoiceDraftNumber(invoice.id)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        Text(l10n.pdfTo, style: const TextStyle(fontWeight: FontWeight.w700)),
        ..._customerAddress(invoice, l10n),
        const SizedBox(height: 32),
        Text('${l10n.pdfDate}: ${_formatDate(invoice.datum, locale)}'),
        const SizedBox(height: 20),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(3),
            1: FixedColumnWidth(64),
            2: FixedColumnWidth(110),
          },
          border: const TableBorder(bottom: BorderSide(color: Color(0xFFE1E4E8))),
          children: <TableRow>[
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFB8BDC7))),
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.pdfDescription, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.pdfQuantity,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.pdfGross,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            for (final RechnungPositionItem position in invoice.positionen)
              TableRow(
                children: <Widget>[
                  Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(position.bezeichnung)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('${position.menge}', textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(formatMoney(position.gesamt, locale: locale), textAlign: TextAlign.right),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(l10n.pdfTotal, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(
                  formatMoney(total, locale: locale),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        const Divider(),
        const Text('OpenAccounting', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
      ],
    );
  }
}

List<Widget> _customerAddress(RechnungItem invoice, AppLocalizations l10n) {
  final List<String> lines = <String>[
    if (invoice.kundeFirma?.trim().isNotEmpty ?? false) invoice.kundeFirma!.trim(),
    if (invoice.kundeName?.trim().isNotEmpty ?? false) invoice.kundeName!.trim(),
    if (invoice.kundeStrasse?.trim().isNotEmpty ?? false) invoice.kundeStrasse!.trim(),
    if ((invoice.kundePlz?.trim().isNotEmpty ?? false) || (invoice.kundeOrt?.trim().isNotEmpty ?? false))
      '${invoice.kundePlz?.trim() ?? ''} ${invoice.kundeOrt?.trim() ?? ''}'.trim(),
  ];
  if (lines.isEmpty) return <Widget>[Text(l10n.pdfUnknown)];
  return <Widget>[for (final String line in lines) Text(line)];
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _InvoiceStatePage extends StatelessWidget {
  const _InvoiceStatePage({required this.title, required this.message, this.actionLabel, this.onAction});

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: AppPageHeader(title: appLocalizationsOf(context).pdfInvoice, showFilterToolbar: false),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 72, horizontal: AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.receipt_long_outlined, size: 48),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

AppStatus _statusFor(String value) {
  final String normalized = value.toLowerCase();
  if (normalized.contains('bezahlt')) return AppStatus.paid;
  if (normalized.contains('überf')) return AppStatus.overdue;
  if (normalized.contains('entwurf')) return AppStatus.draft;
  if (normalized.contains('offen')) return AppStatus.info;
  return AppStatus.neutral;
}

String _statusLabel(String value, AppLocalizations l10n) {
  return switch (value.toLowerCase()) {
    'open' => l10n.statusOpen,
    'paid' => l10n.statusPaid,
    'overdue' => l10n.statusOverdue,
    'draft' => l10n.statusDraft,
    _ => value,
  };
}

String _documentLabel(String value, AppLocalizations l10n) {
  return switch (value) {
    'rechnung' => l10n.pdfInvoice,
    'gutschrift' => l10n.pdfCreditNote,
    _ => l10n.pdfInvoice,
  };
}

String _formatDate(String value, String locale) {
  final DateTime? date = DateTime.tryParse(value);
  if (date == null) return value;
  return formatDate(date, locale: locale);
}
