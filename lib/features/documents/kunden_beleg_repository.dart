import 'package:drift/drift.dart';

/// Customer-document links over the canonical `kunden_belege` join table.
///
/// A Beleg has no `kunde_id` column. Removing a customer-document
/// association removes only its `kunden_belege` row and never deletes shared
/// Beleg metadata or source bytes. Deleting the underlying Beleg requires
/// every relationship to be explicitly unlinked first (see BelegRepository).
/// `loeschdatum` stays visible as informational metadata with due/overdue
/// warnings and never triggers automatic purging.
class KundenBelegRepository {
  const KundenBelegRepository(this.executor);

  final QueryExecutor executor;

  /// Links a Beleg to a customer. Idempotent per (kunde_id, beleg_id).
  Future<void> link({required int kundeId, required int belegId, String? rolle}) async {
    final List<Map<String, Object?>> existing = await executor.runSelect(
      'SELECT id FROM kunden_belege WHERE kunde_id = ? AND beleg_id = ? LIMIT 1',
      <Object?>[kundeId, belegId],
    );
    if (existing.isNotEmpty) return;
    await executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id, rolle) VALUES (?, ?, ?)', <Object?>[
      kundeId,
      belegId,
      rolle,
    ]);
  }

  /// Removes only the customer association; the Beleg remains available.
  Future<void> unlink({required int kundeId, required int belegId}) async {
    await executor.runDelete('DELETE FROM kunden_belege WHERE kunde_id = ? AND beleg_id = ?', <Object?>[
      kundeId,
      belegId,
    ]);
  }

  /// Whether a customer link blocks Beleg deletion.
  Future<bool> hasCustomerLink(int belegId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id FROM kunden_belege WHERE beleg_id = ? LIMIT 1',
      <Object?>[belegId],
    );
    return rows.isNotEmpty;
  }

  /// Lists customer documents with informational deletion-date state.
  Future<List<Map<String, Object?>>> listForCustomer(int kundeId) {
    return executor.runSelect(
      'SELECT b.*, kb.rolle FROM belege b JOIN kunden_belege kb ON kb.beleg_id = b.id WHERE kb.kunde_id = ? ORDER BY b.id',
      <Object?>[kundeId],
    );
  }

  /// German DSGVO badge text for a `loeschdatum`, or null when no badge.
  /// Yellow warning ≤ 30 days ("Löschen in N Tagen"), red when overdue.
  static String? dsgvoBadge(String? loeschdatum, {DateTime? today}) {
    if (loeschdatum == null || loeschdatum.isEmpty) return null;
    final DateTime? due = DateTime.tryParse(loeschdatum);
    if (due == null) return null;
    final DateTime now = today ?? DateTime.now();
    final DateTime dueDay = DateTime(due.year, due.month, due.day);
    final DateTime todayDay = DateTime(now.year, now.month, now.day);
    if (todayDay.isAfter(dueDay)) return 'Überfällig zur Löschung vorgesehen';
    final int days = dueDay.difference(todayDay).inDays;
    if (days <= 30) return 'Löschen in $days Tagen';
    return null;
  }
}
