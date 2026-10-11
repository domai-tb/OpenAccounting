import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';

/// Profile-local mapping-template store. Dedicated table
/// `master_data_import_templates`; never touches `import_mapping_vorlagen`
/// (bank-owned) and never stores file bytes or row values.
class MasterDataImportTemplateStore {
  MasterDataImportTemplateStore(this.executor);

  final QueryExecutor executor;

  Future<void> ensureSchema() async {
    await executor.runCustom(_tableSql);
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_master_data_import_templates_entity ON master_data_import_templates(entity)',
    );
  }

  Future<List<MasterDataImportTemplate>> list(MasterDataImportEntity entity) async {
    try {
      await ensureSchema();
    } catch (_) {
      throw const MasterDataCsvUnavailableException('Vorlagen konnten nicht geladen werden.');
    }
    late final List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT * FROM master_data_import_templates WHERE entity = ? ORDER BY name COLLATE NOCASE, id',
        <Object?>[entity.name],
      );
    } catch (_) {
      throw const MasterDataCsvUnavailableException('Vorlagen konnten nicht geladen werden.');
    }
    final List<MasterDataImportTemplate> out = <MasterDataImportTemplate>[];
    for (final Map<String, Object?> row in rows) {
      try {
        out.add(decodeRow(row));
      } catch (_) {
        // Skip corrupt rows; never apply a partial mapping.
        continue;
      }
    }
    return out;
  }

  Future<MasterDataImportTemplate> save({
    required String name,
    required MasterDataFieldMapping mapping,
    int? id,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const MasterDataCsvMappingException('Vorlagenname ist Pflicht.');
    }
    validateMapping(mapping);
    await ensureSchema();
    final String now = DateTime.now().toUtc().toIso8601String();
    final String payload = encodeMapping(mapping);
    if (id == null) {
      final int newId = await executor.runInsert(
        'INSERT INTO master_data_import_templates '
        '(name, entity, mapping_json, has_header, delimiter, decimal_convention, duplicate_policy, match_field, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          trimmed,
          mapping.entity.name,
          payload,
          mapping.hasHeader ? 1 : 0,
          mapping.delimiter.name,
          mapping.decimalConvention.name,
          mapping.duplicatePolicy.name,
          mapping.matchField,
          now,
          now,
        ],
      );
      final MasterDataImportTemplate? stored = await findById(newId);
      if (stored == null) throw const MasterDataCsvMappingException('Vorlage konnte nicht gespeichert werden.');
      return stored;
    }
    final int updated = await executor.runUpdate(
      'UPDATE master_data_import_templates SET name = ?, entity = ?, mapping_json = ?, has_header = ?, '
      'delimiter = ?, decimal_convention = ?, duplicate_policy = ?, match_field = ?, updated_at = ? WHERE id = ?',
      <Object?>[
        trimmed,
        mapping.entity.name,
        payload,
        mapping.hasHeader ? 1 : 0,
        mapping.delimiter.name,
        mapping.decimalConvention.name,
        mapping.duplicatePolicy.name,
        mapping.matchField,
        now,
        id,
      ],
    );
    if (updated == 0) throw const MasterDataCsvMappingException('Vorlage nicht gefunden.');
    final MasterDataImportTemplate? stored = await findById(id);
    if (stored == null) throw const MasterDataCsvMappingException('Vorlage nicht gefunden.');
    return stored;
  }

  Future<void> delete(int id) async {
    await ensureSchema();
    final int deleted = await executor.runDelete('DELETE FROM master_data_import_templates WHERE id = ?', <Object?>[
      id,
    ]);
    if (deleted == 0) throw const MasterDataCsvMappingException('Vorlage nicht gefunden.');
  }

  Future<MasterDataImportTemplate?> findById(int id) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM master_data_import_templates WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return decodeRow(rows.single);
  }

  /// Loads a template only for its recorded entity. Cross-entity use is a
  /// mapping conflict and never enters preview.
  MasterDataFieldMapping requireForEntity(MasterDataImportTemplate template, MasterDataImportEntity entity) {
    if (template.entity != entity) {
      throw MasterDataCsvMappingException(
        'Vorlage gehört zu ${template.entity.name} und passt nicht zu ${entity.name}.',
      );
    }
    return template.mapping;
  }

  // -- Mapping validation -------------------------------------------------

  /// Validates column-to-field assignments: typed allowlist, no duplicate
  /// targets, no forbidden keys, match-field rules, article basis rules.
  static void validateMapping(MasterDataFieldMapping mapping) {
    final Set<String> allowed = MasterDataImportFields.allowedFor(mapping.entity);
    if (mapping.columnToField.isEmpty) {
      throw const MasterDataCsvMappingException('Mindestens eine Spaltenzuordnung ist erforderlich.');
    }
    final Set<String> seen = <String>{};
    for (final MapEntry<int, String> entry in mapping.columnToField.entries) {
      final String field = MasterDataImportFields.normalizeField(entry.value);
      if (!allowed.contains(field)) {
        throw MasterDataCsvMappingException('Feld wird nicht unterstützt: ${entry.value}.');
      }
      if (!seen.add(field)) {
        throw MasterDataCsvMappingException('Feld ist doppelt zugeordnet: $field.');
      }
    }
    if (mapping.duplicatePolicy != MasterDataDuplicatePolicy.createNew) {
      final String? match = mapping.matchField?.trim();
      if (match == null || match.isEmpty) {
        throw const MasterDataCsvMappingException(
          'Für Überspringen/Aktualisieren ist ein Vergleichsfeld erforderlich.',
        );
      }
      final String normalized = MasterDataImportFields.normalizeField(match);
      if (!mapping.columnToField.values.map(MasterDataImportFields.normalizeField).contains(normalized)) {
        throw const MasterDataCsvMappingException('Das Vergleichsfeld muss zugeordnet sein.');
      }
      if (!allowed.contains(normalized)) {
        throw MasterDataCsvMappingException('Vergleichsfeld wird nicht unterstützt: $match.');
      }
    }
    if (mapping.entity == MasterDataImportEntity.article) {
      if (mapping.articlePriceBasis == null) {
        throw const MasterDataCsvMappingException('Für Artikel ist eine Preisbasis (netto/brutto) erforderlich.');
      }
    }
  }

  static String encodeMapping(MasterDataFieldMapping mapping) {
    final Map<String, Object?> json = <String, Object?>{
      'version': 1,
      'entity': mapping.entity.name,
      'columnToField': <String, String>{
        for (final MapEntry<int, String> e in mapping.columnToField.entries) '${e.key}': e.value,
      },
      'hasHeader': mapping.hasHeader,
      'delimiter': mapping.delimiter.name,
      'decimalConvention': mapping.decimalConvention.name,
      'duplicatePolicy': mapping.duplicatePolicy.name,
      'matchField': mapping.matchField,
      'articlePriceBasis': mapping.articlePriceBasis?.name,
    };
    return jsonEncode(json);
  }

  /// Decodes and strictly validates a stored template. Unknown versions,
  /// fields, entity types, duplicate targets, or policy values make the
  /// template unavailable rather than applying a partial mapping.
  static MasterDataImportTemplate decodeRow(Map<String, Object?> row) {
    final Object? rawId = row['id'];
    final int id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final String name = row['name']?.toString() ?? '';
    MasterDataImportEntity entity;
    try {
      entity = MasterDataImportEntity.values.byName(row['entity']?.toString() ?? '');
    } catch (_) {
      throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    }
    final String payload = row['mapping_json']?.toString() ?? '';
    if (payload.isEmpty || name.trim().isEmpty) {
      throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    }
    late final Map<String, Object?> json;
    try {
      json = Map<String, Object?>.from(jsonDecode(payload) as Map);
    } catch (_) {
      throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    }
    if (json['version'] != 1) throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    if (json['entity']?.toString() != entity.name) {
      throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    }
    final Object? mapRaw = json['columnToField'];
    if (mapRaw is! Map) throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    final Map<int, String> columnToField = <int, String>{};
    for (final MapEntry<Object?, Object?> e in (mapRaw as Map).entries) {
      final int? col = int.tryParse(e.key.toString());
      if (col == null) throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
      columnToField[col] = e.value.toString();
    }
    CsvImportDelimiter delimiter;
    CsvDecimalConvention decimalConvention;
    MasterDataDuplicatePolicy duplicatePolicy;
    try {
      delimiter = CsvImportDelimiter.values.byName(json['delimiter']?.toString() ?? '');
      decimalConvention = CsvDecimalConvention.values.byName(json['decimalConvention']?.toString() ?? '');
      duplicatePolicy = MasterDataDuplicatePolicy.values.byName(json['duplicatePolicy']?.toString() ?? '');
    } catch (_) {
      throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    }
    final bool hasHeader = json['hasHeader'] == true;
    final String? matchField = json['matchField']?.toString();
    ArticlePriceBasis? basis;
    final Object? basisRaw = json['articlePriceBasis'];
    if (basisRaw != null) {
      try {
        basis = ArticlePriceBasis.values.byName(basisRaw.toString());
      } catch (_) {
        throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
      }
    }
    final MasterDataFieldMapping mapping = MasterDataFieldMapping(
      entity: entity,
      columnToField: columnToField,
      hasHeader: hasHeader,
      delimiter: delimiter,
      decimalConvention: decimalConvention,
      duplicatePolicy: duplicatePolicy,
      matchField: matchField,
      articlePriceBasis: basis,
    );
    try {
      validateMapping(mapping);
    } catch (_) {
      throw const MasterDataCsvMappingException('Vorlage ist nicht verfügbar.');
    }
    return MasterDataImportTemplate(
      id: id,
      name: name,
      entity: entity,
      mapping: mapping,
      createdAt: row['created_at']?.toString() ?? '',
      updatedAt: row['updated_at']?.toString() ?? '',
    );
  }

  static const String _tableSql = '''
CREATE TABLE IF NOT EXISTS master_data_import_templates (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  entity TEXT NOT NULL CHECK (entity IN ('customer', 'supplier', 'article')),
  mapping_json TEXT NOT NULL,
  has_header INTEGER NOT NULL DEFAULT 1 CHECK (has_header IN (0, 1)),
  delimiter TEXT NOT NULL,
  decimal_convention TEXT NOT NULL,
  duplicate_policy TEXT NOT NULL,
  match_field TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''';
}
