import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/incoming_invoices/incoming_invoice_importer.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace_state.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:printing/printing.dart';

class IncomingInvoiceCapturePage extends ConsumerStatefulWidget {
  const IncomingInvoiceCapturePage({required this.belegId, super.key});

  final int belegId;

  @override
  ConsumerState<IncomingInvoiceCapturePage> createState() => _IncomingInvoiceCapturePageState();
}

class _IncomingInvoiceCapturePageState extends ConsumerState<IncomingInvoiceCapturePage> {
  final InvoiceEditorState _editor = InvoiceEditorState();
  final TextEditingController _invoiceDate = TextEditingController();
  final TextEditingController _dueDate = TextEditingController();
  final TextEditingController _sourceNumber = TextEditingController();
  final IncomingInvoiceImporter _importer = const IncomingInvoiceImporter();
  bool _loaded = false;
  bool _loading = true;
  bool _saving = false;
  bool _reviewed = false;
  bool _unsupportedConfirmed = false;
  String? _error;
  String _filename = '';
  Uint8List? _sourceBytes;
  List<Lieferant> _suppliers = const <Lieferant>[];
  int? _supplierId;
  IncomingInvoiceImportResult? _suggestions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_load());
  }

  @override
  void dispose() {
    _invoiceDate.dispose();
    _dueDate.dispose();
    _sourceNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final AppServices services = ref.read(appServicesProvider);
      final List<Map<String, Object?>> receipts = await services.receipts.listInbox();
      final Map<String, Object?>? receipt = receipts
          .where((Map<String, Object?> row) => row['id'] == widget.belegId)
          .firstOrNull;
      if (receipt == null) throw StateError('Beleg nicht gefunden');
      final String status = receipt['status']?.toString() ?? '';
      final String filename = (receipt['original_name'] ?? receipt['dateiname'] ?? '').toString();
      final source = await services.receipts.previewSource(widget.belegId);
      final IncomingInvoiceImportResult? suggestions = source.bytes == null
          ? null
          : _importer.parse(bytes: source.bytes!, filename: filename);
      final List<Lieferant> suppliers = await services.lieferanten.listForPicker();
      if (!mounted) return;
      setState(() {
        _reviewed = status.startsWith('geprueft');
        _filename = filename;
        _sourceBytes = source.bytes;
        _error = source.unavailable;
        _suggestions = suggestions;
        _suppliers = suppliers;
        _loading = false;
      });
      _applySuggestions(suggestions);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = appLocalizationsOf(context).dataLoadError;
        });
      }
    }
  }

  void _applySuggestions(IncomingInvoiceImportResult? result) {
    if (result?.status != IncomingInvoiceImportStatus.supported || result!.unsupportedValues.isNotEmpty) {
      _invoiceDate.text = _editor.datum;
      _editor.addPosition(const EditorPosition(bezeichnung: '', menge: 1, einzelpreis: 0, ustSatz: 19));
      return;
    }
    _invoiceDate.text = result.invoiceDate ?? _editor.datum;
    _dueDate.text = result.dueDate ?? '';
    _sourceNumber.text = result.sourceInvoiceNumber ?? '';
    _editor.datum = _invoiceDate.text;
    for (final IncomingInvoiceLineSuggestion line in result.lines) {
      _editor.addPosition(
        EditorPosition(
          bezeichnung: line.description,
          menge: num.tryParse(line.quantity) ?? 1,
          mengeText: line.quantity,
          einzelpreis: num.tryParse(line.netUnitPrice) ?? 0,
          einzelpreisText: line.netUnitPrice,
          ustSatz: num.tryParse(line.vatRate) ?? 19,
        ),
      );
    }
    if (_editor.positionen.isEmpty) {
      _editor.addPosition(const EditorPosition(bezeichnung: '', menge: 1, einzelpreis: 0, ustSatz: 19));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    _editor.datum = _invoiceDate.text.trim();
    if (_supplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.incomingInvoiceSupplierRequired)));
      return;
    }
    if (!_reviewed || (_suggestions?.unsupportedValues.isNotEmpty == true && !_unsupportedConfirmed)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.incomingInvoiceSaveFailed)));
      return;
    }
    if (!_editor.validateDate() ||
        !_editor.recalculate() ||
        (_dueDate.text.trim().isNotEmpty && !_isIsoDate(_dueDate.text.trim()))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invoiceWorkspaceInvalid)));
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      final RechnungItem saved = await ref
          .read(appServicesProvider)
          .rechnungen
          .createIncomingInvoiceDraft(
            lieferantId: _supplierId!,
            belegId: widget.belegId,
            datum: _editor.datum,
            faelligkeit: _dueDate.text.trim().isEmpty ? null : _dueDate.text.trim(),
            fremdRechnungsnummer: _sourceNumber.text,
            positionen: _editor.toDomainPositions(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.incomingInvoiceCaptureSaved)));
      context.go('/invoices/${saved.id}');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.incomingInvoiceSaveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      maxWidth: 1500,
      header: AppPageHeader(
        leading: IconButton(
          onPressed: () => context.go('/receipts/inbox'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
        title: l10n.incomingInvoiceCaptureTitle,
        showFilterToolbar: false,
        actions: <Widget>[
          FilledButton.icon(
            key: const ValueKey<String>('incoming_invoice_save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(l10n.incomingInvoiceCaptureAction),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: _sourcePreview(l10n)),
                      const SizedBox(width: 16),
                      Expanded(child: _editorPanel(l10n)),
                    ],
                  );
                }
                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: <Widget>[
                      TabBar(
                        tabs: <Widget>[
                          Tab(text: l10n.incomingInvoiceCaptureTitle),
                          Tab(text: l10n.receiptPreviewAction),
                        ],
                      ),
                      Expanded(child: TabBarView(children: <Widget>[_editorPanel(l10n), _sourcePreview(l10n)])),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _sourcePreview(AppLocalizations l10n) {
    final Uint8List? bytes = _sourceBytes;
    final bool isPdf = _filename.toLowerCase().endsWith('.pdf');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(_filename.isEmpty ? l10n.receiptDetailTitle('${widget.belegId}') : _filename),
          const SizedBox(height: 8),
          if (bytes == null)
            Text(_error ?? l10n.incomingInvoiceSourcePreviewUnavailable)
          else if (isPdf)
            Expanded(
              child: PdfPreview(
                key: const ValueKey<String>('incoming_invoice_pdf_preview'),
                build: (_) async => bytes,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                useActions: false,
                onError: (BuildContext context, Object error) =>
                    Center(child: Text(l10n.incomingInvoiceSourcePreviewUnavailable)),
              ),
            )
          else
            Expanded(child: SingleChildScrollView(child: SelectableText(utf8.decode(bytes, allowMalformed: true)))),
        ],
      ),
    );
  }

  Widget _editorPanel(AppLocalizations l10n) {
    final IncomingInvoiceImportResult? source = _suggestions;
    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!_reviewed) Text(l10n.incomingInvoiceSaveFailed),
            if (source?.status == IncomingInvoiceImportStatus.unreadable)
              Text(l10n.incomingInvoiceUnreadable)
            else if (source?.status == IncomingInvoiceImportStatus.unsupportedProfile)
              Text(l10n.incomingInvoiceUnsupportedProfile),
            if (source?.unsupportedValues.isNotEmpty == true) ...<Widget>[
              for (final String value in source!.unsupportedValues) Text(l10n.incomingInvoiceUnsupportedValue(value)),
              CheckboxListTile(
                key: const ValueKey<String>('incoming_invoice_unsupported_confirm'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.incomingInvoiceConfirmUnsupportedValues),
                value: _unsupportedConfirmed,
                onChanged: (bool? value) => setState(() => _unsupportedConfirmed = value ?? false),
              ),
            ],
            DropdownButtonFormField<int>(
              key: const ValueKey<String>('incoming_invoice_supplier'),
              initialValue: _supplierId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.incomingInvoiceSupplierLabel),
              items: <DropdownMenuItem<int>>[
                for (final Lieferant supplier in _suppliers)
                  DropdownMenuItem<int>(
                    value: supplier.id,
                    child: Text(supplier.firma?.trim().isNotEmpty == true ? supplier.firma! : supplier.name),
                  ),
              ],
              onChanged: (int? value) => setState(() => _supplierId = value),
            ),
            if (source?.sellerNameHint?.isNotEmpty == true)
              Text(
                '${source!.sellerNameHint}${source.sellerVatIdHint?.isNotEmpty == true ? ' · ${source.sellerVatIdHint}' : ''}',
              ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('incoming_invoice_source_number'),
              controller: _sourceNumber,
              decoration: InputDecoration(
                labelText: l10n.incomingInvoiceSourceNumberLabel,
                helperText: source?.sourceInvoiceNumber?.isNotEmpty == true
                    ? l10n.incomingInvoiceSuggestedValue(source!.sourceInvoiceNumber!)
                    : null,
              ),
            ),
            TextFormField(
              key: const ValueKey<String>('incoming_invoice_date'),
              controller: _invoiceDate,
              decoration: InputDecoration(
                labelText: l10n.dateLabel,
                helperText: source?.invoiceDate?.isNotEmpty == true
                    ? l10n.incomingInvoiceSuggestedValue(source!.invoiceDate!)
                    : null,
              ),
              onChanged: (String value) => setState(() => _editor.datum = value),
            ),
            TextFormField(
              key: const ValueKey<String>('incoming_invoice_due_date'),
              controller: _dueDate,
              decoration: InputDecoration(
                labelText: l10n.incomingInvoiceDueDateLabel,
                helperText: source?.dueDate?.isNotEmpty == true
                    ? l10n.incomingInvoiceSuggestedValue(source!.dueDate!)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _editor.positionen.length; index++) _lineFields(index, l10n),
            OutlinedButton.icon(
              key: const ValueKey<String>('incoming_invoice_add_line'),
              onPressed: () => setState(() {
                _editor.addPosition(const EditorPosition(bezeichnung: '', menge: 1, einzelpreis: 0, ustSatz: 19));
              }),
              icon: const Icon(Icons.add),
              label: Text(l10n.invoiceWorkspaceAddPosition),
            ),
            if (source?.displayTotals.isNotEmpty == true) ...<Widget>[
              const SizedBox(height: 12),
              Text(l10n.incomingInvoiceTotalsDisplayOnly),
              for (final MapEntry<String, String> total in source!.displayTotals.entries)
                Text(
                  '${switch (total.key) {
                    'net' => l10n.pdfNet,
                    'gross' => l10n.pdfGross,
                    _ => l10n.pdfTotal,
                  }}: ${total.value} EUR',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineFields(int index, AppLocalizations l10n) {
    final EditorPosition line = _editor.positionen[index];
    final IncomingInvoiceLineSuggestion? sourceLine = index < (_suggestions?.lines.length ?? 0)
        ? _suggestions!.lines[index]
        : null;
    return Card(
      key: ValueKey<String>('incoming_invoice_line_$index'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            TextFormField(
              key: ValueKey<String>('incoming_invoice_line_${index}_description'),
              initialValue: line.bezeichnung,
              decoration: InputDecoration(
                labelText: l10n.pdfDescription,
                helperText: sourceLine == null ? null : l10n.incomingInvoiceSuggestedValue(sourceLine.description),
              ),
              onChanged: (String value) =>
                  setState(() => _editor.updatePosition(index, _editor.positionen[index].copyWith(bezeichnung: value))),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('incoming_invoice_line_${index}_quantity'),
                    initialValue: line.mengeText ?? '${line.menge}',
                    decoration: InputDecoration(
                      labelText: l10n.pdfQuantity,
                      helperText: sourceLine == null ? null : l10n.incomingInvoiceSuggestedValue(sourceLine.quantity),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (String value) => setState(() {
                      final EditorPosition current = _editor.positionen[index];
                      _editor.updatePosition(
                        index,
                        current.copyWith(
                          menge: EditorPosition.parseNumericInput(value) ?? current.menge,
                          mengeText: value,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('incoming_invoice_line_${index}_price'),
                    initialValue: line.einzelpreisText ?? '${line.einzelpreis}',
                    decoration: InputDecoration(
                      labelText: l10n.pdfUnitPrice,
                      helperText: sourceLine == null
                          ? null
                          : l10n.incomingInvoiceSuggestedValue(sourceLine.netUnitPrice),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (String value) => setState(() {
                      final EditorPosition current = _editor.positionen[index];
                      _editor.updatePosition(
                        index,
                        current.copyWith(
                          einzelpreis: EditorPosition.parseNumericInput(value) ?? current.einzelpreis,
                          einzelpreisText: value,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('incoming_invoice_line_${index}_vat'),
                    initialValue: '${line.ustSatz}',
                    decoration: InputDecoration(
                      labelText: l10n.incomingInvoiceVatRateLabel,
                      helperText: sourceLine == null ? null : l10n.incomingInvoiceSuggestedValue(sourceLine.vatRate),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (String value) => setState(() {
                      final EditorPosition current = _editor.positionen[index];
                      _editor.updatePosition(
                        index,
                        current.copyWith(ustSatz: EditorPosition.parseNumericInput(value) ?? current.ustSatz),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().startsWith(value);
  }
}
