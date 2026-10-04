import 'package:drift/drift.dart';

/// Company fiscal-year configuration per fiscal-year-calendar.
///
/// The start month (1–12, January default) lives in
/// `unternehmen.geschaeftsjahr_startmonat`, written only through this
/// repository. Reads resolve missing company rows to January; writes outside
/// 1–12 are rejected. Reads/writes never modify postings, invoices, or
/// exported snapshots.
class FiscalYearException implements Exception {
  const FiscalYearException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FiscalYearRepository {
  FiscalYearRepository(this.executor);
  final QueryExecutor executor;

  static const int defaultStartMonth = 1;

  /// Active start month, defaulting to January when no company row or no
  /// valid value is stored. Never substitutes silently on write paths.
  Future<int> getStartMonth() async {
    final rows = await executor.runSelect(
      'SELECT geschaeftsjahr_startmonat FROM unternehmen LIMIT 1',
      const <Object?>[],
    );
    if (rows.isEmpty) return defaultStartMonth;
    final Object? raw = rows.single['geschaeftsjahr_startmonat'];
    final int month = raw is int ? raw : (raw is num ? raw.toInt() : defaultStartMonth);
    if (month < 1 || month > 12) return defaultStartMonth;
    return month;
  }

  /// Persists [month] (1–12). Throws on invalid input or missing company row;
  /// a failed save never changes the active setting.
  Future<void> setStartMonth(int month) async {
    if (month < 1 || month > 12) {
      throw const FiscalYearException('Startmonat muss zwischen 1 und 12 liegen');
    }
    final updated = await executor.runUpdate('UPDATE unternehmen SET geschaeftsjahr_startmonat = ?', <Object?>[month]);
    if (updated == 0) {
      throw const FiscalYearException('Kein Unternehmensprofil für Geschäftsjahr vorhanden');
    }
  }
}
