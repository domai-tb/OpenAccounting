import 'package:drift/drift.dart';

/// Setup category-catalog gate per `settings-setup-workspace-completion`.
///
/// Category selection is enabled only when the database holds catalog-verified
/// records whose source/edition provenance and reviewed mapping manifest come
/// from the accepted `accounting-catalog-provenance` contract. A version
/// string or populated category table alone never establishes trust; synthetic
/// `Kategorie N` rows and unverified versions stay deferred.
class CatalogProvenanceState {
  const CatalogProvenanceState({required this.verified, required this.verifiedNames});

  final bool verified;
  final List<({int id, String name})> verifiedNames;
}

Future<CatalogProvenanceState> loadCatalogProvenance(QueryExecutor executor) async {
  try {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, bezeichnung, catalog_source_reference, catalog_source_version, mapping_status '
      'FROM kategorien WHERE mapping_status = ? ORDER BY id',
      const <Object?>['catalog_verified'],
    );
    final List<({int id, String name})> verified = <({int id, String name})>[];
    for (final Map<String, Object?> row in rows) {
      final Object? source = row['catalog_source_reference'];
      final Object? version = row['catalog_source_version'];
      final String sourceText = source is String ? source.trim() : '';
      final String versionText = version is String ? version.trim() : '';
      if (sourceText.isEmpty || versionText.isEmpty) continue;
      final Object? idRaw = row['id'];
      final int id = idRaw is int ? idRaw : (idRaw! as num).toInt();
      final Object? nameRaw = row['bezeichnung'];
      final String name = nameRaw is String && nameRaw.trim().isNotEmpty ? nameRaw : 'Kategorie $id';
      verified.add((id: id, name: name));
    }
    return CatalogProvenanceState(verified: verified.isNotEmpty, verifiedNames: verified);
  } catch (_) {
    return const CatalogProvenanceState(verified: false, verifiedNames: <({int id, String name})>[]);
  }
}

/// Synthetic seed rows are never offered as configured records.
bool isSyntheticCategoryLabel(String name) {
  final String trimmed = name.trim();
  if (RegExp(r'^Kategorie(n)?\s+\d+$', caseSensitive: false).hasMatch(trimmed)) return true;
  if (RegExp(r'^Kategorien\s+\d+$').hasMatch(trimmed)) return true;
  return false;
}
