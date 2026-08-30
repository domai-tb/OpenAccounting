import 'package:drift/drift.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

class RechnungenDataSource {
  const RechnungenDataSource(this.executor);

  final QueryExecutor executor;

  Future<int> createDraftRechnung({required String datum, required List<RechnungPositionItem> positionen}) async {
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final invoiceId = await transaction.runInsert(
        '''
INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus)
VALUES (?, ?, ?, ?, ?, ?)
''',
        <Object?>[null, 'rechnung', 'entwurf', datum, 1, 'netto'],
      );

      for (var index = 0; index < positionen.length; index++) {
        final position = positionen[index];
        await transaction.runInsert(
          '''
INSERT INTO rechnungspositionen (
  rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
          <Object?>[
            invoiceId,
            position.artikelId,
            position.bezeichnung,
            position.menge,
            position.einzelpreis,
            position.gesamt,
            position.ustSatz,
            position.position ?? index,
          ],
        );
      }
      await transaction.send();
      return invoiceId;
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<Map<String, Object?>?> findRechnungById(int id) async {
    final rows = await executor.runSelect(
      '''
SELECT id, rechnungsnummer, typ, status, ist_entwurf, eingabemodus, datum
FROM rechnungen
WHERE id = ?
''',
      <Object?>[id],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> findPositionenByRechnungId(int rechnungId) {
    return executor.runSelect(
      '''
SELECT id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position
FROM rechnungspositionen
WHERE rechnung_id = ?
ORDER BY position, id
''',
      <Object?>[rechnungId],
    );
  }
}

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
