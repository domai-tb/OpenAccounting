import 'package:flutter/foundation.dart';

import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

enum BankImportWorkflowStage { upload, preview, review, confirm, importing, history, retry, error }

enum BankImportInputFormat { csv, camtXml }

enum BankImportRowDecision { include, skip }

enum BankImportHistoryStatus { imported, partial, failed, unsupported, skipped }

enum BankImportRecoveryAction { selectFile, selectTemplate, reviewRows, retry }

/// Keeps parser output and review decisions together without mutating either.
class BankImportReviewRow {
  const BankImportReviewRow({
    required this.index,
    required this.original,
    required this.transaction,
    this.decision = BankImportRowDecision.include,
    this.manualCategoryId,
    this.manualJournalId,
    this.manuallyReviewed = false,
  });

  static const Object _unset = Object();

  final int index;
  final RawTx original;
  final RawTx transaction;
  final BankImportRowDecision decision;
  final int? manualCategoryId;
  final int? manualJournalId;
  final bool manuallyReviewed;

  bool get isIncluded => decision == BankImportRowDecision.include;

  BankImportReviewRow copyWith({
    RawTx? transaction,
    Object? decision = _unset,
    Object? manualCategoryId = _unset,
    Object? manualJournalId = _unset,
    bool? manuallyReviewed,
  }) {
    return BankImportReviewRow(
      index: index,
      original: original,
      transaction: transaction ?? this.transaction,
      decision: identical(decision, _unset) ? this.decision : decision! as BankImportRowDecision,
      manualCategoryId: identical(manualCategoryId, _unset) ? this.manualCategoryId : manualCategoryId as int?,
      manualJournalId: identical(manualJournalId, _unset) ? this.manualJournalId : manualJournalId as int?,
      manuallyReviewed: manuallyReviewed ?? this.manuallyReviewed,
    );
  }
}

/// Metadata retained by the coordinator for UI history and retry.
class BankImportHistoryEntry {
  BankImportHistoryEntry({
    required this.occurredAt,
    required this.sourceFileName,
    required this.kontoId,
    required this.template,
    required this.status,
    required this.attempted,
    required this.result,
    required this.failedCount,
    required List<BankImportReviewRow> retryRows,
    List<ImportRowFailure> failedRows = const <ImportRowFailure>[],
    this.errorMessage,
    this.recoveryAction,
  }) : retryRows = List<BankImportReviewRow>.unmodifiable(retryRows),
       failedRows = List<ImportRowFailure>.unmodifiable(failedRows);

  final DateTime occurredAt;
  final String sourceFileName;
  final int? kontoId;
  final BankTemplate? template;
  final BankImportHistoryStatus status;
  final int attempted;
  final ImportResult? result;
  final int failedCount;
  final List<BankImportReviewRow> retryRows;
  final List<ImportRowFailure> failedRows;
  final String? errorMessage;
  final BankImportRecoveryAction? recoveryAction;

  int get imported => result?.imported ?? 0;
  int get duplicatesSkipped => result?.duplicatesSkipped ?? 0;
  int get autoCategorized => result?.autoCategorized ?? 0;
  int get manualReview => result?.manualReview ?? 0;
  bool get canRetry => failedCount > 0 && retryRows.isNotEmpty;
}

/// Immutable snapshot consumed by a future upload/review/history UI.
class BankImportWorkflowState {
  BankImportWorkflowState({
    this.stage = BankImportWorkflowStage.upload,
    this.kontoId,
    this.sourceFileName,
    this.template,
    this.inputFormat,
    this.importMode = 'manuell',
    this.allowDuplicateOverride = false,
    List<BankTemplate> availableTemplates = const <BankTemplate>[],
    List<BankImportReviewRow> reviewRows = const <BankImportReviewRow>[],
    List<BankImportHistoryEntry> history = const <BankImportHistoryEntry>[],
    this.lastAttempt,
    this.errorMessage,
    this.recoveryAction,
  }) : availableTemplates = List<BankTemplate>.unmodifiable(availableTemplates),
       reviewRows = List<BankImportReviewRow>.unmodifiable(reviewRows),
       history = List<BankImportHistoryEntry>.unmodifiable(history);

  static const Object _unset = Object();

  final BankImportWorkflowStage stage;
  final int? kontoId;
  final String? sourceFileName;
  final BankTemplate? template;
  final BankImportInputFormat? inputFormat;
  final String importMode;
  final bool allowDuplicateOverride;
  final List<BankTemplate> availableTemplates;
  final List<BankImportReviewRow> reviewRows;
  final List<BankImportHistoryEntry> history;
  final BankImportHistoryEntry? lastAttempt;
  final String? errorMessage;
  final BankImportRecoveryAction? recoveryAction;

  List<BankImportReviewRow> get rows => reviewRows;

  List<BankImportReviewRow> get includedRows =>
      List<BankImportReviewRow>.unmodifiable(reviewRows.where((BankImportReviewRow row) => row.isIncluded));

  ImportResult? get lastResult => lastAttempt?.result;
  bool get canReview => stage == BankImportWorkflowStage.preview && reviewRows.isNotEmpty;
  bool get canConfirm => stage == BankImportWorkflowStage.review && reviewRows.isNotEmpty;
  bool get canImport => stage == BankImportWorkflowStage.confirm;
  bool get canRetry => lastAttempt?.canRetry ?? false;

  BankImportWorkflowState copyWith({
    BankImportWorkflowStage? stage,
    Object? kontoId = _unset,
    Object? sourceFileName = _unset,
    Object? template = _unset,
    Object? inputFormat = _unset,
    String? importMode,
    bool? allowDuplicateOverride,
    List<BankTemplate>? availableTemplates,
    List<BankImportReviewRow>? reviewRows,
    List<BankImportHistoryEntry>? history,
    Object? lastAttempt = _unset,
    Object? errorMessage = _unset,
    Object? recoveryAction = _unset,
  }) {
    return BankImportWorkflowState(
      stage: stage ?? this.stage,
      kontoId: identical(kontoId, _unset) ? this.kontoId : kontoId as int?,
      sourceFileName: identical(sourceFileName, _unset) ? this.sourceFileName : sourceFileName as String?,
      template: identical(template, _unset) ? this.template : template as BankTemplate?,
      inputFormat: identical(inputFormat, _unset) ? this.inputFormat : inputFormat as BankImportInputFormat?,
      importMode: importMode ?? this.importMode,
      allowDuplicateOverride: allowDuplicateOverride ?? this.allowDuplicateOverride,
      availableTemplates: availableTemplates ?? this.availableTemplates,
      reviewRows: reviewRows ?? this.reviewRows,
      history: history ?? this.history,
      lastAttempt: identical(lastAttempt, _unset) ? this.lastAttempt : lastAttempt as BankImportHistoryEntry?,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      recoveryAction: identical(recoveryAction, _unset)
          ? this.recoveryAction
          : recoveryAction as BankImportRecoveryAction?,
    );
  }
}

/// Coordinates parse, review, confirmation, import, history, and retry.
class BankImportWorkflowCoordinator extends ChangeNotifier {
  BankImportWorkflowCoordinator(this._service, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final BankImportService _service;
  final DateTime Function() _clock;
  BankImportWorkflowState _state = BankImportWorkflowState();
  bool _importInProgress = false;

  BankImportWorkflowState get state => _state;

  Future<List<BankTemplate>> loadTemplates() async {
    final List<BankTemplate> templates = await _service.loadTemplates();
    _emit(_state.copyWith(availableTemplates: templates));
    return templates;
  }

  BankImportWorkflowState startUpload({
    required String sourceFileName,
    int? kontoId,
    BankTemplate? template,
    String mode = 'manuell',
    bool allowDuplicateOverride = false,
  }) {
    final String fileName = sourceFileName.trim();
    if (fileName.isEmpty) {
      throw ArgumentError.value(sourceFileName, 'sourceFileName', 'must not be empty');
    }
    if (mode.trim().isEmpty) {
      throw ArgumentError.value(mode, 'mode', 'must not be empty');
    }
    _ensureNotImporting();
    _emit(
      _state.copyWith(
        stage: BankImportWorkflowStage.upload,
        kontoId: kontoId ?? _state.kontoId,
        sourceFileName: fileName,
        template: template ?? _state.template,
        inputFormat: null,
        importMode: mode.trim(),
        allowDuplicateOverride: allowDuplicateOverride,
        reviewRows: const <BankImportReviewRow>[],
        lastAttempt: null,
        errorMessage: null,
        recoveryAction: null,
      ),
    );
    return _state;
  }

  BankImportWorkflowState selectAccount(int kontoId) {
    if (kontoId <= 0) {
      throw ArgumentError.value(kontoId, 'kontoId', 'must be positive');
    }
    _ensureNotImporting();
    _emit(_state.copyWith(kontoId: kontoId, errorMessage: null, recoveryAction: null));
    return _state;
  }

  BankImportWorkflowState selectTemplate(BankTemplate? template) {
    _ensureNotImporting();
    final BankImportWorkflowStage stage = _state.stage == BankImportWorkflowStage.error
        ? BankImportWorkflowStage.upload
        : _state.stage;
    _emit(_state.copyWith(stage: stage, template: template, errorMessage: null, recoveryAction: null));
    return _state;
  }

  BankImportWorkflowState configureImport({String? mode, bool? allowDuplicateOverride}) {
    _ensureNotImporting();
    final String nextMode = mode?.trim() ?? _state.importMode;
    if (nextMode.isEmpty) {
      throw ArgumentError.value(mode, 'mode', 'must not be empty');
    }
    _emit(_state.copyWith(importMode: nextMode, allowDuplicateOverride: allowDuplicateOverride));
    return _state;
  }

  BankImportWorkflowState previewCsv({
    required String csv,
    String? sourceFileName,
    int? kontoId,
    BankTemplate? template,
  }) => _preview(csv, BankImportInputFormat.csv, sourceFileName: sourceFileName, kontoId: kontoId, template: template);

  BankImportWorkflowState previewCamtXml({required String xml, String? sourceFileName, int? kontoId}) => _preview(
    xml,
    BankImportInputFormat.camtXml,
    sourceFileName: sourceFileName,
    kontoId: kontoId,
    template: _state.template,
  );

  BankImportWorkflowState beginReview() {
    _ensureStage(BankImportWorkflowStage.preview, 'begin review');
    if (_state.reviewRows.isEmpty) {
      throw StateError('A preview must contain at least one transaction');
    }
    _emit(_state.copyWith(stage: BankImportWorkflowStage.review));
    return _state;
  }

  BankImportWorkflowState editRow(int index, RawTx transaction) {
    _ensureReviewEditable();
    final BankImportReviewRow row = _state.reviewRows[index];
    return _replaceRow(
      index,
      row.copyWith(
        transaction: transaction,
        manualCategoryId: transaction.kategorieId,
        manualJournalId: transaction.journalId,
        manuallyReviewed: true,
      ),
    );
  }

  BankImportWorkflowState setRowDecision(int index, BankImportRowDecision decision) {
    _ensureReviewEditable();
    return _replaceRow(index, _state.reviewRows[index].copyWith(decision: decision, manuallyReviewed: true));
  }

  BankImportWorkflowState categorizeRow(int index, int? categoryId) {
    _ensureReviewEditable();
    final BankImportReviewRow row = _state.reviewRows[index];
    return _replaceRow(
      index,
      row.copyWith(
        transaction: _copyTransaction(row.transaction, categoryId, row.transaction.journalId),
        manualCategoryId: categoryId,
        manuallyReviewed: true,
      ),
    );
  }

  BankImportWorkflowState linkJournalRow(int index, int? journalId) {
    _ensureReviewEditable();
    final BankImportReviewRow row = _state.reviewRows[index];
    return _replaceRow(
      index,
      row.copyWith(
        transaction: _copyTransaction(row.transaction, row.transaction.kategorieId, journalId),
        manualJournalId: journalId,
        manuallyReviewed: true,
      ),
    );
  }

  BankImportWorkflowState confirm() {
    _ensureStage(BankImportWorkflowStage.review, 'confirm');
    if (_state.includedRows.isNotEmpty && _state.kontoId == null) {
      throw StateError('Select a bank account before confirming the import');
    }
    _emit(_state.copyWith(stage: BankImportWorkflowStage.confirm));
    return _state;
  }

  Future<BankImportWorkflowState> importConfirmed() async {
    _ensureStage(BankImportWorkflowStage.confirm, 'import confirmed rows');
    return _runImport();
  }

  BankImportWorkflowState openHistory() {
    _ensureNotImporting();
    _emit(_state.copyWith(stage: BankImportWorkflowStage.history));
    return _state;
  }

  BankImportWorkflowState beginRetry() {
    _ensureNotImporting();
    final BankImportHistoryEntry? attempt = _state.lastAttempt;
    if (attempt == null || !attempt.canRetry) {
      throw StateError('There is no failed bank-import attempt to retry');
    }
    _emit(
      _state.copyWith(
        stage: BankImportWorkflowStage.retry,
        reviewRows: attempt.retryRows,
        kontoId: attempt.kontoId,
        sourceFileName: attempt.sourceFileName,
        template: attempt.template,
        errorMessage: null,
        recoveryAction: null,
      ),
    );
    return _state;
  }

  Future<BankImportWorkflowState> retry() async {
    if (_state.stage != BankImportWorkflowStage.retry) {
      beginRetry();
    }
    return _runImport();
  }

  BankImportWorkflowState reset() {
    _ensureNotImporting();
    _emit(
      BankImportWorkflowState(
        availableTemplates: _state.availableTemplates,
        history: _state.history,
        importMode: _state.importMode,
        allowDuplicateOverride: _state.allowDuplicateOverride,
      ),
    );
    return _state;
  }

  BankImportWorkflowState _preview(
    String contents,
    BankImportInputFormat format, {
    required String? sourceFileName,
    required int? kontoId,
    required BankTemplate? template,
  }) {
    _ensureNotImporting();
    final String fileName = (sourceFileName ?? _state.sourceFileName ?? _defaultFileName(format)).trim();
    if (fileName.isEmpty) {
      throw ArgumentError.value(sourceFileName, 'sourceFileName', 'must not be empty');
    }
    final BankTemplate? selectedTemplate = template ?? _state.template;
    _emit(
      _state.copyWith(
        stage: BankImportWorkflowStage.preview,
        kontoId: kontoId ?? _state.kontoId,
        sourceFileName: fileName,
        template: selectedTemplate,
        inputFormat: format,
        reviewRows: const <BankImportReviewRow>[],
        lastAttempt: null,
        errorMessage: null,
        recoveryAction: null,
      ),
    );
    try {
      final List<RawTx> parsed = format == BankImportInputFormat.csv
          ? _service.parseCsv(csv: contents, template: selectedTemplate)
          : _service.parseCamtXml(contents);
      _emit(
        _state.copyWith(
          reviewRows: <BankImportReviewRow>[
            for (int index = 0; index < parsed.length; index++)
              BankImportReviewRow(index: index, original: parsed[index], transaction: parsed[index]),
          ],
        ),
      );
    } on BankImportException catch (error) {
      return _recordUnsupported(fileName, selectedTemplate, error.message, recoveryHint: error.recoveryAction);
    } catch (error) {
      return _recordUnsupported(fileName, selectedTemplate, error.toString());
    }
    return _state;
  }

  BankImportWorkflowState _recordUnsupported(
    String fileName,
    BankTemplate? template,
    String message, {
    String? recoveryHint,
  }) {
    final String recoveryText = '${recoveryHint ?? ''} $message'.toLowerCase();
    final BankImportRecoveryAction recovery = recoveryText.contains('template')
        ? BankImportRecoveryAction.selectTemplate
        : BankImportRecoveryAction.selectFile;
    return _finish(
      source: fileName,
      kontoId: _state.kontoId,
      template: template,
      attempted: 0,
      result: null,
      failedCount: 0,
      retryRows: const <BankImportReviewRow>[],
      failedRows: const <ImportRowFailure>[],
      status: BankImportHistoryStatus.unsupported,
      errorMessage: message,
      recoveryAction: recovery,
    );
  }

  Future<BankImportWorkflowState> _runImport() async {
    if (_importInProgress) {
      throw StateError('A bank import is already in progress');
    }
    final BankImportWorkflowState before = _state;
    final List<BankImportReviewRow> candidates = before.includedRows;
    if (candidates.isNotEmpty && before.kontoId == null) {
      throw StateError('Select a bank account before importing confirmed rows');
    }
    _importInProgress = true;
    _emit(before.copyWith(stage: BankImportWorkflowStage.importing, errorMessage: null, recoveryAction: null));
    try {
      final List<RawTx> transactions = <RawTx>[for (final BankImportReviewRow row in candidates) row.transaction];
      final ImportResult result = transactions.isEmpty
          ? const ImportResult(imported: 0, duplicatesSkipped: 0, autoCategorized: 0, manualReview: 0)
          : await _service.importTransactions(
              kontoId: before.kontoId!,
              rawTxs: transactions,
              mode: before.importMode,
              allowDuplicateOverride: before.allowDuplicateOverride,
              dateiname: before.sourceFileName ?? _defaultFileName(before.inputFormat),
              template: before.template,
            );
      final int failed = result.failed;
      final List<BankImportReviewRow> retryRows = result.failedRows.isEmpty && failed > 0
          ? candidates
          : _retryRows(candidates, result.failedRows);
      final String? errorMessage = failed == 0
          ? null
          : result.diagnostics.isEmpty
          ? 'The import service reported $failed failed row(s)'
          : result.diagnostics.join('\n');
      return _finish(
        source: before.sourceFileName ?? _defaultFileName(before.inputFormat),
        kontoId: before.kontoId,
        template: before.template,
        attempted: candidates.length,
        result: result,
        failedCount: failed,
        retryRows: retryRows,
        failedRows: result.failedRows,
        status: candidates.isEmpty
            ? BankImportHistoryStatus.skipped
            : failed == 0
            ? BankImportHistoryStatus.imported
            : BankImportHistoryStatus.partial,
        errorMessage: errorMessage,
        recoveryAction: failed == 0 ? null : BankImportRecoveryAction.retry,
      );
    } catch (error) {
      return _finish(
        source: before.sourceFileName ?? _defaultFileName(before.inputFormat),
        kontoId: before.kontoId,
        template: before.template,
        attempted: candidates.length,
        result: null,
        failedCount: candidates.length,
        retryRows: candidates,
        failedRows: const <ImportRowFailure>[],
        status: BankImportHistoryStatus.failed,
        errorMessage: error.toString(),
        recoveryAction: candidates.isEmpty ? BankImportRecoveryAction.reviewRows : BankImportRecoveryAction.retry,
      );
    } finally {
      _importInProgress = false;
    }
  }

  BankImportWorkflowState _finish({
    required String source,
    required int? kontoId,
    required BankTemplate? template,
    required int attempted,
    required ImportResult? result,
    required int failedCount,
    required List<BankImportReviewRow> retryRows,
    required List<ImportRowFailure> failedRows,
    required BankImportHistoryStatus status,
    String? errorMessage,
    BankImportRecoveryAction? recoveryAction,
  }) {
    final BankImportHistoryEntry entry = BankImportHistoryEntry(
      occurredAt: _clock(),
      sourceFileName: source,
      kontoId: kontoId,
      template: template,
      status: status,
      attempted: attempted,
      result: result,
      failedCount: failedCount,
      retryRows: retryRows,
      failedRows: failedRows,
      errorMessage: errorMessage,
      recoveryAction: recoveryAction,
    );
    final BankImportWorkflowStage stage =
        status == BankImportHistoryStatus.unsupported || status == BankImportHistoryStatus.failed
        ? BankImportWorkflowStage.error
        : BankImportWorkflowStage.history;
    _emit(
      _state.copyWith(
        stage: stage,
        reviewRows: status == BankImportHistoryStatus.unsupported ? const <BankImportReviewRow>[] : null,
        lastAttempt: entry,
        history: <BankImportHistoryEntry>[..._state.history, entry],
        errorMessage: errorMessage,
        recoveryAction: recoveryAction,
      ),
    );
    return _state;
  }

  BankImportWorkflowState _replaceRow(int index, BankImportReviewRow row) {
    final List<BankImportReviewRow> rows = <BankImportReviewRow>[..._state.reviewRows];
    rows[index] = row;
    _emit(_state.copyWith(reviewRows: rows, errorMessage: null, recoveryAction: null));
    return _state;
  }

  List<BankImportReviewRow> _retryRows(List<BankImportReviewRow> candidates, List<ImportRowFailure> failures) {
    if (failures.isEmpty) return const <BankImportReviewRow>[];
    return <BankImportReviewRow>[
      for (final ImportRowFailure failure in failures)
        if (failure.rowIndex >= 0 && failure.rowIndex < candidates.length) candidates[failure.rowIndex],
    ];
  }

  void _ensureReviewEditable() {
    if (_state.stage != BankImportWorkflowStage.review && _state.stage != BankImportWorkflowStage.retry) {
      throw StateError('Rows can only be edited during review or retry');
    }
  }

  void _ensureStage(BankImportWorkflowStage expected, String action) {
    if (_state.stage != expected) {
      throw StateError('Cannot $action while workflow is in ${_state.stage.name} stage');
    }
  }

  void _ensureNotImporting() {
    if (_importInProgress || _state.stage == BankImportWorkflowStage.importing) {
      throw StateError('Cannot change the workflow while an import is in progress');
    }
  }

  void _emit(BankImportWorkflowState next) {
    _state = next;
    notifyListeners();
  }

  String _defaultFileName(BankImportInputFormat? format) =>
      format == BankImportInputFormat.camtXml ? 'import.xml' : 'import.csv';
}

typedef BankImportWorkflow = BankImportWorkflowCoordinator;

RawTx _copyTransaction(RawTx transaction, int? categoryId, int? journalId) {
  return RawTx(
    datum: transaction.datum,
    betrag: transaction.betrag,
    verwendungszweck: transaction.verwendungszweck,
    partner: transaction.partner,
    gegenkonto: transaction.gegenkonto,
    kategorieId: categoryId,
    journalId: journalId,
    dedupeHash: transaction.dedupeHash,
  );
}
