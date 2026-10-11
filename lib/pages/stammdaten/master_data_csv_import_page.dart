import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_service.dart';

/// Navigable CSV import workflow state for one master-data entity. Opened
/// from the owning workspace via Navigator push so the list query state stays
/// intact on return; no canonical route is added.
class MasterDataCsvImportView extends ConsumerStatefulWidget {
  const MasterDataCsvImportView({required this.entity, super.key});

  final MasterDataImportEntity entity;

  @override
  ConsumerState<MasterDataCsvImportView> createState() => _MasterDataCsvImportViewState();
}

class _CsvImportStrings {
  _CsvImportStrings({required this.en});

  final bool en;

  String get title => en ? 'CSV import' : 'CSV-Import';
  String get stepSource => en ? '1. Source' : '1. Datei';
  String get stepMapping => en ? '2. Mapping' : '2. Zuordnung';
  String get stepReview => en ? '3. Review' : '3. Prüfung';
  String get stepResult => en ? '4. Result' : '4. Ergebnis';
  String get sourceHint => en
      ? 'Paste CSV text or enter a local file path. Preview writes nothing.'
      : 'CSV-Text einfügen oder lokalen Dateipfad angeben. Die Vorschau schreibt nichts.';
  String get csvLabel => en ? 'CSV text' : 'CSV-Text';
  String get pathLabel => en ? 'Local file path (optional)' : 'Lokaler Dateipfad (optional)';
  String get delimiterLabel => en ? 'Delimiter' : 'Trennzeichen';
  String get headerLabel => en ? 'First row is header' : 'Erste Zeile ist Kopfzeile';
  String get decimalLabel => en ? 'Numeric format' : 'Zahlenformat';
  String get decimalPoint => en ? 'Decimal point (123.50)' : 'Dezimalpunkt (123.50)';
  String get decimalComma => en ? 'Decimal comma (123,50)' : 'Dezimalkomma (123,50)';
  String get policyLabel => en ? 'Duplicate policy' : 'Duplikatregel';
  String get policySkip => en ? 'Skip' : 'Überspringen';
  String get policyUpdate => en ? 'Update' : 'Aktualisieren';
  String get policyCreateNew => en ? 'Create new' : 'Neu anlegen';
  String get matchLabel => en ? 'Match field' : 'Vergleichsfeld';
  String get basisLabel => en ? 'Price basis' : 'Preisbasis';
  String get basisNet => en ? 'Net' : 'Netto';
  String get basisGross => en ? 'Gross' : 'Brutto';
  String get actionParse => en ? 'Parse and map' : 'Parsen und zuordnen';
  String get actionBack => en ? 'Back' : 'Zurück';
  String get actionPreview => en ? 'Validate preview' : 'Vorschau prüfen';
  String get actionConfirm => en ? 'Confirm import' : 'Import bestätigen';
  String get actionCancel => en ? 'Cancel' : 'Abbrechen';
  String get templateLabel => en ? 'Mapping template' : 'Zuordnungsvorlage';
  String get templateNone => en ? 'No template' : 'Keine Vorlage';
  String get templateSave => en ? 'Save mapping' : 'Zuordnung speichern';
  String get templateNameHint => en ? 'Template name' : 'Vorlagenname';
  String get statusValid => en ? 'Valid' : 'Gültig';
  String get statusInvalid => en ? 'Invalid' : 'Ungültig';
  String get statusSkip => en ? 'Skipped' : 'Übersprungen';
  String get statusUpdate => en ? 'Update' : 'Aktualisierung';
  String get statusCreate => en ? 'Create' : 'Neu';
  String get statusAmbiguous => en ? 'Ambiguous' : 'Mehrdeutig';
  String get statusDuplicate => en ? 'Duplicate' : 'Duplikat';
  String get selectUpdate => en ? 'Select update' : 'Aktualisierung wählen';
  String get counts => en ? 'Counts' : 'Anzahlen';
}

class _MasterDataCsvImportViewState extends ConsumerState<MasterDataCsvImportView> {
  final TextEditingController _csvController = TextEditingController();
  final TextEditingController _pathController = TextEditingController();
  CsvImportDelimiter _delimiter = CsvImportDelimiter.semicolon;
  bool _hasHeader = true;
  CsvDecimalConvention _decimal = CsvDecimalConvention.comma;
  MasterDataDuplicatePolicy _policy = MasterDataDuplicatePolicy.skip;
  String? _matchField;
  ArticlePriceBasis _basis = ArticlePriceBasis.gross;
  int _step = 0;
  MasterDataParsedCsv? _parsed;
  Map<int, String> _columnToField = <int, String>{};
  MasterDataImportPreview? _preview;
  Map<int, MasterDataRowSelection> _selections = <int, MasterDataRowSelection>{};
  MasterDataImportResult? _result;
  Object? _error;
  bool _working = false;
  int _previewPage = 1;
  List<MasterDataImportTemplate> _templates = <MasterDataImportTemplate>[];
  int? _templateId;

  @override
  void dispose() {
    _csvController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  _CsvImportStrings _strings(BuildContext context) {
    return _CsvImportStrings(en: Localizations.localeOf(context).languageCode == 'en');
  }

  MasterDataCsvImportService _service(BuildContext context, WidgetRef ref) {
    final AppServices services = AppScope.maybeOf(context)?.services ?? ref.read(appServicesProvider);
    return services.masterDataCsvImport.service;
  }

  List<String> _allowedFields() {
    return MasterDataImportFields.allowedFor(widget.entity).toList(growable: false)..sort();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final _CsvImportStrings s = _strings(context);
    return AppPage(
      maxWidth: 1180,
      header: AppPageHeader(
        title: '${s.title} · ${widget.entity.name}',
        showFilterToolbar: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.actionBack,
        ),
      ),
      child: SingleChildScrollView(
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _stepsHeader(context, s),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) _errorCard(context, l10n),
              if (_step == 0) _sourceStep(context, s),
              if (_step == 1) _mappingStep(context, s),
              if (_step == 2) _reviewStep(context, s, l10n),
              if (_step == 3) _resultStep(context, s, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepsHeader(BuildContext context, _CsvImportStrings s) {
    final List<String> steps = <String>[s.stepSource, s.stepMapping, s.stepReview, s.stepResult];
    return Semantics(
      header: true,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            Chip(
              label: Text(
                '${i == _step ? '● ' : ''}${steps[i]}',
                style: TextStyle(fontWeight: i == _step ? FontWeight.w700 : FontWeight.w400),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, AppLocalizations l10n) {
    final Object error = _error!;
    final String message = error is MasterDataCsvUnavailableException
        ? '${l10n.workspaceUnavailable}: ${error.message}'
        : error.toString();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(liveRegion: true, child: Text(message)),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _working
                ? null
                : () => setState(() {
                    _error = null;
                  }),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.actionRetry),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // -- Step 1: source -------------------------------------------------------

  Widget _sourceStep(BuildContext context, _CsvImportStrings s) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.sourceHint),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pathController,
            decoration: InputDecoration(labelText: s.pathLabel),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _csvController,
            decoration: InputDecoration(labelText: s.csvLabel, alignLabelWithHint: true),
            maxLines: 8,
            minLines: 4,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              DropdownMenu<CsvImportDelimiter>(
                label: Text(s.delimiterLabel),
                initialSelection: _delimiter,
                dropdownMenuEntries: const <DropdownMenuEntry<CsvImportDelimiter>>[
                  DropdownMenuEntry(value: CsvImportDelimiter.comma, label: 'Komma (,)'),
                  DropdownMenuEntry(value: CsvImportDelimiter.semicolon, label: 'Semikolon (;)'),
                  DropdownMenuEntry(value: CsvImportDelimiter.tab, label: 'Tab'),
                ],
                onSelected: (CsvImportDelimiter? v) => setState(() => _delimiter = v ?? _delimiter),
              ),
              DropdownMenu<CsvDecimalConvention>(
                label: Text(s.decimalLabel),
                initialSelection: _decimal,
                dropdownMenuEntries: <DropdownMenuEntry<CsvDecimalConvention>>[
                  DropdownMenuEntry(value: CsvDecimalConvention.point, label: s.decimalPoint),
                  DropdownMenuEntry(value: CsvDecimalConvention.comma, label: s.decimalComma),
                ],
                onSelected: (CsvDecimalConvention? v) => setState(() => _decimal = v ?? _decimal),
              ),
              DropdownMenu<MasterDataDuplicatePolicy>(
                label: Text(s.policyLabel),
                initialSelection: _policy,
                dropdownMenuEntries: <DropdownMenuEntry<MasterDataDuplicatePolicy>>[
                  DropdownMenuEntry(value: MasterDataDuplicatePolicy.skip, label: s.policySkip),
                  DropdownMenuEntry(value: MasterDataDuplicatePolicy.update, label: s.policyUpdate),
                  DropdownMenuEntry(value: MasterDataDuplicatePolicy.createNew, label: s.policyCreateNew),
                ],
                onSelected: (MasterDataDuplicatePolicy? v) => setState(() => _policy = v ?? _policy),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Checkbox(value: _hasHeader, onChanged: (bool? v) => setState(() => _hasHeader = v ?? true)),
              Expanded(child: Text(s.headerLabel)),
            ],
          ),
          if (widget.entity == MasterDataImportEntity.article)
            DropdownMenu<ArticlePriceBasis>(
              label: Text(s.basisLabel),
              initialSelection: _basis,
              dropdownMenuEntries: <DropdownMenuEntry<ArticlePriceBasis>>[
                DropdownMenuEntry(value: ArticlePriceBasis.net, label: s.basisNet),
                DropdownMenuEntry(value: ArticlePriceBasis.gross, label: s.basisGross),
              ],
              onSelected: (ArticlePriceBasis? v) => setState(() => _basis = v ?? _basis),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              const Spacer(),
              FilledButton.icon(
                onPressed: _working ? null : () => unawaited(_parseSource()),
                icon: _working
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward),
                label: Text(s.actionParse),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _parseSource() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final String text = await _resolveSourceText();
      final MasterDataParsedCsv parsed = MasterDataCsvParser.parseText(
        text,
        delimiter: _delimiter,
        hasHeader: _hasHeader,
      );
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _columnToField = <int, String>{};
        _matchField = null;
        _preview = null;
        _result = null;
        _step = 1;
      });
      await _loadTemplates();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String> _resolveSourceText() async {
    final String path = _pathController.text.trim();
    if (path.isNotEmpty) {
      try {
        final File file = File(path);
        final List<int> bytes = await file.readAsBytes();
        // Decode here for the pasted-text pipeline; size/encoding rules apply.
        final MasterDataParsedCsv parsed = MasterDataCsvParser.parseBytes(
          bytes,
          delimiter: _delimiter,
          hasHeader: _hasHeader,
        );
        _parsed = parsed;
        // Re-encode canonical text for the mapping step display.
        return _csvController.text.trim().isNotEmpty ? _csvController.text : utf8.decode(bytes);
      } catch (error) {
        if (error is MasterDataCsvImportException) rethrow;
        // Fall through to pasted text when the path cannot be read.
      }
    }
    final String pasted = _csvController.text;
    if (pasted.trim().isEmpty) {
      throw const MasterDataCsvParseException('Keine CSV-Quelle angegeben.');
    }
    return pasted;
  }

  Future<void> _loadTemplates() async {
    try {
      final MasterDataCsvImportService service = _service(context, ref);
      final List<MasterDataImportTemplate> rows = await service.templates.list(widget.entity);
      if (mounted) setState(() => _templates = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  // -- Step 2: mapping --------------------------------------------------------

  Widget _mappingStep(BuildContext context, _CsvImportStrings s) {
    final MasterDataParsedCsv? parsed = _parsed;
    if (parsed == null) return const SizedBox.shrink();
    final List<String> labels = _columnLabels(parsed);
    final List<String> fields = _allowedFields();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownMenu<int?>(
            label: Text(s.templateLabel),
            initialSelection: _templateId,
            dropdownMenuEntries: <DropdownMenuEntry<int?>>[
              const DropdownMenuEntry<int?>(value: null, label: '—'),
              for (final MasterDataImportTemplate t in _templates) DropdownMenuEntry<int?>(value: t.id, label: t.name),
            ],
            onSelected: _applyTemplate,
          ),
          const SizedBox(height: AppSpacing.md),
          for (int col = 0; col < labels.length; col++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(labels[col])),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: DropdownMenu<String?>(
                      key: ValueKey<String>('map_col_$col'),
                      label: Text('Spalte ${col + 1}'),
                      initialSelection: _columnToField[col],
                      dropdownMenuEntries: <DropdownMenuEntry<String?>>[
                        const DropdownMenuEntry<String?>(value: null, label: '—'),
                        for (final String f in fields) DropdownMenuEntry<String?>(value: f, label: f),
                      ],
                      onSelected: (String? v) => setState(() {
                        if (v == null) {
                          _columnToField.remove(col);
                        } else {
                          _columnToField[col] = v;
                        }
                      }),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          DropdownMenu<String?>(
            label: Text(s.matchLabel),
            initialSelection: _matchField,
            dropdownMenuEntries: <DropdownMenuEntry<String?>>[
              const DropdownMenuEntry<String?>(value: null, label: '—'),
              for (final String f in _columnToField.values.toSet()) DropdownMenuEntry<String?>(value: f, label: f),
            ],
            onSelected: (String? v) => setState(() => _matchField = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.enter, control: true): () => unawaited(_buildPreview()),
            },
            child: Row(
              children: <Widget>[
                OutlinedButton(onPressed: () => setState(() => _step = 0), child: Text(s.actionBack)),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_saveTemplate(context)),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(s.templateSave),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _working ? null : () => unawaited(_buildPreview()),
                  icon: const Icon(Icons.preview_outlined),
                  label: Text(s.actionPreview),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _columnLabels(MasterDataParsedCsv parsed) {
    final int width = parsed.header?.length ?? (parsed.rows.isEmpty ? 0 : parsed.rows.first.cells.length);
    if (parsed.header != null) return parsed.header!;
    return <String>[for (int i = 0; i < width; i++) 'Spalte ${i + 1}'];
  }

  MasterDataFieldMapping _currentMapping() {
    return MasterDataFieldMapping(
      entity: widget.entity,
      columnToField: Map<int, String>.from(_columnToField),
      hasHeader: _hasHeader,
      delimiter: _delimiter,
      decimalConvention: _decimal,
      duplicatePolicy: _policy,
      matchField: _matchField,
      articlePriceBasis: widget.entity == MasterDataImportEntity.article ? _basis : null,
    );
  }

  Future<void> _applyTemplate(int? id) async {
    setState(() => _templateId = id);
    if (id == null) return;
    final MasterDataImportTemplate found = _templates.singleWhere(
      (MasterDataImportTemplate t) => t.id == id,
      orElse: () => throw const MasterDataCsvMappingException('Vorlage nicht gefunden.'),
    );
    late final MasterDataFieldMapping mapping;
    try {
      mapping = found.mapping;
      if (mapping.entity != widget.entity) throw const MasterDataCsvMappingException('Vorlage passt nicht.');
    } catch (error) {
      if (mounted) setState(() => _error = error);
      return;
    }
    if (!mounted) return;
    setState(() {
      _columnToField = Map<int, String>.from(mapping.columnToField);
      _hasHeader = mapping.hasHeader;
      _delimiter = mapping.delimiter;
      _decimal = mapping.decimalConvention;
      _policy = mapping.duplicatePolicy;
      _matchField = mapping.matchField;
      if (mapping.articlePriceBasis != null) _basis = mapping.articlePriceBasis!;
    });
  }

  Future<void> _saveTemplate(BuildContext context) async {
    final TextEditingController name = TextEditingController();
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(_strings(context).templateSave),
        content: TextField(
          controller: name,
          decoration: InputDecoration(labelText: _strings(context).templateNameHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(appLocalizationsOf(context).actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(name.text.trim()),
            child: Text(appLocalizationsOf(context).actionSave),
          ),
        ],
      ),
    );
    final String trimmed = (value ?? '').trim();
    name.dispose();
    if (trimmed.isEmpty || !context.mounted) return;
    try {
      final MasterDataCsvImportService service = _service(context, ref);
      await service.templates.save(name: trimmed, mapping: _currentMapping(), id: _templateId);
      await _loadTemplates();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _buildPreview() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final MasterDataCsvImportService service = _service(context, ref);
      final MasterDataImportPreview preview = await service.buildPreview(_parsed!, _currentMapping());
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _selections = <int, MasterDataRowSelection>{
          for (final MasterDataRowPreview r in preview.rows) r.sourceRowNumber: _initialSelection(r),
        };
        _previewPage = 1;
        _step = 2;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  MasterDataRowSelection _initialSelection(MasterDataRowPreview row) {
    switch (row.proposedAction) {
      case MasterDataRowAction.create:
        return MasterDataRowSelection.create;
      case MasterDataRowAction.skip:
        return MasterDataRowSelection.skip;
      case MasterDataRowAction.update:
      case MasterDataRowAction.invalid:
      case MasterDataRowAction.ambiguous:
        return MasterDataRowSelection.excluded;
    }
  }

  // -- Step 3: review ---------------------------------------------------------

  Widget _reviewStep(BuildContext context, _CsvImportStrings s, AppLocalizations l10n) {
    final MasterDataImportPreview? preview = _preview;
    if (preview == null) return const SizedBox.shrink();
    const int pageSize = 25;
    final int pageCount = preview.rows.isEmpty ? 1 : ((preview.rows.length - 1) ~/ pageSize) + 1;
    final int page = _previewPage.clamp(1, pageCount);
    final List<MasterDataRowPreview> visible = preview.rows.skip((page - 1) * pageSize).take(pageSize).toList();
    return Column(
      children: <Widget>[
        AppCard(
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${s.counts}: ${preview.validCount} ${s.statusValid} · ${preview.invalidCount} ${s.statusInvalid} · '
              '${preview.createCount} ${s.statusCreate} · ${preview.updateCount} ${s.statusUpdate} · '
              '${preview.skipCount} ${s.statusSkip}',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 48),
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Zeile')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Aktion')),
                ],
                rows: <DataRow>[
                  for (final MasterDataRowPreview row in visible)
                    DataRow(
                      cells: <DataCell>[
                        DataCell(Text('${row.sourceRowNumber}')),
                        DataCell(
                          Semantics(
                            label: 'Zeile ${row.sourceRowNumber}: ${_statusText(row, s)}',
                            child: ExcludeSemantics(
                              child: Text(
                                _statusText(row, s),
                                style: TextStyle(
                                  color: row.isValid
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DataCell(_rowActionCell(row, s)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: l10n.filterPreviousPage,
              onPressed: page > 1 ? () => setState(() => _previewPage = page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(l10n.filterPageCount(page, pageCount)),
            IconButton(
              tooltip: l10n.filterNextPage,
              onPressed: page < pageCount ? () => setState(() => _previewPage = page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        // Row error details stay in text form below the paginated table.
        for (final MasterDataRowPreview row in visible)
          if (row.errors.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Zeile ${row.sourceRowNumber}: ${row.errors.map((MasterDataFieldError e) => Localizations.localeOf(context).languageCode == 'en' ? e.messageEn : e.messageDe).join('; ')}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            OutlinedButton(onPressed: () => setState(() => _step = 1), child: Text(s.actionBack)),
            const SizedBox(width: AppSpacing.md),
            OutlinedButton(onPressed: () => setState(() => _step = 0), child: Text(s.actionCancel)),
            const Spacer(),
            FilledButton.icon(
              onPressed: _working ? null : () => unawaited(_confirmAndCommit(context)),
              icon: const Icon(Icons.check),
              label: Text(s.actionConfirm),
            ),
          ],
        ),
      ],
    );
  }

  String _statusText(MasterDataRowPreview row, _CsvImportStrings s) {
    final String base = switch (row.proposedAction) {
      MasterDataRowAction.create => s.statusCreate,
      MasterDataRowAction.update => s.statusUpdate,
      MasterDataRowAction.skip => s.statusSkip,
      MasterDataRowAction.invalid => s.statusInvalid,
      MasterDataRowAction.ambiguous => s.statusAmbiguous,
    };
    if (row.isDuplicateLabelled && row.proposedAction == MasterDataRowAction.create) {
      return '$base · ${s.statusDuplicate}';
    }
    return base;
  }

  Widget _rowActionCell(MasterDataRowPreview row, _CsvImportStrings s) {
    if (row.proposedAction == MasterDataRowAction.update) {
      final bool selected = _selections[row.sourceRowNumber] == MasterDataRowSelection.update;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Checkbox(
            value: selected,
            onChanged: (bool? v) => setState(() {
              _selections[row.sourceRowNumber] = v == true
                  ? MasterDataRowSelection.update
                  : MasterDataRowSelection.excluded;
            }),
          ),
          Text(s.selectUpdate),
        ],
      );
    }
    if (row.proposedAction == MasterDataRowAction.create && row.isDuplicateLabelled) {
      return Text(s.statusDuplicate);
    }
    return Text(_statusText(row, s));
  }

  Future<void> _confirmAndCommit(BuildContext context) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final _CsvImportStrings s = _strings(context);
    final MasterDataImportPreview preview = _preview!;
    final int creates = _selections.values
        .where((MasterDataRowSelection v) => v == MasterDataRowSelection.create)
        .length;
    final int updates = _selections.values
        .where((MasterDataRowSelection v) => v == MasterDataRowSelection.update)
        .length;
    final int skips = preview.skipCount;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(s.actionConfirm),
        content: Text('$creates ${s.statusCreate} · $updates ${s.statusUpdate} · $skips ${s.statusSkip}'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionConfirm)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final MasterDataCsvImportService service = _service(context, ref);
      final MasterDataReviewedBatch batch = MasterDataReviewedBatch(
        preview: preview,
        selections: Map<int, MasterDataRowSelection>.from(_selections),
      );
      final MasterDataImportResult result = await service.commit(batch, _currentMapping());
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = 3;
        if (result.isFailure) _error = MasterDataCsvImportException(result.failureMessage ?? '');
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // -- Step 4: result -----------------------------------------------------------

  Widget _resultStep(BuildContext context, _CsvImportStrings s, AppLocalizations l10n) {
    final MasterDataImportResult? result = _result;
    if (result == null) return const SizedBox.shrink();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              result.isFailure
                  ? (result.failureMessage ?? l10n.workspaceUnavailable)
                  : 'Erstellt: ${result.created} · Aktualisiert: ${result.updated} · '
                        'Übersprungen: ${result.skipped} · Fehler: ${result.invalid}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(s.actionBack)),
              const Spacer(),
              if (result.isFailure)
                FilledButton.icon(
                  onPressed: () => setState(() => _step = 2),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.actionRetry),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the import workflow from an owning workspace without adding a
/// canonical route; the list query state stays intact on return.
Future<void> openMasterDataCsvImport(BuildContext context, MasterDataImportEntity entity) {
  return Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (BuildContext context) => MasterDataCsvImportView(entity: entity)));
}
