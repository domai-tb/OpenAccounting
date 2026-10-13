import 'package:drift/drift.dart';

/// Customer and invoice dunning exclusions.
///
/// Additive profile-local table, created idempotently; no migration version
/// bump (checked against `MigrationRunner.currentVersion = 21`: no new
/// migration step is added by this change).
class DunningExclusionsRepository {
  DunningExclusionsRepository(this.executor);

  final QueryExecutor executor;

  Future<void>? _ready;

  Future<void> ensureSchema() => _ready ??= _ensure();

  Future<void> _ensure() async {
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS mahnwesen_ausschluesse (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER REFERENCES kunden(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  grund TEXT NOT NULL,
  erstellt_am TEXT NOT NULL,
  CHECK (kunde_id IS NOT NULL OR rechnung_id IS NOT NULL)
)''');
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_mahnwesen_ausschluesse_kunde ON mahnwesen_ausschluesse(kunde_id)',
    );
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_mahnwesen_ausschluesse_rechnung ON mahnwesen_ausschluesse(rechnung_id)',
    );
  }

  Future<int> excludeCustomer(int kundeId, String grund) async {
    await ensureSchema();
    if (kundeId <= 0) throw ArgumentError('kundeId muss > 0 sein');
    if (grund.trim().isEmpty) throw ArgumentError('Grund ist Pflicht');
    return executor.runInsert(
      'INSERT INTO mahnwesen_ausschluesse (kunde_id, grund, erstellt_am) VALUES (?, ?, ?)',
      <Object?>[kundeId, grund.trim(), DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<int> excludeInvoice(int rechnungId, String grund) async {
    await ensureSchema();
    if (rechnungId <= 0) throw ArgumentError('rechnungId muss > 0 sein');
    if (grund.trim().isEmpty) throw ArgumentError('Grund ist Pflicht');
    return executor.runInsert(
      'INSERT INTO mahnwesen_ausschluesse (rechnung_id, grund, erstellt_am) VALUES (?, ?, ?)',
      <Object?>[rechnungId, grund.trim(), DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<void> removeExclusion(int id) async {
    await ensureSchema();
    await executor.runDelete('DELETE FROM mahnwesen_ausschluesse WHERE id = ?', <Object?>[id]);
  }

  Future<bool> isExcluded({int? kundeId, int? rechnungId}) async {
    await ensureSchema();
    if (kundeId != null && kundeId > 0) {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM mahnwesen_ausschluesse WHERE kunde_id = ? LIMIT 1',
        <Object?>[kundeId],
      );
      if (rows.isNotEmpty) return true;
    }
    if (rechnungId != null && rechnungId > 0) {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM mahnwesen_ausschluesse WHERE rechnung_id = ? LIMIT 1',
        <Object?>[rechnungId],
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<List<Map<String, Object?>>> list() async {
    await ensureSchema();
    return executor.runSelect(
      'SELECT id, kunde_id, rechnung_id, grund, erstellt_am FROM mahnwesen_ausschluesse ORDER BY id ASC',
      const <Object?>[],
    );
  }
}
