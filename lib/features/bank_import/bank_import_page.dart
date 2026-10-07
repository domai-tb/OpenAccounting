import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/features/bank_import/banking_usecase.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_history_review_dialog.dart';
import 'package:openaccounting/features/bank_import/bank_import_mode_repository.dart';
import 'package:openaccounting/features/bank_import/bank_rules_view.dart';
import 'package:openaccounting/features/bank_import/bank_templates_view.dart';
import 'package:openaccounting/features/bank_import/bank_import_failure_payload.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_execution.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_repository.dart';
import 'package:openaccounting/features/quick_booking/quick_bookings_view.dart';

/// ponytail: German literals here are display strings for bank workflow; migrate to l10n via AppLocalizations when ARB coverage expands.
/// Locale literals for sidebar/app shell already via l10n; this page pending full centralization (minimal diff per subtask 12).
/// Provider for the existing bank-import service, scoped to the active database.
final bankImportServiceProvider = Provider<BankImportService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return BankImportService(db.executor);
});

final quickBookingRepositoryProvider = Provider<QuickBookingRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return QuickBookingRepository(db.executor);
});

/// Optional file reader seam for widget tests and desktop integrations.
typedef BankImportFileReader = Future<List<int>> Function(String path);

const int _maxImportFileBytes = 20 * 1024 * 1024;

enum _BankImportView {
  import,
  history,
  rules,
  templates,
  quickBookings;

  static _BankImportView fromQueryValue(String? value) => switch (value) {
    'history' => history,
    'rules' => rules,
    'templates' => templates,
    'quick-bookings' => quickBookings,
    _ => import,
  };

  String get queryValue => switch (this) {
    import => 'import',
    history => 'history',
    rules => 'rules',
    templates => 'templates',
    quickBookings => 'quick-bookings',
  };
}

enum _BankImportStage { upload, review, result }

/// Production banking surface: file input, template choice, review, import,
/// recovery, and auditable history.
class BankImportPage extends ConsumerStatefulWidget {
  const BankImportPage({
    this.service,
    this.useCase,
    this.fileReader,
    this.initialContent,
    this.initialFileName = 'import.csv',
    this.initialTemplate,
    this.routeUri,
    super.key,
  });

  /// Optional service injection keeps the page easy to exercise in isolation.
  final BankImportService? service;

  /// Optional typed use-case injection (AppScope otherwise, provider fallback).
  final BankingUseCase? useCase;

  /// Optional reader used by desktop integrations or widget tests.
  final BankImportFileReader? fileReader;

  /// Optional in-memory input, useful for opening a known file from an OS association.
  final String? initialContent;

  final String initialFileName;

  /// Optional template preselection for deep links and integrations that know the source format.
  final BankTemplate? initialTemplate;

  final Uri? routeUri;

  @override
  ConsumerState<BankImportPage> createState() => _BankImportPageState();
}

class _BankImportPageState extends ConsumerState<BankImportPage> {
  late final TextEditingController _pathController;

  final List<BankTemplate> _templates = <BankTemplate>[];
  final List<_BankAccountOption> _accounts = <_BankAccountOption>[];
  final List<_BankCategoryOption> _categories = <_BankCategoryOption>[];
  final List<({int id, String label})> _taxRates = <({int id, String label})>[];
  final List<_EditableBankRow> _rows = <_EditableBankRow>[];
  final List<_HistoryEntry> _rejectedAttempts = <_HistoryEntry>[];
  final Map<int, _ImportOutcome> _outcomesByImportId = <int, _ImportOutcome>{};

  List<_HistoryEntry> _history = <_HistoryEntry>[];
  String _historyQuery = '';
  int _historyPage = 1;
  static const int _historyPageSize = 50;
  BankTemplate? _selectedTemplate;
  int? _selectedAccountId;
  List<int>? _fileBytes;
  String? _fileName;
  String? _errorMessage;
  String? _pageDataError;
  String? _quickBookingOptionsError;
  String? _noticeMessage;
  String? _historyError;
  _ImportOutcome? _outcome;
  _BankImportView _view = _BankImportView.import;
  _BankImportStage _stage = _BankImportStage.upload;
  bool _isLoading = true;
  bool _historyLoading = false;
  bool _isBusy = false;
  bool _allowDuplicateOverride = false;
  BankImportMode _profileMode = BankImportMode.manual;
  bool _overrideOnceAutomatic = false;
  Map<int, _RowSuggestion> _suggestions = <int, _RowSuggestion>{};
  bool _candidatesUnavailable = false;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  AppLocalizations get _l10n => appLocalizationsOf(context);

  /// Locale tag handed to the service, mirroring [appLocalizationsOf]: an
  /// isolated embedding without the generated delegate resolves to the German
  /// catalog, so service messages match the copy rendered on this page.
  String get _activeLocale {
    final AppLocalizations? provided = AppLocalizations.of(context);
    if (provided == null) return localeTag(const Locale('de'));
    return localeTag(Localizations.localeOf(context));
  }

  BankImportService get _service => widget.service ?? ref.read(bankImportServiceProvider);

  /// Typed Banking use case: AppScope first, widget override second,
  /// provider-built fallback last.
  BankingUseCase get _banking {
    final AppScope? scope = AppScope.maybeOf(context);
    if (scope != null) return scope.services.banking;
    if (widget.useCase != null) return widget.useCase!;
    return BankingUseCase(ref.read(appDatabaseProvider).executor);
  }

  @override
  void initState() {
    super.initState();
    _view = _BankImportView.fromQueryValue(widget.routeUri?.queryParameters['view']);
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
  void didUpdateWidget(covariant BankImportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeUri != oldWidget.routeUri) {
      _view = _BankImportView.fromQueryValue(widget.routeUri?.queryParameters['view']);
    }
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
    List<Map<String, Object?>> taxRateRows = <Map<String, Object?>>[];
    String? quickBookingOptionsError;

    try {
      templates = await _service.loadTemplates();
    } catch (error, stackTrace) {
      debugPrint('bank_import templates failed: $error\n$stackTrace');
      dataError = _l10n.dataLoadError;
    }

    try {
      accountRows = await _db.executor.runSelect(
        'SELECT id, name, iban, waehrung FROM konten ORDER BY name, id',
        const <Object?>[],
      );
    } catch (error, stackTrace) {
      debugPrint('bank_import accounts failed: $error\n$stackTrace');
      dataError = _l10n.dataLoadError;
      quickBookingOptionsError = _l10n.dataLoadError;
    }

    try {
      categoryRows = await _db.executor.runSelect(
        'SELECT id, bezeichnung FROM kategorien WHERE aktiv = 1 ORDER BY bezeichnung, id',
        const <Object?>[],
      );
    } catch (error, stackTrace) {
      debugPrint('bank_import categories failed: $error\n$stackTrace');
      dataError ??= _l10n.bankCategoriesLoadFailed;
      quickBookingOptionsError ??= _l10n.bankCategoriesLoadFailed;
    }

    try {
      taxRateRows = await _db.executor.runSelect(
        'SELECT id, bezeichnung FROM ust_saetze ORDER BY id',
        const <Object?>[],
      );
    } catch (error, stackTrace) {
      debugPrint('bank_import tax rates failed: $error\n$stackTrace');
      dataError ??= _l10n.dataLoadError;
      quickBookingOptionsError ??= _l10n.dataLoadError;
    }

    final List<_HistoryEntry> history = await _readHistory();
    BankImportMode profileMode = BankImportMode.manual;
    try {
      profileMode = await _banking.modes.getMode();
    } catch (error, stackTrace) {
      debugPrint('bank_import mode failed: $error\n$stackTrace');
      dataError ??= _l10n.dataLoadError;
    }
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
        ..addAll(accountRows.map((Map<String, Object?> row) => _BankAccountOption.fromRow(row, l10n: _l10n)));
      _categories
        ..clear()
        ..addAll(categoryRows.map((Map<String, Object?> row) => _BankCategoryOption.fromRow(row, l10n: _l10n)));
      _taxRates
        ..clear()
        ..addAll(
          taxRateRows.map((Map<String, Object?> row) => (id: _asInt(row['id'])!, label: _asString(row['bezeichnung']))),
        );
      _selectedAccountId = _accounts.isEmpty ? null : _accounts.first.id;
      _selectedTemplate = resolvedTemplate;
      _profileMode = profileMode;
      _overrideOnceAutomatic = false;
      _history = history;
      _historyError = null;
      _pageDataError = dataError;
      _quickBookingOptionsError = quickBookingOptionsError;
      _errorMessage = dataError;
      _isLoading = false;
    });
  }

  Future<void> _changeProfileMode(BankImportMode mode) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _banking.modes.setMode(mode);
      if (!mounted) return;
      setState(() {
        _profileMode = mode;
        _isBusy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _retryPageData() async {
    if (_isBusy || _isLoading) return;
    setState(() {
      _isLoading = true;
      _pageDataError = null;
      _errorMessage = null;
    });
    await _loadPageData();
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
            (Map<String, Object?> row) =>
                _HistoryEntry.fromRow(row, outcome: _outcomesByImportId[_asInt(row['id'])], l10n: _l10n),
          )
          .toList();
      entries.addAll(_rejectedAttempts);
      entries.sort((_HistoryEntry a, _HistoryEntry b) => b.date.compareTo(a.date));
      return entries;
    } catch (error, stackTrace) {
      debugPrint('bank_import history failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _historyError = _l10n.bankHistoryLoadFailed;
        });
      }
      return List<_HistoryEntry>.from(_rejectedAttempts);
    }
  }

  Future<void> _loadFileFromPath() async {
    final String path = _pathController.text.trim();
    if (path.isEmpty) {
      _showError(_l10n.setupRequired);
      return;
    }

    final String fileName = _baseName(path);
    if (!_isSupportedFileName(fileName)) {
      await _rejectInput(fileName, _l10n.bankUnsupportedFile);
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
      await _rejectInput(fileName, _l10n.bankFileReadFailed(error.message));
    } catch (error) {
      await _rejectInput(fileName, _l10n.bankFileReadFailed(_safeError(error)));
    }
  }

  Future<void> _pickFile() async {
    try {
      const XTypeGroup csvGroup = XTypeGroup(label: 'CSV', extensions: <String>['csv']);
      const XTypeGroup xmlGroup = XTypeGroup(label: 'CAMT', extensions: <String>['xml']);
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[csvGroup, xmlGroup]);
      if (file == null) return;
      _pathController.text = file.path;
      await _loadFileFromPath();
    } catch (_) {
      // ponytail: selector unavailable (web/test) — fallback to manual path field
      await _loadFileFromPath();
    }
  }

  Future<List<int>> _readLocalFile(String path) => File(path).readAsBytes();

  Future<void> _acceptFile(String fileName, List<int> bytes) async {
    if (bytes.length > _maxImportFileBytes) {
      await _rejectInput(fileName, _l10n.bankFileTooLarge);
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
      _noticeMessage = _l10n.setupIbanHint;
    });
  }

  Future<void> _pasteCsv() async {
    final TextEditingController controller = TextEditingController();
    final AppLocalizations l10n = _l10n;
    final String? content = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.bankPasteTitle),
          content: SizedBox(
            width: 700,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 8,
              maxLines: 16,
              decoration: InputDecoration(
                labelText: l10n.bankPasteContentLabel,
                hintText: l10n.bankPasteHint,
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.actionCancel)),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(l10n.actionApply),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || content == null) return;
    if (content.trim().isEmpty) {
      _showError(_l10n.emptyResults);
      return;
    }
    await _acceptFile(_l10n.bankPasteFileName, utf8.encode(content));
  }

  Future<void> _parseLoadedFile() async {
    final List<int>? bytes = _fileBytes;
    final String? fileName = _fileName;
    if (bytes == null || fileName == null) {
      _showError(_l10n.setupRequired);
      return;
    }
    if (!_isCamtFile(fileName) && _selectedTemplate == null) {
      _showError(_l10n.setupRequired);
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
          ? _service.parseCamtXml(content, locale: _activeLocale)
          : _service.parseCsv(csv: content, template: _selectedTemplate, locale: _activeLocale);
      if (parsed.isEmpty) {
        throw BankImportException(_l10n.bankNoTransactionsFound);
      }
      _disposeRows();
      _rows.addAll(
        parsed.asMap().entries.map(
          (MapEntry<int, RawTx> entry) =>
              _EditableBankRow(lineNumber: entry.value.sourceRowNumber ?? entry.key + 2, source: entry.value),
        ),
      );
      if (!mounted) return;
      setState(() {
        _stage = _BankImportStage.review;
        _isBusy = false;
        _errorMessage = null;
        _noticeMessage = _l10n.setupSaved;
      });
      unawaited(_computeSuggestions());
    } on BankImportException catch (error) {
      await _rejectInput(fileName, error.message, recoveryAction: error.recoveryAction);
    } catch (error) {
      await _rejectInput(fileName, _l10n.bankFileProcessFailed(_safeError(error)));
    }
  }

  Future<void> _confirmImport() async {
    final int selectedCount = _rows.where((_EditableBankRow row) => row.included).length;
    if (selectedCount == 0) {
      _showError(_l10n.setupRequired);
      return;
    }
    if (_selectedAccountId == null) {
      _showError(_l10n.setupRequired);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations l10n = appLocalizationsOf(dialogContext);
        return AlertDialog(
          title: Text(l10n.bankConfirmTitle),
          content: Text(l10n.bankConfirmMessage(selectedCount, _selectedAccountName)),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.bankBackToReview)),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.bankConfirmTitle)),
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
      _noticeMessage = _l10n.setupSaving;
    });

    try {
      final String effectiveMode = _overrideOnceAutomatic || _profileMode == BankImportMode.automatic
          ? 'automatisch'
          : 'manuell';
      final ImportResult serviceResult = await _service.importTransactions(
        kontoId: kontoId,
        rawTxs: preparedRows.map((_PreparedBankRow item) => item.raw).toList(),
        mode: effectiveMode,
        allowDuplicateOverride: _allowDuplicateOverride,
        dateiname: fileName,
        template: _selectedTemplate,
        locale: _activeLocale,
      );
      if (mounted) {
        setState(() => _overrideOnceAutomatic = false);
      }
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
        status: _historyStatus(serviceResult.status, _l10n),
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
        detail: _l10n.bankImportIncomplete(_safeError(error)),
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

  /// Computes top-1 score suggestions for the current review rows without
  /// touching accounting data. A candidate-query failure marks the review
  /// unavailable (automatic linking disabled) instead of showing no-match.
  Future<void> _computeSuggestions() async {
    final Map<int, _RowSuggestion> next = <int, _RowSuggestion>{};
    bool unavailable = false;
    for (final _EditableBankRow row in _rows) {
      try {
        final RawTx tx = row.toRawTx();
        final List<MatchCandidate> ranked = await _service.rankCandidates(tx);
        if (ranked.isNotEmpty) {
          final MatchCandidate top = ranked.first;
          next[row.lineNumber] = _RowSuggestion(
            score: top.score,
            label: _service.confidenceLabel(top.score, _l10n),
            description: <String>[
              if ((top.betrag ?? '').isNotEmpty) top.betrag!,
              if ((top.datum ?? '').isNotEmpty) top.datum!,
              if ((top.beschreibung ?? '').isNotEmpty) top.beschreibung!,
            ].join(' · '),
          );
        }
      } catch (_) {
        unavailable = true;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _suggestions = next;
      _candidatesUnavailable = unavailable;
    });
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
      _noticeMessage = _l10n.bankRetryNotice;
    });
    unawaited(_computeSuggestions());
  }

  Future<void> _rejectInput(String fileName, String reason, {String? recoveryAction}) async {
    final String diagnostic = recoveryAction == null ? reason : '$reason $recoveryAction';
    await _recordRejectedAttempt(fileName, diagnostic);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _stage = _BankImportStage.upload;
      _outcome = null;
      _errorMessage = _l10n.bankImportAborted(diagnostic);
      _noticeMessage = _l10n.bankImportAbortedHint;
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
          locale: _activeLocale,
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
            BankImportFailurePayload.encodeFileRejection(const <String>['unknown_file_rejection']),
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
      status: _l10n.bankStatusRejected,
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
      _suggestions = <int, _RowSuggestion>{};
      _candidatesUnavailable = false;
      _overrideOnceAutomatic = false;
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
        if (_pageDataError != null)
          _buildMessage(_pageDataError!, isError: true)
        else if (_errorMessage != null)
          _buildMessage(_errorMessage!, isError: true),
        if (_pageDataError != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : () => unawaited(_retryPageData()),
              icon: const Icon(Icons.refresh),
              label: Text(_l10n.actionRetry),
            ),
          )
        else if (_errorMessage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _startOver,
              icon: const Icon(Icons.refresh),
              label: Text(_l10n.actionRetry),
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
          title: _l10n.bankStepChooseFile,
          icon: Icons.upload_file,
          children: <Widget>[
            Text(_l10n.bankUploadHint),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _pathController,
              enabled: !_isBusy,
              decoration: InputDecoration(
                labelText: _l10n.bankPathLabel,
                hintText: _l10n.bankPathHintExample,
                prefixIcon: const Icon(Icons.folder_open),
                helperText: _l10n.bankPathHint,
              ),
              onSubmitted: (_) => unawaited(_loadFileFromPath()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isBusy ? null : () => unawaited(_pickFile()),
                  icon: const Icon(Icons.file_open),
                  label: Text(_l10n.actionChooseFile),
                ),
                // ponytail: native picker via file_selector, manual path fallback keeps headless/test path
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : () => unawaited(_pasteCsv()),
                  icon: const Icon(Icons.content_paste),
                  label: Text(_l10n.actionContinue),
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
          title: _l10n.bankStepAccountTemplate,
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
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_l10n.bankNoAccountYet),
              ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  Text(_l10n.bankModeLabel),
                  const SizedBox(width: AppSpacing.md),
                  SegmentedButton<BankImportMode>(
                    segments: <ButtonSegment<BankImportMode>>[
                      ButtonSegment<BankImportMode>(value: BankImportMode.manual, label: Text(_l10n.bankModeManual)),
                      ButtonSegment<BankImportMode>(
                        value: BankImportMode.automatic,
                        label: Text(_l10n.bankModeAutomatic),
                      ),
                    ],
                    selected: <BankImportMode>{_profileMode},
                    onSelectionChanged: (Set<BankImportMode> value) => unawaited(_changeProfileMode(value.single)),
                  ),
                ],
              ),
            ),
            if (_isCamtFile(_fileName))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_l10n.bankCamtHint),
              ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _isBusy || _fileBytes == null ? null : () => unawaited(_parseLoadedFile()),
                icon: const Icon(Icons.preview),
                label: Text(_l10n.actionPreview),
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
          title: _l10n.bankStepReview,
          icon: Icons.fact_check,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(_l10n.bankRowsDetected(_rows.length)),
                Text(_l10n.bankRowsSelected(selectedCount)),
                Text(_l10n.bankRowsManual(manualCategoryCount)),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _startOver,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_l10n.actionBack),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_l10n.bankReviewNotice),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Checkbox(
                  value: _allowDuplicateOverride,
                  onChanged: _isBusy ? null : (bool? value) => setState(() => _allowDuplicateOverride = value ?? false),
                ),
                Expanded(child: Text(_l10n.bankDuplicateOverride)),
              ],
            ),
            Row(
              children: <Widget>[
                Checkbox(
                  value: _overrideOnceAutomatic,
                  onChanged: _isBusy ? null : (bool? value) => setState(() => _overrideOnceAutomatic = value ?? false),
                ),
                Expanded(child: Text(_l10n.bankModeOverride)),
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
                  label: Text(_l10n.bankConfirmActionCount(selectedCount)),
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
      return Text(_l10n.emptyResults);
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
            columns: <DataColumn>[
              DataColumn(label: Text(_l10n.bankColImport)),
              DataColumn(label: Text(_l10n.dateLabel)),
              DataColumn(label: Text(_l10n.bankColAmount)),
              DataColumn(label: Text(_l10n.bankColPartnerPurpose)),
              DataColumn(label: Text(_l10n.bankColCategory)),
              DataColumn(label: Text(_l10n.bankScoreLabel)),
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
              decoration: InputDecoration(labelText: _l10n.bankRowLabel(row.lineNumber)),
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
                  decoration: InputDecoration(labelText: _l10n.bankColPartner),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: row.purposeController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(labelText: _l10n.bankColPurpose),
                ),
              ],
            ),
          ),
        ),
        DataCell(_buildCategoryDropdown(row)),
        DataCell(_buildSuggestionCell(row)),
      ],
    );
  }

  /// Top score suggestion for a review row. Suggestions never mutate
  /// accounting data; an unavailable candidate query shows a warning state
  /// instead of a fabricated no-match.
  Widget _buildSuggestionCell(_EditableBankRow row) {
    if (_candidatesUnavailable) {
      return Tooltip(
        message: _l10n.bankCandidatesUnavailable,
        child: Text(_l10n.bankCandidatesUnavailable, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    final _RowSuggestion? suggestion = _suggestions[row.lineNumber];
    if (suggestion == null) {
      return Text(_l10n.bankConfidenceNone);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${suggestion.score}% · ${suggestion.label}'),
        if (suggestion.description.isNotEmpty) Text(suggestion.description),
      ],
    );
  }

  Widget _buildCategoryDropdown(_EditableBankRow row) {
    if (_categories.isEmpty) {
      return Text(_l10n.emptyResults);
    }
    final int selectedValue = row.categoryId ?? 0;
    return DropdownButton<int>(
      value: selectedValue,
      isDense: true,
      hint: Text(_l10n.actionRetry),
      items: <DropdownMenuItem<int>>[
        DropdownMenuItem<int>(value: 0, child: Text(_l10n.actionRetry)),
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
          title: _l10n.bankStepResult,
          icon: hasFailure ? Icons.warning_amber : Icons.check_circle,
          children: <Widget>[
            AppStatusChip(status: hasFailure ? AppStatus.warning : AppStatus.paid, label: outcome.status),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _buildResultStat(_l10n.bankStatImported, outcome.imported, Icons.save_alt),
                _buildResultStat(_l10n.bankStatDuplicatesSkipped, outcome.duplicates, Icons.copy_all),
                _buildResultStat(_l10n.bankStatCategorized, outcome.categorized, Icons.label_outline),
                _buildResultStat(_l10n.bankStatManualReview, outcome.manualReview, Icons.rate_review),
                _buildResultStat(_l10n.bankStatFailed, outcome.failed, Icons.error_outline),
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
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: Text(_l10n.bankResultAllSaved),
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
                    label: Text(_l10n.bankRetryFailedRows),
                  ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _startOver,
                  icon: const Icon(Icons.add),
                  label: Text(_l10n.actionContinue),
                ),
                FilledButton.icon(
                  onPressed: _isBusy
                      ? null
                      : () => setState(() {
                          _view = _BankImportView.history;
                          _historyError = null;
                        }),
                  icon: const Icon(Icons.history),
                  label: Text(_l10n.actionBack),
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
      return Text(_l10n.bankFailureRowsGeneric);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(_l10n.bankNotSavedFix, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        ...rows.map(
          (_FailedEditableRow failure) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(_failureRowText(failure)),
          ),
        ),
      ],
    );
  }

  String _failureRowText(_FailedEditableRow failure) {
    final String partner = failure.row.partnerController.text.trim();
    final String purpose = failure.row.purposeController.text.trim();
    final String amount = failure.row.amountController.text.trim();
    final String prefix = _l10n.bankFailureRowPrefix(failure.row.lineNumber, failure.error);
    final String partnerText = partner.isEmpty ? _l10n.bankWithoutPartner : partner;
    final String purposeText = purpose.isEmpty ? _l10n.bankWithoutPurpose : purpose;
    return '$prefix · $partnerText · $amount € · $purposeText';
  }

  Widget _buildHistoryView() {
    return ListView(
      key: const ValueKey<String>('bank-import-history'),
      children: <Widget>[
        _buildSectionCard(
          title: _l10n.bankHistoryTitle,
          icon: Icons.history,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(_l10n.bankHistoryCardSubtitle)),
                IconButton(
                  tooltip: _l10n.bankHistoryRefresh,
                  onPressed: _historyLoading ? null : () => unawaited(_refreshHistory()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              decoration: InputDecoration(
                labelText: _l10n.bankHistorySearch,
                hintText: _l10n.bankHistorySearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (String value) => setState(() {
                _historyQuery = value;
                _historyPage = 1;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_historyError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _buildMessage(_historyError!, isError: true),
            ],
            const SizedBox(height: AppSpacing.md),
            if (_historyLoading)
              const Center(child: CircularProgressIndicator())
            else if (_history.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_l10n.bankHistoryEmpty),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () => setState(() => _view = _BankImportView.import),
                    icon: const Icon(Icons.file_open),
                    label: Text(_l10n.bankHistoryImportAction),
                  ),
                ],
              )
            else
              _buildHistoryTable(),
          ],
        ),
      ],
    );
  }

  /// Filtered + paginated history rows (filter before pagination, 50/page).
  List<_HistoryEntry> get _visibleHistory {
    final String needle = _historyQuery.trim().toLowerCase();
    final List<_HistoryEntry> filtered = needle.isEmpty
        ? _history
        : _history
              .where(
                (_HistoryEntry e) =>
                    e.fileName.toLowerCase().contains(needle) ||
                    e.template.toLowerCase().contains(needle) ||
                    e.status.toLowerCase().contains(needle),
              )
              .toList(growable: false);
    final int lastPage = filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _historyPageSize) + 1;
    final int page = _historyPage < 1 ? 1 : (_historyPage > lastPage ? lastPage : _historyPage);
    if (page != _historyPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _historyPage = page);
      });
    }
    final int start = (page - 1) * _historyPageSize;
    final int end = (start + _historyPageSize).clamp(0, filtered.length);
    return start >= filtered.length ? <_HistoryEntry>[] : filtered.sublist(start, end);
  }

  int get _historyTotalPages {
    final String needle = _historyQuery.trim().toLowerCase();
    final int count = needle.isEmpty
        ? _history.length
        : _history
              .where(
                (_HistoryEntry e) =>
                    e.fileName.toLowerCase().contains(needle) ||
                    e.template.toLowerCase().contains(needle) ||
                    e.status.toLowerCase().contains(needle),
              )
              .length;
    return count == 0 ? 1 : ((count - 1) ~/ _historyPageSize) + 1;
  }

  Widget _buildHistoryTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: AppSpacing.lg,
            columns: <DataColumn>[
              DataColumn(label: Text(_l10n.bankColTime)),
              DataColumn(label: Text(_l10n.bankColSource)),
              DataColumn(label: Text(_l10n.bankColTemplate)),
              DataColumn(label: Text(_l10n.bankColAccount)),
              DataColumn(label: Text(_l10n.bankColImported)),
              DataColumn(label: Text(_l10n.bankColDuplicates)),
              DataColumn(label: Text(_l10n.bankColError)),
              DataColumn(label: Text(_l10n.bankColStatus)),
              DataColumn(label: Text(_l10n.bankHistoryDetail)),
            ],
            rows: _visibleHistory.map(_buildHistoryRow).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: _l10n.bankHistoryPrevPage,
              onPressed: _historyPage > 1 ? () => setState(() => _historyPage--) : null,
            ),
            Text('$_historyPage / $_historyTotalPages'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: _l10n.bankHistoryNextPage,
              onPressed: _historyPage < _historyTotalPages ? () => setState(() => _historyPage++) : null,
            ),
          ],
        ),
      ],
    );
  }

  /// History detail dialog: metadata, safe diagnostics, unresolved count,
  /// and the retry/review actions allowed by the attempt and row states.
  Future<void> _showHistoryDetail(int? importId) async {
    if (importId == null) return;
    BankImportHistoryDetail detail;
    try {
      detail = await _banking.service.historyDetail(importId, locale: _activeLocale);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
      return;
    }
    if (!mounted) return;
    final BankImportHistoryActions actions = _banking.service.historyActions(
      status: detail.status,
      retryable: detail.retryable,
      unresolvedNeu: detail.unresolvedNeu,
    );
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(detail.dateiname),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('${detail.status} · ${detail.datum}'),
              Text(
                '${_l10n.bankDetailImported}: ${detail.imported} · ${_l10n.bankDetailDuplicates}: ${detail.duplicates} · ${_l10n.bankDetailFailed}: ${detail.failed}',
              ),
              Text('${_l10n.bankDetailUnresolved}: ${detail.unresolvedNeu}'),
              if (detail.diagnostics.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                ...detail.diagnostics.map(Text.new),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          if (actions.review)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_showHistoryReview(importId));
              },
              child: Text(_l10n.bankHistoryReview),
            ),
          if (actions.retry)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_retryHistoryImport(importId));
              },
              child: Text(_l10n.bankHistoryRetry),
            ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(_l10n.actionClose)),
        ],
      ),
    );
  }

  Future<void> _retryHistoryImport(int importId) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _banking.service.retryImport(importId: importId, locale: _activeLocale);
      if (!mounted) return;
      setState(() => _isBusy = false);
      await _refreshHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Manual review for one history attempt: unresolved rows with category
  /// confirm + journal link actions. Review never creates postings/payments.
  Future<void> _showHistoryReview(int importId) async {
    List<Map<String, Object?>> rows;
    try {
      rows = await _banking.service.unresolvedReviewRows(importId: importId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => HistoryReviewDialog(
        banking: _banking,
        importId: importId,
        initialRows: rows,
        categories: <({int id, String name})>[
          for (final _BankCategoryOption c in _categories) (id: c.id, name: c.name),
        ],
        onChanged: () => unawaited(_refreshHistory()),
      ),
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
        DataCell(
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: _l10n.bankHistoryDetail,
            onPressed: () => unawaited(_showHistoryDetail(entry.id)),
          ),
        ),
      ],
    );
  }

  Widget _buildStageIndicator() {
    final List<_StageDescriptor> stages = <_StageDescriptor>[
      (label: _l10n.bankStageFile, icon: Icons.upload_file, stage: _BankImportStage.upload),
      (label: _l10n.bankStageReview, icon: Icons.fact_check, stage: _BankImportStage.review),
      (label: _l10n.bankStageResult, icon: Icons.task_alt, stage: _BankImportStage.result),
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
    final AppLocalizations l10n = _l10n;
    final String state = active
        ? l10n.bankStageCurrent
        : complete
        ? l10n.bankStageComplete
        : l10n.bankStageOpen;
    return Semantics(
      label: '${stage.label}: $state',
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
              _l10n.bankReady(_fileName ?? '', _formatBytes(bytes)),
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
      decoration: InputDecoration(labelText: _l10n.pdfBank),
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
      decoration: InputDecoration(labelText: _l10n.pdfBank),
      hint: Text(_l10n.actionContinue),
      items: _templates
          .map(
            (BankTemplate template) => DropdownMenuItem<BankTemplate>(
              value: template,
              child: Text(
                '${template.name} · ${template.delimiter == ';' ? _l10n.bankDelimiterSemicolon : _l10n.bankDelimiterComma}',
              ),
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

  void _changeView(_BankImportView value) {
    final Uri? routeUri = widget.routeUri;
    if (routeUri == null) {
      setState(() => _view = value);
      return;
    }

    // Keep repeated filters by passing each query value's iterable through Uri.replace.
    final Map<String, dynamic> queryParameters = Map<String, dynamic>.from(routeUri.queryParametersAll);
    queryParameters['view'] = value.queryValue;
    context.go(routeUri.replace(queryParameters: queryParameters).toString());
  }

  Widget _buildQuickBookingsView() {
    final Widget workspace = QuickBookingsView(
      repository: ref.watch(quickBookingRepositoryProvider),
      executorPort: const UnavailableQuickBookingPosting(),
      konten: <({int id, String name})>[
        for (final _BankAccountOption account in _accounts) (id: account.id, name: account.name),
      ],
      categories: <({int id, String name})>[
        for (final _BankCategoryOption category in _categories) (id: category.id, name: category.name),
      ],
      taxRates: _taxRates,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_quickBookingOptionsError != null) ...<Widget>[
          _buildMessage(_quickBookingOptionsError!, isError: true),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : () => unawaited(_retryPageData()),
              icon: const Icon(Icons.refresh),
              label: Text(_l10n.actionRetry),
            ),
          ),
        ],
        Expanded(child: workspace),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : switch (_view) {
            _BankImportView.history => _buildHistoryView(),
            _BankImportView.rules => BankRulesView(
              useCase: _banking,
              categories: <({int id, String name})>[
                for (final _BankCategoryOption c in _categories) (id: c.id, name: c.name),
              ],
            ),
            _BankImportView.templates => BankTemplatesView(useCase: _banking),
            _BankImportView.quickBookings => _buildQuickBookingsView(),
            _BankImportView.import => _buildImportView(),
          };
    return AppPage(
      maxWidth: 1400,
      header: AppPageHeader(
        title: _l10n.sidebarBanking,
        subtitle: _view == _BankImportView.history ? _l10n.bankHeaderSubtitleHistory : _l10n.bankHeaderSubtitleImport,
        showFilterToolbar: false,
        actions: <Widget>[
          PopupMenuButton<_BankImportView>(
            icon: const Icon(Icons.menu),
            tooltip: _l10n.sidebarBanking,
            onSelected: _changeView,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_BankImportView>>[
              PopupMenuItem<_BankImportView>(value: _BankImportView.import, child: Text(_l10n.bankViewImport)),
              PopupMenuItem<_BankImportView>(value: _BankImportView.history, child: Text(_l10n.bankViewHistory)),
              PopupMenuItem<_BankImportView>(value: _BankImportView.rules, child: Text(_l10n.bankViewRules)),
              PopupMenuItem<_BankImportView>(value: _BankImportView.templates, child: Text(_l10n.bankViewTemplates)),
              PopupMenuItem<_BankImportView>(
                value: _BankImportView.quickBookings,
                child: Text(_l10n.quickBookingsTitle),
              ),
            ],
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
    return _l10n.bankNoAccountSelected;
  }
}

typedef _StageDescriptor = ({String label, IconData icon, _BankImportStage stage});

class _PreparedBankRow {
  const _PreparedBankRow({required this.row, required this.raw});

  final _EditableBankRow row;
  final RawTx raw;
}

class _RowSuggestion {
  const _RowSuggestion({required this.score, required this.label, required this.description});
  final int score;
  final String label;
  final String description;
}

class _EditableBankRow {
  _EditableBankRow({required this.lineNumber, required RawTx source})
    : _source = source,
      dateController = TextEditingController(
        text: source.rawDatum ?? (source.datum == null ? '' : _formatDate(source.datum!)),
      ),
      amountController = TextEditingController(text: source.rawBetrag ?? source.betrag),
      partnerController = TextEditingController(text: source.partner),
      purposeController = TextEditingController(text: source.verwendungszweck),
      counterAccount = source.gegenkonto;

  final RawTx _source;
  final int lineNumber;
  final TextEditingController dateController;
  final TextEditingController amountController;
  final TextEditingController partnerController;
  final TextEditingController purposeController;
  final String? counterAccount;
  bool included = true;
  int? categoryId;

  RawTx toRawTx() {
    final DateTime? date = _parseEditableDate(dateController.text);
    final String amount = amountController.text.trim();
    return RawTx(
      datum: date,
      betrag: amount,
      verwendungszweck: purposeController.text.trim(),
      partner: partnerController.text.trim(),
      gegenkonto: counterAccount,
      kategorieId: categoryId,
      rawDatum: dateController.text,
      rawBetrag: amountController.text,
      sourceRowNumber: _source.sourceRowNumber ?? lineNumber,
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

  factory _BankAccountOption.fromRow(Map<String, Object?> row, {required AppLocalizations l10n}) {
    final String rawName = _asString(row['name']);
    return _BankAccountOption(
      id: _asInt(row['id']) ?? 0,
      name: rawName.isEmpty ? l10n.bankAccountFallback('${_asInt(row['id']) ?? ''}') : rawName,
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

  factory _BankCategoryOption.fromRow(Map<String, Object?> row, {required AppLocalizations l10n}) {
    final int id = _asInt(row['id']) ?? 0;
    final String rawName = _asString(row['bezeichnung']);
    return _BankCategoryOption(id: id, name: rawName.isEmpty ? l10n.bankCategoryFallback('$id') : rawName);
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

  factory _HistoryEntry.fromRow(Map<String, Object?> row, {_ImportOutcome? outcome, required AppLocalizations l10n}) {
    final int imported =
        outcome?.imported ?? (_asInt(row['anzahl_importiert']) ?? _asInt(row['anzahl_transaktionen']) ?? 0);
    final int duplicates = outcome?.duplicates ?? (_asInt(row['duplikate']) ?? 0);
    final int failed = outcome?.failed ?? (_asInt(row['anzahl_fehlgeschlagen']) ?? 0);
    final String rawStatus = _asString(row['status']);
    final String? detail = outcome?.detail ?? _diagnosticText(_asString(row['fehler_details']), l10n);
    final String rawFileName = _asString(row['dateiname']);
    return _HistoryEntry(
      id: _asInt(row['id']),
      fileName: rawFileName.isEmpty ? l10n.bankUnknownFile : rawFileName,
      date: DateTime.tryParse(_asString(row['datum'])) ?? DateTime.now(),
      template: _asString(row['template_typ']).isEmpty ? '—' : _asString(row['template_typ']),
      account: _asString(row['konto_name']).isEmpty ? '—' : _asString(row['konto_name']),
      imported: imported,
      duplicates: duplicates,
      failed: failed,
      status: outcome?.status ?? _historyStatus(rawStatus, l10n),
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

DateTime? _parseEditableDate(String raw) {
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
  return null;
}

bool _isValidDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  final DateTime candidate = DateTime(year, month, day);
  return candidate.year == year && candidate.month == month && candidate.day == day;
}

String _historyStatus(String raw, AppLocalizations l10n) {
  final String lower = raw.toLowerCase();
  if (lower.startsWith('abgelehnt') || lower.startsWith('unsupported')) {
    return l10n.bankStatusRejected;
  }
  if (lower.startsWith('teilweise') || lower.startsWith('partial')) {
    return l10n.bankStatusPartial;
  }
  if (lower.startsWith('fehlgeschlagen') || lower.startsWith('failed')) {
    return l10n.bankStatusFailed;
  }
  if (lower.startsWith('importiert') || lower.startsWith('success')) {
    return l10n.bankStatusImported;
  }
  return raw.isEmpty ? l10n.statusUnknown : raw;
}

String? _diagnosticText(String raw, AppLocalizations l10n) {
  if (raw.isEmpty) return null;
  try {
    final Map<String, Object?> envelope = BankImportFailurePayload.decodeValidated(raw);
    if (envelope['kind'] == 'file_rejection') {
      final List<dynamic> codes = envelope['diagnostic_codes']! as List<dynamic>;
      return '${l10n.bankDetailFileRejection} (${codes.join(', ')})';
    }
    final List<dynamic> rows = envelope['rows']! as List<dynamic>;
    return '${rows.length} ${l10n.bankDetailErrorRows} (${l10n.bankDetailSeeHistory})';
  } on BankImportPayloadException {
    return raw.length > 200 ? '${raw.substring(0, 200)}…' : raw;
  }
}

String _safeError(Object error) {
  if (error is BankImportException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _asString(Object? value) => value?.toString().trim() ?? '';
