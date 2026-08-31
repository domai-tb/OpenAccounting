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
            position.menge.toStringAsFixed(2),
            position.einzelpreis.toStringAsFixed(2),
            position.gesamt.toStringAsFixed(2),
            position.ustSatz.toStringAsFixed(2),
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

  Future<int> finalizeRechnung({required int rechnungId}) async {
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final invoiceRows = await transaction.runSelect(
        '''
SELECT id, ist_entwurf, datum
FROM rechnungen
WHERE id = ?
''',
        <Object?>[rechnungId],
      );
      if (invoiceRows.isEmpty) {
        throw StateError('Rechnung nicht gefunden');
      }

      final invoice = invoiceRows.single;
      if (_asInt(invoice['ist_entwurf']) != 1) {
        throw StateError('Dokument ist bereits finalisiert');
      }
      final invoiceDate = DateTime.tryParse(invoice['datum']?.toString() ?? '');
      if (invoiceDate == null) {
        throw StateError('Rechnungsdatum ist ungültig');
      }

      final rangeRows = await transaction.runSelect(
        '''
SELECT id, format, naechste_nummer, aktiv
FROM nummernkreise
WHERE typ = ?
ORDER BY id
LIMIT 1
''',
        const <Object?>['rechnung_ausgang'],
      );
      if (rangeRows.isEmpty) {
        throw StateError('Rechnungsausgang-Nummernkreis fehlt');
      }

      final range = rangeRows.single;
      if (_asInt(range['aktiv']) != 1) {
        throw StateError('Rechnungsausgang-Nummernkreis ist inaktiv');
      }
      final format = range['format']?.toString().trim() ?? '';
      if (format.isEmpty) {
        throw StateError('Rechnungsausgang-Nummernkreis hat kein Format');
      }
      final nextNumber = _asInt(range['naechste_nummer']);
      if (nextNumber == null || nextNumber < 1) {
        throw StateError('Rechnungsausgang-Nummernkreis ist erschöpft');
      }
      final sequenceWidth = _sequenceWidth(format);
      if (sequenceWidth != null && (sequenceWidth > 9 || nextNumber > _maximumForWidth(sequenceWidth))) {
        throw StateError('Rechnungsausgang-Nummernkreis ist erschöpft');
      }
      final documentNumber = _formatNumber(format, invoiceDate.year, nextNumber);

      final sequenceUpdated = await transaction.runUpdate(
        '''
UPDATE nummernkreise
SET naechste_nummer = ?
WHERE id = ? AND aktiv = 1 AND naechste_nummer = ?
''',
        <Object?>[nextNumber + 1, range['id'], nextNumber],
      );
      if (sequenceUpdated != 1) {
        throw StateError('Rechnungsausgang-Nummernkreis konnte nicht atomar reserviert werden');
      }

      final invoiceUpdated = await transaction.runUpdate(
        '''
UPDATE rechnungen
SET rechnungsnummer = ?, nummernkreis_id = ?, ist_entwurf = 0, status = ?
WHERE id = ? AND ist_entwurf = 1
''',
        <Object?>[documentNumber, range['id'], 'offen', rechnungId],
      );
      if (invoiceUpdated != 1) {
        throw StateError('Rechnung konnte nicht finalisiert werden');
      }

      await transaction.send();
      return rechnungId;
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

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _sequenceWidth(String format) {
    final match = RegExp(r'\{(#+|N+)\}|(#+)').firstMatch(format);
    final token = match?.group(1) ?? match?.group(2);
    return token?.length;
  }

  static int _maximumForWidth(int width) {
    var maximum = 9;
    for (var index = 1; index < width; index++) {
      maximum = maximum * 10 + 9;
    }
    return maximum;
  }

  static String _formatNumber(String format, int year, int number) {
    final result = format
        .replaceAll('{YYYY}', year.toString())
        .replaceAll('{YY}', _twoDigits(year % 100))
        .replaceAll('YYYY', year.toString())
        .replaceAll('YY', _twoDigits(year % 100));
    return result.replaceAllMapped(RegExp(r'\{(#+|N+)\}|(#+)'), (match) {
      final token = match.group(1) ?? match.group(2)!;
      return number.toString().padLeft(token.length, '0');
    });
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
