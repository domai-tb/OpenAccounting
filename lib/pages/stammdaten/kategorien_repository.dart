import 'dart:convert';

import 'package:drift/drift.dart';

class KategorieException implements Exception {
  const KategorieException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when a mapping review is attempted while the owning workspace is
/// unavailable. The category status is left unchanged; untrusted mappings stay
/// blocked from mapping-dependent operations until review succeeds.
class CategoryReviewUnavailable implements Exception {
  const CategoryReviewUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Mapping provenance per accounting-catalog-provenance. Only `catalogVerified`
/// values came from an approved, versioned catalog manifest; `userConfirmed`
/// values were explicitly reviewed by the user and must be identified as not
/// source-verified in output. All other states block mapping-dependent use.
enum CategoryMappingStatus {
  catalogVerified('catalog_verified'),
  userConfirmed('user_confirmed'),
  legacyUnverified('legacy_unverified'),
  reviewRequired('review_required'),
  unmapped('unmapped');

  const CategoryMappingStatus(this.db);
  final String db;

  static CategoryMappingStatus fromDb(Object? v) {
    for (final s in CategoryMappingStatus.values) {
      if (s.db == v) return s;
    }
    return CategoryMappingStatus.legacyUnverified;
  }
}

/// One approved catalog entry. Stable [key] identifies the entry across releases.
class CategoryCatalogEntry {
  const CategoryCatalogEntry({
    required this.key,
    required this.bezeichnung,
    this.beschreibung,
    this.kontoSkr03,
    this.kontoSkr04,
    this.euerZeile,
    this.eksKategorie,
  });
  final String key;
  final String bezeichnung;
  final String? beschreibung;
  final String? kontoSkr03;
  final String? kontoSkr04;
  final int? euerZeile;
  final String? eksKategorie;
}

/// Versioned catalog manifest. Eligible only with source reference, version,
/// and approved accounting review; otherwise its mappings must be rejected.
class CategoryCatalogManifest {
  const CategoryCatalogManifest({
    required this.sourceReference,
    required this.sourceVersion,
    required this.reviewApproved,
    required this.entries,
  });
  final String sourceReference;
  final String sourceVersion;
  final bool reviewApproved;
  final List<CategoryCatalogEntry> entries;
}

class Kategorie {
  const Kategorie({
    required this.id,
    required this.bezeichnung,
    this.beschreibung,
    this.art,
    this.kontoSkr03,
    this.kontoSkr04,
    this.kontoUstSkr03,
    this.kontoUstSkr04,
    this.euerZeile,
    this.eksKategorie,
    required this.aktiv,
    this.typ,
    this.mappingStatus = CategoryMappingStatus.legacyUnverified,
    this.catalogEntryKey,
    this.catalogSourceReference,
    this.catalogSourceVersion,
    this.mappingReviewedAt,
  });
  final int id;
  final String bezeichnung;
  final String? beschreibung;
  final String? art;
  final String? kontoSkr03;
  final String? kontoSkr04;
  final String? kontoUstSkr03;
  final String? kontoUstSkr04;
  final int? euerZeile;
  final String? eksKategorie;
  final bool aktiv;
  final String? typ;
  final CategoryMappingStatus mappingStatus;
  final String? catalogEntryKey;
  final String? catalogSourceReference;
  final String? catalogSourceVersion;
  final String? mappingReviewedAt;

  /// True when the category carries no accounting mapping values at all.
  bool get hasNoMappings =>
      kontoSkr03 == null &&
      kontoSkr04 == null &&
      kontoUstSkr03 == null &&
      kontoUstSkr04 == null &&
      euerZeile == null &&
      eksKategorie == null;
}

/// Posting-gate decision for a category mapping status. Blocked decisions
/// apply only when the posting/output contract requires category mapping
/// values; an inactive-category warning never replaces mapping review and
/// deactivation never changes provenance status.
enum CategoryPostingDecision {
  /// Mapping values may be consumed (verified or user-confirmed).
  allowed,

  /// Untrusted mapping blocks operations requiring mapping values.
  blockedUntrusted,

  /// No mapping values required: the category is a descriptive label only.
  allowedUnmappedLabel,
}

/// Decides whether a posting may proceed for [status]. When [requiresMapping]
/// is true only verified/user-confirmed mappings are allowed; otherwise every
/// status may label the posting without consuming mapping values.
CategoryPostingDecision decidePostingUse(CategoryMappingStatus status, {required bool requiresMapping}) {
  if (!requiresMapping) {
    return status == CategoryMappingStatus.unmapped
        ? CategoryPostingDecision.allowedUnmappedLabel
        : CategoryPostingDecision.allowed;
  }
  return switch (status) {
    CategoryMappingStatus.catalogVerified || CategoryMappingStatus.userConfirmed => CategoryPostingDecision.allowed,
    _ => CategoryPostingDecision.blockedUntrusted,
  };
}

class KategorienRepository {
  KategorienRepository(this.executor, {this.categoryWorkspaceAvailable = false});
  final QueryExecutor executor;

  /// Whether the owning `/settings/categories` workspace (accepted via
  /// master-data-workspaces-and-crud) is available. Until then provenance is
  /// read-only: reviews throw [CategoryReviewUnavailable] and untrusted
  /// mappings stay blocked.
  final bool categoryWorkspaceAvailable;
  Future<void>? _schemaReady;
  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema(executor);

  static const List<_ColumnDefinition> _kategorienColumns = <_ColumnDefinition>[
    _ColumnDefinition('konto_ust_skr03', 'TEXT'),
    _ColumnDefinition('konto_ust_skr04', 'TEXT'),
    _ColumnDefinition('art', 'TEXT'),
    _ColumnDefinition('typ', 'TEXT'),
    _ColumnDefinition('eks_kategorie', 'TEXT'),
    _ColumnDefinition('euer_zeile', 'INTEGER'),
    _ColumnDefinition('aktiv', 'INTEGER DEFAULT 1'),
    _ColumnDefinition('beschreibung', 'TEXT'),
    _ColumnDefinition(
      'mapping_status',
      "TEXT NOT NULL DEFAULT 'legacy_unverified' CHECK (mapping_status IN "
          "('catalog_verified','user_confirmed','legacy_unverified','review_required','unmapped'))",
    ),
    _ColumnDefinition('catalog_entry_key', 'TEXT'),
    _ColumnDefinition('catalog_source_reference', 'TEXT'),
    _ColumnDefinition('catalog_source_version', 'TEXT'),
    _ColumnDefinition('mapping_reviewed_at', 'TEXT'),
  ];

  static const String _select = '''
SELECT id, bezeichnung, beschreibung, art, typ, konto_skr03, konto_skr04, konto_ust_skr03, konto_ust_skr04, euer_zeile, eks_kategorie, aktiv, mapping_status, catalog_entry_key, catalog_source_reference, catalog_source_version, mapping_reviewed_at
FROM kategorien
''';

  /// Mapping fields whose change requires re-review of the whole mapping.
  static const Set<String> mappingColumns = <String>{
    'konto_skr03',
    'konto_skr04',
    'konto_ust_skr03',
    'konto_ust_skr04',
    'euer_zeile',
    'eks_kategorie',
  };

  /// Creates a user-defined category. It is never catalog-verified: without
  /// mapping values it is `unmapped`, with mapping values it is
  /// `reviewRequired` until every populated mapping field is explicitly
  /// reviewed. The UI must identify it as user-configured, not standard.
  Future<Kategorie> create({
    required String bezeichnung,
    String? beschreibung,
    String? art,
    String? kontoSkr03,
    String? kontoSkr04,
    String? kontoUstSkr03,
    String? kontoUstSkr04,
    int? euerZeile,
    String? eksKategorie,
    bool aktiv = true,
    String? typ,
  }) async {
    if (bezeichnung.trim().isEmpty) throw const KategorieException('Bezeichnung ist Pflicht');
    await ensureSchema();
    final int aktivInt = aktiv ? 1 : 0;
    final bool hasMappings =
        kontoSkr03 != null ||
        kontoSkr04 != null ||
        kontoUstSkr03 != null ||
        kontoUstSkr04 != null ||
        euerZeile != null ||
        eksKategorie != null;
    final status = hasMappings ? CategoryMappingStatus.reviewRequired : CategoryMappingStatus.unmapped;
    final int id = await _inTransaction(() async {
      final newId = await executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, beschreibung, art, typ, konto_skr03, konto_skr04, konto_ust_skr03, konto_ust_skr04, euer_zeile, eks_kategorie, aktiv, mapping_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          bezeichnung,
          beschreibung,
          art,
          typ,
          kontoSkr03,
          kontoSkr04,
          kontoUstSkr03,
          kontoUstSkr04,
          euerZeile,
          eksKategorie,
          aktivInt,
          status.db,
        ],
      );
      await _insertHistory(
        kategorieId: newId,
        aktion: 'mapping_edit',
        nachher: <String, Object?>{
          'konto_skr03': kontoSkr03,
          'konto_skr04': kontoSkr04,
          'konto_ust_skr03': kontoUstSkr03,
          'konto_ust_skr04': kontoUstSkr04,
          'euer_zeile': euerZeile,
          'eks_kategorie': eksKategorie,
          'mapping_status': status.db,
        },
      );
      return newId;
    });
    final stored = await findById(id);
    if (stored == null) throw const KategorieException('Kategorie konnte nicht gespeichert werden');
    return stored;
  }

  Future<Kategorie?> findById(int id) async {
    await ensureSchema();
    final rows = await executor.runSelect('$_select WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<Kategorie>> list({bool onlyActive = false}) async {
    await ensureSchema();
    final sql = onlyActive ? '$_select WHERE aktiv = 1 ORDER BY id' : '$_select ORDER BY id';
    final rows = await executor.runSelect(sql, const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  /// Updates a category. Changing any mapping field moves the whole mapping to
  /// `reviewRequired` while the prior catalog source/version stays recorded as
  /// baseline; other fields leave provenance untouched. Deactivation never
  /// changes provenance. Values, status, and history commit atomically.
  Future<Kategorie> update(int id, Map<String, dynamic> values) async {
    await ensureSchema();
    final current = await findById(id);
    if (current == null) throw const KategorieException('Kategorie nicht gefunden');
    if (values.isEmpty) return current;
    final map = <String, String>{
      'bezeichnung': 'bezeichnung',
      'beschreibung': 'beschreibung',
      'art': 'art',
      'typ': 'typ',
      'kontoSkr03': 'konto_skr03',
      'konto_skr03': 'konto_skr03',
      'kontoSkr04': 'konto_skr04',
      'konto_skr04': 'konto_skr04',
      'kontoUstSkr03': 'konto_ust_skr03',
      'konto_ust_skr03': 'konto_ust_skr03',
      'kontoUstSkr04': 'konto_ust_skr04',
      'konto_ust_skr04': 'konto_ust_skr04',
      'euerZeile': 'euer_zeile',
      'euer_zeile': 'euer_zeile',
      'eksKategorie': 'eks_kategorie',
      'eks_kategorie': 'eks_kategorie',
      'aktiv': 'aktiv',
    };
    final assignments = <String, Object?>{};
    for (final e in values.entries) {
      final col = map[e.key];
      if (col == null) throw KategorieException('Unbekanntes Kategoriefeld: ${e.key}');
      assignments[col] = e.value is bool ? ((e.value as bool) ? 1 : 0) : e.value;
    }
    final currentValues = _mappingValuesOf(current);
    var mappingChanged = false;
    for (final col in mappingColumns) {
      if (assignments.containsKey(col) && !_equalDbValue(currentValues[col], assignments[col])) {
        mappingChanged = true;
        break;
      }
    }
    await _inTransaction(() async {
      CategoryMappingStatus resulting = current.mappingStatus;
      if (mappingChanged) {
        resulting = CategoryMappingStatus.reviewRequired;
        assignments['mapping_status'] = resulting.db;
      }
      final sql = assignments.keys.map((c) => '$c = ?').join(', ');
      await executor.runUpdate('UPDATE kategorien SET $sql WHERE id = ?', <Object?>[...assignments.values, id]);
      if (mappingChanged) {
        final nachher = <String, Object?>{...currentValues, ...assignments};
        nachher['mapping_status'] = resulting.db;
        nachher.removeWhere((k, _) => !mappingColumns.contains(k) && k != 'mapping_status');
        await _insertHistory(
          kategorieId: id,
          aktion: 'mapping_edit',
          vorher: <String, Object?>{...currentValues, 'mapping_status': current.mappingStatus.db},
          nachher: nachher,
          quelle: current.catalogSourceReference,
          version: current.catalogSourceVersion,
        );
      }
    });
    return (await findById(id))!;
  }

  /// Deletes a category. Categories with history are deactivated instead of
  /// physically deleted so the audit trail keeps its references.
  Future<void> delete(int id) async {
    await ensureSchema();
    final refs = await executor.runSelect('SELECT id FROM journal WHERE kategorie_id = ? LIMIT 1', <Object?>[id]);
    if (refs.isNotEmpty) {
      throw KategorieException('Kategorie wird von ${refs.length} Journalbuchungen verwendet');
    }
    // also check if still more than 5? mimic spec: show count
    final countRows = await executor.runSelect('SELECT COUNT(*) as c FROM journal WHERE kategorie_id = ?', <Object?>[
      id,
    ]);
    final count = _asInt(countRows.single['c']) ?? 0;
    if (count > 0) {
      throw KategorieException('Kategorie wird von $count Journalbuchungen verwendet');
    }
    final history = await executor.runSelect(
      'SELECT COUNT(*) AS c FROM category_mapping_history WHERE kategorie_id = ?',
      <Object?>[id],
    );
    if ((_asInt(history.single['c']) ?? 0) > 0) {
      await executor.runUpdate('UPDATE kategorien SET aktiv = 0 WHERE id = ?', <Object?>[id]);
      return;
    }
    final deleted = await executor.runDelete('DELETE FROM kategorien WHERE id = ?', <Object?>[id]);
    if (deleted == 0) throw const KategorieException('Kategorie nicht gefunden');
  }

  /// Explicitly reviews every populated mapping field. Requires the owning
  /// workspace; while unavailable the status is left unchanged and
  /// [CategoryReviewUnavailable] is thrown. A reviewed mapping with populated
  /// fields becomes `userConfirmed` (never silently catalog-verified); without
  /// populated fields it stays `unmapped`. The original catalog release
  /// remains visible as baseline.
  Future<Kategorie> reviewMapping(int id) async {
    await ensureSchema();
    final current = await findById(id);
    if (current == null) throw const KategorieException('Kategorie nicht gefunden');
    if (!categoryWorkspaceAvailable) {
      throw const CategoryReviewUnavailable(
        'Kategorie-Prüfung ist erst nach Freigabe des Kategorie-Arbeitsbereichs verfügbar',
      );
    }
    final values = _mappingValuesOf(current);
    final populated = values.values.any((v) => v != null);
    final resulting = populated ? CategoryMappingStatus.userConfirmed : CategoryMappingStatus.unmapped;
    final reviewedAt = DateTime.now().toUtc().toIso8601String();
    await _inTransaction(() async {
      await executor.runUpdate(
        'UPDATE kategorien SET mapping_status = ?, mapping_reviewed_at = ? WHERE id = ?',
        <Object?>[resulting.db, reviewedAt, id],
      );
      await _insertHistory(
        kategorieId: id,
        aktion: 'user_review',
        vorher: <String, Object?>{...values, 'mapping_status': current.mappingStatus.db},
        nachher: <String, Object?>{...values, 'mapping_status': resulting.db},
        quelle: current.catalogSourceReference,
        version: current.catalogSourceVersion,
      );
    });
    return (await findById(id))!;
  }

  /// Imports an approved catalog manifest. Entries whose stable key already
  /// exists are skipped; existing rows are never overwritten. A manifest
  /// missing source/version metadata or approved review is rejected and none
  /// of its mappings is persisted as catalog-verified.
  Future<List<Kategorie>> importApprovedManifest(CategoryCatalogManifest manifest) async {
    await ensureSchema();
    if (manifest.sourceReference.trim().isEmpty || manifest.sourceVersion.trim().isEmpty || !manifest.reviewApproved) {
      throw const KategorieException('Katalog-Manifest ist nicht freigegeben');
    }
    final imported = <Kategorie>[];
    await _inTransaction(() async {
      for (final entry in manifest.entries) {
        if (entry.key.trim().isEmpty) {
          throw const KategorieException('Katalog-Eintrag ohne stabilen Schlüssel');
        }
        final existing = await executor.runSelect(
          'SELECT id FROM kategorien WHERE catalog_entry_key = ? LIMIT 1',
          <Object?>[entry.key],
        );
        if (existing.isNotEmpty) continue;
        final id = await executor.runInsert(
          'INSERT INTO kategorien (bezeichnung, beschreibung, konto_skr03, konto_skr04, euer_zeile, eks_kategorie, aktiv, mapping_status, catalog_entry_key, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            entry.bezeichnung,
            entry.beschreibung,
            entry.kontoSkr03,
            entry.kontoSkr04,
            entry.euerZeile,
            entry.eksKategorie,
            1,
            CategoryMappingStatus.catalogVerified.db,
            entry.key,
            manifest.sourceReference,
            manifest.sourceVersion,
          ],
        );
        await _insertHistory(
          kategorieId: id,
          aktion: 'catalog_import',
          nachher: <String, Object?>{
            'konto_skr03': entry.kontoSkr03,
            'konto_skr04': entry.kontoSkr04,
            'konto_ust_skr03': null,
            'konto_ust_skr04': null,
            'euer_zeile': entry.euerZeile,
            'eks_kategorie': entry.eksKategorie,
            'mapping_status': CategoryMappingStatus.catalogVerified.db,
          },
          quelle: manifest.sourceReference,
          version: manifest.sourceVersion,
        );
      }
    });
    for (final entry in manifest.entries) {
      final rows = await executor.runSelect('SELECT id FROM kategorien WHERE catalog_entry_key = ? LIMIT 1', <Object?>[
        entry.key,
      ]);
      if (rows.isNotEmpty) {
        final stored = await findById(_asInt(rows.single['id']) ?? 0);
        if (stored != null) imported.add(stored);
      }
    }
    return imported;
  }

  /// True when at least one catalog-verified category exists. Fresh profiles
  /// without an approved manifest report false (explicit unconfigured state).
  Future<bool> isAccountingConfigured() async {
    await ensureSchema();
    final rows = await executor.runSelect(
      "SELECT 1 FROM kategorien WHERE mapping_status = 'catalog_verified' LIMIT 1",
      const <Object?>[],
    );
    return rows.isNotEmpty;
  }

  Future<T> _inTransaction<T>(Future<T> Function() work) async {
    await executor.runCustom('BEGIN');
    try {
      final result = await work();
      await executor.runCustom('COMMIT');
      return result;
    } catch (e) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _insertHistory({
    required int kategorieId,
    required String aktion,
    Map<String, Object?>? vorher,
    required Map<String, Object?> nachher,
    String? quelle,
    String? version,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final String? vorherJson = vorher == null ? null : jsonEncode(vorher);
    await executor.runInsert(
      'INSERT INTO category_mapping_history (kategorie_id, geaendert_am, aktion, vorher_mapping_json, nachher_mapping_json, katalog_quelle, katalog_version) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[kategorieId, now, aktion, vorherJson, jsonEncode(nachher), quelle, version],
    );
  }

  static Map<String, Object?> _mappingValuesOf(Kategorie k) => <String, Object?>{
    'konto_skr03': k.kontoSkr03,
    'konto_skr04': k.kontoSkr04,
    'konto_ust_skr03': k.kontoUstSkr03,
    'konto_ust_skr04': k.kontoUstSkr04,
    'euer_zeile': k.euerZeile,
    'eks_kategorie': k.eksKategorie,
  };

  static bool _equalDbValue(Object? a, Object? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a is num && b is num) return a == b;
    if (a is num) return a.toString() == b.toString();
    if (b is num) return a.toString() == b.toString();
    return a == b;
  }

  String kontoForSkr(Kategorie k, String skr) {
    if (skr == 'SKR04') return k.kontoSkr04 ?? k.kontoSkr03 ?? '';
    return k.kontoSkr03 ?? k.kontoSkr04 ?? '';
  }

  Kategorie _fromRow(Map<String, Object?> r) {
    return Kategorie(
      id: _asInt(r['id']) ?? 0,
      bezeichnung: _asString(r['bezeichnung']) ?? '',
      beschreibung: _asString(r['beschreibung']),
      art: _asString(r['art']),
      typ: _asString(r['typ']),
      kontoSkr03: _asString(r['konto_skr03']),
      kontoSkr04: _asString(r['konto_skr04']),
      kontoUstSkr03: _asString(r['konto_ust_skr03']),
      kontoUstSkr04: _asString(r['konto_ust_skr04']),
      euerZeile: _asInt(r['euer_zeile']),
      eksKategorie: _asString(r['eks_kategorie']),
      aktiv: _asBool(r['aktiv']),
      mappingStatus: r.containsKey('mapping_status')
          ? CategoryMappingStatus.fromDb(r['mapping_status'])
          : CategoryMappingStatus.legacyUnverified,
      catalogEntryKey: _asString(r['catalog_entry_key']),
      catalogSourceReference: _asString(r['catalog_source_reference']),
      catalogSourceVersion: _asString(r['catalog_source_version']),
      mappingReviewedAt: _asString(r['mapping_reviewed_at']),
    );
  }

  static Future<void> _ensureSchema(QueryExecutor executor) async {
    await executor.ensureOpen(_NoopUser());
    final t = executor.beginTransaction();
    try {
      await t.ensureOpen(_NoopUser());
      await _addMissing(t, 'kategorien', _kategorienColumns);
      await t.send();
    } catch (e, s) {
      try {
        await t.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, s);
    }
  }

  static Future<void> _addMissing(QueryExecutor ex, String table, List<_ColumnDefinition> defs) async {
    final rows = await ex.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    final existing = <String>{
      for (final r in rows)
        if (r['name'] is String) r['name']! as String,
    };
    for (final d in defs) {
      if (!existing.contains(d.name)) {
        await ex.runCustom('ALTER TABLE $table ADD COLUMN ${d.name} ${d.definition}');
      }
    }
  }

  static String? _asString(Object? v) => v is String ? v : v?.toString();
  static int? _asInt(Object? v) => v is int
      ? v
      : v is num
      ? v.toInt()
      : v is String
      ? int.tryParse(v)
      : null;
  static bool _asBool(Object? v) => v is bool
      ? v
      : v is num
      ? v != 0
      : v == '1' || v == 'true';
}

class _ColumnDefinition {
  const _ColumnDefinition(this.name, this.definition);
  final String name;
  final String definition;
}

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
