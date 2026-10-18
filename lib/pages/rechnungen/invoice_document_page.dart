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
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_output_format.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace.dart' show invoiceByIdProvider, localeTagFor;
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';
import 'package:path/path.dart' as p;

/// Invoice detail designed as a document workspace rather than a database
/// inspector. The preview mirrors the printed hierarchy and keeps lifecycle
/// actions beside the document state. Displayed totals are copied from one
/// authoritative domain preview result; this page never sums position
/// aggregates to derive a document total.
class InvoiceDocumentPage extends ConsumerStatefulWidget {
  const InvoiceDocumentPage({required this.id, super.key});

  final int id;

  @override
  ConsumerState<InvoiceDocumentPage> createState() => _InvoiceDocumentPageState();
}

class _InvoiceDocumentPageState extends ConsumerState<InvoiceDocumentPage> {
  bool _pending = false;
  bool _exportPending = false;

  /// Explicit per-invoice choice for the open draft, keyed by invoice id so
  /// reopening another document never reuses a stale selection.
  EInvoiceOutputFormat? _chosenFormat;
  int? _chosenForId;

  /// Validation details from the last failed export, shown beside the format.
  List<EInvoiceDiagnostic> _exportDiagnostics = const <EInvoiceDiagnostic>[];
  EInvoiceValidationResult? _exportValidationFailure;
  int? _exportValidationForId;

  /// Session flag: XRechnung was validated and written for this invoice.
  bool _xrechnungExported = false;
  int? _exportedForId;

  RechnungenUseCases get _useCases => ref.read(appServicesProvider).rechnungen;

  void _refreshAfter(int? createdId) {
    ref.invalidate(invoiceByIdProvider(widget.id));
    if (createdId != null) ref.invalidate(invoiceByIdProvider(createdId));
    ref.invalidate(routeRecordsProvider('rechnungen'));
  }

  void _fail(Object _) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).invoiceActionFailed)));
  }

  /// Authoritative preview for the persisted document. Null when the stored
  /// values fail domain validation (stale totals are never presented).
  VorschauResult? _authoritativePreview(RechnungItem invoice) {
    try {
      return VorschauService.calculate(
        eingabemodus: invoice.eingabemodus,
        positionen: invoice.positionen,
        rabattProzent: invoice.rabattProzent,
        rabattBetrag: invoice.rabattBetrag,
      );
      // This domain validation type intentionally remains ArgumentError-derived for API compatibility.
      // ignore: avoid_catching_errors
    } on InvoiceMoneyValidationException {
      return null;
    }
  }

  Future<void> _finalize(RechnungItem invoice, VorschauResult? preview) async {
    if (_pending) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (preview == null) return; // Invalid preview blocks confirmation.
    final String locale = localeTag(Localizations.localeOf(context));
    final EInvoiceOutputFormat selection = _draftSelection(invoice);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.invoiceFinalizeConfirmTitle),
        content: Text(l10n.invoiceFinalizeConfirmMessage),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('invoice_finalize_dialog_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('invoice_finalize_dialog_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.invoiceFinalizeConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return; // Cancelled: draft stays editable.
    setState(() => _pending = true);
    try {
      // The explicitly selected output format is persisted atomically with
      // finalization; the customer preference only supplied the default.
      await _useCases.finalizeRechnung(
        rechnungId: widget.id,
        locale: locale,
        ausgabeformat: eInvoiceOutputFormatStorage(selection),
      );
      _refreshAfter(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invoiceLifecycleDone)));
      }
    } catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _storno(RechnungItem invoice) async {
    if (_pending) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    String reason = '';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.invoiceActionStorno),
        content: TextField(
          autofocus: true,
          onChanged: (String value) => reason = value,
          decoration: InputDecoration(labelText: l10n.invoiceStornoReasonLabel),
          maxLength: 500,
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('invoice_storno_dialog_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('invoice_storno_dialog_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    final String trimmed = reason.trim();
    if (confirmed != true) return;
    if (trimmed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invoiceStornoReasonRequired)));
      }
      return; // Blank reason never reaches the use case.
    }
    setState(() => _pending = true);
    try {
      final RechnungItem created = await _useCases.stornoRechnung(rechnungId: widget.id, grund: trimmed);
      _refreshAfter(created.id);
      if (mounted) context.go('/invoices/${created.id}');
    } catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _gutschrift(RechnungItem invoice) async {
    if (_pending) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.invoiceActionCreditNote),
        content: Text(l10n.invoiceCreditNoteConfirmMessage),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('invoice_gutschrift_dialog_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('invoice_gutschrift_dialog_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _pending = true);
    try {
      // Invoice-derived credit note: date and positions omitted, the
      // optional reason passes through `grund` with its empty default.
      final RechnungItem created = await _useCases.createGutschrift(vonRechnungId: widget.id);
      _refreshAfter(created.id);
      if (mounted) context.go('/invoices/${created.id}');
    } catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _ersatz(RechnungItem invoice) async {
    if (_pending) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.invoiceActionReplacement),
        content: Text(l10n.invoiceReplacementConfirmMessage),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('invoice_replacement_dialog_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('invoice_replacement_dialog_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _pending = true);
    try {
      final RechnungItem created = await _useCases.createErsatzRechnung(vonRechnungId: widget.id);
      _refreshAfter(created.id);
      if (mounted) context.go('/invoices/${created.id}');
    } catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _konvertieren(RechnungItem invoice, String zielTyp) async {
    if (_pending) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.invoiceConvertConfirmTitle),
        content: Text(_documentLabel(zielTyp, l10n)),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('invoice_convert_dialog_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('invoice_convert_dialog_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _pending = true);
    try {
      final RechnungItem created = await _useCases.konvertiereDokument(quelleId: widget.id, zielTyp: zielTyp);
      _refreshAfter(created.id);
      if (mounted) context.go('/invoices/${created.id}');
    } catch (error) {
      _fail(error);
    } finally {
      if (mounted) setState(() => _pending = false);
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
    } catch (_) {
      _showMessage(l10n.loadError);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Explicit per-invoice output selection. Finalized invoices restore the
  /// persisted choice; drafts use the user override or the customer default.
  EInvoiceOutputFormat _draftSelection(RechnungItem invoice) {
    if (!invoice.istEntwurfDokument) return parseEInvoiceOutputFormat(invoice.ausgabeformat);
    if (_chosenForId == invoice.id && _chosenFormat != null) return _chosenFormat!;
    return ref.read(invoiceOutputDefaultProvider(invoice.id)).asData?.value ?? EInvoiceOutputFormat.pdf;
  }

  bool _isOrdinaryOutgoing(RechnungItem invoice) {
    return invoice.typ.trim().toLowerCase() == 'rechnung' && invoice.lieferantId == null;
  }

  /// Readiness derived from validated artifacts only. XRechnung shows as not
  /// yet validated until this session exports it; legacy rows resolve to PDF.
  EInvoiceReadiness _readiness(RechnungItem invoice) {
    if (invoice.istEntwurfDokument) return EInvoiceReadiness.notValidated;
    switch (parseEInvoiceOutputFormat(invoice.ausgabeformat)) {
      case EInvoiceOutputFormat.pdf:
        return (invoice.originalPdfPath?.trim().isNotEmpty ?? false)
            ? EInvoiceReadiness.valid
            : EInvoiceReadiness.notValidated;
      case EInvoiceOutputFormat.zugferd:
        if (!const EInvoiceService().validatorAvailable) return EInvoiceReadiness.unavailable;
        return _zugferdXmlExists(invoice.id) ? EInvoiceReadiness.valid : EInvoiceReadiness.invalid;
      case EInvoiceOutputFormat.xrechnung:
        if (_exportValidationForId == invoice.id && _exportValidationFailure != null) {
          return const EInvoiceService().readiness(_exportValidationFailure);
        }
        if (!const EInvoiceService().validatorAvailable) return EInvoiceReadiness.unavailable;
        return (_exportedForId == invoice.id && _xrechnungExported)
            ? EInvoiceReadiness.valid
            : EInvoiceReadiness.notValidated;
    }
  }

  bool _zugferdXmlExists(int invoiceId) {
    try {
      final String? profileDir = ref.read(appDatabaseProvider).profileDir;
      if (profileDir == null || profileDir.trim().isEmpty) return false;
      return File('$profileDir/pdfs/documents/$invoiceId.zugferd.xml').existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _exportXRechnung(RechnungItem invoice) async {
    if (_exportPending) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    String buyerReference = '';
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.eInvoiceExportXrechnung),
        content: TextField(
          key: const ValueKey<String>('e_invoice_buyer_reference'),
          autofocus: true,
          onChanged: (String value) => buyerReference = value,
          decoration: InputDecoration(
            labelText: l10n.eInvoiceBuyerReferenceLabel,
            hintText: l10n.eInvoiceBuyerReferenceHint,
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('e_invoice_export_dialog_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            key: const ValueKey<String>('e_invoice_export_dialog_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _exportPending = true;
      _exportDiagnostics = const <EInvoiceDiagnostic>[];
      _exportValidationFailure = null;
      _exportValidationForId = null;
    });
    try {
      // Validation runs before any save dialog or file write inside the use
      // case; a failing snapshot never shows the save dialog or changes data.
      final String? destination = await _useCases.exportXRechnung(
        rechnungId: widget.id,
        buyerReference: buyerReference.trim().isEmpty ? null : buyerReference.trim(),
      );
      if (!mounted) return;
      if (destination == null) {
        _showMessage(l10n.eInvoiceExportCancelled);
      } else {
        setState(() {
          _xrechnungExported = true;
          _exportedForId = widget.id;
        });
        _showMessage(l10n.eInvoiceExportSaved);
      }
    } on EInvoiceExportValidationException catch (error) {
      if (mounted) {
        setState(() {
          _exportDiagnostics = error.result.diagnostics;
          _exportValidationFailure = error.result;
          _exportValidationForId = invoice.id;
        });
        final String message = switch (error.result.status) {
          EInvoiceValidationStatus.valid => l10n.eInvoiceReadinessValid,
          EInvoiceValidationStatus.invalid => l10n.eInvoiceReadinessInvalid,
          EInvoiceValidationStatus.unavailable => l10n.eInvoiceReadinessUnavailable,
        };
        _showMessage(message);
      }
    } catch (_) {
      if (mounted) _showMessage(l10n.invoiceActionFailed);
    } finally {
      if (mounted) setState(() => _exportPending = false);
    }
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
    final VorschauResult? preview = _authoritativePreview(invoice);
    // The document total is the preview result's gross value. When the
    // stored values fail validation no amount is presented as current.
    final num? total = preview?.bruttoBetrag;
    final bool isDraft = invoice.istEntwurfDokument;
    return AppPage(
      maxWidth: 1100,
      header: AppPageHeader(
        leading: _backButton(context),
        title: '${appLocalizationsOf(context).pdfInvoice} ${invoice.id}',
        subtitle:
            '$heading · ${_documentLabel(invoice.typ, appLocalizationsOf(context))} · ${_formatDate(invoice.datum, locale)}',
        showFilterToolbar: false,
        actions: _headerActions(context, invoice, preview),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _summaryCard(context, invoice, total, isDraft),
            const SizedBox(height: AppSpacing.lg),
            _lifecycleCard(context, invoice, preview),
            if (_isOrdinaryOutgoing(invoice)) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _eInvoiceCard(context, invoice),
            ],
            const SizedBox(height: AppSpacing.lg),
            _relationshipCard(context, invoice),
            const SizedBox(height: AppSpacing.lg),
            _previewCard(context, invoice, total, isDraft),
          ],
        ),
      ),
    );
  }

  List<Widget> _headerActions(BuildContext context, RechnungItem invoice, VorschauResult? preview) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool isDraft = invoice.istEntwurfDokument;
    if (isDraft) {
      final bool canFinalize = _useCases.kannFinalisieren(invoice) && preview != null;
      return <Widget>[
        TextButton.icon(
          onPressed: () => context.go('/invoices/${invoice.id}/edit'),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.invoiceWorkspaceEditDraft),
        ),
        FilledButton.icon(
          key: const ValueKey<String>('invoice_finalize_header'),
          onPressed: (_pending || !canFinalize) ? null : () => _finalize(invoice, preview),
          icon: _pending
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.task_alt),
          label: Text(_pending ? l10n.setupSaving : l10n.invoiceActionFinalize),
        ),
      ];
    }
    return <Widget>[
      OutlinedButton.icon(
        onPressed: () => _savePdf(invoice),
        icon: const Icon(Icons.save_alt_outlined),
        label: Text(l10n.actionSave),
      ),
      FilledButton.icon(
        onPressed: () => _showPreview(context, invoice, preview?.bruttoBetrag),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(l10n.pdfInvoice),
      ),
    ];
  }

  /// Contextual lifecycle actions derived from persisted type, status and
  /// relationships. Only eligible operations are enabled.
  Widget _lifecycleCard(BuildContext context, RechnungItem invoice, VorschauResult? preview) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool correctionsReady = _useCases.correctionActionsAvailable;
    final Set<String> targets = correctionsReady ? _useCases.konvertierZiele(invoice) : <String>{};
    final bool showFinalize = _useCases.kannFinalisieren(invoice);
    final bool showStorno = correctionsReady && !invoice.istEntwurfDokument && _useCases.kannStorno(invoice);
    final bool showCredit = correctionsReady && _useCases.kannGutschrift(invoice);
    final bool showErsatz = correctionsReady && _useCases.kannErsatz(invoice);
    final bool anyAction = showFinalize || showStorno || showCredit || showErsatz || targets.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.invoiceLifecycleTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (!correctionsReady && !invoice.istEntwurfDokument)
            Text(l10n.invoiceLifecycleUnavailable, style: Theme.of(context).textTheme.bodySmall),
          if (anyAction)
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (showFinalize)
                  FilledButton.icon(
                    key: const ValueKey<String>('invoice_finalize_lifecycle'),
                    onPressed: (_pending || preview == null) ? null : () => _finalize(invoice, preview),
                    icon: const Icon(Icons.task_alt),
                    label: Text(l10n.invoiceActionFinalize),
                  ),
                if (showStorno)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('invoice_action_storno'),
                    onPressed: _pending ? null : () => _storno(invoice),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(l10n.invoiceActionStorno),
                  ),
                if (showCredit)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('invoice_action_credit_note'),
                    onPressed: _pending ? null : () => _gutschrift(invoice),
                    icon: const Icon(Icons.receipt_outlined),
                    label: Text(l10n.invoiceActionCreditNote),
                  ),
                if (showErsatz)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('invoice_action_replacement'),
                    onPressed: _pending ? null : () => _ersatz(invoice),
                    icon: const Icon(Icons.autorenew),
                    label: Text(l10n.invoiceActionReplacement),
                  ),
                for (final String ziel in targets)
                  OutlinedButton.icon(
                    key: ValueKey<String>('invoice_action_convert_$ziel'),
                    onPressed: _pending ? null : () => _konvertieren(invoice, ziel),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text('${l10n.invoiceActionConvert}: ${_documentLabel(ziel, l10n)}'),
                  ),
              ],
            )
          else
            Text(l10n.invoiceLifecycleUnavailable, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  /// Explicit e-invoice output surface: draft choice with customer default,
  /// finalized restore with readiness and export. The widget never issues
  /// SQL; export runs through the registered invoice use case.
  Widget _eInvoiceCard(BuildContext context, RechnungItem invoice) {
    final bool isDraft = invoice.istEntwurfDokument;
    if (isDraft) {
      final AsyncValue<EInvoiceOutputFormat> defaultFormat = ref.watch(invoiceOutputDefaultProvider(invoice.id));
      return AppCard(
        child: defaultFormat.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) => InvoiceOutputFormatSelector(
            selected: _chosenFormat ?? EInvoiceOutputFormat.pdf,
            readiness: EInvoiceReadiness.notValidated,
            onChanged: (EInvoiceOutputFormat value) {
              setState(() {
                _chosenFormat = value;
                _chosenForId = invoice.id;
              });
            },
          ),
          data: (EInvoiceOutputFormat fallback) {
            final EInvoiceOutputFormat selected = (_chosenForId == invoice.id && _chosenFormat != null)
                ? _chosenFormat!
                : fallback;
            return InvoiceOutputFormatSelector(
              selected: selected,
              readiness: EInvoiceReadiness.notValidated,
              onChanged: (EInvoiceOutputFormat value) {
                setState(() {
                  _chosenFormat = value;
                  _chosenForId = invoice.id;
                });
              },
            );
          },
        ),
      );
    }
    final EInvoiceOutputFormat selected = parseEInvoiceOutputFormat(invoice.ausgabeformat);
    return AppCard(
      child: InvoiceOutputFormatSelector(
        selected: selected,
        readiness: _readiness(invoice),
        diagnostics: _exportDiagnostics,
        isDraft: false,
        exportAvailable: true,
        exportPending: _exportPending,
        onExport: () => _exportXRechnung(invoice),
      ),
    );
  }

  /// Reciprocal typed source/target links with navigable targets.
  Widget _relationshipCard(BuildContext context, RechnungItem invoice) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.invoiceRelationshipsTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (invoice.beziehungen.isEmpty)
            Text(l10n.invoiceRelationshipsEmpty, style: Theme.of(context).textTheme.bodySmall)
          else
            for (final RechnungBeziehung link in invoice.beziehungen)
              ListTile(
                key: ValueKey<String>('relationship_${link.kind}_${link.documentId}'),
                leading: const Icon(Icons.link),
                title: Text('${_relationshipLabel(link.kind, l10n)} · ${link.label}'),
                subtitle: link.available ? null : Text('${l10n.invoiceRelationshipMissing} #${link.documentId}'),
                trailing: link.available ? const Icon(Icons.arrow_forward) : null,
                enabled: link.available,
                onTap: link.available ? () => context.go('/invoices/${link.documentId}') : null,
              ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, RechnungItem invoice, num? total, bool isDraft) {
    final String locale = localeTag(Localizations.localeOf(context));
    final AppLocalizations l10n = appLocalizationsOf(context);
    final VorschauResult? preview = _authoritativePreview(invoice);
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
              if (preview != null && total != null)
                MoneyText(total, textAlign: TextAlign.left, style: Theme.of(context).textTheme.titleLarge)
              else
                Text(
                  l10n.invoiceWorkspacePreviewStale,
                  key: const ValueKey<String>('detail_total_stale'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
          if (preview != null) ...<Widget>[
            _SummaryMetric(
              label: l10n.pdfNet,
              value: formatMoney(preview.nettoBetrag, locale: locale),
            ),
            _SummaryMetric(
              label: l10n.pdfTax,
              value: formatMoney(preview.ustBetrag, locale: locale),
            ),
          ],
          if (!isDraft)
            TextButton.icon(
              onPressed: () => _showPreview(context, invoice, total),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l10n.pdfInvoice),
            ),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context, RechnungItem invoice, num? total, bool isDraft) {
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

  void _showPreview(BuildContext context, RechnungItem invoice, num? total) {
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
  final num? total;

  @override
  Widget build(BuildContext context) {
    final String locale = localeTagFor(context);
    final num? displayedTotal = total;
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
                    invoice.eingabemodus == 'brutto' ? l10n.pdfGross : l10n.pdfNet,
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
                if (displayedTotal != null)
                  Flexible(
                    child: Text(
                      formatMoney(displayedTotal, locale: locale),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      l10n.invoiceWorkspacePreviewStale,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
  return switch (value.trim().toLowerCase()) {
    'rechnung' => l10n.pdfInvoice,
    'gutschrift' => l10n.pdfCreditNote,
    'storno' => l10n.pdfStorno,
    'angebot' => l10n.pdfQuote,
    'auftrag' => l10n.pdfOrder,
    'proforma' => l10n.pdfProforma,
    'lieferschein' => l10n.pdfDelivery,
    _ => l10n.pdfInvoice,
  };
}

String _relationshipLabel(String kind, AppLocalizations l10n) {
  final String normalized = kind.toLowerCase();
  if (normalized.contains('storno')) return l10n.pdfStorno;
  if (normalized.contains('gutschrift')) return l10n.pdfCreditNote;
  if (normalized.contains('ersatz')) return l10n.invoiceActionReplacement;
  if (normalized.contains('konvertierung')) return l10n.invoiceActionConvert;
  return l10n.invoiceRelationshipsTitle;
}

String _formatDate(String value, String locale) {
  final DateTime? date = DateTime.tryParse(value);
  if (date == null) return value;
  return formatDate(date, locale: locale);
}
