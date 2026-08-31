import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/journal_entity.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// Journal repository — raw SQL via drift executor, GoBD via DB triggers.
/// ponytail: global executor lock ceiling — per-journal if throughput matters.
/// ponytail: gruppe_id deferred — storno_von chain covers Buchungsgruppe
/// without extra table/FK; add column + FK if multi-entry groups required.
class JournalRepository {
  JournalRepository(this.executor);

  final QueryExecutor executor;

  static const Set<String> _allowedArt = <String>{'Einnahme', 'Ausgabe'};

  static const Set<String> _allowedSonderfall = <String>{'ig_erwerb', '13b_abs1', '13b_abs2'};

  static final RegExp _betragRegex = RegExp(r'^\d+(\.\d{1,2})?$');

  static final RegExp _betragNegRegex = RegExp(r'^-?\d+(\.\d{1,2})?$');

  Future<JournalEntry> create({
    required DateTime datum,
    required String bezeichnung,
    required int kategorieId,
    required String betrag,
    required String art,
    String? kontoSkr03,
    String? kontoSkr04,
    int? ustSatzId,
    String? belegNr,
    int? kontoId,
    int? stornoVon,
    String? ustSatz,
    String? ustSonderfall,
    String? marge25a,
    String? ustSatz25a,
    bool? istEuLieferung,
    String? vorsteuerBetrag,
  }) async {
    final String cleanBezeichnung = bezeichnung.trim();
    if (cleanBezeichnung.isEmpty) {
      throw const JournalException('Bezeichnung ist Pflicht');
    }
    if (kategorieId <= 0) {
      throw const JournalException('Kategorie ist Pflicht');
    }
    final String cleanBetrag = betrag.trim();
    if (cleanBetrag.isEmpty) {
      throw const JournalException('Betrag ist Pflicht');
    }
    if (cleanBetrag.startsWith('-')) {
      throw const JournalException('Betrag darf nicht negativ sein');
    }
    if (!_betragRegex.hasMatch(cleanBetrag)) {
      throw const JournalException('Betrag ungültig: max 2 Dezimalstellen');
    }
    // ponytail: string range check — 12,2 means |betrag| < 10^10, no double parse to keep precision
    final List<String> parts = cleanBetrag.split('.');
    final String rawInt = parts[0];
    final String intPart = rawInt.replaceFirst(RegExp('^0+'), '');
    final String effectiveInt = intPart.isEmpty ? '0' : intPart;
    if (effectiveInt.length > 10) {
      throw const JournalException('Betrag außerhalb NUMERIC(12,2)');
    }
    if (effectiveInt.length == 10 && effectiveInt.compareTo('9999999999') > 0) {
      throw const JournalException('Betrag außerhalb NUMERIC(12,2)');
    }
    if (!_allowedArt.contains(art)) {
      throw const JournalException('Art muss Einnahme oder Ausgabe sein');
    }

    // Validate ustSonderfall whitelist
    String? cleanSonderfall;
    if (ustSonderfall != null) {
      final String t = ustSonderfall.trim();
      if (t.isNotEmpty) {
        if (!_allowedSonderfall.contains(t)) {
          throw JournalException('Ungültiger ust_sonderfall: $t');
        }
        cleanSonderfall = t;
      }
    }

    // Validate ustSatz and ustSatz25a against configured ust_saetze
    String? cleanUstSatz;
    if (ustSatz != null) {
      final String t = ustSatz.trim();
      if (t.isNotEmpty) {
        final num? numParsed = num.tryParse(t);
        if (numParsed == null) {
          throw JournalException('USt-Satz ungültig: $t');
        }
        await _ensureSatzConfigured(t, numParsed);
        cleanUstSatz = t;
      }
    }
    String? cleanUstSatz25a;
    if (ustSatz25a != null) {
      final String t = ustSatz25a.trim();
      if (t.isNotEmpty) {
        final num? numParsed = num.tryParse(t);
        if (numParsed == null) {
          throw JournalException('USt-Satz 25a ungültig: $t');
        }
        await _ensureSatzConfigured(t, numParsed);
        cleanUstSatz25a = t;
      }
    }

    String? cleanMarge;
    if (marge25a != null) {
      final String t = marge25a.trim();
      if (t.isNotEmpty) {
        if (!_betragNegRegex.hasMatch(t)) {
          throw JournalException('marge_25a_brutto ungültig: $t');
        }
        // range check absolute
        final String abs = t.startsWith('-') ? t.substring(1) : t;
        final List<String> p = abs.split('.');
        final String ri = p[0].replaceFirst(RegExp('^0+'), '');
        final String ei = ri.isEmpty ? '0' : ri;
        if (ei.length > 10) {
          throw const JournalException('marge_25a_brutto außerhalb NUMERIC(12,2)');
        }
        if (ei.length == 10 && ei.compareTo('9999999999') > 0) {
          throw const JournalException('marge_25a_brutto außerhalb NUMERIC(12,2)');
        }
        cleanMarge = _formatBetrag(t);
      }
    }

    String? cleanVorsteuer;
    if (vorsteuerBetrag != null) {
      final String t = vorsteuerBetrag.trim();
      if (t.isNotEmpty) {
        if (!_betragRegex.hasMatch(t)) {
          // allow negative? spec says vorsteuer positive, but keep strict positive
          throw JournalException('vorsteuer_betrag ungültig: $t');
        }
        final List<String> p = t.split('.');
        final String ri = p[0].replaceFirst(RegExp('^0+'), '');
        final String ei = ri.isEmpty ? '0' : ri;
        if (ei.length > 10) {
          throw const JournalException('vorsteuer_betrag außerhalb NUMERIC(12,2)');
        }
        if (ei.length == 10 && ei.compareTo('9999999999') > 0) {
          throw const JournalException('vorsteuer_betrag außerhalb NUMERIC(12,2)');
        }
        cleanVorsteuer = _formatBetrag(t);
      }
    }

    final int? istEuInt = istEuLieferung == null ? null : (istEuLieferung ? 1 : 0);

    final String datumStr = _formatDate(datum);
    final int id = await executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, beleg_nr, storno_von, konto_id, '
      'ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a, ist_eu_lieferung, vorsteuer_betrag) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        datumStr,
        cleanBezeichnung,
        kategorieId,
        cleanBetrag,
        art,
        kontoSkr03,
        kontoSkr04,
        ustSatzId,
        belegNr,
        stornoVon,
        kontoId,
        cleanUstSatz,
        cleanSonderfall,
        cleanMarge,
        cleanUstSatz25a,
        istEuInt,
        cleanVorsteuer,
      ],
    );

    final JournalEntry? entry = await findById(id);
    if (entry == null) {
      throw const JournalException('Journaleintrag konnte nicht gespeichert werden');
    }
    return entry;
  }

  Future<void> _ensureSatzConfigured(String raw, num parsed) async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT satz FROM ust_saetze',
        const <Object?>[],
      );
      bool found = false;
      for (final Map<String, Object?> r in rows) {
        final Object? v = r['satz'];
        num? n;
        if (v is num) {
          n = v;
        } else if (v is String) {
          n = num.tryParse(v);
        }
        if (n != null && (n - parsed).abs() < 0.0001) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw JournalException('USt-Satz nicht konfiguriert: $raw');
      }
    } catch (e) {
      if (e is JournalException) rethrow;
      // ponytail: if ust_saetze missing, allow 0,7,19 defaults, else reject
      if (parsed == 0 || parsed == 7 || parsed == 19 || parsed == 7.0 || parsed == 19.0) {
        return;
      }
      throw JournalException('USt-Satz nicht konfiguriert: $raw');
    }
  }

  Future<JournalEntry> storno({required int originalId}) async {
    final JournalEntry? original = await findById(originalId);
    if (original == null) {
      throw const JournalException('Original-Eintrag nicht gefunden');
    }

    // Prevent duplicate storno per spec §Storno correction.
    final List<Map<String, Object?>> existing = await executor.runSelect(
      'SELECT id FROM journal WHERE storno_von = ? LIMIT 1',
      <Object?>[originalId],
    );
    if (existing.isNotEmpty) {
      throw const JournalException('Eintrag bereits storniert');
    }

    final String negBetrag = _negateBetrag(original.betrag);
    final DateTime now = DateTime.now();
    final String datumStr = _formatDate(now);
    final String stornoBezeichnung = 'Storno: ${original.bezeichnung}';

    // Fetch extra fields for storno copy (best-effort, missing columns fallback)
    String? origUstSatz;
    String? origSonderfall;
    String? origMarge;
    String? origSatz25a;
    int? origEu;
    String? origVorsteuer;
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a, ist_eu_lieferung, vorsteuer_betrag '
        'FROM journal WHERE id = ?',
        <Object?>[originalId],
      );
      if (rows.isNotEmpty) {
        final Map<String, Object?> r = rows.single;
        origUstSatz = r['ust_satz']?.toString();
        origSonderfall = r['ust_sonderfall'] as String?;
        origMarge = r['marge_25a_brutto']?.toString();
        origSatz25a = r['ust_satz_25a']?.toString();
        origEu = (r['ist_eu_lieferung'] as num?)?.toInt();
        origVorsteuer = r['vorsteuer_betrag']?.toString();
      }
    } catch (_) {}

    // Negate marge and vorsteuer if present
    String? negMarge;
    if (origMarge != null && origMarge.trim().isNotEmpty) {
      negMarge = _negateBetrag(money.formatBetrag(origMarge));
    }
    String? negVorsteuer;
    if (origVorsteuer != null && origVorsteuer.trim().isNotEmpty) {
      negVorsteuer = _negateBetrag(money.formatBetrag(origVorsteuer));
    }

    final int id = await executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, storno_von, konto_id, '
      'ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a, ist_eu_lieferung, vorsteuer_betrag) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        datumStr,
        stornoBezeichnung,
        original.kategorieId,
        negBetrag,
        original.art,
        original.kontoSkr03,
        original.kontoSkr04,
        original.ustSatzId,
        originalId,
        original.kontoId,
        origUstSatz,
        origSonderfall,
        negMarge,
        origSatz25a,
        origEu,
        negVorsteuer,
      ],
    );

    final JournalEntry? entry = await findById(id);
    if (entry == null) {
      throw const JournalException('Storno konnte nicht gespeichert werden');
    }
    return entry;
  }

  Future<JournalEntry?> findById(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, beleg_nr, storno_von, konto_id, '
      'ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a, ist_eu_lieferung, vorsteuer_betrag '
      'FROM journal WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<JournalEntry>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, beleg_nr, storno_von, konto_id, '
      'ust_satz, ust_sonderfall, marge_25a_brutto, ust_satz_25a, ist_eu_lieferung, vorsteuer_betrag '
      'FROM journal ORDER BY id',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  JournalEntry _fromRow(Map<String, Object?> row) {
    final int id = (row['id'] as num).toInt();
    final String datumRaw = row['datum'] as String? ?? '';
    final DateTime datum = DateTime.tryParse(datumRaw) ?? DateTime(1970, 1, 1);
    final String beschreibung = row['beschreibung'] as String? ?? '';
    final int kategorieId = (row['kategorie_id'] as num?)?.toInt() ?? 0;
    // ponytail: keep string directly — no num→toStringAsFixed, preserves NUMERIC(12,2) precision
    final String betragRaw = row['betrag']?.toString() ?? '0.00';
    final String betrag = money.formatBetrag(betragRaw);
    final String art = row['beleg_typ'] as String? ?? 'Einnahme';
    final bool immutable = (row['immutable'] as num? ?? 0).toInt() == 1;
    final String? kontoSkr03 = row['konto_skr03_snapshot'] as String?;
    final String? kontoSkr04 = row['konto_skr04_snapshot'] as String?;
    final int? ustSatzId = (row['ust_satz_id'] as num?)?.toInt();
    final String? belegNr = row['beleg_nr'] as String?;
    final int? stornoVon = (row['storno_von'] as num?)?.toInt();
    final int? kontoId = (row['konto_id'] as num?)?.toInt();
    // ponytail: gruppe_id ceiling — column deferred, storno_von chain
    // covers group; read if column exists
    final int? gruppeId = row.containsKey('gruppe_id') ? (row['gruppe_id'] as num?)?.toInt() : null;
    return JournalEntry(
      id: id,
      datum: datum,
      bezeichnung: beschreibung,
      kategorieId: kategorieId,
      betrag: betrag,
      art: art,
      immutable: immutable,
      kontoSkr03: kontoSkr03,
      kontoSkr04: kontoSkr04,
      ustSatzId: ustSatzId,
      belegNr: belegNr,
      stornoVon: stornoVon,
      kontoId: kontoId,
      gruppeId: gruppeId ?? stornoVon,
    );
  }

  String _formatDate(DateTime d) {
    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatBetrag(String raw) => money.formatBetrag(raw);

  String _negateBetrag(String betrag) {
    final String t = betrag.trim();
    // ponytail: string negation preserves precision, no double parse
    final String neg = t.startsWith('-') ? t.substring(1) : '-$t';
    return money.formatBetrag(neg);
  }
}
