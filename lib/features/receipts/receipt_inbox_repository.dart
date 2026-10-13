import 'dart:io';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/documents/beleg_repository.dart';

/// Review states of the receipt inbox lifecycle.
enum ReceiptReviewState { neu, geprueft, verknuepft }

/// Actionable receipt inbox over the Beleg store.
///
/// Import retains original bytes unchanged with SHA-256 metadata; review and
/// association are explicit transitions (import → review → association).
/// Associating evidence never creates a posting or allocates a payment —
/// that is a separate confirmed operation. Recognition suggestions stay
/// advisory until explicitly accepted. Preview failures preserve the record.
class ReceiptInboxRepository {
  ReceiptInboxRepository(this.executor, {this.profileDir}) : belege = BelegRepository(executor, profileDir: profileDir);

  final QueryExecutor executor;
  final String? profileDir;
  final BelegRepository belege;

  /// Imports a receipt into the inbox. Returns the Beleg id.
  Future<int> importReceipt({required Uint8List bytes, required String filename, String? beschreibung}) {
    return belege.importSource(bytes: bytes, filename: filename, beschreibung: beschreibung);
  }

  /// Marks a receipt reviewed with an explicit decision. Manual assignment
  /// stays available when parsing or recognition failed.
  Future<void> markReviewed({required int belegId, String entscheidung = 'geprüft'}) async {
    await executor.runUpdate('UPDATE belege SET status = ? WHERE id = ?', <Object?>['geprueft:$entscheidung', belegId]);
  }

  /// Associates a reviewed receipt with an invoice, journal record, customer,
  /// supplier, or package target. Creates no posting or payment allocation.
  Future<void> associate({
    required int belegId,
    int? rechnungId,
    int? journalId,
    int? kundeId,
    int? lieferantId,
    int? paketId,
    String? rolle,
  }) async {
    if (rechnungId == null && journalId == null && kundeId == null && lieferantId == null && paketId == null) {
      throw StateError('Kein Zuordnungsziel angegeben');
    }
    if (rechnungId != null) {
      await belege.attachToInvoice(belegId: belegId, rechnungId: rechnungId);
    }
    if (journalId != null) {
      final List<Map<String, Object?>> rows = await executor.runSelect('SELECT id FROM journal WHERE id = ?', <Object?>[
        journalId,
      ]);
      if (rows.isEmpty) throw StateError('Journalbuchung nicht gefunden');
      await executor.runUpdate('UPDATE journal SET beleg_id = ? WHERE id = ?', <Object?>[belegId, journalId]);
    }
    if (kundeId != null) {
      final List<Map<String, Object?>> existing = await executor.runSelect(
        'SELECT id FROM kunden_belege WHERE kunde_id = ? AND beleg_id = ? LIMIT 1',
        <Object?>[kundeId, belegId],
      );
      if (existing.isEmpty) {
        await executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id, rolle) VALUES (?, ?, ?)', <Object?>[
          kundeId,
          belegId,
          rolle,
        ]);
      }
    }
    if (lieferantId != null) {
      await executor.runUpdate('UPDATE belege SET lieferant_id = ? WHERE id = ?', <Object?>[lieferantId, belegId]);
    }
    if (paketId != null) {
      final List<Map<String, Object?>> existing = await executor.runSelect(
        'SELECT id FROM dokumentenpaket_belege WHERE paket_id = ? AND beleg_id = ? LIMIT 1',
        <Object?>[paketId, belegId],
      );
      if (existing.isEmpty) {
        await executor.runInsert('INSERT INTO dokumentenpaket_belege (paket_id, beleg_id) VALUES (?, ?)', <Object?>[
          paketId,
          belegId,
        ]);
      }
    }
    await executor.runUpdate('UPDATE belege SET status = ? WHERE id = ?', <Object?>['verknuepft', belegId]);
  }

  /// Reads the stored source for preview. Returns a German unavailability
  /// message instead of throwing, preserving receipt state and links.
  Future<({Uint8List? bytes, String? unavailable})> previewSource(int belegId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT dateipfad FROM belege WHERE id = ?',
      <Object?>[belegId],
    );
    if (rows.isEmpty) return (bytes: null, unavailable: 'Beleg nicht gefunden');
    final String? path = rows.single['dateipfad']?.toString();
    if (path == null || path.isEmpty) return (bytes: null, unavailable: 'Quelle ist nicht verfügbar');
    try {
      final File file = File(path);
      if (!file.existsSync()) return (bytes: null, unavailable: 'Quelle ist nicht verfügbar');
      final Uint8List bytes = file.readAsBytesSync();
      if (bytes.isEmpty) return (bytes: null, unavailable: 'Quelle ist nicht lesbar');
      return (bytes: bytes, unavailable: null);
    } catch (_) {
      return (bytes: null, unavailable: 'Quelle ist nicht lesbar');
    }
  }

  /// Lists inbox receipts with review state.
  Future<List<Map<String, Object?>>> listInbox({String? statusPrefix}) {
    if (statusPrefix == null || statusPrefix.isEmpty) {
      return executor.runSelect('SELECT * FROM belege ORDER BY id DESC', const <Object?>[]);
    }
    return executor.runSelect('SELECT * FROM belege WHERE status LIKE ? ORDER BY id DESC', <Object?>['$statusPrefix%']);
  }
}
