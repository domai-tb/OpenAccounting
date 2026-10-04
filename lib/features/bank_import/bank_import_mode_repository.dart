import 'package:drift/drift.dart';

/// Bank import profile mode per bank-import-confidence-and-rule-workspace.
/// `manual` (1) is the default for fresh and existing profiles; `automatic`
/// (0) links only unique ≥90% candidates after explicit confirmation and
/// never creates postings or payments.
enum BankImportMode {
  manual(1),
  automatic(0);

  const BankImportMode(this.db);
  final int db;

  static BankImportMode fromDb(Object? v) => v == 0 ? BankImportMode.automatic : BankImportMode.manual;
}

class BankImportModeException implements Exception {
  const BankImportModeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Profile-scoped import mode behind `unternehmen.bank_import_manuell`.
/// There is deliberately no schema fallback: the column exists only through
/// the ordered v10 migration or fresh v10 schema. A missing column surfaces
/// as a failure (Banking must not run against it); a missing company row or
/// an unresolvable value resolves to manual mode.
class BankImportModeRepository {
  BankImportModeRepository(this.executor);
  final QueryExecutor executor;

  Future<BankImportMode> getMode() async {
    final rows = await executor.runSelect('SELECT bank_import_manuell FROM unternehmen LIMIT 1', const <Object?>[]);
    if (rows.isEmpty) return BankImportMode.manual;
    return BankImportMode.fromDb(rows.single['bank_import_manuell']);
  }

  Future<void> setMode(BankImportMode mode) async {
    final updated = await executor.runUpdate('UPDATE unternehmen SET bank_import_manuell = ?', <Object?>[mode.db]);
    if (updated == 0) {
      throw const BankImportModeException('Kein Unternehmensprofil für Importmodus vorhanden');
    }
  }
}
