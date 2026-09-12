import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// Repository für Setup-Persistenz: unternehmen, konten (Kasse), kategorien.
/// ponytail: raw SQL — kein Codegen, idempotent für frische + bestehende DB.
class SetupRepository {
  SetupRepository(this.executor);

  final QueryExecutor executor;

  // ---------------------------------------------------------------------------
  // IBAN Validation
  // ---------------------------------------------------------------------------

  /// Validiert IBAN (vereinfacht, DE-fokussiert aber generisch).
  /// Entfernt Leerzeichen, prüft 15–34 alphanumerisch, Ländercode A-Z.
  static bool isValidIban(String raw) {
    final String cleaned = raw.replaceAll(' ', '').replaceAll('-', '').trim().toUpperCase();
    if (cleaned.length < 15 || cleaned.length > 34) return false;
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(cleaned)) return false;
    // DE Spezial: DE + 20 Ziffern = 22
    if (cleaned.startsWith('DE') && !RegExp(r'^DE[0-9]{20}$').hasMatch(cleaned)) {
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Unternehmen
  // ---------------------------------------------------------------------------

  Future<void> saveUnternehmen({
    required String name,
    String? strasse,
    String? plz,
    String? ort,
    String? steuernummer,
    String? ustIdnr,
    String? rechtsform,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) throw const SetupException('Name ist Pflicht');
    // ensure row exists
    await executor.runInsert('INSERT OR IGNORE INTO unternehmen (id, name) VALUES (1, ?)', <Object?>[trimmed]);
    await executor.runUpdate(
      'UPDATE unternehmen SET name = ?, strasse = COALESCE(?, strasse), '
      'plz = COALESCE(?, plz), ort = COALESCE(?, ort), '
      'steuernummer = COALESCE(?, steuernummer), ust_idnr = COALESCE(?, ust_idnr) WHERE id = 1',
      <Object?>[trimmed, strasse, plz, ort, steuernummer, ustIdnr],
    );
    if (rechtsform != null) {
      await _addColumnIfMissing('unternehmen', 'rechtsform', 'TEXT');
      await executor.runUpdate('UPDATE unternehmen SET rechtsform = ? WHERE id = 1', <Object?>[rechtsform]);
    }
  }

  // ---------------------------------------------------------------------------
  // Konten
  // ---------------------------------------------------------------------------

  Future<int> createKonto({
    required String name,
    String? iban,
    String? bic,
    String? inhaber,
    String kontoart = 'Bank',
  }) async {
    if (iban != null && iban.trim().isNotEmpty && !isValidIban(iban)) {
      throw const SetupException('IBAN ungültig');
    }
    final normalizedIban = iban == null ? null : _normalizeIban(iban);
    if (normalizedIban != null && normalizedIban.isNotEmpty) {
      final existing = await executor.runSelect('SELECT id, iban FROM konten WHERE iban IS NOT NULL', const []);
      for (final row in existing) {
        final storedIban = row['iban'];
        if (storedIban is! String || _normalizeIban(storedIban) != normalizedIban) {
          continue;
        }
        final id = (row['id'] as num?)?.toInt();
        if (id == null) continue;
        await executor.runUpdate(
          'UPDATE konten SET name = ?, bic = ?, kontoart = ?, waehrung = ? WHERE id = ?',
          <Object?>[name.trim(), bic, kontoart, 'EUR', id],
        );
        return id;
      }
    }
    final int id = await executor.runInsert(
      'INSERT INTO konten (name, iban, bic, kontoart, waehrung) VALUES (?, ?, ?, ?, ?)',
      <Object?>[name, normalizedIban, bic, kontoart, 'EUR'],
    );
    return id;
  }

  /// Erstellt oder aktualisiert Kasse-Konto + Eröffnungs-Journal.
  /// Betrag als String '0.00' — negativ abgelehnt. Idempotent: nur ein Kasse-Konto.
  Future<void> ensureKassenKonto({required String betrag}) async {
    final String t = betrag.trim().replaceAll(',', '.');
    final String normalized = t.isEmpty ? '0.00' : t;
    if (normalized.startsWith('-')) {
      throw const SetupException('Kassenbestand darf nicht negativ sein');
    }
    final String formatted = money.formatBetrag(normalized);
    // validate numeric 12,2
    final int cents = money.toCents(formatted);
    if (cents < 0) {
      throw const SetupException('Kassenbestand darf nicht negativ sein');
    }

    // Reuse an account already named Kasse/Kassenbestand as well as one whose
    // account type is Kasse.  The wizard accepts a user supplied account list,
    // so otherwise a row named "Kasse" with the default Bank type would be
    // left at zero while a second hidden Kasse row receives the opening cash.
    final List<Map<String, Object?>> existing = await executor.runSelect(
      "SELECT id FROM konten WHERE kontoart = 'Kasse' OR name IN ('Kasse', 'Kassenbestand') "
      "ORDER BY CASE WHEN kontoart = 'Kasse' THEN 0 ELSE 1 END, id LIMIT 1",
      const [],
    );
    int kasseId;
    if (existing.isEmpty) {
      kasseId = await executor.runInsert(
        "INSERT INTO konten (name, kontoart, waehrung, saldo) VALUES ('Kasse', 'Kasse', 'EUR', 0)",
        const [],
      );
    } else {
      kasseId = ((existing.single['id'] as num?) ?? 0).toInt();
      await executor.runUpdate(
        "UPDATE konten SET name = 'Kasse', kontoart = 'Kasse', waehrung = 'EUR' WHERE id = ?",
        <Object?>[kasseId],
      );
    }

    await _addColumnIfMissing('journal', 'is_opening_balance', 'INTEGER DEFAULT 0');
    final String datum = _todayIso();
    // stable marker: WHERE is_opening_balance=1 (not konto_id LIMIT 1 — that clobbered unrelated rows)
    List<Map<String, Object?>> journals = await executor.runSelect(
      'SELECT id FROM journal WHERE is_opening_balance = 1 LIMIT 1',
      const [],
    );
    if (journals.isEmpty) {
      // backfill legacy opening entry created before marker existed
      final List<Map<String, Object?>> legacy = await executor.runSelect(
        'SELECT id FROM journal WHERE beleg_typ = ? LIMIT 1',
        <Object?>[BelegTyp.eroeffnung],
      );
      if (legacy.isNotEmpty) {
        final int legacyId = ((legacy.single['id'] as num?) ?? 0).toInt();
        await executor.runUpdate('UPDATE journal SET is_opening_balance = 1 WHERE id = ?', <Object?>[legacyId]);
        journals = await executor.runSelect('SELECT id FROM journal WHERE is_opening_balance = 1 LIMIT 1', const []);
      }
    }
    if (journals.isEmpty) {
      // need at least one kategorie for FK — use first available or create fallback 1
      int kategorieId = 1;
      try {
        final List<Map<String, Object?>> kats = await executor.runSelect('SELECT id FROM kategorien LIMIT 1', const []);
        if (kats.isNotEmpty) {
          kategorieId = ((kats.single['id'] as num?) ?? 0).toInt();
        }
      } catch (_) {}
      await executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
        'VALUES (?, ?, ?, ?, ?, ?, 0, 1)',
        <Object?>[datum, 'Eröffnung Kasse', kategorieId, formatted, BelegTyp.eroeffnung, kasseId],
      );
    } else {
      final int jid = ((journals.single['id'] as num?) ?? 0).toInt();
      await executor.runUpdate(
        'UPDATE journal SET betrag = ?, datum = ?, konto_id = ?, beleg_typ = ?, beschreibung = ?, is_opening_balance = 1 WHERE id = ?',
        <Object?>[formatted, datum, kasseId, BelegTyp.eroeffnung, 'Eröffnung Kasse', jid],
      );
    }
    // Keep the account read model consistent with its opening journal entry.
    // Setup may be retried, so assign the opening balance instead of adding it.
    await executor.runUpdate('UPDATE konten SET saldo = ? WHERE id = ?', <Object?>[formatted, kasseId]);
  }

  // ---------------------------------------------------------------------------
  // Kategorien
  // ---------------------------------------------------------------------------

  Future<void> ensureKategorienSelected(List<int> ids) async {
    if (ids.isEmpty) {
      throw const SetupException('Mindestens eine Kategorie erforderlich');
    }
    // seed guarantees 1..85 exist; validate each exists
    for (final int id in ids) {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM kategorien WHERE id = ?',
        <Object?>[id],
      );
      if (rows.isEmpty) throw SetupException('Kategorie $id nicht gefunden');
    }
    // persist selection as unternehmen.dashboard_config or shared flag — minimal: nothing extra
  }

  // ---------------------------------------------------------------------------
  // Skip defaults
  // ---------------------------------------------------------------------------

  Future<void> createMinimalDefaults() => runInTransaction<void>((SetupRepository repository) {
    return repository._createMinimalDefaults();
  });

  Future<void> _createMinimalDefaults() async {
    await executor.runInsert('INSERT OR IGNORE INTO unternehmen (id, name) VALUES (1, ?)', const ['Meine Firma']);
    // keep existing name if already set to real value
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT name FROM unternehmen WHERE id = 1',
      const [],
    );
    if (rows.single['name'] == 'Meine Firma') {
      await executor.runUpdate('UPDATE unternehmen SET name = ? WHERE id = 1', const ['Meine Firma']);
    }
    await ensureKassenKonto(betrag: '0.00');
    // kategorien already seeded — ensure at least one aktiv
  }

  /// Run a complete setup write as one SQLite transaction.
  Future<T> runInTransaction<T>(Future<T> Function(SetupRepository repository) operation) async {
    final TransactionExecutor transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_SetupTransactionUser());
      final T result = await operation(SetupRepository(transaction));
      await transaction.send();
      return result;
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _addColumnIfMissing(String table, String name, String definition) async {
    final columns = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (columns.any((column) => column['name'] == name)) return;
    await executor.runCustom('ALTER TABLE $table ADD COLUMN $name $definition');
    final verified = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (!verified.any((column) => column['name'] == name)) {
      throw StateError('Setup konnte Spalte $table.$name nicht verifizieren');
    }
  }

  static String _normalizeIban(String raw) => raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  String _todayIso() {
    final DateTime now = DateTime.now();
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class SetupException implements Exception {
  const SetupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SetupDatabaseException extends SetupException {
  const SetupDatabaseException(super.message, {this.cause});

  final Object? cause;
}

class _SetupTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
