import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace_state.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

/// Detail record for one persisted invoice, shared by workspace and detail.
final invoiceByIdProvider = FutureProvider.family<RechnungItem?, int>((ref, id) {
  return ref.watch(appServicesProvider).rechnungen.findById(id);
});

/// Shared outgoing-invoice draft workspace for create and edit routes.
///
/// Desktop (≥960px) shows editor and live preview side by side;
/// narrow windows use localized editor/preview tabs. Totals shown are
/// copied from one authoritative domain preview result; this widget never
/// sums position aggregates or calculates money itself.
class InvoiceWorkspace extends ConsumerStatefulWidget {
  const InvoiceWorkspace({this.draftId, super.key});

  final int? draftId;

  @override
  ConsumerState<InvoiceWorkspace> createState() => _InvoiceWorkspaceState();
}

class _InvoiceWorkspaceState extends ConsumerState<InvoiceWorkspace> {
  late final InvoiceEditorState _state = InvoiceEditorState();
  final TextEditingController _dateController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  void _ensureLoaded(RechnungItem? draft) {
    if (_loaded) return;
    _loaded = true;
    if (draft != null) {
      _state.loadDraft(draft);
      _dateController.text = _state.datum;
    } else {
      _dateController.text = _state.datum;
      _state.recalculate();
    }
  }

  void _refreshPreview() {
    _state.datum = _dateController.text.trim();
    setState(() {
      _state.recalculate();
      _state.validateDate();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    _state.datum = _dateController.text.trim();
    final bool previewValid = _state.recalculate();
    final bool dateValid = _state.validateDate();
    if (!previewValid || !dateValid) {
      setState(() {});
      return;
    }
    if (widget.draftId == null && !_state.validateCustomerRequired()) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      final services = ref.read(appServicesProvider).rechnungen;
      final RechnungItem saved;
      if (widget.draftId == null) {
        saved = await services.createDraftRechnung(
          datum: _state.datum,
          positionen: _state.toDomainPositions(),
          eingabemodus: _state.eingabemodus,
          kundeId: _state.kundeId,
          rabattProzent: _state.rabattProzent,
          rabattBetrag: _state.rabattBetrag,
        );
      } else {
        saved = await services.updateDraftRechnung(
          rechnungId: widget.draftId!,
          datum: _state.datum,
          positionen: _state.toDomainPositions(),
          eingabemodus: _state.eingabemodus,
          rabattProzent: _state.rabattProzent,
          rabattBetrag: _state.rabattBetrag,
        );
      }
      ref.invalidate(routeRecordsProvider('rechnungen'));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appLocalizationsOf(context).invoiceWorkspaceSaved)));
        context.go('/invoices/${saved.id}');
      }
    } catch (error) {
      if (error is InvoiceMoneyValidationException) {
        _state.applyValidationError(error);
      }
      // Keep the entered values in the editor and show only localized copy;
      // technical exception details stay out of the user-facing message.
      if (mounted) {
        final AppLocalizations l10n = appLocalizationsOf(context);
        final String message = error is InvoiceMoneyValidationException
            ? l10n.invoiceWorkspaceInvalid
            : l10n.draftSaveFailed(l10n.invoiceWorkspaceInvalid);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (widget.draftId == null) {
      _ensureLoaded(null);
      return _scaffold(context, l10n, null);
    }
    final AsyncValue<RechnungItem?> draft = ref.watch(invoiceByIdProvider(widget.draftId!));
    return draft.when(
      loading: () => AppPage(
        header: AppPageHeader(title: l10n.invoiceWorkspaceTitle, showFilterToolbar: false),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stack) => AppPage(
        header: AppPageHeader(title: l10n.invoiceWorkspaceTitle, showFilterToolbar: false),
        child: Center(child: Text(l10n.dataLoadError)),
      ),
      data: (RechnungItem? value) {
        if (value == null) {
          return AppPage(
            header: AppPageHeader(title: l10n.invoiceWorkspaceTitle, showFilterToolbar: false),
            child: Center(child: Text(l10n.notFoundDescription)),
          );
        }
        _ensureLoaded(value);
        return _scaffold(context, l10n, value);
      },
    );
  }

  Widget _scaffold(BuildContext context, AppLocalizations l10n, RechnungItem? draft) {
    return AppPage(
      maxWidth: 1200,
      header: AppPageHeader(
        leading: IconButton(
          onPressed: () => context.go('/invoices'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
        title: widget.draftId == null ? l10n.actionNewInvoice : l10n.invoiceWorkspaceEditDraft,
        showFilterToolbar: false,
        actions: <Widget>[
          FilledButton.icon(
            key: const ValueKey<String>('workspace_save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(l10n.actionSaveDraft),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= 960) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 58, child: _editorPanel(context, l10n)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 42, child: _previewPanel(context, l10n, draft)),
              ],
            );
          }
          return DefaultTabController(
            length: 2,
            child: Column(
              children: <Widget>[
                TabBar(
                  tabs: <Widget>[
                    Tab(key: const ValueKey<String>('workspace_tab_editor'), text: l10n.invoiceWorkspaceEditorTab),
                    Tab(key: const ValueKey<String>('workspace_tab_preview'), text: l10n.invoiceWorkspacePreviewTab),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      SingleChildScrollView(child: _editorPanel(context, l10n)),
                      SingleChildScrollView(child: _previewPanel(context, l10n, draft)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editorPanel(BuildContext context, AppLocalizations l10n) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.draftId == null) ...<Widget>[_customerPicker(l10n), const SizedBox(height: AppSpacing.md)],
          TextFormField(
            key: const ValueKey<String>('workspace_date'),
            controller: _dateController,
            decoration: InputDecoration(
              labelText: l10n.dateLabel,
              hintText: '2026-01-31',
              errorText: _workspaceFieldErrorText(_state.fieldErrors['datum'], l10n),
            ),
            onChanged: (_) => _refreshPreview(),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(value: 'netto', label: Text(l10n.quickBookingModusNetto)),
              ButtonSegment<String>(value: 'brutto', label: Text(l10n.quickBookingModusBrutto)),
            ],
            selected: <String>{_state.eingabemodus},
            onSelectionChanged: (Set<String> selection) {
              _state.setEingabemodus(selection.single);
              _refreshPreview();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < _state.positionen.length; index++) _positionRow(context, l10n, index),
          OutlinedButton.icon(
            key: const ValueKey<String>('workspace_add_position'),
            onPressed: () {
              _state.addPosition(const EditorPosition(bezeichnung: '', menge: 1, einzelpreis: 0, ustSatz: 19));
              _refreshPreview();
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.invoiceWorkspaceAddPosition),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.invoiceWorkspacePreviewTab, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          _previewTotals(l10n, 'workspace_editor'),
          if (_state.summaryErrors.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.invoiceWorkspaceInvalid,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customerPicker(AppLocalizations l10n) {
    final AsyncValue<List<Map<String, Object?>>> customersState = ref.watch(routeRecordsProvider('kunden'));
    return customersState.when(
      loading: () => DropdownButtonFormField<int>(
        key: const ValueKey<String>('workspace_customer'),
        decoration: InputDecoration(
          labelText: l10n.invoiceDraftCustomerLabel,
          hintText: l10n.customersLoading,
          errorText: _workspaceFieldErrorText(_state.fieldErrors['kundeId'], l10n),
        ),
        items: const <DropdownMenuItem<int>>[],
        onChanged: null,
      ),
      error: (Object error, StackTrace stack) => DropdownButtonFormField<int>(
        key: const ValueKey<String>('workspace_customer'),
        decoration: InputDecoration(
          labelText: l10n.invoiceDraftCustomerLabel,
          hintText: l10n.invoiceDraftCustomerHint,
          errorText: _workspaceFieldErrorText(_state.fieldErrors['kundeId'], l10n) ?? l10n.dataLoadError,
        ),
        items: const <DropdownMenuItem<int>>[],
        onChanged: null,
      ),
      data: (List<Map<String, Object?>> customers) {
        final List<DropdownMenuItem<int>> items = <DropdownMenuItem<int>>[];
        for (final Map<String, Object?> customer in customers) {
          final int? id = int.tryParse(customer['id']?.toString() ?? '');
          if (id == null) continue;
          final String name = customer['name']?.toString().trim() ?? '';
          final String company = customer['firma']?.toString().trim() ?? '';
          final String label = company.isEmpty || company == name
              ? name
              : name.isEmpty
              ? company
              : '$company · $name';
          items.add(
            DropdownMenuItem<int>(
              value: id,
              child: Text(label.isEmpty ? l10n.invoiceDraftCustomerLabel : label, overflow: TextOverflow.ellipsis),
            ),
          );
        }
        final bool selectedCustomerExists = items.any((DropdownMenuItem<int> item) => item.value == _state.kundeId);
        return DropdownButtonFormField<int>(
          key: const ValueKey<String>('workspace_customer'),
          initialValue: selectedCustomerExists ? _state.kundeId : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.invoiceDraftCustomerLabel,
            hintText: l10n.invoiceDraftCustomerHint,
            errorText: _workspaceFieldErrorText(_state.fieldErrors['kundeId'], l10n),
          ),
          items: items,
          onChanged: items.isEmpty
              ? null
              : (int? value) {
                  _state.setKundeId(value);
                  _refreshPreview();
                },
        );
      },
    );
  }

  Widget _positionRow(BuildContext context, AppLocalizations l10n, int index) {
    final EditorPosition row = _state.positionen[index];
    final String? genericError = _state.fieldErrors['position[$index]'];
    final String? descriptionError = _state.fieldErrors['position[$index].bezeichnung'] ?? genericError;
    final String? quantityError = _state.fieldErrors['position[$index].menge'] ?? genericError;
    final String? priceError = _state.fieldErrors['position[$index].einzelpreis'] ?? genericError;
    return Card(
      key: ValueKey<String>('workspace_position_${row.stableId ?? index}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            TextFormField(
              key: ValueKey<String>('workspace_position_${index}_description'),
              initialValue: row.bezeichnung,
              decoration: InputDecoration(
                labelText: l10n.pdfDescription,
                errorText: _workspaceFieldErrorText(descriptionError, l10n),
              ),
              onChanged: (String value) {
                _state.updatePosition(index, row.copyWith(bezeichnung: value));
                _refreshPreview();
              },
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('workspace_position_${index}_quantity'),
                    initialValue: row.mengeText ?? '${row.menge}',
                    decoration: InputDecoration(
                      labelText: l10n.pdfQuantity,
                      errorText: _workspaceFieldErrorText(quantityError, l10n),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (String value) {
                      final num? parsed = EditorPosition.parseNumericInput(value);
                      _state.updatePosition(index, row.copyWith(menge: parsed ?? row.menge, mengeText: value));
                      _refreshPreview();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('workspace_position_${index}_price'),
                    initialValue: row.einzelpreisText ?? '${row.einzelpreis}',
                    decoration: InputDecoration(
                      labelText: l10n.pdfUnitPrice,
                      errorText: _workspaceFieldErrorText(priceError, l10n),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (String value) {
                      final num? parsed = EditorPosition.parseNumericInput(value);
                      _state.updatePosition(
                        index,
                        row.copyWith(einzelpreis: parsed ?? row.einzelpreis, einzelpreisText: value),
                      );
                      _refreshPreview();
                    },
                  ),
                ),
              ],
            ),
            OverflowBar(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.invoiceWorkspaceMoveUp,
                  onPressed: index == 0
                      ? null
                      : () {
                          _state.movePosition(index, index - 1);
                          _refreshPreview();
                        },
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: l10n.invoiceWorkspaceMoveDown,
                  onPressed: index == _state.positionen.length - 1
                      ? null
                      : () {
                          _state.movePosition(index, index + 1);
                          _refreshPreview();
                        },
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: l10n.invoiceWorkspaceRemovePosition,
                  onPressed: () {
                    _state.removePosition(index);
                    _refreshPreview();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Read-only projection of the latest authoritative domain preview.
  Widget _previewTotals(AppLocalizations l10n, String keyPrefix) {
    final VorschauResult? result = _state.previewStale ? null : _state.preview;
    if (result == null) {
      return Text(
        key: ValueKey<String>('${keyPrefix}_stale'),
        l10n.invoiceWorkspacePreviewStale,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final String locale = localeTagFor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PreviewTotal(
          key: ValueKey<String>('${keyPrefix}_net'),
          label: l10n.pdfNet,
          valueCents: result.nettoCents,
          locale: locale,
        ),
        _PreviewTotal(
          key: ValueKey<String>('${keyPrefix}_tax'),
          label: l10n.pdfTax,
          valueCents: result.ustCents,
          locale: locale,
        ),
        _PreviewTotal(
          key: ValueKey<String>('${keyPrefix}_total'),
          label: l10n.pdfTotal,
          valueCents: result.bruttoCents,
          locale: locale,
          prominent: true,
        ),
      ],
    );
  }

  Widget _previewPanel(BuildContext context, AppLocalizations l10n, RechnungItem? draft) {
    final AsyncValue<List<Map<String, Object?>>> customersState = ref.watch(routeRecordsProvider('kunden'));
    final List<Map<String, Object?>> customers = customersState.asData?.value ?? const <Map<String, Object?>>[];
    Map<String, Object?>? selectedCustomer;
    for (final Map<String, Object?> customer in customers) {
      if (int.tryParse(customer['id']?.toString() ?? '') == _state.kundeId) {
        selectedCustomer = customer;
        break;
      }
    }
    final String company = draft?.kundeFirma?.trim() ?? selectedCustomer?['firma']?.toString().trim() ?? '';
    final String name = draft?.kundeName?.trim() ?? selectedCustomer?['name']?.toString().trim() ?? '';
    final String customerLabel = company.isEmpty || company == name
        ? name
        : name.isEmpty
        ? company
        : '$company · $name';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.invoiceWorkspacePreviewTab, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.dateLabel, style: Theme.of(context).textTheme.labelMedium),
          Text(_dateController.text),
          if (customerLabel.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.invoiceDraftCustomerLabel, style: Theme.of(context).textTheme.labelMedium),
            Text(customerLabel),
          ],
          if (_state.positionen.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < _state.positionen.length; index++)
              Padding(
                key: ValueKey<String>('workspace_preview_line_$index'),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _state.positionen[index].bezeichnung.trim().isEmpty
                            ? l10n.invoiceDraftPositionLabel
                            : _state.positionen[index].bezeichnung,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${l10n.pdfQuantity}: '
                      '${_state.positionen[index].mengeText ?? _state.positionen[index].menge}',
                    ),
                  ],
                ),
              ),
          ],
          const Divider(),
          _previewTotals(l10n, 'workspace_preview'),
        ],
      ),
    );
  }
}

String localeTagFor(BuildContext context) => localeTag(Localizations.localeOf(context));

class _PreviewTotal extends StatelessWidget {
  const _PreviewTotal({
    required this.label,
    required this.valueCents,
    required this.locale,
    this.prominent = false,
    super.key,
  });

  final String label;
  final int valueCents;
  final String locale;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        MoneyText(
          valueCents / 100.0,
          style: prominent ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

String? _workspaceFieldErrorText(String? code, AppLocalizations l10n) {
  if (code == null) return null;
  if (code == 'customerRequired') return l10n.errorCustomerRequired;
  if (code == 'invalidDate') return l10n.errorDateFormat;
  return l10n.invoiceWorkspaceInvalid;
}
