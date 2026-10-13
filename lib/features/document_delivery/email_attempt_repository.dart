import 'package:drift/drift.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';

// Durable send-attempt history: each user-confirmed attempt is recorded as
// `submitting` before network transmission and ends as `accepted` (SMTP final
// success response only — never "delivered"), `rejected`, or `unknown`.
// Recovery converts abandoned `submitting` rows to `unknown` and never
// resubmits. History stores no credentials, bodies, or attachment bytes.

class EmailAttempt {
  const EmailAttempt({
    required this.id,
    required this.dokumentId,
    required this.dokumentTyp,
    required this.empfaenger,
    required this.ergebnis,
    required this.idempotenzSchluessel,
    required this.erstelltAm,
    this.mahnungId,
    this.artefaktIds = const <String>[],
    this.abgeschlossenAm,
    this.fehlerKategorie,
  });

  final int id;
  final int dokumentId;
  final String dokumentTyp;
  final String empfaenger;
  final String ergebnis;
  final String idempotenzSchluessel;
  final String erstelltAm;
  final int? mahnungId;
  final List<String> artefaktIds;
  final String? abgeschlossenAm;
  final String? fehlerKategorie;
}

class EmailAttemptRepository {
  EmailAttemptRepository(this.executor);

  final QueryExecutor executor;
  Future<void>? _ready;

  Future<void> ensureSchema() => _ready ??= _ensure();

  Future<void> _ensure() async {
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS dokument_email_versuche (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dokument_id INTEGER NOT NULL,
  dokument_typ TEXT NOT NULL,
  empfaenger TEXT NOT NULL,
  ergebnis TEXT NOT NULL DEFAULT 'submitting',
  mahnung_id INTEGER,
  idempotenz_schluessel TEXT NOT NULL UNIQUE,
  artefakt_ids TEXT NOT NULL DEFAULT '[]',
  erstellt_am TEXT NOT NULL,
  abgeschlossen_am TEXT,
  fehler_kategorie TEXT
)''');
    await executor.runCustom(
      'CREATE INDEX IF NOT EXISTS idx_email_versuche_dokument ON dokument_email_versuche(dokument_id, erstellt_am)',
    );
  }

  /// Records the attempt as `submitting` before any network transmission.
  Future<EmailAttempt> begin({
    required int dokumentId,
    required String dokumentTyp,
    required String empfaenger,
    required List<String> artefaktIds,
    int? mahnungId,
    String? idempotenzSchluessel,
  }) async {
    await ensureSchema();
    final String key =
        idempotenzSchluessel ?? 'dok-$dokumentTyp-$dokumentId-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final String now = DateTime.now().toUtc().toIso8601String();
    try {
      final int id = await executor.runInsert(
        'INSERT INTO dokument_email_versuche (dokument_id, dokument_typ, empfaenger, ergebnis, mahnung_id, '
        'idempotenz_schluessel, artefakt_ids, erstellt_am) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          dokumentId,
          dokumentTyp,
          empfaenger,
          EmailAttemptOutcome.submitting,
          mahnungId,
          key,
          artefaktIds.join(','),
          now,
        ],
      );
      final EmailAttempt? created = await findById(id);
      if (created == null) throw const DocumentDeliveryException('Sendeversuch verloren', code: 'versuch_fehlt');
      return created;
    } catch (error) {
      if ('$error'.contains('UNIQUE') || '$error'.contains('unique')) {
        final EmailAttempt? existing = await findByKey(key);
        if (existing != null) return existing;
      }
      rethrow;
    }
  }

  Future<EmailAttempt?> findById(int id) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM dokument_email_versuche WHERE id = ?',
      <Object?>[id],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<EmailAttempt?> findByKey(String key) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM dokument_email_versuche WHERE idempotenz_schluessel = ?',
      <Object?>[key],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<EmailAttempt?> findInProgress(int dokumentId) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      "SELECT * FROM dokument_email_versuche WHERE dokument_id = ? AND ergebnis = 'submitting' "
      'ORDER BY erstellt_am DESC, id DESC LIMIT 1',
      <Object?>[dokumentId],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<EmailAttempt>> historyFor(int dokumentId) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM dokument_email_versuche WHERE dokument_id = ? ORDER BY erstellt_am DESC, id DESC',
      <Object?>[dokumentId],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  /// After the SMTP final success response, commits accepted + invoice
  /// first-output time + the owner projection in one local transaction. The
  /// projection stays attached by stable reminder/attempt IDs and must be
  /// idempotent; first-release Mahnung sending remains unavailable.
  Future<EmailAttempt> commitAccepted(
    int attemptId, {
    Future<void> Function(TransactionExecutor transaction) ownerProjection = _noProjection,
  }) async {
    await ensureSchema();
    final TransactionExecutor transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopUser());
      final List<Map<String, Object?>> rows = await transaction.runSelect(
        'SELECT * FROM dokument_email_versuche WHERE id = ?',
        <Object?>[attemptId],
      );
      if (rows.isEmpty) throw const DocumentDeliveryException('Sendeversuch verloren', code: 'versuch_fehlt');
      final EmailAttempt attempt = _fromRow(rows.single);
      if (attempt.ergebnis == EmailAttemptOutcome.accepted) {
        await transaction.send();
        return attempt;
      }
      final String now = DateTime.now().toUtc().toIso8601String();
      await transaction.runUpdate(
        "UPDATE dokument_email_versuche SET ergebnis = 'accepted', abgeschlossen_am = ? WHERE id = ?",
        <Object?>[now, attemptId],
      );
      final List<Map<String, Object?>> invoices = await transaction.runSelect(
        'SELECT ausgegeben_am FROM rechnungen WHERE id = ?',
        <Object?>[attempt.dokumentId],
      );
      if (invoices.isNotEmpty && invoices.single['ausgegeben_am'] == null) {
        await transaction.runUpdate('UPDATE rechnungen SET ausgegeben_am = ? WHERE id = ?', <Object?>[
          now,
          attempt.dokumentId,
        ]);
      }
      await ownerProjection(transaction);
      await transaction.send();
      final EmailAttempt? updated = await findById(attemptId);
      if (updated == null) throw const DocumentDeliveryException('Sendeversuch verloren', code: 'versuch_fehlt');
      return updated;
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<EmailAttempt> finish(int attemptId, String ergebnis, {String? fehlerKategorie}) async {
    await ensureSchema();
    if (ergebnis != EmailAttemptOutcome.rejected && ergebnis != EmailAttemptOutcome.unknown) {
      throw const DocumentDeliveryException('Ungültiges Endergebnis', code: 'ergebnis_ungueltig');
    }
    await executor.runUpdate(
      'UPDATE dokument_email_versuche SET ergebnis = ?, abgeschlossen_am = ?, fehler_kategorie = ? WHERE id = ?',
      <Object?>[ergebnis, DateTime.now().toUtc().toIso8601String(), fehlerKategorie, attemptId],
    );
    final EmailAttempt? updated = await findById(attemptId);
    if (updated == null) throw const DocumentDeliveryException('Sendeversuch verloren', code: 'versuch_fehlt');
    return updated;
  }

  /// Startup recovery: abandoned `submitting` rows become `unknown`, keep
  /// their stable reminder link, and are never resubmitted.
  Future<int> recoverIncomplete() async {
    await ensureSchema();
    return executor.runUpdate(
      "UPDATE dokument_email_versuche SET ergebnis = 'unknown', fehler_kategorie = 'wiederhergestellt', "
      "abgeschlossen_am = ? WHERE ergebnis = 'submitting'",
      <Object?>[DateTime.now().toUtc().toIso8601String()],
    );
  }

  EmailAttempt _fromRow(Map<String, Object?> row) {
    int? asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}');
    }

    return EmailAttempt(
      id: asInt(row['id']) ?? 0,
      dokumentId: asInt(row['dokument_id']) ?? 0,
      dokumentTyp: '${row['dokument_typ'] ?? ''}',
      empfaenger: '${row['empfaenger'] ?? ''}',
      ergebnis: '${row['ergebnis'] ?? EmailAttemptOutcome.unknown}',
      idempotenzSchluessel: '${row['idempotenz_schluessel'] ?? ''}',
      erstelltAm: '${row['erstellt_am'] ?? ''}',
      mahnungId: asInt(row['mahnung_id']),
      artefaktIds: '${row['artefakt_ids'] ?? ''}'.split(',').where((String e) => e.isNotEmpty).toList(),
      abgeschlossenAm: row['abgeschlossen_am'] as String?,
      fehlerKategorie: row['fehler_kategorie'] as String?,
    );
  }

  static Future<void> _noProjection(TransactionExecutor _) async {}
}

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
