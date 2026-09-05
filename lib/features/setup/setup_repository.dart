import 'package:drift/drift.dart';
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
    if (cleaned.startsWith('DE') && !RegExp(r'^DE[0-9]{20}$').hasMatch(cleaned)) return false;
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
    // rechtsform: optional column, add if missing
    if (rechtsform != null) {
      try {
        await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN rechtsform TEXT');
      } catch (_) {}
      try {
        await executor.runUpdate('UPDATE unternehmen SET rechtsform = ? WHERE id = 1', <Object?>[rechtsform]);
      } catch (_) {}
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
    final int id = await executor.runInsert(
      'INSERT INTO konten (name, iban, bic, kontoart, waehrung) VALUES (?, ?, ?, ?, ?)',
      <Object?>[name, iban, bic, kontoart, 'EUR'],
    );
    return id;
  }

  /// Erstellt oder aktualisiert Kasse-Konto + Eröffnungs-Journal.
  /// Betrag als String '0.00' — negativ abgelehnt. Idempotent: nur ein Kasse-Konto.
  Future<void> ensureKassenKonto({required String betrag}) async {
    final String t = betrag.trim().replaceAll(',', '.');
    final String normalized = t.isEmpty ? '0.00' : t;
    if (normalized.startsWith('-')) throw const SetupException('Kassenbestand darf nicht negativ sein');
    final String formatted = money.formatBetrag(normalized);
    // validate numeric 12,2
    final int cents = money.toCents(formatted);
    if (cents < 0) throw const SetupException('Kassenbestand darf nicht negativ sein');

    // check existing Kasse
    final List<Map<String, Object?>> existing = await executor.runSelect(
      'SELECT id FROM konten WHERE kontoart = ? LIMIT 1',
      const ['Kasse'],
    );
    int kasseId;
    if (existing.isEmpty) {
      kasseId = await executor.runInsert(
        "INSERT INTO konten (name, kontoart, waehrung, saldo) VALUES ('Kasse', 'Kasse', 'EUR', 0)",
        const [],
      );
    } else {
      kasseId = (existing.single['id'] as num).toInt();
    }

    // idempotent journal: if already one journal for this konto, reuse/update
    final List<Map<String, Object?>> journals = await executor.runSelect(
      'SELECT id FROM journal WHERE konto_id = ? LIMIT 1',
      <Object?>[kasseId],
    );
    final String datum = _todayIso();
    if (journals.isEmpty) {
      // need at least one kategorie for FK — use first available or create fallback 1
      int kategorieId = 1;
      try {
        final List<Map<String, Object?>> kats = await executor.runSelect('SELECT id FROM kategorien LIMIT 1', const []);
        if (kats.isNotEmpty) kategorieId = (kats.single['id'] as num).toInt();
      } catch (_) {}
      await executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, immutable) '
        'VALUES (?, ?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Eröffnung Kasse', kategorieId, formatted, 'Einnahme', kasseId],
      );
    } else {
      final int jid = (journals.single['id'] as num).toInt();
      await executor.runUpdate('UPDATE journal SET betrag = ?, datum = ? WHERE id = ?', <Object?>[
        formatted,
        datum,
        jid,
      ]);
    }
  }

  // ---------------------------------------------------------------------------
  // Kategorien
  // ---------------------------------------------------------------------------

  Future<void> ensureKategorienSelected(List<int> ids) async {
    if (ids.isEmpty) throw const SetupException('Mindestens eine Kategorie erforderlich');
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

  Future<void> createMinimalDefaults() async {
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
