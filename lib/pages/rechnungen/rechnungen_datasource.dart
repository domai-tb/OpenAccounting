import 'dart:convert';

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
SELECT id, ist_entwurf, datum, unternehmen_id
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
WHERE typ = ? AND aktiv = 1
ORDER BY id
LIMIT 1
''',
        const <Object?>['rechnung_ausgang'],
      );
      if (rangeRows.isEmpty) {
        throw StateError('Rechnungsausgang-Nummernkreis fehlt');
      }

      final range = rangeRows.single;
      final format = range['format']?.toString().trim() ?? '';
      final sequenceMatches = _sequenceMatchesForFormat(format);
      if (sequenceMatches == null || sequenceMatches.length != 1) {
        throw StateError('Rechnungsausgang-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
      }

      final storedNextNumber = _asInt(range['naechste_nummer']);
      if (storedNextNumber == null || storedNextNumber < 1) {
        throw StateError('Rechnungsausgang-Nummernkreis ist erschöpft');
      }

      final latestRows = await transaction.runSelect(
        '''
SELECT datum
FROM rechnungen
WHERE nummernkreis_id = ? AND ist_entwurf = 0 AND rechnungsnummer IS NOT NULL
''',
        <Object?>[range['id']],
      );
      DateTime? latestDate;
      for (final row in latestRows) {
        final date = DateTime.tryParse(row['datum']?.toString() ?? '');
        if (date != null && (latestDate == null || date.isAfter(latestDate))) {
          latestDate = date;
        }
      }
      if (latestDate != null && latestDate.year > invoiceDate.year) {
        throw StateError('Rechnungsdatum liegt vor letzter finalisierter Rechnung');
      }
      final nextNumber = latestDate != null && latestDate.year < invoiceDate.year ? 1 : storedNextNumber;
      final sequenceWidth = _sequenceWidth(sequenceMatches.single);
      if (sequenceWidth > 9 || nextNumber > _maximumForWidth(sequenceWidth)) {
        throw StateError('Rechnungsausgang-Nummernkreis ist erschöpft');
      }
      final documentNumber = _formatNumber(format, invoiceDate.year, nextNumber);

      final companyRows = invoice['unternehmen_id'] == null
          ? const <Map<String, Object?>>[]
          : await transaction.runSelect('SELECT * FROM unternehmen WHERE id = ?', <Object?>[invoice['unternehmen_id']]);
      final senderSnapshot = jsonEncode(companyRows.isEmpty ? <String, Object?>{} : companyRows.single);
      final issuedAt = DateTime.now().toUtc().toIso8601String();

      final sequenceUpdated = await transaction.runUpdate(
        '''
UPDATE nummernkreise
SET naechste_nummer = ?
WHERE id = ? AND aktiv = 1 AND naechste_nummer = ?
''',
        <Object?>[nextNumber + 1, range['id'], storedNextNumber],
      );
      if (sequenceUpdated != 1) {
        throw StateError('Rechnungsausgang-Nummernkreis konnte nicht atomar reserviert werden');
      }

      final invoiceUpdated = await transaction.runUpdate(
        '''
UPDATE rechnungen
SET rechnungsnummer = ?, nummernkreis_id = ?, ist_entwurf = 0, status = ?, absender_snapshot = ?, ausgegeben_am = ?
WHERE id = ? AND ist_entwurf = 1
''',
        <Object?>[documentNumber, range['id'], 'offen', senderSnapshot, issuedAt, rechnungId],
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

  static List<RegExpMatch>? _sequenceMatchesForFormat(String format) {
    final tokens = _formatTokenPattern.allMatches(format).toList(growable: false);
    var end = 0;
    for (final token in tokens) {
      if (token.start != end) return null;
      end = token.end;
    }
    if (end != format.length) return null;
    return _sequenceTokenPattern.allMatches(format).toList(growable: false);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int _sequenceWidth(RegExpMatch match) {
    final token = match.group(1) ?? match.group(0)!;
    return token.length;
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
    return result.replaceAllMapped(_sequenceTokenPattern, (match) {
      final token = match.group(1) ?? match.group(0)!;
      return number.toString().padLeft(token.length, '0');
    });
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

final RegExp _formatTokenPattern = RegExp(r'\{(?:YYYY|YY|#+|N+)\}|YYYY|YY|#+|(?<![A-Za-z])N+(?![A-Za-z])|[^{}#]');
final RegExp _sequenceTokenPattern = RegExp(r'\{(#+|N+)\}|#+|(?<![A-Za-z])N+(?![A-Za-z])');

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
