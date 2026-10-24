import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// Repository für Setup-Persistenz: unternehmen, konten (Kasse), kategorien.
/// ponytail: raw SQL — kein Codegen, idempotent für frische + bestehende DB.
class SetupRepository {
  SetupRepository(this.executor) : _transactional = false;

  SetupRepository._transactional(this.executor) : _transactional = true;

  final QueryExecutor executor;
  final bool _transactional;

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
    await _ensureInhaberColumn();
    if (iban != null && iban.trim().isNotEmpty && !isValidIban(iban)) {
      throw const SetupException('IBAN ungültig');
    }
    final String? normalizedHolder = inhaber == null || inhaber.trim().isEmpty ? null : inhaber.trim();
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
          'UPDATE konten SET name = ?, bic = ?, inhaber = COALESCE(?, inhaber), kontoart = ?, waehrung = ? WHERE id = ?',
          <Object?>[name.trim(), bic, normalizedHolder, kontoart, 'EUR', id],
        );
        return id;
      }
    }
    final int id = await executor.runInsert(
      'INSERT INTO konten (name, iban, bic, inhaber, kontoart, waehrung) VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>[name, normalizedIban, bic, normalizedHolder, kontoart, 'EUR'],
    );
    return id;
  }

  /// Erstellt die Kasse-Eröffnung mit ihrer v26 Quelle als eine Transaktion.
  /// Betrag als String '0.00' — negativ abgelehnt. Exakte Retries bleiben unverändert.
  Future<void> ensureKassenKonto({required String betrag}) {
    if (_transactional) return _ensureKassenKontoInTransaction(betrag: betrag);
    return runInTransaction<void>(
      (SetupRepository repository) => repository._ensureKassenKontoInTransaction(betrag: betrag),
    );
  }

  Future<void> _ensureKassenKontoInTransaction({required String betrag}) async {
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

    final List<Map<String, Object?>> companies = await executor.runSelect(
      'SELECT id FROM unternehmen WHERE id = 1',
      const <Object?>[],
    );
    if (companies.isEmpty) {
      await executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (1, ?)', const <Object?>['Meine Firma']);
    }
    const int companyId = 1;
    await _addColumnIfMissing('journal', 'is_opening_balance', 'INTEGER DEFAULT 0');

    // Reuse an account already named Kasse/Kassenbestand as well as one whose
    // account type is Kasse.  The wizard accepts a user supplied account list,
    // so otherwise a row named "Kasse" with the default Bank type would be
    // left at zero while a second hidden Kasse row receives the opening cash.
    final List<Map<String, Object?>> existing = await executor.runSelect(
      "SELECT id FROM konten WHERE (kontoart = 'Kasse' OR name IN ('Kasse', 'Kassenbestand')) "
      'AND (unternehmen_id = ? OR unternehmen_id IS NULL) '
      'ORDER BY CASE WHEN unternehmen_id = ? THEN 0 ELSE 1 END, '
      "CASE WHEN kontoart = 'Kasse' THEN 0 ELSE 1 END, id LIMIT 1",
      <Object?>[companyId, companyId],
    );
    int kasseId;
    if (existing.isEmpty) {
      kasseId = await executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Kasse', 'Kasse', 'EUR', companyId, '0.00'],
      );
    } else {
      kasseId = ((existing.single['id'] as num?) ?? 0).toInt();
    }

    final List<Map<String, Object?>> sources = await _openingSourcesForAccount(kasseId);
    if (sources.isNotEmpty) {
      _validateOpeningSourceRetry(sources, companyId: companyId, accountId: kasseId, openingAmountCents: cents);
      return;
    }

    final List<Map<String, Object?>> priorJournalRows = await executor.runSelect(
      'SELECT id FROM journal WHERE konto_id = ? LIMIT 1',
      <Object?>[kasseId],
    );
    final List<Map<String, Object?>> accountRows = await executor.runSelect(
      'SELECT unternehmen_id, waehrung, saldo FROM konten WHERE id = ?',
      <Object?>[kasseId],
    );
    if (priorJournalRows.isNotEmpty || accountRows.isEmpty) {
      throw const SetupException('Kassenkonto enthält nicht zugeordnete Buchungen und braucht eine manuelle Prüfung');
    }
    final Map<String, Object?> account = accountRows.single;
    if (account['unternehmen_id'] != null && (account['unternehmen_id'] as num?)!.toInt() != companyId) {
      throw const SetupException('Kassenkonto gehört zu einem anderen Unternehmen');
    }
    if (_tryAmountCents(account['saldo']) != 0) {
      throw const SetupException('Kassenkonto enthält einen nicht verifizierten Eröffnungsbestand');
    }
    if (account['waehrung'] != null && account['waehrung'] != 'EUR') {
      throw const SetupException('Kassenkonto verwendet eine nicht unterstützte Währung');
    }

    await executor.runUpdate(
      'UPDATE konten SET name = ?, kontoart = ?, waehrung = ?, unternehmen_id = ? WHERE id = ?',
      <Object?>['Kasse', 'Kasse', 'EUR', companyId, kasseId],
    );
    await _createOpeningSource(
      companyId: companyId,
      accountId: kasseId,
      openingAmountCents: cents,
      formattedAmount: formatted,
    );
  }

  void _validateOpeningSourceRetry(
    List<Map<String, Object?>> sources, {
    required int companyId,
    required int accountId,
    required int openingAmountCents,
  }) {
    if (sources.length != 1 ||
        !_isCompleteOpeningSourceIdentity(sources.single, companyId: companyId, accountId: accountId)) {
      throw const SetupException('Kassen-Eröffnungsquelle ist mehrdeutig oder unvollständig');
    }
    final int sourceAmount = ((sources.single['source_amount_cents'] as num?) ?? -1).toInt();
    if (sourceAmount != openingAmountCents) {
      throw const SetupException('Kassen-Eröffnungsquelle kann nicht mit einem anderen Betrag wiederholt werden');
    }
  }

  Future<void> _createOpeningSource({
    required int companyId,
    required int accountId,
    required int openingAmountCents,
    required String formattedAmount,
  }) async {
    final String effectiveDate = _todayIso();
    final List<Map<String, Object?>> categories = await executor.runSelect(
      'SELECT id FROM kategorien LIMIT 1',
      const <Object?>[],
    );
    final int categoryId;
    if (categories.isNotEmpty) {
      categoryId = (categories.single['id'] as num? ?? 0).toInt();
    } else {
      categoryId = await executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, beschreibung, aktiv, mapping_status) VALUES (?, ?, 1, 'unmapped')",
        const <Object?>['Eröffnung', 'Automatisch angelegte Eröffungskategorie ohne Kontenrahmen-Mapping'],
      );
    }
    final int journalId = await executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
      'VALUES (?, ?, ?, ?, ?, ?, 0, 1)',
      <Object?>[effectiveDate, 'Eröffnung Kasse', categoryId, formattedAmount, BelegTyp.eroeffnung, accountId],
    );
    await executor.runUpdate('UPDATE konten SET saldo = ? WHERE id = ?', <Object?>[formattedAmount, accountId]);
    final String sourceReference = 'setup-opening:$companyId:$accountId';
    await executor.runInsert(
      'INSERT INTO account_opening_balance_sources '
      '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>[companyId, accountId, journalId, effectiveDate, openingAmountCents, 'EUR', sourceReference],
    );
    final List<Map<String, Object?>> createdSource = await _openingSourcesForAccount(accountId);
    if (createdSource.length != 1 ||
        !_isCompleteCreatedOpeningSource(
          createdSource.single,
          companyId: companyId,
          accountId: accountId,
          openingAmountCents: openingAmountCents,
        )) {
      throw const SetupException('Kassen-Eröffnungsquelle konnte nicht verifiziert werden');
    }
  }

  Future<List<Map<String, Object?>>> _openingSourcesForAccount(int accountId) {
    return executor.runSelect(
      'SELECT s.id AS source_id, s.unternehmen_id AS source_company_id, s.konto_id AS source_account_id, '
      's.journal_id AS source_journal_id, s.effective_date AS source_effective_date, '
      's.amount_cents AS source_amount_cents, s.currency_code AS source_currency_code, '
      's.source_reference AS source_reference, k.unternehmen_id AS account_company_id, '
      'k.waehrung AS account_currency, k.saldo AS account_saldo, j.konto_id AS journal_account_id, '
      'j.datum AS journal_date, j.betrag AS journal_amount, j.beleg_typ AS journal_type, '
      'j.is_opening_balance AS journal_is_opening_balance '
      'FROM account_opening_balance_sources AS s '
      'LEFT JOIN konten AS k ON k.id = s.konto_id '
      'LEFT JOIN journal AS j ON j.id = s.journal_id WHERE s.konto_id = ?',
      <Object?>[accountId],
    );
  }

  bool _isCompleteOpeningSourceIdentity(Map<String, Object?> source, {required int companyId, required int accountId}) {
    final String? effectiveDate = source['source_effective_date'] as String?;
    final String? journalDate = source['journal_date'] as String?;
    final int? amountCents = (source['source_amount_cents'] as num?)?.toInt();
    return (source['source_company_id'] as num?)?.toInt() == companyId &&
        (source['source_account_id'] as num?)?.toInt() == accountId &&
        (source['source_journal_id'] as num?)?.toInt() != null &&
        effectiveDate != null &&
        _isLocalIsoDate(effectiveDate) &&
        journalDate == effectiveDate &&
        amountCents != null &&
        amountCents >= 0 &&
        _tryAmountCents(source['journal_amount']) == amountCents &&
        source['source_currency_code'] == 'EUR' &&
        source['account_currency'] == 'EUR' &&
        (source['account_company_id'] as num?)?.toInt() == companyId &&
        (source['journal_account_id'] as num?)?.toInt() == accountId &&
        source['journal_type'] == BelegTyp.eroeffnung &&
        source['journal_is_opening_balance'] == 1 &&
        (source['source_reference'] as String?)?.trim().isNotEmpty == true;
  }

  bool _isCompleteCreatedOpeningSource(
    Map<String, Object?> source, {
    required int companyId,
    required int accountId,
    required int openingAmountCents,
  }) {
    return _isCompleteOpeningSourceIdentity(source, companyId: companyId, accountId: accountId) &&
        (source['source_amount_cents'] as num?)?.toInt() == openingAmountCents &&
        _tryAmountCents(source['account_saldo']) == openingAmountCents;
  }

  bool _isLocalIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final DateTime? date = DateTime.tryParse(value);
    if (date == null) return false;
    final String normalized =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return normalized == value;
  }

  int? _tryAmountCents(Object? amount) {
    if (amount == null) return null;
    try {
      return money.parseScaled(amount.toString(), scale: 2, field: 'opening amount');
    } on Object {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Kategorien
  // ---------------------------------------------------------------------------

  Future<void> ensureKategorienSelected(List<int> ids) async {
    if (ids.isEmpty) {
      throw const SetupException('Mindestens eine Kategorie erforderlich');
    }
    // Categories are user data: every selected id must exist. Fresh profiles
    // ship with no preconfigured categories (explicit unconfigured state).
    for (final int id in ids) {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id FROM kategorien WHERE id = ?',
        <Object?>[id],
      );
      if (rows.isEmpty) throw SetupException('Kategorie $id nicht gefunden');
    }
    await _addColumnIfMissing('unternehmen', 'setup_kategorie_ids', 'TEXT');
    final List<int> normalized = ids.toSet().toList()..sort();
    await executor.runUpdate('UPDATE unternehmen SET setup_kategorie_ids = ? WHERE id = 1', <Object?>[
      normalized.join(','),
    ]);
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
    // No categories are preseeded; the opening entry creates its own
    // explicitly unmapped label category when none exists.
  }

  /// Run a complete setup write as one SQLite transaction.
  Future<T> runInTransaction<T>(Future<T> Function(SetupRepository repository) operation) async {
    if (_transactional) return operation(this);
    final TransactionExecutor transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_SetupTransactionUser());
      final T result = await operation(SetupRepository._transactional(transaction));
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

  Future<void> _ensureInhaberColumn() => _addColumnIfMissing('konten', 'inhaber', 'TEXT');

  /// Reads the stored holder back from the same account record for summaries.
  Future<String?> readInhaber(int kontoId) async {
    await _ensureInhaberColumn();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT inhaber FROM konten WHERE id = ?',
      <Object?>[kontoId],
    );
    if (rows.isEmpty) return null;
    final Object? value = rows.single['inhaber'];
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
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
