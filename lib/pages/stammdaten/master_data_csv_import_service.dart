import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_parser.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_templates.dart';

/// Typed import boundary over the active-profile database. Parsing stays
/// pure; this service owns preview validation, exact duplicate review, and
/// the single atomic commit transaction. No writes happen before confirmation.
class MasterDataCsvImportService {
  MasterDataCsvImportService(this.executor);

  final QueryExecutor executor;

  late final MasterDataImportTemplateStore templates = MasterDataImportTemplateStore(executor);

  static const Set<String> _articleTypes = <String>{'Artikel', 'Dienstleistung', 'Fremdleistung', 'Eigenleistung'};

  static const Map<String, String> _fallbackVatPatterns = <String, String>{
    'DE': r'^DE[0-9]{9}$',
    'AT': r'^ATU[0-9]{8}$',
    'FR': r'^FR[0-9A-Z]{2}[0-9]{9}$',
    'IT': r'^IT[0-9]{11}$',
    'ES': r'^ES[A-Z0-9][0-9]{7}[A-Z0-9]$',
    'NL': r'^NL[0-9]{9}B[0-9]{2}$',
    'PL': r'^PL[0-9]{10}$',
    'BE': r'^BE[0-9]{10}$',
    'SE': r'^SE[0-9]{12}$',
    'DK': r'^DK[0-9]{8}$',
    'FI': r'^FI[0-9]{8}$',
    'IE': r'^IE[0-9][0-9A-Z*+][0-9]{5}[A-Z]{1,2}$',
    'PT': r'^PT[0-9]{9}$',
    'CZ': r'^CZ[0-9]{8,10}$',
    'HR': r'^HR[0-9]{9,12}$',
    'HU': r'^HU[0-9]{8}$',
    'RO': r'^RO[0-9]{2,10}$',
    'BG': r'^BG[0-9]{9,10}$',
    'SK': r'^SK[0-9]{10}$',
    'SI': r'^SI[0-9]{8}$',
    'LT': r'^LT[0-9]{9,12}$',
    'LV': r'^LV[0-9]{11}$',
    'EE': r'^EE[0-9]{9}$',
    'CY': r'^CY[0-9]{8}[A-Z]$',
    'MT': r'^MT[0-9]{8}$',
    'LU': r'^LU[0-9]{8}$',
    'GR': r'^EL[0-9]{9}$',
  };

  // -- Preview ------------------------------------------------------------

  /// Parses and validates the complete file. Never writes business records.
  Future<MasterDataImportPreview> buildPreview(MasterDataParsedCsv parsed, MasterDataFieldMapping mapping) async {
    MasterDataImportTemplateStore.validateMapping(mapping);
    _assertMappingFitsColumns(parsed, mapping);
    final QueryExecutor reader = executor;
    final List<_ExistingRecord> existing = await _loadExisting(reader, mapping.entity);
    return _previewWithExisting(parsed, mapping, existing, reader);
  }

  void _assertMappingFitsColumns(MasterDataParsedCsv parsed, MasterDataFieldMapping mapping) {
    final int width = _parsedWidth(parsed);
    for (final int col in mapping.columnToField.keys) {
      if (col < 0 || col >= width) {
        throw const MasterDataCsvMappingException('Spaltenzuordnung passt nicht zur Datei.');
      }
    }
  }

  int _parsedWidth(MasterDataParsedCsv parsed) {
    if (parsed.header != null) return parsed.header!.length;
    if (parsed.rows.isNotEmpty) return parsed.rows.first.cells.length;
    return 0;
  }

  Future<MasterDataImportPreview> _previewWithExisting(
    MasterDataParsedCsv parsed,
    MasterDataFieldMapping mapping,
    List<_ExistingRecord> existing,
    QueryExecutor reader,
  ) async {
    // Mapped values per row (trimmed, inert).
    final List<Map<String, String>> mappedPerRow = <Map<String, String>>[];
    for (final MasterDataCsvRow row in parsed.rows) {
      final Map<String, String> mapped = <String, String>{};
      mapping.columnToField.forEach((int col, String rawField) {
        final String field = MasterDataImportFields.normalizeField(rawField);
        final String value = col < row.cells.length ? row.cells[col].trim() : '';
        mapped[field] = value;
      });
      mappedPerRow.add(mapped);
    }
    final List<int> rowNumbers = <int>[for (final MasterDataCsvRow r in parsed.rows) r.sourceRowNumber];
    return _previewFromMappedValues(rowNumbers, mappedPerRow, mapping, existing, reader);
  }

  Future<MasterDataImportPreview> _previewFromMappedValues(
    List<int> rowNumbers,
    List<Map<String, String>> mappedPerRow,
    MasterDataFieldMapping mapping,
    List<_ExistingRecord> existing,
    QueryExecutor reader,
  ) async {
    // Source-key repetition (normalized) marks ambiguity.
    final Map<String, List<int>> keyToIndexes = <String, List<int>>{};
    final String? matchField = mapping.matchField == null
        ? null
        : MasterDataImportFields.normalizeField(mapping.matchField!);
    if (matchField != null) {
      for (int i = 0; i < mappedPerRow.length; i++) {
        final String key = _normalizeKey(mappedPerRow[i][matchField] ?? '', matchField, mapping.decimalConvention);
        if (key.isEmpty) continue;
        keyToIndexes.putIfAbsent(key, () => <int>[]).add(i);
      }
    }
    final List<MasterDataRowPreview> previews = <MasterDataRowPreview>[];
    for (int i = 0; i < mappedPerRow.length; i++) {
      final int sourceRow = i < rowNumbers.length ? rowNumbers[i] : i + 1;
      final Map<String, String> mapped = mappedPerRow[i];
      final _MatchResult match = _findMatches(mapped, matchField, mapping, existing);
      final bool sourceDup =
          matchField != null &&
          _normalizeKey(mapped[matchField] ?? '', matchField, mapping.decimalConvention).isNotEmpty &&
          (keyToIndexes[_normalizeKey(mapped[matchField] ?? '', matchField, mapping.decimalConvention)]?.length ?? 0) >
              1;
      // Tentative update candidacy (single exact match under Update).
      final bool updateCandidate =
          mapping.duplicatePolicy == MasterDataDuplicatePolicy.update && match.ids.length == 1 && !sourceDup;
      final List<MasterDataFieldError> errors = await _validateRow(mapped, mapping, reader, isUpdate: updateCandidate);
      MasterDataRowAction action;
      bool labelled = match.ids.isNotEmpty;
      if (errors.isNotEmpty) {
        action = MasterDataRowAction.invalid;
      } else if (sourceDup || match.ids.length > 1) {
        action = MasterDataRowAction.ambiguous;
      } else if (mapping.duplicatePolicy == MasterDataDuplicatePolicy.skip) {
        action = match.ids.isEmpty ? MasterDataRowAction.create : MasterDataRowAction.skip;
        if (match.ids.isNotEmpty) labelled = true;
      } else if (mapping.duplicatePolicy == MasterDataDuplicatePolicy.update) {
        if (match.ids.isEmpty) {
          action = MasterDataRowAction.create;
          labelled = false;
        } else {
          action = MasterDataRowAction.update;
        }
      } else {
        action = MasterDataRowAction.create;
        labelled = match.ids.isNotEmpty;
      }
      Map<String, String>? oldValues;
      if (action == MasterDataRowAction.update) {
        oldValues = _oldValuesFor(match.ids.single, mapped, existing);
      }
      previews.add(
        MasterDataRowPreview(
          sourceRowNumber: sourceRow,
          mappedValues: Map<String, String>.unmodifiable(mapped),
          errors: errors,
          matchCount: match.ids.length,
          isSourceDuplicate: sourceDup,
          proposedAction: action,
          isDuplicateLabelled: labelled,
          existingId: match.ids.length == 1 ? match.ids.single : null,
          oldValues: oldValues,
        ),
      );
    }
    return MasterDataImportPreview(rows: previews, entity: mapping.entity);
  }

  // -- Commit ---------------------------------------------------------------

  /// Commits the reviewed batch in one transaction. Recomputes duplicates
  /// inside the transaction; any failure rolls back everything with no
  /// success count. Only explicitly selected creates/updates are written.
  Future<MasterDataImportResult> commit(MasterDataReviewedBatch batch, MasterDataFieldMapping mapping) async {
    MasterDataImportTemplateStore.validateMapping(mapping);
    final TransactionExecutor tx = executor.beginTransaction();
    try {
      await tx.ensureOpen(_NoopImportUser());
      final List<_ExistingRecord> existing = await _loadExisting(tx, mapping.entity);
      // Recompute duplicates against live data inside the transaction from
      // the reviewed mapped values; stale preview evidence never overwrites.
      final List<int> rowNumbers = <int>[for (final MasterDataRowPreview r in batch.preview.rows) r.sourceRowNumber];
      final List<Map<String, String>> mappedPerRow = <Map<String, String>>[
        for (final MasterDataRowPreview r in batch.preview.rows) Map<String, String>.from(r.mappedValues),
      ];
      final MasterDataImportPreview fresh = await _previewFromMappedValues(
        rowNumbers,
        mappedPerRow,
        mapping,
        existing,
        tx,
      );
      int created = 0;
      int updated = 0;
      int skipped = 0;
      int invalid = 0;
      // Apply selections in file order; counts reflect applied selections.
      for (final MasterDataRowPreview row in fresh.rows) {
        final MasterDataRowSelection selection = batch.selections[row.sourceRowNumber] ?? _defaultSelection(row);
        if (selection == MasterDataRowSelection.create) {
          if (row.proposedAction == MasterDataRowAction.invalid ||
              row.proposedAction == MasterDataRowAction.ambiguous) {
            throw MasterDataCsvImportException(
              'Zeile ${row.sourceRowNumber} ist ungültig und kann nicht übernommen werden.',
            );
          }
          if (row.proposedAction == MasterDataRowAction.skip || row.proposedAction == MasterDataRowAction.update) {
            // Explicit override: Skip->Create and Update->Create (unmatched)
            // are allowed only when the fresh preview proposes create or the
            // user confirms a CreateNew duplicate label.
            if (mapping.duplicatePolicy != MasterDataDuplicatePolicy.createNew &&
                row.proposedAction != MasterDataRowAction.create) {
              throw MasterDataCsvImportException(
                'Zeile ${row.sourceRowNumber} ist nicht als Neuerstellung vorgesehen.',
              );
            }
          }
          await _insertRow(tx, mapping, row.mappedValues);
          created++;
        } else if (selection == MasterDataRowSelection.update) {
          if (row.proposedAction != MasterDataRowAction.update || row.existingId == null) {
            throw MasterDataCsvImportException(
              'Zeile ${row.sourceRowNumber} hat kein eindeutiges Duplikat für Aktualisierung.',
            );
          }
          await _updateRow(tx, mapping, row.existingId!, row.mappedValues);
          updated++;
        } else if (selection == MasterDataRowSelection.skip) {
          skipped++;
        } else if (row.proposedAction == MasterDataRowAction.skip) {
          // Explicitly excluded but proposed skip: record stays unchanged.
          skipped++;
        } else if (row.proposedAction == MasterDataRowAction.invalid ||
            row.proposedAction == MasterDataRowAction.ambiguous) {
          invalid++;
        }
      }
      await tx.send();
      return MasterDataImportResult(created: created, updated: updated, skipped: skipped, invalid: invalid);
    } catch (error, stackTrace) {
      try {
        await tx.rollback();
      } catch (_) {}
      if (error is MasterDataCsvImportException) {
        // Retryable batch failure with no success count.
        int skipped = 0;
        int invalid = 0;
        for (final MasterDataRowPreview row in batch.preview.rows) {
          if (row.proposedAction == MasterDataRowAction.skip) skipped++;
          if (row.proposedAction == MasterDataRowAction.invalid ||
              row.proposedAction == MasterDataRowAction.ambiguous) {
            invalid++;
          }
        }
        return MasterDataImportResult(
          created: 0,
          updated: 0,
          skipped: skipped,
          invalid: invalid,
          failureMessage: error.message,
        );
      }
      Error.throwWithStackTrace(
        MasterDataCsvImportException('Import fehlgeschlagen; keine Zeile wurde übernommen: $error'),
        stackTrace,
      );
    }
  }

  MasterDataRowSelection _defaultSelection(MasterDataRowPreview row) {
    switch (row.proposedAction) {
      case MasterDataRowAction.create:
        return MasterDataRowSelection.create;
      case MasterDataRowAction.skip:
        return MasterDataRowSelection.skip;
      case MasterDataRowAction.update:
        // Updates require explicit per-row selection; default excludes.
        return MasterDataRowSelection.excluded;
      case MasterDataRowAction.invalid:
      case MasterDataRowAction.ambiguous:
        return MasterDataRowSelection.excluded;
    }
  }

  // -- Validation -----------------------------------------------------------

  Future<List<MasterDataFieldError>> _validateRow(
    Map<String, String> mapped,
    MasterDataFieldMapping mapping,
    QueryExecutor reader, {
    required bool isUpdate,
  }) async {
    switch (mapping.entity) {
      case MasterDataImportEntity.customer:
      case MasterDataImportEntity.supplier:
        return _validateContact(mapped, mapping, reader, isUpdate: isUpdate);
      case MasterDataImportEntity.article:
        return _validateArticle(mapped, mapping, isUpdate: isUpdate);
    }
  }

  Future<List<MasterDataFieldError>> _validateContact(
    Map<String, String> mapped,
    MasterDataFieldMapping mapping,
    QueryExecutor reader, {
    required bool isUpdate,
  }) async {
    final List<MasterDataFieldError> errors = <MasterDataFieldError>[];
    void requiredField(String field, String labelDe, String labelEn) {
      final String value = (mapped[field] ?? '').trim();
      final bool present = mapped.containsKey(field);
      if (isUpdate && (!present || value.isEmpty)) return; // blank preserves.
      if (value.isEmpty) {
        errors.add(
          MasterDataFieldError(field: field, messageDe: '$labelDe ist Pflicht.', messageEn: '$labelEn is required.'),
        );
      }
    }

    requiredField('name', 'Name', 'Name');
    requiredField('strasse', 'Straße', 'Street');
    requiredField('plz', 'PLZ', 'Postal code');
    requiredField('ort', 'Ort', 'City');
    // anrede/land have repository defaults; only validate supplied values.
    if ((mapped['anrede'] ?? '').trim().isEmpty && mapped.containsKey('anrede') && !isUpdate) {
      errors.add(
        const MasterDataFieldError(
          field: 'anrede',
          messageDe: 'Anrede ist Pflicht.',
          messageEn: 'Salutation is required.',
        ),
      );
    }
    // Numeric fields under the selected convention.
    for (final String field in <String>['zahlungsziel', 'skonto_tage', 'skonto_prozent', 'kreditlimit']) {
      if (!mapped.containsKey(field)) continue;
      final String raw = (mapped[field] ?? '').trim();
      if (raw.isEmpty) {
        if (isUpdate) continue;
        if (field == 'zahlungsziel' || field == 'skonto_tage' || field == 'skonto_prozent') continue; // defaults apply.
        continue;
      }
      if (MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention) == null) {
        errors.add(
          MasterDataFieldError(
            field: field,
            messageDe: '$field ist keine gültige Zahl.',
            messageEn: '$field is not a valid number.',
          ),
        );
      } else if ((field == 'zahlungsziel' || field == 'skonto_tage') &&
          num.tryParse(MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention)!)?.toInt() == null) {
        errors.add(
          MasterDataFieldError(
            field: field,
            messageDe: '$field muss eine ganze Zahl sein.',
            messageEn: '$field must be a whole number.',
          ),
        );
      }
    }
    // VAT ID against country-specific pattern (existing typed rule).
    final String ustId = (mapped['ust_idnr'] ?? '').trim();
    if (ustId.isNotEmpty) {
      final String country = ((mapped['land'] ?? '').trim().isEmpty ? 'DE' : mapped['land']!.trim()).toUpperCase();
      final bool valid = await _validateVatId(reader, country, ustId);
      if (!valid) {
        errors.add(
          MasterDataFieldError(
            field: 'ust_idnr',
            messageDe: 'USt-IdNr ungültig für $country.',
            messageEn: 'VAT ID invalid for $country.',
          ),
        );
      }
    }
    final String foreign = (mapped['steuernummer_ausland'] ?? '').trim();
    if (foreign.length > 50) {
      errors.add(
        const MasterDataFieldError(
          field: 'steuernummer_ausland',
          messageDe: 'Steuernummer Ausland darf höchstens 50 Zeichen enthalten.',
          messageEn: 'Foreign tax number must not exceed 50 characters.',
        ),
      );
    }
    return errors;
  }

  Future<List<MasterDataFieldError>> _validateArticle(
    Map<String, String> mapped,
    MasterDataFieldMapping mapping, {
    required bool isUpdate,
  }) async {
    final List<MasterDataFieldError> errors = <MasterDataFieldError>[];
    if (isUpdate) {
      // Forbidden price/derivation fields reject the whole row.
      for (final String field in MasterDataImportFields.articleUpdateForbidden) {
        if ((mapped[field] ?? '').trim().isNotEmpty) {
          errors.add(
            MasterDataFieldError(
              field: field,
              messageDe: '$field wird für Artikel-Aktualisierung nicht unterstützt.',
              messageEn: '$field is not supported for article update.',
            ),
          );
        }
      }
      if (errors.isNotEmpty) return errors;
      // Other supplied values use typed rules; blanks preserve.
      final String typ = (mapped['typ'] ?? '').trim();
      if (typ.isNotEmpty && !_articleTypes.contains(typ)) {
        errors.add(
          MasterDataFieldError(field: 'typ', messageDe: 'Ungültiger Typ: $typ.', messageEn: 'Invalid type: $typ.'),
        );
      }
      // Blank bezeichnung preserves the stored value on update; no required check here.
      final String ek = (mapped['ek_netto'] ?? '').trim();
      if (ek.isNotEmpty && MasterDataNumericParser.tryNormalize(ek, mapping.decimalConvention) == null) {
        errors.add(
          const MasterDataFieldError(
            field: 'ek_netto',
            messageDe: 'ek_netto ist keine gültige Zahl.',
            messageEn: 'ek_netto is not a valid number.',
          ),
        );
      }
      return errors;
    }
    // Create validation: full required contract.
    if ((mapped['bezeichnung'] ?? '').trim().isEmpty) {
      errors.add(
        const MasterDataFieldError(
          field: 'bezeichnung',
          messageDe: 'Bezeichnung ist Pflicht.',
          messageEn: 'Name is required.',
        ),
      );
    }
    final String typ = (mapped['typ'] ?? '').trim();
    if (mapped.containsKey('typ') && !_articleTypes.contains(typ)) {
      errors.add(
        MasterDataFieldError(field: 'typ', messageDe: 'Ungültiger Typ: $typ.', messageEn: 'Invalid type: $typ.'),
      );
    }
    final ArticlePriceBasis? basis = mapping.articlePriceBasis;
    if (basis == null) {
      errors.add(
        const MasterDataFieldError(
          field: 'vk_eingabe',
          messageDe: 'Preisbasis ist erforderlich.',
          messageEn: 'Price basis is required.',
        ),
      );
    } else {
      final String net = (mapped['vk_netto'] ?? '').trim();
      final String gross = (mapped['vk_brutto'] ?? '').trim();
      final String selected = basis == ArticlePriceBasis.net ? net : gross;
      final String unselected = basis == ArticlePriceBasis.net ? gross : net;
      if (selected.isEmpty || MasterDataNumericParser.tryNormalize(selected, mapping.decimalConvention) == null) {
        errors.add(
          MasterDataFieldError(
            field: basis == ArticlePriceBasis.net ? 'vk_netto' : 'vk_brutto',
            messageDe: 'Verkaufspreis ist keine gültige Zahl.',
            messageEn: 'Selling price is not a valid number.',
          ),
        );
      }
      if (unselected.isNotEmpty) {
        errors.add(
          const MasterDataFieldError(
            field: 'vk_eingabe',
            messageDe: 'Nur eine Preisbasis (netto oder brutto) ist zulässig.',
            messageEn: 'Only one price basis (net or gross) is allowed.',
          ),
        );
      }
    }
    for (final String field in <String>['ek_netto', 'ust_satz']) {
      if (!mapped.containsKey(field)) continue;
      final String raw = (mapped[field] ?? '').trim();
      if (raw.isEmpty) continue;
      if (MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention) == null) {
        errors.add(
          MasterDataFieldError(
            field: field,
            messageDe: '$field ist keine gültige Zahl.',
            messageEn: '$field is not a valid number.',
          ),
        );
      }
    }
    if (mapped.containsKey('ust_satz_id')) {
      final String raw = (mapped['ust_satz_id'] ?? '').trim();
      if (raw.isNotEmpty) {
        final String? norm = MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention);
        if (norm == null || int.tryParse(norm) == null) {
          errors.add(
            const MasterDataFieldError(
              field: 'ust_satz_id',
              messageDe: 'ust_satz_id muss eine ganze Zahl sein.',
              messageEn: 'ust_satz_id must be a whole number.',
            ),
          );
        }
      }
    }
    return errors;
  }

  Future<bool> _validateVatId(QueryExecutor reader, String country, String value) async {
    String? pattern;
    try {
      final List<Map<String, Object?>> rows = await reader.runSelect(
        'SELECT ust_idnr_format FROM eu_laender WHERE laendercode = ?',
        <Object?>[country],
      );
      final Object? seeded = rows.isEmpty ? null : rows.single['ust_idnr_format'];
      if (seeded != null && seeded.toString().trim().isNotEmpty) pattern = seeded.toString();
    } catch (_) {
      pattern = null;
    }
    pattern ??= _fallbackVatPatterns[country];
    if (pattern == null) return true;
    try {
      return RegExp(pattern).hasMatch(value);
    } on FormatException {
      return false;
    }
  }

  // -- Duplicates -----------------------------------------------------------

  String _normalizeKey(String value, String field, CsvDecimalConvention convention) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (MasterDataImportFields.numericFields.contains(field)) {
      final String? norm = MasterDataNumericParser.tryNormalize(trimmed, convention);
      return norm ?? trimmed;
    }
    return trimmed.toLowerCase();
  }

  _MatchResult _findMatches(
    Map<String, String> mapped,
    String? matchField,
    MasterDataFieldMapping mapping,
    List<_ExistingRecord> existing,
  ) {
    if (matchField == null) return const _MatchResult(<int>[]);
    final String raw = (mapped[matchField] ?? '').trim();
    if (raw.isEmpty) return const _MatchResult(<int>[]);
    final String key = _normalizeKey(raw, matchField, mapping.decimalConvention);
    final List<int> ids = <int>[];
    for (final _ExistingRecord record in existing) {
      final String stored = (record.values[matchField] ?? '').trim();
      if (stored.isEmpty) continue;
      if (MasterDataImportFields.numericFields.contains(matchField)) {
        final bool? eq = MasterDataNumericParser.exactEquals(raw, stored, mapping.decimalConvention);
        if (eq == true) ids.add(record.id);
      } else {
        if (stored.toLowerCase() == key) ids.add(record.id);
      }
    }
    return _MatchResult(ids);
  }

  Map<String, String> _oldValuesFor(int id, Map<String, String> mapped, List<_ExistingRecord> existing) {
    final _ExistingRecord record = existing.singleWhere(
      (r) => r.id == id,
      orElse: () => _ExistingRecord(id, const <String, String>{}),
    );
    final Map<String, String> old = <String, String>{};
    for (final String field in mapped.keys) {
      final String current = (record.values[field] ?? '').trim();
      final String proposed = (mapped[field] ?? '').trim();
      if (proposed.isNotEmpty && proposed != current) old[field] = current;
    }
    return old;
  }

  Future<List<_ExistingRecord>> _loadExisting(QueryExecutor reader, MasterDataImportEntity entity) async {
    try {
      switch (entity) {
        case MasterDataImportEntity.customer:
          final List<Map<String, Object?>> rows = await reader.runSelect(
            'SELECT id, anrede, name, firma, strasse, hausnummer, plz, ort, land, ust_idnr, '
            'steuernummer_ausland, telefon, email, zahlungsziel, skonto_prozent, skonto_tage, kreditlimit, note '
            'FROM kunden ORDER BY id',
            const <Object?>[],
          );
          return <_ExistingRecord>[
            for (final Map<String, Object?> r in rows) _ExistingRecord(_asInt(r['id']), _stringMap(r)),
          ];
        case MasterDataImportEntity.supplier:
          final List<Map<String, Object?>> rows = await reader.runSelect(
            'SELECT id, anrede, name, firma, strasse, hausnummer, plz, ort, land, ust_idnr, '
            'steuernummer_ausland, telefon, email, iban, zahlungsziel, skonto_prozent, skonto_tage, note '
            'FROM lieferanten ORDER BY id',
            const <Object?>[],
          );
          return <_ExistingRecord>[
            for (final Map<String, Object?> r in rows) _ExistingRecord(_asInt(r['id']), _stringMap(r)),
          ];
        case MasterDataImportEntity.article:
          final List<Map<String, Object?>> rows = await reader.runSelect(
            'SELECT id, bezeichnung, beschreibung, typ, einheit, artikelnummer, vk_netto, vk_brutto, vk_eingabe, '
            'ust_satz_id, ust_satz, differenzbesteuerung, ek_netto FROM artikel ORDER BY id',
            const <Object?>[],
          );
          return <_ExistingRecord>[
            for (final Map<String, Object?> r in rows) _ExistingRecord(_asInt(r['id']), _stringMap(r)),
          ];
      }
    } catch (_) {
      throw const MasterDataCsvUnavailableException('Stammdaten konnten nicht geladen werden.');
    }
  }

  static int _asInt(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static Map<String, String> _stringMap(Map<String, Object?> row) {
    final Map<String, String> out = <String, String>{};
    row.forEach((String key, Object? value) {
      if (key == 'id') return;
      out[key] = value?.toString() ?? '';
    });
    // Repository aliases used in mappings.
    if (row.containsKey('ust_idnr')) out['ust_idnr'] = row['ust_idnr']?.toString() ?? '';
    return out;
  }

  // -- Transactional writes (same validators/allocator as repositories) ------

  Future<void> _insertRow(QueryExecutor tx, MasterDataFieldMapping mapping, Map<String, String> mapped) async {
    switch (mapping.entity) {
      case MasterDataImportEntity.customer:
        await _insertCustomer(tx, mapping, mapped);
      case MasterDataImportEntity.supplier:
        await _insertSupplier(tx, mapping, mapped);
      case MasterDataImportEntity.article:
        await _insertArticle(tx, mapping, mapped);
    }
  }

  Future<void> _updateRow(QueryExecutor tx, MasterDataFieldMapping mapping, int id, Map<String, String> mapped) async {
    // Only explicitly mapped, non-empty values participate; blanks preserve.
    final Map<String, Object?> assignments = <String, Object?>{};
    if (mapping.entity == MasterDataImportEntity.customer || mapping.entity == MasterDataImportEntity.supplier) {
      const Map<String, String> columns = <String, String>{
        'anrede': 'anrede',
        'name': 'name',
        'firma': 'firma',
        'strasse': 'strasse',
        'hausnummer': 'hausnummer',
        'plz': 'plz',
        'ort': 'ort',
        'land': 'land',
        'ust_idnr': 'ust_idnr',
        'steuernummer_ausland': 'steuernummer_ausland',
        'telefon': 'telefon',
        'email': 'email',
        'iban': 'iban',
        'zahlungsziel': 'zahlungsziel',
        'skonto_prozent': 'skonto_prozent',
        'skonto_tage': 'skonto_tage',
        'kreditlimit': 'kreditlimit',
        'note': 'note',
      };
      mapped.forEach((String field, String raw) {
        if (raw.trim().isEmpty) return;
        final String? column = columns[field];
        if (column == null) return;
        if (mapping.entity == MasterDataImportEntity.customer && field == 'iban') return;
        if (mapping.entity == MasterDataImportEntity.supplier && field == 'kreditlimit') return;
        Object? value = raw.trim();
        if (MasterDataImportFields.numericFields.contains(field)) {
          value =
              num.tryParse(MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention) ?? '') ?? raw.trim();
        }
        if (field == 'land') value = raw.trim().toUpperCase();
        assignments[column] = value;
      });
      if (assignments.isEmpty) return;
      // Re-validate merged record inside the transaction.
      final String table = mapping.entity == MasterDataImportEntity.customer ? 'kunden' : 'lieferanten';
      final List<Map<String, Object?>> current = await tx.runSelect('SELECT * FROM $table WHERE id = ?', <Object?>[id]);
      if (current.isEmpty) throw const MasterDataCsvImportException('Datensatz wurde inzwischen gelöscht.');
      final Map<String, Object?> merged = Map<String, Object?>.from(current.single)..addAll(assignments);
      for (final String required in <String>['anrede', 'name', 'strasse', 'plz', 'ort', 'land']) {
        if ((merged[required]?.toString() ?? '').trim().isEmpty) {
          throw MasterDataCsvImportException('$required ist Pflicht.');
        }
      }
      final String sql = assignments.keys.map((String c) => '$c = ?').join(', ');
      await tx.runUpdate('UPDATE $table SET $sql WHERE id = ?', <Object?>[...assignments.values, id]);
      return;
    }
    // Article update: only non-price scalar fields; prices preserved exactly.
    final Map<String, Object?> articleAssignments = <String, Object?>{};
    const Map<String, String> articleColumns = <String, String>{
      'bezeichnung': 'bezeichnung',
      'beschreibung': 'beschreibung',
      'typ': 'typ',
      'einheit': 'einheit',
      'artikelnummer': 'artikelnummer',
      'ek_netto': 'ek_netto',
    };
    mapped.forEach((String field, String raw) {
      if (raw.trim().isEmpty) return;
      if (MasterDataImportFields.articleUpdateForbidden.contains(field)) return;
      final String? column = articleColumns[field];
      if (column == null) return;
      Object? value = raw.trim();
      if (field == 'ek_netto') {
        value = num.tryParse(MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention) ?? '') ?? raw.trim();
      }
      articleAssignments[column] = value;
    });
    if (articleAssignments.isEmpty) return;
    if (articleAssignments.containsKey('typ') && !_articleTypes.contains(articleAssignments['typ']?.toString())) {
      throw MasterDataCsvImportException('Ungültiger Typ: ${articleAssignments['typ']}.');
    }
    final String sql = articleAssignments.keys.map((String c) => '$c = ?').join(', ');
    await tx.runUpdate('UPDATE artikel SET $sql WHERE id = ?', <Object?>[...articleAssignments.values, id]);
  }

  Future<void> _insertCustomer(QueryExecutor tx, MasterDataFieldMapping mapping, Map<String, String> mapped) async {
    String get(String field, [String fallback = '']) =>
        (mapped[field] ?? '').trim().isEmpty ? fallback : mapped[field]!.trim();
    final String name = get('name');
    final String strasse = get('strasse');
    final String plz = get('plz');
    final String ort = get('ort');
    if (name.isEmpty || strasse.isEmpty || plz.isEmpty || ort.isEmpty) {
      throw const MasterDataCsvImportException('Pflichtfelder fehlen (Name, Straße, PLZ, Ort).');
    }
    final String anrede = get('anrede', 'Herr');
    final String land = get('land', 'DE').toUpperCase();
    num? numeric(String field) {
      final String raw = (mapped[field] ?? '').trim();
      if (raw.isEmpty) return null;
      return num.tryParse(MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention) ?? '');
    }

    final String debitorNr = await _allocateNumber(tx, 'debitor', '1####');
    await tx.runInsert(
      'INSERT INTO kunden (kundennummer, debitor_nr, anrede, name, firma, strasse, hausnummer, plz, ort, land, '
      'ust_idnr, steuernummer_ausland, telefon, email, zahlungsziel, skonto_prozent, skonto_tage, kreditlimit, '
      'mahngesperrt, zugferd_aktiv, note, notiz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?)',
      <Object?>[
        debitorNr,
        debitorNr,
        anrede,
        name,
        _nullIfEmpty(mapped['firma']),
        strasse,
        _nullIfEmpty(mapped['hausnummer']),
        plz,
        ort,
        land,
        _nullIfEmpty(mapped['ust_idnr']),
        _nullIfEmpty(mapped['steuernummer_ausland']),
        _nullIfEmpty(mapped['telefon']),
        _nullIfEmpty(mapped['email']),
        _intOr(mapped['zahlungsziel'], mapping.decimalConvention, 14),
        numeric('skonto_prozent') ?? 0,
        _intOr(mapped['skonto_tage'], mapping.decimalConvention, 0),
        numeric('kreditlimit'),
        _nullIfEmpty(mapped['note']),
        _nullIfEmpty(mapped['note']),
      ],
    );
  }

  Future<void> _insertSupplier(QueryExecutor tx, MasterDataFieldMapping mapping, Map<String, String> mapped) async {
    String get(String field, [String fallback = '']) =>
        (mapped[field] ?? '').trim().isEmpty ? fallback : mapped[field]!.trim();
    final String name = get('name');
    final String strasse = get('strasse');
    final String plz = get('plz');
    final String ort = get('ort');
    if (name.isEmpty || strasse.isEmpty || plz.isEmpty || ort.isEmpty) {
      throw const MasterDataCsvImportException('Pflichtfelder fehlen (Name, Straße, PLZ, Ort).');
    }
    final String anrede = get('anrede', 'Herr');
    final String land = get('land', 'DE').toUpperCase();
    num? numeric(String field) {
      final String raw = (mapped[field] ?? '').trim();
      if (raw.isEmpty) return null;
      return num.tryParse(MasterDataNumericParser.tryNormalize(raw, mapping.decimalConvention) ?? '');
    }

    final String kreditorNr = await _allocateNumber(tx, 'kreditor', '7####');
    await tx.runInsert(
      'INSERT INTO lieferanten (lieferantennummer, kreditor_nr, anrede, name, firma, strasse, hausnummer, plz, ort, '
      'land, ust_idnr, steuernummer_ausland, telefon, email, iban, zahlungsziel, skonto_prozent, skonto_tage, note) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        kreditorNr,
        kreditorNr,
        anrede,
        name,
        _nullIfEmpty(mapped['firma']),
        strasse,
        _nullIfEmpty(mapped['hausnummer']),
        plz,
        ort,
        land,
        _nullIfEmpty(mapped['ust_idnr']),
        _nullIfEmpty(mapped['steuernummer_ausland']),
        _nullIfEmpty(mapped['telefon']),
        _nullIfEmpty(mapped['email']),
        _nullIfEmpty(mapped['iban']),
        _intOr(mapped['zahlungsziel'], mapping.decimalConvention, 14),
        numeric('skonto_prozent') ?? 0,
        _intOr(mapped['skonto_tage'], mapping.decimalConvention, 0),
        _nullIfEmpty(mapped['note']),
      ],
    );
  }

  Future<void> _insertArticle(QueryExecutor tx, MasterDataFieldMapping mapping, Map<String, String> mapped) async {
    final String bezeichnung = (mapped['bezeichnung'] ?? '').trim();
    if (bezeichnung.isEmpty) throw const MasterDataCsvImportException('Bezeichnung ist Pflicht.');
    final String typ = (mapped['typ'] ?? '').trim().isEmpty ? 'Artikel' : mapped['typ']!.trim();
    if (!_articleTypes.contains(typ)) throw MasterDataCsvImportException('Ungültiger Typ: $typ.');
    final ArticlePriceBasis basis = mapping.articlePriceBasis ?? ArticlePriceBasis.gross;
    final String priceRaw = ((basis == ArticlePriceBasis.net ? mapped['vk_netto'] : mapped['vk_brutto']) ?? '').trim();
    final num? price = num.tryParse(MasterDataNumericParser.tryNormalize(priceRaw, mapping.decimalConvention) ?? '');
    if (price == null) throw const MasterDataCsvImportException('Verkaufspreis ist ungültig.');
    num rate = 19;
    final String ustRaw = (mapped['ust_satz'] ?? '').trim();
    if (ustRaw.isNotEmpty) {
      rate = num.tryParse(MasterDataNumericParser.tryNormalize(ustRaw, mapping.decimalConvention) ?? '') ?? 19;
    } else {
      final String ustIdRaw = (mapped['ust_satz_id'] ?? '').trim();
      if (ustIdRaw.isNotEmpty) {
        final int? ustId = int.tryParse(
          MasterDataNumericParser.tryNormalize(ustIdRaw, mapping.decimalConvention) ?? '',
        );
        if (ustId != null) {
          try {
            final List<Map<String, Object?>> rows = await tx.runSelect(
              'SELECT satz FROM ust_saetze WHERE id = ?',
              <Object?>[ustId],
            );
            if (rows.isNotEmpty) {
              final Object? v = rows.single['satz'];
              rate = v is num ? v : num.tryParse(v?.toString() ?? '') ?? 19;
            }
          } catch (_) {}
        }
      }
    }
    num? ekNetto;
    final String ekRaw = (mapped['ek_netto'] ?? '').trim();
    if (ekRaw.isNotEmpty) {
      ekNetto = num.tryParse(MasterDataNumericParser.tryNormalize(ekRaw, mapping.decimalConvention) ?? '');
    }
    late final num finalNetto;
    late final num finalBrutto;
    final String vkEingabe = basis == ArticlePriceBasis.net ? 'netto' : 'brutto';
    if (basis == ArticlePriceBasis.gross) {
      finalNetto = price / (1 + rate / 100);
      finalBrutto = price;
    } else {
      finalBrutto = price * (1 + rate / 100);
      finalNetto = price;
    }
    int? ustSatzId;
    final String ustIdRaw = (mapped['ust_satz_id'] ?? '').trim();
    if (ustIdRaw.isNotEmpty) {
      ustSatzId = int.tryParse(MasterDataNumericParser.tryNormalize(ustIdRaw, mapping.decimalConvention) ?? '');
    }
    await tx.runInsert(
      'INSERT INTO artikel (bezeichnung, typ, beschreibung, einheit, vk_netto, vk_brutto, vk_eingabe, ust_satz_id, '
      'ust_satz, differenzbesteuerung, ek_netto, lager_aktiv, bestand_aktuell, mindestbestand, minusbestand_erlaubt, '
      'artikelnummer, aktiv, bestand) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 0, 0, 0, 0, ?, 1, 0)',
      <Object?>[
        bezeichnung,
        typ,
        _nullIfEmpty(mapped['beschreibung']),
        if ((mapped['einheit'] ?? '').trim().isEmpty) 'Stk' else mapped['einheit']!.trim(),
        finalNetto,
        finalBrutto,
        vkEingabe,
        ustSatzId,
        rate,
        ekNetto,
        _nullIfEmpty(mapped['artikelnummer']),
      ],
    );
  }

  Future<String> _allocateNumber(QueryExecutor tx, String typ, String fallbackFormat) async {
    final List<Map<String, Object?>> rows = await tx.runSelect(
      'SELECT id, format, naechste_nummer, letzte_nummer, letze_nummer FROM nummernkreise WHERE typ = ? AND aktiv = 1 '
      'ORDER BY id LIMIT 1',
      <Object?>[typ],
    );
    if (rows.isEmpty) throw const MasterDataCsvImportException('Nummernkreis fehlt.');
    final Map<String, Object?> row = rows.single;
    final int? configured = _asIntOrNull(row['naechste_nummer']);
    final List<int> lasts = <int>[
      if (_asIntOrNull(row['letzte_nummer']) != null) _asIntOrNull(row['letzte_nummer'])!,
      if (_asIntOrNull(row['letze_nummer']) != null) _asIntOrNull(row['letze_nummer'])!,
    ];
    final int minimum = lasts.isEmpty ? 1 : lasts.reduce((int a, int b) => a > b ? a : b) + 1;
    final int number = (configured ?? 1) > minimum ? configured! : minimum;
    await tx.runUpdate(
      'UPDATE nummernkreise SET naechste_nummer = ?, letzte_nummer = ?, letze_nummer = ? WHERE id = ?',
      <Object?>[number + 1, number, number, row['id']],
    );
    final String format = row['format']?.toString() ?? fallbackFormat;
    return _formatNumber(format, number);
  }

  static int? _asIntOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _formatNumber(String format, int number) {
    final RegExpMatch? numeric = RegExp(r'^([0-9]*)(#+)$').firstMatch(format);
    if (numeric != null) {
      final String prefix = numeric.group(1)!;
      final int width = numeric.group(2)!.length;
      final String value = number.toString();
      if (prefix.isEmpty) return value.padLeft(width, '0');
      if (value.startsWith(prefix) && value.length > width) return value;
      return '$prefix${value.padLeft(width, '0')}';
    }
    final DateTime now = DateTime.now();
    String result = format
        .replaceAll('{YYYY}', now.year.toString())
        .replaceAll('{YY}', now.year.toString().substring(2))
        .replaceAll('{MM}', now.month.toString().padLeft(2, '0'));
    result = result.replaceAllMapped(
      RegExp(r'\{N+\}'),
      (Match m) => number.toString().padLeft(m.group(0)!.length - 2, '0'),
    );
    return result.replaceAllMapped(RegExp('#+'), (Match m) => number.toString().padLeft(m.group(0)!.length, '0'));
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _intOr(String? raw, CsvDecimalConvention convention, int fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final String? norm = MasterDataNumericParser.tryNormalize(raw, convention);
    return int.tryParse(norm ?? '') ?? fallback;
  }
}

class _ExistingRecord {
  const _ExistingRecord(this.id, this.values);

  final int id;
  final Map<String, String> values;
}

class _MatchResult {
  const _MatchResult(this.ids);

  final List<int> ids;
}

class _NoopImportUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

/// Thin application-service facade over the import service. Pages resolve
/// through `AppServices.masterDataCsvImport`, never via raw SQL.
class MasterDataCsvImportUseCase {
  const MasterDataCsvImportUseCase(this._service);

  final MasterDataCsvImportService _service;

  MasterDataCsvImportService get service => _service;

  Future<MasterDataImportPreview> preview(MasterDataParsedCsv parsed, MasterDataFieldMapping mapping) {
    return _service.buildPreview(parsed, mapping);
  }

  Future<MasterDataImportResult> commit(MasterDataReviewedBatch batch, MasterDataFieldMapping mapping) {
    return _service.commit(batch, mapping);
  }

  MasterDataImportTemplateStore get templates => _service.templates;
}

/// Riverpod provider for the import boundary (active-profile executor).
final masterDataCsvImportServiceProvider = Provider<MasterDataCsvImportService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return MasterDataCsvImportService(db.executor);
});
