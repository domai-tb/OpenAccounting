import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

/// Provider for the existing bank-import service, scoped to the active database.
final bankImportServiceProvider = Provider<BankImportService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BankImportService(db.executor);
});

/// Optional file reader seam for widget tests and desktop integrations.
typedef BankImportFileReader = Future<List<int>> Function(String path);

const int _maxImportFileBytes = 20 * 1024 * 1024;

enum _BankImportView { import, history }

enum _BankImportStage { upload, review, result }

/// Production banking surface: file input, template choice, review, import,
/// recovery, and auditable history.
class BankImportPage extends ConsumerStatefulWidget {
  const BankImportPage({
    this.service,
    this.fileReader,
    this.initialContent,
    this.initialFileName = 'import.csv',
    this.initialTemplate,
    super.key,
  });

  /// Optional service injection keeps the page easy to exercise in isolation.
  final BankImportService? service;

  /// Optional reader used by desktop integrations or widget tests.
  final BankImportFileReader? fileReader;

  /// Optional in-memory input, useful for opening a known file from an OS association.
  final String? initialContent;

  final String initialFileName;

  /// Optional template preselection for deep links and integrations that know the source format.
  final BankTemplate? initialTemplate;

  @override
  ConsumerState<BankImportPage> createState() => _BankImportPageState();
}

class _BankImportPageState extends ConsumerState<BankImportPage> {
  late final TextEditingController _pathController;

  final List<BankTemplate> _templates = <BankTemplate>[];
  final List<_BankAccountOption> _accounts = <_BankAccountOption>[];
  final List<_BankCategoryOption> _categories = <_BankCategoryOption>[];
  final List<_EditableBankRow> _rows = <_EditableBankRow>[];
  final List<_HistoryEntry> _rejectedAttempts = <_HistoryEntry>[];
  final Map<int, _ImportOutcome> _outcomesByImportId = <int, _ImportOutcome>{};

  List<_HistoryEntry> _history = <_HistoryEntry>[];
  BankTemplate? _selectedTemplate;
  int? _selectedAccountId;
  List<int>? _fileBytes;
  String? _fileName;
  String? _errorMessage;
  String? _noticeMessage;
  String? _historyError;
  _ImportOutcome? _outcome;
  _BankImportView _view = _BankImportView.import;
  _BankImportStage _stage = _BankImportStage.upload;
  bool _isLoading = true;
  bool _historyLoading = false;
  bool _isBusy = false;
  bool _allowDuplicateOverride = false;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  BankImportService get _service => widget.service ?? ref.read(bankImportServiceProvider);

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
    _selectedTemplate = widget.initialTemplate;
    final String? initialContent = widget.initialContent;
    if (initialContent != null) {
      _fileName = widget.initialFileName;
      _fileBytes = utf8.encode(initialContent);
      _pathController.text = widget.initialFileName;
    }
    unawaited(_loadPageData());
  }

  @override
  void dispose() {
    _pathController.dispose();
    _disposeRows();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    String? dataError;
    List<BankTemplate> templates = <BankTemplate>[];
    List<Map<String, Object?>> accountRows = <Map<String, Object?>>[];
    List<Map<String, Object?>> categoryRows = <Map<String, Object?>>[];

    try {
      templates = await _service.loadTemplates();
    } catch (error, stackTrace) {
      debugPrint('bank_import templates failed: $error\n$stackTrace');
      dataError = 'Bank-Templates konnten nicht geladen werden.';
    }

    try {
      accountRows = await _db.executor.runSelect(
        'SELECT id, name, iban, waehrung FROM konten ORDER BY name, id',
        const <Object?>[],
      );
    } catch (error, stackTrace) {
      debugPrint('bank_import accounts failed: $error\n$stackTrace');
      dataError = 'Bankkonten konnten nicht geladen werden. Prüfe die Datenbank und versuche es erneut.';
    }

    try {
      categoryRows = await _db.executor.runSelect(
        'SELECT id, bezeichnung FROM kategorien WHERE aktiv = 1 ORDER BY bezeichnung, id',
        const <Object?>[],
      );
    } catch (error, stackTrace) {
      debugPrint('bank_import categories failed: $error\n$stackTrace');
      dataError ??= 'Kategorien konnten nicht geladen werden. Manuelle Kategorisierung ist derzeit nicht verfügbar.';
    }

    final List<_HistoryEntry> history = await _readHistory();
    if (!mounted) return;
    final String? initialTemplateType = widget.initialTemplate?.typ;
    final BankTemplate? resolvedTemplate = initialTemplateType == null
        ? _selectedTemplate
        : templates.cast<BankTemplate?>().firstWhere(
            (BankTemplate? template) => template?.typ == initialTemplateType,
            orElse: () => _selectedTemplate,
          );

    setState(() {
      _templates
        ..clear()
        ..addAll(templates);
      _accounts
        ..clear()
        ..addAll(accountRows.map(_BankAccountOption.fromRow));
      _categories
        ..clear()
        ..addAll(categoryRows.map(_BankCategoryOption.fromRow));
      _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;
      _selectedTemplate = resolvedTemplate;
      _history = history;
      _historyError = null;
      _errorMessage = dataError;
      _isLoading = false;
    });
  }

  Future<void> _refreshHistory() async {
    if (_historyLoading) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    final List<_HistoryEntry> history = await _readHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _historyLoading = false;
    });
  }

  Future<List<_HistoryEntry>> _readHistory() async {
    try {
      late final List<Map<String, Object?>> rows;
      try {
        rows = await _db.executor.runSelect('''
SELECT bi.id, bi.dateiname, bi.datum, bi.anzahl_transaktionen, bi.duplikate,
       bi.template_typ, bi.anzahl_importiert, bi.anzahl_auto_kategorisiert,
       bi.anzahl_manuelle_pruefung, bi.anzahl_fehlgeschlagen, bi.fehler_details,
       bi.status, k.name AS konto_name, COUNT(bt.id) AS persisted_count
FROM bank_imports bi
LEFT JOIN konten k ON k.id = bi.konto_id
LEFT JOIN bank_transaktionen bt ON bt.import_id = bi.id
GROUP BY bi.id
ORDER BY bi.id DESC
LIMIT 100
''', const <Object?>[]);
      } catch (error) {
        debugPrint('bank_import extended history query unavailable: $error');
        rows = await _db.executor.runSelect('''
SELECT bi.id, bi.dateiname, bi.datum, bi.anzahl_transaktionen, bi.duplikate,
       bi.template_typ, bi.status, k.name AS konto_name, COUNT(bt.id) AS persisted_count
FROM bank_imports bi
LEFT JOIN konten k ON k.id = bi.konto_id
LEFT JOIN bank_transaktionen bt ON bt.import_id = bi.id
GROUP BY bi.id
ORDER BY bi.id DESC
LIMIT 100
''', const <Object?>[]);
      }
      final List<_HistoryEntry> entries = rows
          .map(
            (Map<String, Object?> row) => _HistoryEntry.fromRow(row, outcome: _outcomesByImportId[_asInt(row['id'])]),
          )
          .toList();
      entries.addAll(_rejectedAttempts);
      entries.sort((_HistoryEntry a, _HistoryEntry b) => b.date.compareTo(a.date));
      return entries;
    } catch (error, stackTrace) {
      debugPrint('bank_import history failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _historyError = 'Importverlauf konnte nicht geladen werden.';
        });
      }
      return List<_HistoryEntry>.from(_rejectedAttempts);
    }
  }

  Future<void> _loadFileFromPath() async {
    final String path = _pathController.text.trim();
    if (path.isEmpty) {
      _showError('Gib einen Dateipfad ein oder füge CSV-Daten ein.');
      return;
    }

    final String fileName = _baseName(path);
    if (!_isSupportedFileName(fileName)) {
      await _rejectInput(
        fileName,
        'Dieses Dateiformat wird nicht unterstützt. Unterstützt werden CSV und CAMT.053 XML.',
      );
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      final BankImportFileReader reader = widget.fileReader ?? _readLocalFile;
      final List<int> bytes = await reader(path);
      await _acceptFile(fileName, bytes);
    } on FileSystemException catch (error) {
      await _rejectInput(fileName, 'Die Datei konnte nicht gelesen werden: ${error.message}');
    } catch (error) {
      await _rejectInput(fileName, 'Die Datei konnte nicht gelesen werden: ${_safeError(error)}');
    }
  }

  Future<List<int>> _readLocalFile(String path) => File(path).readAsBytes();

  Future<void> _acceptFile(String fileName, List<int> bytes) async {
    if (bytes.length > _maxImportFileBytes) {
      await _rejectInput(
        fileName,
        'Die Datei ist größer als 20 MB. Exportiere einen kleineren Zeitraum und versuche es erneut.',
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _fileName = fileName;
      _fileBytes = List<int>.unmodifiable(bytes);
      _pathController.text = fileName;
      _stage = _BankImportStage.upload;
      _outcome = null;
      _isBusy = false;
      _errorMessage = null;
      _noticeMessage = 'Datei bereit. Wähle das passende Template und öffne danach die Vorschau.';
    });
  }

  Future<void> _pasteCsv() async {
    final TextEditingController controller = TextEditingController();
    final String? content = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('CSV-Daten einfügen'),
          content: SizedBox(
            width: 700,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 8,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'CSV-Inhalt',
                hintText: 'Datum;Betrag;Verwendungszweck;Partner',
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || content == null) return;
    if (content.trim().isEmpty) {
      _showError('Es wurden keine CSV-Daten eingefügt.');
      return;
    }
    await _acceptFile('eingefügter-import.csv', utf8.encode(content));
  }

  Future<void> _parseLoadedFile() async {
    final List<int>? bytes = _fileBytes;
    final String? fileName = _fileName;
    if (bytes == null || fileName == null) {
      _showError('Lade zuerst eine CSV- oder CAMT.053-Datei.');
      return;
    }
    if (!_isCamtFile(fileName) && _selectedTemplate == null) {
      _showError('Wähle vor der Vorschau ein Bank-Template aus.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _noticeMessage = null;
    });

    try {
      final String content = _decodeBytes(bytes, _selectedTemplate);
      final List<RawTx> parsed = _isCamtFile(fileName)
          ? _service.parseCamtXml(content)
          : _service.parseCsv(csv: content, template: _selectedTemplate);
      if (parsed.isEmpty) {
        throw const BankImportException('Keine Transaktionen gefunden.');
      }
      _disposeRows();
      _rows.addAll(
        parsed.asMap().entries.map(
          (MapEntry<int, RawTx> entry) => _EditableBankRow(lineNumber: entry.key + 2, source: entry.value),
        ),
      );
      if (!mounted) return;
      setState(() {
        _stage = _BankImportStage.review;
        _isBusy = false;
        _errorMessage = null;
        _noticeMessage = 'Vorschau geöffnet. Noch keine Transaktion wurde gespeichert.';
      });
    } on BankImportException catch (error) {
      await _rejectInput(fileName, error.message, recoveryAction: error.recoveryAction);
    } catch (error) {
      await _rejectInput(fileName, 'Die Datei konnte nicht verarbeitet werden: ${_safeError(error)}');
    }
  }

  Future<void> _confirmImport() async {
    final int selectedCount = _rows.where((_EditableBankRow row) => row.included).length;
    if (selectedCount == 0) {
      _showError('Wähle mindestens eine Zeile für den Import aus.');
      return;
    }
    if (_selectedAccountId == null) {
      _showError('Wähle ein Bankkonto aus, bevor du importierst.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Import bestätigen'),
          content: Text(
            '$selectedCount ausgewählte Zeile${selectedCount == 1 ? '' : 'n'} werden in '
            '$_selectedAccountName importiert. Duplikate werden standardmäßig übersprungen.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Zurück zur Prüfung'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import bestätigen'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    await _importRows();
  }

  Future<void> _importRows() async {
    if (_isBusy || _selectedAccountId == null) return;
    final List<_EditableBankRow> selectedRows = _rows.where((_EditableBankRow row) => row.included).toList();
    final List<_PreparedBankRow> preparedRows = <_PreparedBankRow>[];
    try {
      for (final _EditableBankRow row in selectedRows) {
        preparedRows.add(_PreparedBankRow(row: row, raw: row.toRawTx()));
      }
    } on BankImportException catch (error) {
      _showError(error.message);
      return;
    }

    final int kontoId = _selectedAccountId!;
    final String fileName = _fileName ?? 'import.csv';
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _noticeMessage = 'Import wird verarbeitet …';
    });

    try {
      final ImportResult serviceResult = await _service.importTransactions(
        kontoId: kontoId,
        rawTxs: preparedRows.map((_PreparedBankRow item) => item.raw).toList(),
        allowDuplicateOverride: _allowDuplicateOverride,
        dateiname: fileName,
        template: _selectedTemplate,
      );
      final List<_FailedEditableRow> failedRows = _mapFailedRows(preparedRows, serviceResult.failedRows);
      final int categorized = await _loadCategorizedCount(serviceResult.importId);
      final String? detail = serviceResult.diagnostics.isEmpty ? null : serviceResult.diagnostics.join('\n');
      final _ImportOutcome outcome = _ImportOutcome(
        imported: serviceResult.imported,
        duplicates: serviceResult.duplicatesSkipped,
        categorized: categorized,
        failed: serviceResult.failed,
        failedRows: failedRows,
        importId: serviceResult.importId,
        status: _historyStatus(serviceResult.status),
        detail: detail,
      );
      if (serviceResult.importId != null) {
        _outcomesByImportId[serviceResult.importId!] = outcome;
      }
      final List<_HistoryEntry> history = await _readHistory();
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _history = history;
        _stage = _BankImportStage.result;
        _isBusy = false;
        _errorMessage = null;
        _noticeMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('bank_import import failed: $error\n$stackTrace');
      final _ImportOutcome outcome = _ImportOutcome(
        imported: 0,
        duplicates: 0,
        categorized: 0,
        failed: preparedRows.length,
        failedRows: selectedRows
            .map((_EditableBankRow row) => _FailedEditableRow(row: row, error: _safeError(error)))
            .toList(),
        status: 'fehlgeschlagen',
        detail: 'Der Import wurde nicht vollständig abgeschlossen: ${_safeError(error)}',
      );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _stage = _BankImportStage.result;
        _isBusy = false;
        _errorMessage = null;
        _noticeMessage = null;
      });
    }
  }

  Future<int> _loadCategorizedCount(int? importId) async {
    if (importId == null) return 0;
    try {
      final List<Map<String, Object?>> rows = await _db.executor.runSelect(
        'SELECT COUNT(*) AS count FROM bank_transaktionen WHERE import_id = ? AND kategorie_id IS NOT NULL',
        <Object?>[importId],
      );
      return rows.isEmpty ? 0 : (_asInt(rows.first['count']) ?? 0);
    } catch (error, stackTrace) {
      debugPrint('bank_import category count failed: $error\n$stackTrace');
      return 0;
    }
  }

  List<_FailedEditableRow> _mapFailedRows(List<_PreparedBankRow> preparedRows, List<ImportRowFailure> failures) {
    final List<_FailedEditableRow> mapped = <_FailedEditableRow>[];
    for (final ImportRowFailure failure in failures) {
      final int index = failure.rowNumber - 1;
      if (index >= 0 && index < preparedRows.length) {
        mapped.add(_FailedEditableRow(row: preparedRows[index].row, error: failure.error));
      }
    }
    return mapped;
  }

  Future<void> _retryFailedRows() async {
    final _ImportOutcome? outcome = _outcome;
    if (outcome == null || outcome.failed == 0) return;
    final List<_EditableBankRow> retryRows = outcome.failedRows.isEmpty
        ? List<_EditableBankRow>.from(_rows)
        : outcome.failedRows.map((_FailedEditableRow failure) => failure.row).toList();
    _disposeRowsExcept(retryRows);
    setState(() {
      _rows
        ..clear()
        ..addAll(retryRows);
      _stage = _BankImportStage.review;
      _outcome = null;
      _allowDuplicateOverride = false;
      _errorMessage = null;
      _noticeMessage =
          'Nur die nicht gespeicherten Zeilen werden erneut geprüft. Bereits importierte Zeilen bleiben dedupliziert.';
    });
  }

  Future<void> _rejectInput(String fileName, String reason, {String? recoveryAction}) async {
    final String diagnostic = recoveryAction == null ? reason : '$reason $recoveryAction';
    await _recordRejectedAttempt(fileName, diagnostic);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _stage = _BankImportStage.upload;
      _outcome = null;
      _errorMessage = 'Import abgebrochen: $diagnostic Keine Transaktion wurde gespeichert.';
      _noticeMessage = 'Korrigiere die Datei oder wähle ein passendes Template und versuche es erneut.';
    });
  }

  Future<void> _recordRejectedAttempt(String fileName, String reason) async {
    final DateTime now = DateTime.now();
    int? historyId;
    if (_selectedAccountId != null) {
      try {
        final ImportResult result = await _service.recordRejectedImport(
          kontoId: _selectedAccountId!,
          diagnostic: reason,
          dateiname: fileName,
          template: _selectedTemplate,
        );
        historyId = result.importId;
      } catch (error, stackTrace) {
        debugPrint('bank_import rejected history service failed: $error\n$stackTrace');
      }
    }

    if (historyId == null) {
      try {
        historyId = await _db.executor.runInsert(
          'INSERT INTO bank_imports (konto_id, dateiname, datum, anzahl_transaktionen, duplikate, template_typ, '
          'anzahl_importiert, anzahl_fehlgeschlagen, fehler_details, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            _selectedAccountId,
            fileName,
            now.toIso8601String(),
            0,
            0,
            _selectedTemplate?.typ,
            0,
            0,
            reason,
            'fehlgeschlagen',
          ],
        );
      } catch (firstError) {
        debugPrint('bank_import rejected history extended insert failed: $firstError');
        try {
          historyId = await _db.executor.runInsert(
            'INSERT INTO bank_imports (konto_id, dateiname, datum, anzahl_transaktionen, status) VALUES (?, ?, ?, ?, ?)',
            <Object?>[_selectedAccountId, fileName, now.toIso8601String(), 0, 'fehlgeschlagen'],
          );
        } catch (fallbackError) {
          debugPrint('bank_import rejected history fallback failed: $fallbackError');
        }
      }
    }

    if (historyId != null && mounted) {
      final List<_HistoryEntry> history = await _readHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
      });
      return;
    }

    final _HistoryEntry entry = _HistoryEntry(
      id: null,
      fileName: fileName,
      date: now,
      template: _selectedTemplate?.name ?? '—',
      account: _selectedAccountName,
      imported: 0,
      duplicates: 0,
      failed: 0,
      status: 'Abgelehnt',
      detail: reason,
    );
    if (!mounted) return;
    setState(() {
      _rejectedAttempts.insert(0, entry);
      _history = <_HistoryEntry>[entry, ..._history];
    });
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _noticeMessage = null;
    });
  }

  void _startOver() {
    _disposeRows();
    setState(() {
      _rows.clear();
      _fileBytes = null;
      _fileName = null;
      _pathController.clear();
      _selectedTemplate = null;
      _stage = _BankImportStage.upload;
      _outcome = null;
      _allowDuplicateOverride = false;
      _errorMessage = null;
      _noticeMessage = null;
    });
  }

  void _disposeRows() {
    for (final _EditableBankRow row in _rows) {
      row.dispose();
    }
    _rows.clear();
  }

  void _disposeRowsExcept(List<_EditableBankRow> keep) {
    final Set<_EditableBankRow> keepSet = keep.toSet();
    for (final _EditableBankRow row in _rows) {
      if (!keepSet.contains(row)) row.dispose();
    }
  }

  Widget _buildImportView() {
    final Widget workflow = switch (_stage) {
      _BankImportStage.upload => _buildUploadStep(),
      _BankImportStage.review => _buildReviewStep(),
      _BankImportStage.result => _buildResultStep(),
    };
    return ListView(
      key: const ValueKey<String>('bank-import-workflow'),
      children: <Widget>[
        _buildStageIndicator(),
        if (_errorMessage != null) _buildMessage(_errorMessage!, isError: true),
        if (_errorMessage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _startOver,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut versuchen'),
            ),
          ),
        if (_noticeMessage != null) _buildMessage(_noticeMessage!, isError: false),
        const SizedBox(height: AppSpacing.lg),
        workflow,
      ],
    );
  }

  Widget _buildUploadStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionCard(
          title: '1. Datei auswählen',
          icon: Icons.upload_file,
          children: <Widget>[
            const Text(
              'Unterstützt werden CSV-Dateien und CAMT.053 XML-Exporte. Die Vorschau schreibt noch nichts in die Datenbank.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _pathController,
              enabled: !_isBusy,
              decoration: const InputDecoration(
                labelText: 'Dateipfad',
                hintText: '/Pfad/zum/Kontoauszug.csv',
                prefixIcon: Icon(Icons.folder_open),
              ),
              onSubmitted: (_) => unawaited(_loadFileFromPath()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isBusy ? null : () => unawaited(_loadFileFromPath()),
                  icon: const Icon(Icons.file_open),
                  label: const Text('Datei auswählen'),
                ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : () => unawaited(_pasteCsv()),
                  icon: const Icon(Icons.content_paste),
                  label: const Text('CSV einfügen'),
                ),
              ],
            ),
            if (_fileBytes != null && _fileName != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _buildFileSummary(),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildSectionCard(
          title: '2. Konto und Template',
          icon: Icons.tune,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth < 760 ? constraints.maxWidth : 360;
                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: <Widget>[
                    SizedBox(width: width, child: _buildAccountDropdown()),
                    if (!_isCamtFile(_fileName)) SizedBox(width: width, child: _buildTemplateDropdown()),
                  ],
                );
              },
            ),
            if (_accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'Noch kein Bankkonto vorhanden. Lege zuerst ein Konto in den Stammdaten an; ein Import ohne Konto ist gesperrt.',
                ),
              ),
            if (_isCamtFile(_fileName))
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: Text(
                  'CAMT.053 wird anhand der XML-Struktur erkannt; ein CSV-Template ist dafür nicht erforderlich.',
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _isBusy || _fileBytes == null ? null : () => unawaited(_parseLoadedFile()),
                icon: const Icon(Icons.preview),
                label: const Text('Vorschau'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final int selectedCount = _rows.where((_EditableBankRow row) => row.included).length;
    final int manualCategoryCount = _rows
        .where((_EditableBankRow row) => row.included && row.categoryId != null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionCard(
          title: '3. Vorschau prüfen und bearbeiten',
          icon: Icons.fact_check,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('${_rows.length} Zeilen erkannt'),
                Text('$selectedCount ausgewählt'),
                Text('$manualCategoryCount manuell kategorisiert'),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _startOver,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Andere Datei'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Änderungen und manuelle Kategorien werden erst nach deiner ausdrücklichen Importbestätigung gespeichert.',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Checkbox(
                  value: _allowDuplicateOverride,
                  onChanged: _isBusy ? null : (bool? value) => setState(() => _allowDuplicateOverride = value ?? false),
                ),
                const Expanded(child: Text('Bereits importierte Duplikate erneut übernehmen (nur bewusst aktivieren)')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildReviewTable(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isBusy ? null : () => unawaited(_confirmImport()),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text('Import bestätigen ($selectedCount)'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewTable() {
    if (_rows.isEmpty) {
      return const Text('Keine Zeilen zur Prüfung vorhanden.');
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 520),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: AppSpacing.lg,
            dataRowMinHeight: 112,
            dataRowMaxHeight: 128,
            headingRowHeight: 48,
            columns: const <DataColumn>[
              DataColumn(label: Text('Import')),
              DataColumn(label: Text('Datum')),
              DataColumn(label: Text('Betrag')),
              DataColumn(label: Text('Partner / Zweck')),
              DataColumn(label: Text('Kategorie')),
            ],
            rows: _rows.map(_buildReviewRow).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildReviewRow(_EditableBankRow row) {
    return DataRow(
      cells: <DataCell>[
        DataCell(
          Checkbox(
            value: row.included,
            onChanged: _isBusy ? null : (bool? value) => setState(() => row.included = value ?? false),
          ),
        ),
        DataCell(
          SizedBox(
            width: 112,
            child: TextField(
              controller: row.dateController,
              enabled: !_isBusy,
              decoration: InputDecoration(labelText: 'Zeile ${row.lineNumber}'),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 108,
            child: TextField(
              controller: row.amountController,
              enabled: !_isBusy,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(suffixText: '€'),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 320,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextField(
                  controller: row.partnerController,
                  enabled: !_isBusy,
                  decoration: const InputDecoration(labelText: 'Partner'),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: row.purposeController,
                  enabled: !_isBusy,
                  decoration: const InputDecoration(labelText: 'Verwendungszweck'),
                ),
              ],
            ),
          ),
        ),
        DataCell(_buildCategoryDropdown(row)),
      ],
    );
  }

  Widget _buildCategoryDropdown(_EditableBankRow row) {
    if (_categories.isEmpty) {
      return const Text('Keine Kategorien');
    }
    final int selectedValue = row.categoryId ?? 0;
    return DropdownButton<int>(
      value: selectedValue,
      isDense: true,
      hint: const Text('Manuell prüfen'),
      items: <DropdownMenuItem<int>>[
        const DropdownMenuItem<int>(value: 0, child: Text('Manuell prüfen')),
        ..._categories.map(
          (_BankCategoryOption category) => DropdownMenuItem<int>(
            value: category.id,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(category.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ],
      onChanged: _isBusy
          ? null
          : (int? value) => setState(() => row.categoryId = value == null || value == 0 ? null : value),
    );
  }

  Widget _buildResultStep() {
    final _ImportOutcome? outcome = _outcome;
    if (outcome == null) return const SizedBox.shrink();
    final bool hasFailure = outcome.failed > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSectionCard(
          title: '4. Importergebnis',
          icon: hasFailure ? Icons.warning_amber : Icons.check_circle,
          children: <Widget>[
            AppStatusChip(status: hasFailure ? AppStatus.warning : AppStatus.paid, label: outcome.status),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _buildResultStat('Importiert', outcome.imported, Icons.save_alt),
                _buildResultStat('Duplikate übersprungen', outcome.duplicates, Icons.copy_all),
                _buildResultStat('Kategorisiert', outcome.categorized, Icons.label_outline),
                _buildResultStat('Manuelle Prüfung', outcome.manualReview, Icons.rate_review),
                _buildResultStat('Fehlgeschlagen', outcome.failed, Icons.error_outline),
              ],
            ),
            if (outcome.detail != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _buildMessage(outcome.detail!, isError: hasFailure),
            ],
            if (hasFailure) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _buildFailureRows(outcome.failedRows),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.lg),
                child: Text(
                  'Alle bestätigten neuen Zeilen wurden gespeichert. Der Import ist im Verlauf dokumentiert.',
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: <Widget>[
                if (hasFailure)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : () => unawaited(_retryFailedRows()),
                    icon: const Icon(Icons.replay),
                    label: const Text('Fehlgeschlagene Zeilen erneut prüfen'),
                  ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _startOver,
                  icon: const Icon(Icons.add),
                  label: const Text('Neuen Import starten'),
                ),
                FilledButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () => setState(() {
                          _view = _BankImportView.history;
                          _historyError = null;
                        }),
                  icon: const Icon(Icons.history),
                  label: const Text('Zum Importverlauf'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFailureRows(List<_FailedEditableRow> rows) {
    if (rows.isEmpty) {
      return const Text(
        'Die Datenbank meldete nicht gespeicherte Zeilen, konnte aber keinen einzelnen Zeilenfehler zurückgeben. Prüfe Konto, Datum und Betrag; ein erneuter Versuch bleibt dedupliziert.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Nicht gespeichert — bitte korrigieren und erneut prüfen:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...rows.map(
          (_FailedEditableRow failure) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              'Zeile ${failure.row.lineNumber}: ${failure.error} · '
              '${failure.row.partnerController.text.trim().isEmpty ? 'ohne Partner' : failure.row.partnerController.text.trim()} · '
              '${failure.row.amountController.text.trim()} € · '
              '${failure.row.purposeController.text.trim().isEmpty ? 'ohne Verwendungszweck' : failure.row.purposeController.text.trim()}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    return ListView(
      key: const ValueKey<String>('bank-import-history'),
      children: <Widget>[
        _buildSectionCard(
          title: 'Importverlauf',
          icon: Icons.history,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('Quelle, Template, Mengen und Ergebnisstatus bleiben hier nachvollziehbar.'),
                ),
                IconButton(
                  tooltip: 'Importverlauf aktualisieren',
                  onPressed: _historyLoading ? null : () => unawaited(_refreshHistory()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_historyError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _buildMessage(_historyError!, isError: true),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_historyLoading)
              const Center(child: CircularProgressIndicator())
            else if (_history.isEmpty)
              const Text('Noch keine Importe vorhanden.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: AppSpacing.lg,
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Zeitpunkt')),
                    DataColumn(label: Text('Quelle')),
                    DataColumn(label: Text('Template')),
                    DataColumn(label: Text('Konto')),
                    DataColumn(label: Text('Importiert')),
                    DataColumn(label: Text('Duplikate')),
                    DataColumn(label: Text('Fehler')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _history.map(_buildHistoryRow).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  DataRow _buildHistoryRow(_HistoryEntry entry) {
    final Color statusColor = entry.failed > 0
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(_formatDateTime(entry.date))),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Tooltip(
              message: entry.fileName,
              child: Text(entry.fileName, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
        DataCell(Text(entry.template)),
        DataCell(Text(entry.account)),
        DataCell(Text('${entry.imported}')),
        DataCell(Text('${entry.duplicates}')),
        DataCell(Text('${entry.failed}', style: TextStyle(color: entry.failed > 0 ? statusColor : null))),
        DataCell(
          Tooltip(
            message: entry.detail ?? entry.status,
            child: Text(
              entry.status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageIndicator() {
    final List<_StageDescriptor> stages = <_StageDescriptor>[
      (label: 'Datei', icon: Icons.upload_file, stage: _BankImportStage.upload),
      (label: 'Prüfen', icon: Icons.fact_check, stage: _BankImportStage.review),
      (label: 'Ergebnis', icon: Icons.task_alt, stage: _BankImportStage.result),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Wrap(spacing: AppSpacing.xl, runSpacing: AppSpacing.sm, children: stages.map(_buildStageItem).toList()),
    );
  }

  Widget _buildStageItem(_StageDescriptor stage) {
    final bool active = _stage == stage.stage;
    final bool complete = _stage.index > stage.stage.index;
    final Color color = active || complete ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor;
    return Semantics(
      label:
          '${stage.label}: ${active
              ? 'aktuell'
              : complete
              ? 'abgeschlossen'
              : 'offen'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(complete ? Icons.check_circle : stage.icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            stage.label,
            style: TextStyle(color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSummary() {
    final int bytes = _fileBytes?.length ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.description, color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Bereit: $_fileName · ${_formatBytes(bytes)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
          if (_isCamtFile(_fileName)) const Chip(label: Text('CAMT.053')) else const Chip(label: Text('CSV')),
        ],
      ),
    );
  }

  Widget _buildAccountDropdown() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _accounts.any((_BankAccountOption account) => account.id == _selectedAccountId)
          ? _selectedAccountId
          : null,
      decoration: const InputDecoration(labelText: 'Bankkonto'),
      items: _accounts
          .map(
            (_BankAccountOption account) => DropdownMenuItem<int>(
              value: account.id,
              child: Text(account.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _isBusy || _accounts.isEmpty
          ? null
          : (int? value) => setState(() {
              _selectedAccountId = value;
              _errorMessage = null;
            }),
    );
  }

  Widget _buildTemplateDropdown() {
    final String? selectedType = _selectedTemplate?.typ;
    BankTemplate? selectedTemplate;
    for (final BankTemplate template in _templates) {
      if (template.typ == selectedType) {
        selectedTemplate = template;
        break;
      }
    }
    return DropdownButtonFormField<BankTemplate>(
      isExpanded: true,
      key: ValueKey<String?>(selectedTemplate?.typ),
      initialValue: selectedTemplate,
      decoration: const InputDecoration(labelText: 'Bank-Template'),
      hint: const Text('Template auswählen'),
      items: _templates
          .map(
            (BankTemplate template) => DropdownMenuItem<BankTemplate>(
              value: template,
              child: Text('${template.name} · ${template.delimiter == ';' ? 'Semikolon' : 'Komma'}'),
            ),
          )
          .toList(),
      onChanged: _isBusy || _templates.isEmpty
          ? null
          : (BankTemplate? value) => setState(() {
              _selectedTemplate = value;
              _errorMessage = null;
            }),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    final Color color = isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    final Color foreground = isError
        ? Theme.of(context).colorScheme.onErrorContainer
        : Theme.of(context).colorScheme.onSecondaryContainer;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(isError ? Icons.error_outline : Icons.info_outline, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, int value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$value', style: Theme.of(context).textTheme.titleLarge),
              Text(label),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _view == _BankImportView.history
        ? _buildHistoryView()
        : _buildImportView();
    return AppPage(
      maxWidth: 1400,
      header: AppPageHeader(
        title: 'Bank & Zahlungen',
        subtitle: _view == _BankImportView.history
            ? 'Nachvollziehbarer Importverlauf'
            : 'Dateiimport mit Prüfung vor dem Speichern',
        showFilterToolbar: false,
        actions: <Widget>[
          TextButton.icon(
            onPressed: _isBusy
                ? null
                : () => setState(() {
                    _view = _view == _BankImportView.import ? _BankImportView.history : _BankImportView.import;
                  }),
            icon: Icon(_view == _BankImportView.import ? Icons.history : Icons.file_upload),
            label: Text(_view == _BankImportView.import ? 'Verlauf' : 'Importieren'),
          ),
        ],
      ),
      child: content,
    );
  }

  String get _selectedAccountName {
    for (final _BankAccountOption account in _accounts) {
      if (account.id == _selectedAccountId) return account.label;
    }
    return 'kein Konto';
  }
}

typedef _StageDescriptor = ({String label, IconData icon, _BankImportStage stage});

class _PreparedBankRow {
  const _PreparedBankRow({required this.row, required this.raw});

  final _EditableBankRow row;
  final RawTx raw;
}

class _EditableBankRow {
  _EditableBankRow({required this.lineNumber, required RawTx source})
    : dateController = TextEditingController(text: _formatDate(source.datum)),
      amountController = TextEditingController(text: source.betrag),
      partnerController = TextEditingController(text: source.partner),
      purposeController = TextEditingController(text: source.verwendungszweck),
      counterAccount = source.gegenkonto;

  final int lineNumber;
  final TextEditingController dateController;
  final TextEditingController amountController;
  final TextEditingController partnerController;
  final TextEditingController purposeController;
  final String? counterAccount;
  bool included = true;
  int? categoryId;

  RawTx toRawTx() {
    final DateTime date = _parseEditableDate(dateController.text, lineNumber);
    final String amount = _normaliseAmount(amountController.text, lineNumber: lineNumber);
    return RawTx(
      datum: date,
      betrag: amount,
      verwendungszweck: purposeController.text.trim(),
      partner: partnerController.text.trim(),
      gegenkonto: counterAccount,
      kategorieId: categoryId,
    );
  }

  void dispose() {
    dateController.dispose();
    amountController.dispose();
    partnerController.dispose();
    purposeController.dispose();
  }
}

class _FailedEditableRow {
  const _FailedEditableRow({required this.row, required this.error});

  final _EditableBankRow row;
  final String error;
}

class _ImportOutcome {
  _ImportOutcome({
    required this.imported,
    required this.duplicates,
    required this.categorized,
    required this.failed,
    required this.failedRows,
    required this.status,
    this.importId,
    this.detail,
  });

  final int imported;
  final int duplicates;
  final int categorized;
  final int failed;
  final List<_FailedEditableRow> failedRows;
  final String status;
  final int? importId;
  final String? detail;

  int get manualReview => (imported - categorized).clamp(0, imported);
}

class _BankAccountOption {
  const _BankAccountOption({required this.id, required this.name, this.iban, this.currency});

  factory _BankAccountOption.fromRow(Map<String, Object?> row) {
    return _BankAccountOption(
      id: _asInt(row['id']) ?? 0,
      name: _asString(row['name']).isEmpty ? 'Konto ${_asInt(row['id']) ?? ''}' : _asString(row['name']),
      iban: _asString(row['iban']).isEmpty ? null : _asString(row['iban']),
      currency: _asString(row['waehrung']).isEmpty ? null : _asString(row['waehrung']),
    );
  }

  final int id;
  final String name;
  final String? iban;
  final String? currency;

  String get label {
    final List<String> details = <String>[?iban, ?currency];
    return details.isEmpty ? name : '$name · ${details.join(' · ')}';
  }
}

class _BankCategoryOption {
  const _BankCategoryOption({required this.id, required this.name});

  factory _BankCategoryOption.fromRow(Map<String, Object?> row) {
    final int id = _asInt(row['id']) ?? 0;
    return _BankCategoryOption(
      id: id,
      name: _asString(row['bezeichnung']).isEmpty ? 'Kategorie $id' : _asString(row['bezeichnung']),
    );
  }

  final int id;
  final String name;
}

class _HistoryEntry {
  const _HistoryEntry({
    required this.id,
    required this.fileName,
    required this.date,
    required this.template,
    required this.account,
    required this.imported,
    required this.duplicates,
    required this.failed,
    required this.status,
    this.detail,
  });

  factory _HistoryEntry.fromRow(Map<String, Object?> row, {_ImportOutcome? outcome}) {
    final int imported =
        outcome?.imported ?? (_asInt(row['anzahl_importiert']) ?? _asInt(row['anzahl_transaktionen']) ?? 0);
    final int duplicates = outcome?.duplicates ?? (_asInt(row['duplikate']) ?? 0);
    final int failed = outcome?.failed ?? (_asInt(row['anzahl_fehlgeschlagen']) ?? 0);
    final String rawStatus = _asString(row['status']);
    final String? detail = outcome?.detail ?? _diagnosticText(_asString(row['fehler_details']));
    return _HistoryEntry(
      id: _asInt(row['id']),
      fileName: _asString(row['dateiname']).isEmpty ? 'Unbekannte Datei' : _asString(row['dateiname']),
      date: DateTime.tryParse(_asString(row['datum'])) ?? DateTime.now(),
      template: _asString(row['template_typ']).isEmpty ? '—' : _asString(row['template_typ']),
      account: _asString(row['konto_name']).isEmpty ? '—' : _asString(row['konto_name']),
      imported: imported,
      duplicates: duplicates,
      failed: failed,
      status: outcome?.status ?? _historyStatus(rawStatus),
      detail: detail,
    );
  }

  final int? id;
  final String fileName;
  final DateTime date;
  final String template;
  final String account;
  final int imported;
  final int duplicates;
  final int failed;
  final String status;
  final String? detail;
}

String _decodeBytes(List<int> bytes, BankTemplate? template) {
  if (template?.encoding.toLowerCase().contains('iso') ?? false) {
    return latin1.decode(bytes);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

bool _isSupportedFileName(String fileName) {
  final String lower = fileName.toLowerCase();
  return lower.endsWith('.csv') || lower.endsWith('.xml') || lower.endsWith('.camt') || lower.endsWith('.camt.053');
}

bool _isCamtFile(String? fileName) {
  final String lower = (fileName ?? '').toLowerCase();
  return lower.endsWith('.xml') || lower.endsWith('.camt') || lower.endsWith('.camt.053');
}

String _baseName(String path) {
  final List<String> pieces = path.split(RegExp(r'[/\\]'));
  return pieces.isEmpty || pieces.last.isEmpty ? path : pieces.last;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}';

String _formatDateTime(DateTime date) =>
    '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

DateTime _parseEditableDate(String raw, int lineNumber) {
  final String value = raw.trim();
  final DateTime? iso = DateTime.tryParse(value);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  final List<String> dotParts = value.split('.');
  final List<String> slashParts = value.split('/');
  final List<String> parts = dotParts.length == 3 ? dotParts : slashParts;
  if (parts.length == 3) {
    final int? day = int.tryParse(parts[0].trim());
    final int? month = int.tryParse(parts[1].trim());
    final int? year = int.tryParse(parts[2].trim());
    if (day != null && month != null && year != null && _isValidDate(year, month, day)) {
      return DateTime(year, month, day);
    }
  }
  throw BankImportException('Zeile $lineNumber: Datum ist ungültig. Verwende z. B. 15.03.2026.');
}

bool _isValidDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  final DateTime candidate = DateTime(year, month, day);
  return candidate.year == year && candidate.month == month && candidate.day == day;
}

String _normaliseAmount(String raw, {int? lineNumber}) {
  String value = raw
      .trim()
      .replaceAll('€', '')
      .replaceAll(RegExp('eur', caseSensitive: false), '')
      .replaceAll('\u00a0', '')
      .replaceAll(' ', '');
  if (value.isEmpty) {
    throw BankImportException('Zeile ${lineNumber ?? ''}: Betrag fehlt.');
  }
  final bool negative = value.startsWith('-');
  final bool positive = value.startsWith('+');
  if (negative || positive) value = value.substring(1);
  if (value.contains('.') && value.contains(',')) {
    final int dot = value.lastIndexOf('.');
    final int comma = value.lastIndexOf(',');
    value = comma > dot ? value.replaceAll('.', '').replaceAll(',', '.') : value.replaceAll(',', '');
  } else if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(value)) {
    value = value.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
    throw BankImportException('Zeile ${lineNumber ?? ''}: Betrag ist ungültig.');
  }
  final String signed = negative ? '-$value' : value;
  try {
    return money.fromCents(money.toCents(signed));
  } catch (_) {
    throw BankImportException('Zeile ${lineNumber ?? ''}: Betrag ist ungültig.');
  }
}

String _historyStatus(String raw) {
  final String lower = raw.toLowerCase();
  if (lower.startsWith('abgelehnt') || lower.startsWith('unsupported')) {
    return 'Abgelehnt';
  }
  if (lower.startsWith('teilweise') || lower.startsWith('partial')) {
    return 'Teilweise importiert';
  }
  if (lower.startsWith('fehlgeschlagen') || lower.startsWith('failed')) {
    return 'Import fehlgeschlagen';
  }
  if (lower.startsWith('importiert') || lower.startsWith('success')) {
    return 'Importiert';
  }
  return raw.isEmpty ? 'Unbekannt' : raw;
}

String? _diagnosticText(String raw) => raw.isEmpty ? null : raw;

String _safeError(Object error) {
  if (error is BankImportException) return error.message;
  final String text = error.toString();
  return text.startsWith('Exception: ') ? text.substring('Exception: '.length) : text;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _asString(Object? value) => value?.toString().trim() ?? '';
