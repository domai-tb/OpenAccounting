import 'package:drift/drift.dart';

class CategoryRuleException implements Exception {
  const CategoryRuleException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Persisted auto-filter rule in `auto_filter_regeln`.
class CategoryRule {
  const CategoryRule({
    required this.id,
    required this.pattern,
    required this.kategorieId,
    this.kontoId,
    this.prioritaet = 0,
    this.aktiv = true,
  });
  final int id;
  final String pattern;
  final int kategorieId;
  final int? kontoId;
  final int prioritaet;
  final bool aktiv;
}

/// Rule CRUD + matching per bank-import-confidence-and-rule-workspace.
/// Rules match case-insensitively against Verwendungszweck only; active rules
/// evaluate by priority descending then rule ID ascending. Writes affect
/// future imports only and never rewrite prior transactions.
class CategoryRuleRepository {
  CategoryRuleRepository(this.executor);
  final QueryExecutor executor;

  Future<List<CategoryRule>> list() async {
    final rows = await executor.runSelect(
      'SELECT id, muster, kategorie_id, konto_id, prioritaet, aktiv FROM auto_filter_regeln ORDER BY prioritaet DESC, id ASC',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<CategoryRule> create({
    required String pattern,
    required int kategorieId,
    int? kontoId,
    int prioritaet = 0,
    bool aktiv = true,
  }) async {
    final clean = await _validated(pattern: pattern, kategorieId: kategorieId, prioritaet: prioritaet);
    final int aktivInt = aktiv ? 1 : 0;
    final id = await executor.runInsert(
      'INSERT INTO auto_filter_regeln (muster, kategorie_id, konto_id, prioritaet, aktiv) VALUES (?, ?, ?, ?, ?)',
      <Object?>[clean, kategorieId, kontoId, prioritaet, aktivInt],
    );
    final stored = await findById(id);
    if (stored == null) throw const CategoryRuleException('Regel konnte nicht gespeichert werden');
    return stored;
  }

  Future<CategoryRule?> findById(int id) async {
    final rows = await executor.runSelect(
      'SELECT id, muster, kategorie_id, konto_id, prioritaet, aktiv FROM auto_filter_regeln WHERE id = ?',
      <Object?>[id],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<CategoryRule> update(
    int id, {
    String? pattern,
    int? kategorieId,
    int? kontoId,
    int? prioritaet,
    bool? aktiv,
  }) async {
    final current = await findById(id);
    if (current == null) throw const CategoryRuleException('Regel nicht gefunden');
    final nextPattern = pattern ?? current.pattern;
    final nextKategorie = kategorieId ?? current.kategorieId;
    final nextPrioritaet = prioritaet ?? current.prioritaet;
    final clean = await _validated(pattern: nextPattern, kategorieId: nextKategorie, prioritaet: nextPrioritaet);
    final bool nextAktiv = aktiv ?? current.aktiv;
    final int aktivInt = nextAktiv ? 1 : 0;
    await executor.runUpdate(
      'UPDATE auto_filter_regeln SET muster = ?, kategorie_id = ?, konto_id = ?, prioritaet = ?, aktiv = ? WHERE id = ?',
      <Object?>[clean, nextKategorie, kontoId ?? current.kontoId, nextPrioritaet, aktivInt, id],
    );
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    final deleted = await executor.runDelete('DELETE FROM auto_filter_regeln WHERE id = ?', <Object?>[id]);
    if (deleted == 0) throw const CategoryRuleException('Regel nicht gefunden');
  }

  /// First matching active rule in priority/descending-ID order, or null.
  Future<CategoryRule?> match(String verwendungszweck) async {
    final String lower = verwendungszweck.trim().toLowerCase();
    if (lower.isEmpty) return null;
    for (final rule in await list()) {
      if (!rule.aktiv) continue;
      if (lower.contains(rule.pattern.toLowerCase())) return rule;
    }
    return null;
  }

  Future<String> _validated({required String pattern, required int kategorieId, required int prioritaet}) async {
    final clean = pattern.trim();
    if (clean.isEmpty) throw const CategoryRuleException('Muster ist Pflicht');
    final cats = await executor.runSelect('SELECT id FROM kategorien WHERE id = ?', <Object?>[kategorieId]);
    if (cats.isEmpty) throw const CategoryRuleException('Kategorie nicht gefunden');
    return clean;
  }

  CategoryRule _fromRow(Map<String, Object?> r) {
    return CategoryRule(
      id: (r['id']! as num).toInt(),
      pattern: r['muster']?.toString() ?? '',
      kategorieId: (r['kategorie_id']! as num).toInt(),
      kontoId: (r['konto_id'] as num?)?.toInt(),
      prioritaet: (r['prioritaet'] as num?)?.toInt() ?? 0,
      aktiv: (r['aktiv'] as num?)?.toInt() != 0,
    );
  }
}
