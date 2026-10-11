// Typed CSV import boundary for master data (customers, suppliers, articles).
// Pure Dart: no Flutter dependency so VM tests can drive preview/commit.

/// Entity targeted by one import run. Exactly one table per run, never mixed.
enum MasterDataImportEntity { customer, supplier, article }

/// User-selected field delimiter. No auto-detection: guessing can silently
/// reinterpret descriptions and prices.
enum CsvImportDelimiter { comma, semicolon, tab }

/// Numeric convention selected for the whole file.
enum CsvDecimalConvention { point, comma }

/// Duplicate strategy. New templates default to [skip].
enum MasterDataDuplicatePolicy { skip, update, createNew }

/// Price input basis for article Create rows.
enum ArticlePriceBasis { net, gross }

/// Proposed action for a preview row after validation + duplicate detection.
enum MasterDataRowAction { create, update, skip, invalid, ambiguous }

/// Per-row selection confirmed by the user before commit.
enum MasterDataRowSelection { create, update, skip, excluded }

/// Import failure that rolls back the whole batch and stays retryable.
class MasterDataCsvImportException implements Exception {
  const MasterDataCsvImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// File-level parse failure. No master-data row, template, or history write.
class MasterDataCsvParseException extends MasterDataCsvImportException {
  const MasterDataCsvParseException(super.message);
}

/// Mapping/template failure. Preview is never entered on conflict.
class MasterDataCsvMappingException extends MasterDataCsvImportException {
  const MasterDataCsvMappingException(super.message);
}

/// Unavailable profile database while loading templates or candidates.
class MasterDataCsvUnavailableException extends MasterDataCsvImportException {
  const MasterDataCsvUnavailableException(super.message);
}

/// Column-index-to-field mapping plus file options for one entity.
class MasterDataFieldMapping {
  const MasterDataFieldMapping({
    required this.entity,
    required this.columnToField,
    required this.hasHeader,
    required this.delimiter,
    required this.decimalConvention,
    required this.duplicatePolicy,
    this.matchField,
    this.articlePriceBasis,
  });

  final MasterDataImportEntity entity;
  final Map<int, String> columnToField;
  final bool hasHeader;
  final CsvImportDelimiter delimiter;
  final CsvDecimalConvention decimalConvention;
  final MasterDataDuplicatePolicy duplicatePolicy;
  final String? matchField;
  final ArticlePriceBasis? articlePriceBasis;

  MasterDataFieldMapping copyWith({
    MasterDataImportEntity? entity,
    Map<int, String>? columnToField,
    bool? hasHeader,
    CsvImportDelimiter? delimiter,
    CsvDecimalConvention? decimalConvention,
    MasterDataDuplicatePolicy? duplicatePolicy,
    String? Function()? matchField,
    ArticlePriceBasis? Function()? articlePriceBasis,
  }) {
    return MasterDataFieldMapping(
      entity: entity ?? this.entity,
      columnToField: columnToField ?? Map<int, String>.from(this.columnToField),
      hasHeader: hasHeader ?? this.hasHeader,
      delimiter: delimiter ?? this.delimiter,
      decimalConvention: decimalConvention ?? this.decimalConvention,
      duplicatePolicy: duplicatePolicy ?? this.duplicatePolicy,
      matchField: matchField != null ? matchField() : this.matchField,
      articlePriceBasis: articlePriceBasis != null ? articlePriceBasis() : this.articlePriceBasis,
    );
  }
}

/// One parsed data row with its original 1-based file row number.
class MasterDataCsvRow {
  const MasterDataCsvRow({required this.sourceRowNumber, required this.cells});

  final int sourceRowNumber;
  final List<String> cells;
}

/// Parsed file: optional header labels plus data rows.
class MasterDataParsedCsv {
  const MasterDataParsedCsv({required this.header, required this.rows, required this.totalDataRows});

  final List<String>? header;
  final List<MasterDataCsvRow> rows;
  final int totalDataRows;
}

/// Field-level validation error with a localized message.
class MasterDataFieldError {
  const MasterDataFieldError({required this.field, required this.messageDe, required this.messageEn});

  final String field;
  final String messageDe;
  final String messageEn;

  String messageFor(String locale) => locale.startsWith('en') ? messageEn : messageDe;
}

/// Preview of one source row: mapped values, errors, duplicate state.
class MasterDataRowPreview {
  const MasterDataRowPreview({
    required this.sourceRowNumber,
    required this.mappedValues,
    required this.errors,
    required this.matchCount,
    required this.isSourceDuplicate,
    required this.proposedAction,
    required this.isDuplicateLabelled,
    this.existingId,
    this.oldValues,
  });

  final int sourceRowNumber;
  final Map<String, String> mappedValues;
  final List<MasterDataFieldError> errors;
  final int matchCount;
  final bool isSourceDuplicate;
  final MasterDataRowAction proposedAction;
  final bool isDuplicateLabelled;
  final int? existingId;
  final Map<String, String>? oldValues;

  bool get isValid => errors.isEmpty;
}

/// Full preview before any write.
class MasterDataImportPreview {
  const MasterDataImportPreview({required this.rows, required this.entity});

  final List<MasterDataRowPreview> rows;
  final MasterDataImportEntity entity;

  int get validCount => rows.where((r) => r.isValid).length;

  int get invalidCount => rows.where((r) => !r.isValid).length;

  int get duplicateCount => rows.where((r) => r.isDuplicateLabelled || r.matchCount > 0).length;

  int get createCount => rows.where((r) => r.proposedAction == MasterDataRowAction.create).length;

  int get updateCount => rows.where((r) => r.proposedAction == MasterDataRowAction.update).length;

  int get skipCount => rows.where((r) => r.proposedAction == MasterDataRowAction.skip).length;
}

/// Reviewed batch: preview plus explicit per-row selections.
class MasterDataReviewedBatch {
  const MasterDataReviewedBatch({required this.preview, required this.selections});

  final MasterDataImportPreview preview;
  final Map<int, MasterDataRowSelection> selections;
}

/// Atomic commit result. Success counts only; failure carries no success count.
class MasterDataImportResult {
  const MasterDataImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.invalid,
    this.failureMessage,
  });

  final int created;
  final int updated;
  final int skipped;
  final int invalid;
  final String? failureMessage;

  bool get isFailure => failureMessage != null;
}

/// Reusable mapping template. Never contains file bytes or row values.
class MasterDataImportTemplate {
  const MasterDataImportTemplate({
    required this.id,
    required this.name,
    required this.entity,
    required this.mapping,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final MasterDataImportEntity entity;
  final MasterDataFieldMapping mapping;
  final String createdAt;
  final String updatedAt;
}

/// Supported scalar destination fields per entity. Primary keys, generated
/// numbers, foreign keys, stock, and inventory controls are never exposed.
class MasterDataImportFields {
  static const Set<String> customerFields = <String>{
    'anrede',
    'name',
    'firma',
    'strasse',
    'hausnummer',
    'plz',
    'ort',
    'land',
    'ust_idnr',
    'steuernummer_ausland',
    'telefon',
    'email',
    'zahlungsziel',
    'skonto_prozent',
    'skonto_tage',
    'kreditlimit',
    'note',
  };

  static const Set<String> supplierFields = <String>{
    'anrede',
    'name',
    'firma',
    'strasse',
    'hausnummer',
    'plz',
    'ort',
    'land',
    'ust_idnr',
    'steuernummer_ausland',
    'telefon',
    'email',
    'iban',
    'zahlungsziel',
    'skonto_prozent',
    'skonto_tage',
    'note',
  };

  static const Set<String> articleCreateFields = <String>{
    'bezeichnung',
    'beschreibung',
    'typ',
    'einheit',
    'artikelnummer',
    'vk_netto',
    'vk_brutto',
    'ek_netto',
    'ust_satz',
    'ust_satz_id',
  };

  /// Article Update accepts the same scalar fields except the paired
  /// selling-price and derivation fields, which are rejected row-wide.
  static const Set<String> articleUpdateForbidden = <String>{
    'vk_netto',
    'vk_brutto',
    'vk_eingabe',
    'ust_satz',
    'ust_satz_id',
    'differenzbesteuerung',
  };

  static const Set<String> articleUpdateFields = <String>{
    'bezeichnung',
    'beschreibung',
    'typ',
    'einheit',
    'artikelnummer',
    'ek_netto',
  };

  static Set<String> allowedFor(MasterDataImportEntity entity) {
    switch (entity) {
      case MasterDataImportEntity.customer:
        return customerFields;
      case MasterDataImportEntity.supplier:
        return supplierFields;
      case MasterDataImportEntity.article:
        return articleCreateFields;
    }
  }

  /// Numeric target fields parsed under the selected decimal convention.
  static const Set<String> numericFields = <String>{
    'zahlungsziel',
    'skonto_prozent',
    'skonto_tage',
    'kreditlimit',
    'vk_netto',
    'vk_brutto',
    'ek_netto',
    'ust_satz',
    'ust_satz_id',
  };

  static String normalizeField(String raw) {
    final String v = raw.trim();
    // Accept both camelCase repository aliases and snake_case columns.
    switch (v) {
      case 'ustIdNr':
        return 'ust_idnr';
      case 'foreignTaxNumber':
      case 'steuernummerAusland':
        return 'steuernummer_ausland';
      case 'skontoProzent':
        return 'skonto_prozent';
      case 'skontoTage':
        return 'skonto_tage';
      case 'vkNetto':
        return 'vk_netto';
      case 'vkBrutto':
        return 'vk_brutto';
      case 'vkEingabe':
        return 'vk_eingabe';
      case 'ustSatzId':
        return 'ust_satz_id';
      case 'ustSatz':
        return 'ust_satz';
      case 'ekNetto':
        return 'ek_netto';
      default:
        return v;
    }
  }
}
