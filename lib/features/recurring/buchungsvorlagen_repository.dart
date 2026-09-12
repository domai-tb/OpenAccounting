import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/rechnung_typ.dart';

class BuchungsVorlagenException implements Exception {
  const BuchungsVorlagenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BuchungsVorlage {
  const BuchungsVorlage({
    required this.id,
    required this.name,
    this.kategorieId,
    this.kontoId,
    this.betrag,
    this.beschreibung,
    required this.modus,
    required this.art,
    required this.intervall,
    this.naechsteFaelligkeit,
    required this.aktiv,
    required this.status,
    this.lieferantId,
    required this.ustSatz,
    required this.eingabemodus,
    this.vorlageDatenRaw,
    this.positionen = const <Map<String, dynamic>>[],
  });

  final int id;
  final String name;
  final int? kategorieId;
  final int? kontoId;
  final String? betrag;
  final String? beschreibung;
  final String modus;
  final String art;
  final String intervall;
  final String? naechsteFaelligkeit;
  final bool aktiv;
  final String status;
  final int? lieferantId;
  final String ustSatz;
  final String eingabemodus;
  final String? vorlageDatenRaw;
  final List<Map<String, dynamic>> positionen;
}

class BuchungsVorlagenRepository {
  BuchungsVorlagenRepository(this.executor);

  final QueryExecutor executor;
  Future<void>? _schemaReady;

  static const Set<String> allowedInterval = <String>{'monatlich', 'quartalsweise', 'jährlich'};
  static const Set<String> allowedModus = <String>{'direkt', 'beleg'};
  static const Set<String> allowedArt = <String>{'Einnahme', 'Ausgabe'};

  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema();

  Future<void> _ensureSchema() async {
    for (final ({String name, String definition}) column in <({String name, String definition})>[
      (name: 'ust_satz', definition: 'NUMERIC(12,2) DEFAULT 19'),
      (name: 'eingabemodus', definition: "TEXT DEFAULT 'brutto'"),
      (name: 'vorlage_daten', definition: 'TEXT'),
    ]) {
      final columns = await executor.runSelect('PRAGMA table_info(buchungsvorlagen)', const <Object?>[]);
      if (columns.any((row) => row['name'] == column.name)) continue;
      await executor.runCustom('ALTER TABLE buchungsvorlagen ADD COLUMN ${column.name} ${column.definition}');
      final verified = await executor.runSelect('PRAGMA table_info(buchungsvorlagen)', const <Object?>[]);
      if (!verified.any((row) => row['name'] == column.name)) {
        throw StateError('Buchungsvorlage konnte Spalte ${column.name} nicht verifizieren');
      }
    }
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS buchungsvorlagen_occurrences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vorlage_id INTEGER NOT NULL REFERENCES buchungsvorlagen(id),
  faelligkeit TEXT NOT NULL,
  journal_id INTEGER REFERENCES journal(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  UNIQUE(vorlage_id, faelligkeit)
)''');
  }

  Future<BuchungsVorlage> create({
    required String name,
    int? kategorieId,
    int? kontoId,
    String betrag = '0.00',
    String? beschreibung,
    String modus = 'direkt',
    required String art,
    required String intervall,
    String? naechsteFaelligkeit,
    int? lieferantId,
    DateTime? bezugsDatum,
    num ustSatz = 19,
    String eingabemodus = 'brutto',
    List<Map<String, dynamic>> positionen = const <Map<String, dynamic>>[],
  }) async {
    await ensureSchema();
    final String cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const BuchungsVorlagenException('Name ist Pflicht');
    }
    if (!allowedModus.contains(modus)) {
      throw BuchungsVorlagenException('Ungültiger modus: $modus');
    }
    if (!allowedArt.contains(art)) {
      throw BuchungsVorlagenException('Ungültige art: $art');
    }
    final String cleanEingabemodus = eingabemodus.trim().toLowerCase();
    if (cleanEingabemodus != 'netto' && cleanEingabemodus != 'brutto') {
      throw BuchungsVorlagenException('Ungültiger eingabemodus: $eingabemodus');
    }
    final String cleanUstSatz = _validateUstSatz(ustSatz);
    final String cleanBetrag = _normalizeBetrag(betrag);
    final String cleanIntervall = intervall.trim();
    if (cleanIntervall.isEmpty) {
      throw const BuchungsVorlagenException('Intervall ist Pflicht');
    }
    if (!allowedInterval.contains(cleanIntervall)) {
      throw BuchungsVorlagenException('Ungültiges Intervall: $cleanIntervall');
    }
    for (var index = 0; index < positionen.length; index++) {
      _validatePosition(positionen[index], index);
    }
    // Ensure uniform input mode across positions if provided.
    if (positionen.isNotEmpty) {
      _documentInputMode(positionen);
    }
    final String jsonStr = jsonEncode(positionen);
    final String nextDue =
        naechsteFaelligkeit ?? _formatDate(_nextDueFrom(bezugsDatum ?? DateTime.now(), cleanIntervall));
    final int id = await executor.runInsert(
      'INSERT INTO buchungsvorlagen (name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, '
      'naechste_faelligkeit, art, lieferant_id, status, ust_satz, eingabemodus, vorlage_daten) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        cleanName,
        kategorieId,
        kontoId,
        cleanBetrag,
        beschreibung,
        modus,
        cleanIntervall,
        nextDue,
        art,
        lieferantId,
        'aktiv',
        cleanUstSatz,
        cleanEingabemodus,
        jsonStr,
      ],
    );
    final BuchungsVorlage? created = await findById(id);
    if (created == null) throw const BuchungsVorlagenException('Vorlage konnte nicht gespeichert werden');
    return created;
  }

  Future<BuchungsVorlage?> findById(int id) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, naechste_faelligkeit, '
      'art, lieferant_id, status, ust_satz, eingabemodus, vorlage_daten FROM buchungsvorlagen WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<BuchungsVorlage>> list() async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, naechste_faelligkeit, '
      'art, lieferant_id, status, ust_satz, eingabemodus, vorlage_daten FROM buchungsvorlagen ORDER BY id',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<BuchungsVorlage> update(
    int id, {
    String? name,
    String? betrag,
    String? modus,
    String? art,
    String? intervall,
    int? kategorieId,
    int? kontoId,
    int? lieferantId,
    num? ustSatz,
    String? eingabemodus,
    List<Map<String, dynamic>>? positionen,
  }) async {
    await ensureSchema();
    final BuchungsVorlage? cur = await findById(id);
    if (cur == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    if (modus != null && !allowedModus.contains(modus)) {
      throw BuchungsVorlagenException('Ungültiger modus: $modus');
    }
    if (art != null && !allowedArt.contains(art)) {
      throw BuchungsVorlagenException('Ungültige art: $art');
    }
    final String? cleanUstSatz = ustSatz == null ? null : _validateUstSatz(ustSatz);
    final String? cleanEingabemodus = eingabemodus?.trim().toLowerCase();
    if (cleanEingabemodus != null && cleanEingabemodus != 'netto' && cleanEingabemodus != 'brutto') {
      throw BuchungsVorlagenException('Ungültiger eingabemodus: $eingabemodus');
    }
    if (intervall != null) {
      final String t = intervall.trim();
      if (t.isEmpty) throw const BuchungsVorlagenException('Intervall ist Pflicht');
      if (!allowedInterval.contains(t)) throw BuchungsVorlagenException('Ungültiges Intervall: $t');
    }
    if (positionen != null) {
      for (var index = 0; index < positionen.length; index++) {
        _validatePosition(positionen[index], index);
      }
      if (positionen.isNotEmpty) _documentInputMode(positionen);
    }
    final String newName = name?.trim().isEmpty ?? true ? cur.name : name!.trim();
    if (newName.isEmpty) throw const BuchungsVorlagenException('Name ist Pflicht');
    final String? cleanBetrag = betrag == null ? null : _normalizeBetrag(betrag);
    final String newJson = positionen == null ? (cur.vorlageDatenRaw ?? '[]') : jsonEncode(positionen);
    await executor.runUpdate(
      'UPDATE buchungsvorlagen SET name = ?, betrag = ?, modus = ?, art = ?, intervall = ?, '
      'kategorie_id = ?, konto_id = ?, lieferant_id = ?, ust_satz = ?, eingabemodus = ?, vorlage_daten = ? WHERE id = ?',
      <Object?>[
        newName,
        cleanBetrag ?? cur.betrag,
        modus ?? cur.modus,
        art ?? cur.art,
        intervall ?? cur.intervall,
        kategorieId ?? cur.kategorieId,
        kontoId ?? cur.kontoId,
        lieferantId ?? cur.lieferantId,
        cleanUstSatz ?? cur.ustSatz,
        cleanEingabemodus ?? cur.eingabemodus,
        newJson,
        id,
      ],
    );
    return (await findById(id))!;
  }

  Future<BuchungsVorlage> pause(int id) async {
    final BuchungsVorlage? cur = await findById(id);
    if (cur == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    await executor.runUpdate('UPDATE buchungsvorlagen SET aktiv = 0, status = ? WHERE id = ?', <Object?>[
      'pausiert',
      id,
    ]);
    return (await findById(id))!;
  }

  Future<BuchungsVorlage> resume(int id) async {
    final BuchungsVorlage? cur = await findById(id);
    if (cur == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    await executor.runUpdate('UPDATE buchungsvorlagen SET aktiv = 1, status = ? WHERE id = ?', <Object?>['aktiv', id]);
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    final List<Map<String, Object?>> linked = await executor.runSelect(
      'SELECT count(*) as c FROM journal WHERE vorlage_id = ?',
      <Object?>[id],
    );
    final int count = (linked.single['c'] as num?)?.toInt() ?? 0;
    if (count > 0) {
      throw BuchungsVorlagenException('Vorlage hat $count erzeugte Buchungen und kann nicht gelöscht werden');
    }
    // Auch Rechnungen prüfen für beleg-Modus.
    final List<Map<String, Object?>> reCnt = await executor.runSelect(
      'SELECT count(*) as c FROM rechnungen WHERE vorlage_id = ?',
      <Object?>[id],
    );
    final int rc = (reCnt.single['c'] as num?)?.toInt() ?? 0;
    if (rc > 0) {
      throw BuchungsVorlagenException('Vorlage hat $rc erzeugte Belege und kann nicht gelöscht werden');
    }
    final int del = await executor.runDelete('DELETE FROM buchungsvorlagen WHERE id = ?', <Object?>[id]);
    if (del == 0) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
  }

  bool isDue(BuchungsVorlage vorlage, DateTime heute) {
    if (!vorlage.aktiv || vorlage.status != 'aktiv') return false;
    if (vorlage.naechsteFaelligkeit == null) return false;
    final DateTime? due = DateTime.tryParse(vorlage.naechsteFaelligkeit!);
    if (due == null) return false;
    final DateTime h = DateTime(heute.year, heute.month, heute.day);
    final DateTime d = DateTime(due.year, due.month, due.day);
    return !h.isBefore(d);
  }

  DateTime nextDue(DateTime from, String intervall) => _nextDueFrom(from, intervall);

  DateTime _nextDueFrom(DateTime from, String intervall) {
    switch (intervall) {
      case 'monatlich':
        return _addMonths(from, 1);
      case 'quartalsweise':
        return _addMonths(from, 3);
      case 'jährlich':
        return _addMonths(from, 12);
      default:
        throw BuchungsVorlagenException('Ungültiges Intervall: $intervall');
    }
  }

  DateTime _addMonths(DateTime d, int months) {
    final int total = d.month - 1 + months;
    final int y = d.year + total ~/ 12;
    final int m = total % 12 + 1;
    final int dim = _daysInMonth(y, m);
    return DateTime(y, m, d.day > dim ? dim : d.day);
  }

  int _daysInMonth(int y, int m) {
    if (m == 12) return DateTime(y + 1, 1, 0).day;
    return DateTime(y, m + 1, 0).day;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Auto-Generation — erzeugt fällige Journal- oder Beleg-Einträge.
  Future<List<int>> generateFaellig({DateTime? heute}) async {
    await ensureSchema();
    final DateTime now = heute ?? DateTime.now();
    final List<BuchungsVorlage> alle = await list();
    final List<int> created = <int>[];
    for (final BuchungsVorlage v in alle) {
      if (!isDue(v, now)) continue;
      DateTime due = DateTime.parse(v.naechsteFaelligkeit!);
      while (!now.isBefore(DateTime(due.year, due.month, due.day))) {
        final int genId = await _generateOne(v, due);
        created.add(genId);
        due = _nextDueFrom(due, v.intervall);
        await executor.runUpdate('UPDATE buchungsvorlagen SET naechste_faelligkeit = ? WHERE id = ?', <Object?>[
          _formatDate(due),
          v.id,
        ]);
        if (due.isAfter(DateTime(now.year, now.month, now.day))) break;
      }
    }
    return created;
  }

  Future<int> _generateOne(BuchungsVorlage vorlage, DateTime datum) async {
    final String datumStr = _formatDate(datum);
    if (vorlage.modus == 'direkt') {
      // USt-Richtung: Ausgabe => Vorsteuer (KZ 66), Einnahme => Umsatzsteuer (KZ 81)
      final bool isAusgabe = vorlage.art == 'Ausgabe';
      // If positions exist, compute sum from them; otherwise fallback to single betrag.
      int amountCents = 0;
      int taxCents = 0;
      if (vorlage.positionen.isNotEmpty) {
        final List<_BuchungsLine> lines = <_BuchungsLine>[];
        for (var i = 0; i < vorlage.positionen.length; i++) {
          final _BuchungsLine line = _calculateLine(vorlage.positionen[i], i, vorlage.eingabemodus);
          lines.add(line);
        }
        for (final _BuchungsLine l in lines) {
          amountCents += l.bruttoCents;
          taxCents += l.ustCents;
        }
        // Override per-line ust distribution already summed; total tax is sum.
      } else {
        amountCents = _parseCents(vorlage.betrag ?? '0.00');
        final int rateCents = _parseRateCents(vorlage.ustSatz);
        taxCents = vorlage.eingabemodus == 'brutto'
            ? _roundHalfUp(amountCents * rateCents, 10000 + rateCents)
            : _roundHalfUp(amountCents * rateCents, 10000);
      }
      final int rateCentsForJournal = _parseRateCents(vorlage.ustSatz);
      // For multi-line, journal ust_satz not representative; keep header rate.
      final String? vorsteuerBetrag = isAusgabe ? money.fromCents(taxCents) : null;
      final String belegTyp = vorlage.art;
      final String beschreibung = vorlage.beschreibung ?? vorlage.name;
      // Lieferant/Konto werden vererbt — journal.konto_id = vorlage.konto_id, lieferant via rechnung_id null.
      await executor.runCustom('BEGIN');
      try {
        final List<Map<String, Object?>> prior = await executor.runSelect(
          'SELECT journal_id FROM buchungsvorlagen_occurrences WHERE vorlage_id = ? AND faelligkeit = ? LIMIT 1',
          <Object?>[vorlage.id, datumStr],
        );
        if (prior.isNotEmpty && prior.single['journal_id'] != null) {
          await executor.runCustom('COMMIT');
          return (prior.single['journal_id'] as num?)?.toInt() ?? 0;
        }
        final int jId = await executor.runInsert(
          'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, '
          'vorlage_id, ist_eu_lieferung, vorsteuer_betrag, ust_satz) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)',
          <Object?>[
            datumStr,
            beschreibung,
            vorlage.kategorieId,
            money.fromCents(amountCents),
            belegTyp,
            vorlage.kontoId,
            vorlage.id,
            vorsteuerBetrag,
            money.fromCents(rateCentsForJournal),
          ],
        );
        await executor.runUpdate('UPDATE journal SET gruppe_id = ? WHERE id = ?', <Object?>[jId, jId]);
        if (isAusgabe && taxCents > 0) {
          // UStVA's Soll principle reads the durable input-tax claim table;
          // journal.vorsteuer_betrag alone is only an audit snapshot.
          await executor.runInsert(
            'INSERT INTO vorsteuer_ansprueche (betrag, status, faelligkeit, ust_sonderfall) '
            'VALUES (?, ?, ?, ?)',
            <Object?>[money.fromCents(taxCents), 'offen', datumStr, null],
          );
        }
        await executor.runCustom(
          'INSERT OR IGNORE INTO buchungsvorlagen_occurrences '
          '(vorlage_id, faelligkeit, journal_id) VALUES (?, ?, ?)',
          <Object?>[vorlage.id, datumStr, jId],
        );
        final List<Map<String, Object?>> occurrence = await executor.runSelect(
          'SELECT journal_id FROM buchungsvorlagen_occurrences '
          'WHERE vorlage_id = ? AND faelligkeit = ? LIMIT 1',
          <Object?>[vorlage.id, datumStr],
        );
        final int persistedId = (occurrence.single['journal_id'] as num?)?.toInt() ?? jId;
        if (persistedId != jId) {
          await executor.runDelete('DELETE FROM journal WHERE id = ?', <Object?>[jId]);
        }
        await executor.runCustom('COMMIT');
        return persistedId;
      } catch (e) {
        try {
          await executor.runCustom('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    } else {
      // beleg Modus: pre-filled Rechnung Draft (rechnung_eingang).
      // Reuse rechnungspositionen pattern — N lines round-trip, totals derived from lines.
      final String documentInputMode = vorlage.positionen.isEmpty
          ? vorlage.eingabemodus
          : _documentInputMode(vorlage.positionen);
      final List<_BuchungsLine> lines = <_BuchungsLine>[];
      var nettoCents = 0;
      var ustCents = 0;
      var bruttoCents = 0;
      if (vorlage.positionen.isNotEmpty) {
        for (var i = 0; i < vorlage.positionen.length; i++) {
          final _BuchungsLine line = _calculateLine(vorlage.positionen[i], i, vorlage.eingabemodus);
          lines.add(line);
          nettoCents += line.nettoCents;
          ustCents += line.ustCents;
          bruttoCents += line.bruttoCents;
        }
      } else {
        // Legacy single-line fallback — still persist one rechnungsposition.
        final int amountCents = _parseCents(vorlage.betrag ?? '0.00');
        final int rateCents = _parseRateCents(vorlage.ustSatz);
        final int tax = vorlage.eingabemodus == 'brutto'
            ? _roundHalfUp(amountCents * rateCents, 10000 + rateCents)
            : _roundHalfUp(amountCents * rateCents, 10000);
        final int netto = vorlage.eingabemodus == 'brutto' ? amountCents - tax : amountCents;
        final int brutto = vorlage.eingabemodus == 'brutto' ? amountCents : amountCents + tax;
        nettoCents = netto;
        ustCents = tax;
        bruttoCents = brutto;
        lines.add(
          _BuchungsLine(
            bezeichnung: vorlage.beschreibung ?? vorlage.name,
            menge: '1.000',
            einzelpreis: money.fromCents(vorlage.eingabemodus == 'brutto' ? brutto : netto),
            rate: money.fromCents(rateCents),
            inputMode: vorlage.eingabemodus,
            nettoCents: netto,
            ustCents: tax,
            bruttoCents: brutto,
            kontoId: vorlage.kontoId,
          ),
        );
      }
      await executor.runCustom('BEGIN');
      try {
        final List<Map<String, Object?>> prior = await executor.runSelect(
          'SELECT rechnung_id FROM buchungsvorlagen_occurrences WHERE vorlage_id = ? AND faelligkeit = ? LIMIT 1',
          <Object?>[vorlage.id, datumStr],
        );
        if (prior.isNotEmpty && prior.single['rechnung_id'] != null) {
          await executor.runCustom('COMMIT');
          return (prior.single['rechnung_id'] as num?)?.toInt() ?? 0;
        }
        // Canonical type via shared helper (old code used eingangsrechnung).
        const String canonicalTyp = RechnungTyp.eingang;
        final int rId = await executor.runInsert(
          'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, lieferant_id, datum, '
          'netto_betrag, brutto_betrag, ust_betrag, vorlage_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            null,
            canonicalTyp,
            'entwurf',
            1,
            documentInputMode,
            vorlage.lieferantId,
            datumStr,
            money.fromCents(nettoCents),
            money.fromCents(bruttoCents),
            money.fromCents(ustCents),
            vorlage.id,
          ],
        );
        for (var posIndex = 0; posIndex < lines.length; posIndex++) {
          final _BuchungsLine line = lines[posIndex];
          await executor.runInsert(
            'INSERT INTO rechnungspositionen (rechnung_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              rId,
              line.bezeichnung,
              line.menge,
              line.einzelpreis,
              money.fromCents(line.inputMode == 'brutto' ? line.bruttoCents : line.nettoCents),
              line.rate,
              posIndex,
            ],
          );
        }
        await executor.runCustom(
          'INSERT OR IGNORE INTO buchungsvorlagen_occurrences '
          '(vorlage_id, faelligkeit, rechnung_id) VALUES (?, ?, ?)',
          <Object?>[vorlage.id, datumStr, rId],
        );
        final List<Map<String, Object?>> occurrence = await executor.runSelect(
          'SELECT rechnung_id FROM buchungsvorlagen_occurrences '
          'WHERE vorlage_id = ? AND faelligkeit = ? LIMIT 1',
          <Object?>[vorlage.id, datumStr],
        );
        final int persistedId = (occurrence.single['rechnung_id'] as num?)?.toInt() ?? rId;
        if (persistedId != rId) {
          await executor.runDelete('DELETE FROM rechnungen WHERE id = ?', <Object?>[rId]);
        }
        await executor.runCustom('COMMIT');
        return persistedId;
      } catch (e) {
        try {
          await executor.runCustom('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    }
  }

  BuchungsVorlage _fromRow(Map<String, Object?> r) {
    final int id = ((r['id'] as num?) ?? 0).toInt();
    final String name = r['name'] as String? ?? '';
    final int? kategorieId = (r['kategorie_id'] as num?)?.toInt();
    final int? kontoId = (r['konto_id'] as num?)?.toInt();
    final String? betrag = r['betrag']?.toString();
    final String? beschreibung = r['beschreibung'] as String?;
    final String modus = (r['modus'] as String?) ?? 'direkt';
    final String art = (r['art'] as String?) ?? 'Ausgabe';
    final String intervall = (r['intervall'] as String?) ?? 'monatlich';
    final String? next = r['naechste_faelligkeit'] as String?;
    final bool aktiv = ((r['aktiv'] as num?) ?? 0) != 0;
    final String status = (r['status'] as String?) ?? (aktiv ? 'aktiv' : 'pausiert');
    final int? lieferantId = (r['lieferant_id'] as num?)?.toInt();
    final String raw = (r['vorlage_daten'] as String?) ?? '[]';
    List<Map<String, dynamic>> pos = <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        pos = decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    } catch (_) {
      pos = <Map<String, dynamic>>[];
    }
    return BuchungsVorlage(
      id: id,
      name: name,
      kategorieId: kategorieId,
      kontoId: kontoId,
      betrag: betrag,
      beschreibung: beschreibung,
      modus: modus,
      art: art,
      intervall: intervall,
      naechsteFaelligkeit: next,
      aktiv: aktiv,
      status: status,
      lieferantId: lieferantId,
      ustSatz: r['ust_satz']?.toString() ?? '19.00',
      eingabemodus: r['eingabemodus']?.toString() ?? 'brutto',
      vorlageDatenRaw: raw,
      positionen: pos,
    );
  }

  String _validateUstSatz(num rate) {
    try {
      final int cents = money.scaledFromNum(rate, scale: 2, field: 'ustSatz', allowNegative: false);
      if (cents > 10000) {
        throw const BuchungsVorlagenException('USt-Satz muss zwischen 0 und 100 liegen');
      }
      return money.fromCents(cents);
    } on money.MoneyParseException catch (error) {
      throw BuchungsVorlagenException(error.message);
    }
  }

  String _normalizeBetrag(String raw) {
    try {
      return money.fromCents(money.parseScaled(raw, scale: 2, field: 'betrag', allowNegative: false));
    } on money.MoneyParseException catch (error) {
      throw BuchungsVorlagenException(error.message);
    }
  }

  int _parseRateCents(String raw) => money.parseScaled(raw, scale: 2, field: 'ustSatz', allowNegative: false);

  int _parseCents(String raw) => money.parseScaled(raw, scale: 2, field: 'betrag', allowNegative: false);

  int _roundHalfUp(int numerator, int denominator) => (numerator + denominator ~/ 2) ~/ denominator;

  void _validatePosition(Map<String, dynamic> position, int index) {
    final Object? description = position['bezeichnung'];
    if (description is! String || description.trim().isEmpty) {
      throw BuchungsVorlagenException('Position $index: bezeichnung ist Pflicht');
    }
    try {
      _scaled(position['menge'] ?? 1, scale: 3, field: 'Position $index menge', allowNegative: false);
      _scaled(position['einzelpreis'] ?? 0, scale: 4, field: 'Position $index einzelpreis', allowNegative: false);
      _rate(position['ust_satz'] ?? position['ustSatz'] ?? 19, index);
      _inputMode(position, index);
    } on money.MoneyParseException catch (error) {
      throw BuchungsVorlagenException(error.message);
    }
  }

  _BuchungsLine _calculateLine(Map<String, dynamic> position, int index, String fallbackInputMode) {
    _validatePosition(position, index);
    final int menge = _scaled(position['menge'] ?? 1, scale: 3, field: 'Position $index menge', allowNegative: false);
    final int einzelpreis = _scaled(
      position['einzelpreis'] ?? 0,
      scale: 4,
      field: 'Position $index einzelpreis',
      allowNegative: false,
    );
    final int rateCents = _rate(position['ust_satz'] ?? position['ustSatz'] ?? 19, index);
    final String mode = position.containsKey('eingabemodus')
        ? _inputMode(position, index)
        : fallbackInputMode.trim().toLowerCase();
    if (mode != 'netto' && mode != 'brutto') {
      throw BuchungsVorlagenException('Position $index: eingabemodus muss netto oder brutto sein');
    }
    final int amountCents = _roundHalfUp(einzelpreis * menge, 100000);
    final int nettoCents;
    final int bruttoCents;
    final int ustCents;
    if (mode == 'brutto') {
      bruttoCents = amountCents;
      nettoCents = _roundHalfUp(amountCents * 10000, 10000 + rateCents);
      ustCents = bruttoCents - nettoCents;
    } else {
      nettoCents = amountCents;
      ustCents = _roundHalfUp(nettoCents * rateCents, 10000);
      bruttoCents = nettoCents + ustCents;
    }
    return _BuchungsLine(
      bezeichnung: position['bezeichnung'] as String,
      menge: _formatScaled(menge, scale: 3),
      einzelpreis: _formatScaled(einzelpreis, scale: 4),
      rate: money.fromCents(rateCents),
      inputMode: mode,
      nettoCents: nettoCents,
      ustCents: ustCents,
      bruttoCents: bruttoCents,
      kontoId: (position['konto_id'] as num?)?.toInt(),
    );
  }

  String _inputMode(Map<String, dynamic> position, int index) {
    final String mode = (position['eingabemodus'] ?? 'netto').toString().trim().toLowerCase();
    if (mode != 'netto' && mode != 'brutto') {
      throw BuchungsVorlagenException('Position $index: eingabemodus muss netto oder brutto sein');
    }
    return mode;
  }

  String _documentInputMode(List<Map<String, dynamic>> positions) {
    String? mode;
    for (var index = 0; index < positions.length; index++) {
      final String current = _inputMode(positions[index], index);
      if (mode != null && mode != current) {
        throw const BuchungsVorlagenException('Eine wiederkehrende Buchung darf nicht netto und brutto mischen');
      }
      mode = current;
    }
    return mode ?? 'brutto';
  }

  int _rate(Object raw, int index) {
    final int value = _scaled(raw, scale: 2, field: 'Position $index ust_satz', allowNegative: false);
    if (value > 10000) {
      throw BuchungsVorlagenException('Position $index: USt-Satz muss zwischen 0 und 100 liegen');
    }
    return value;
  }

  int _scaled(Object raw, {required int scale, required String field, required bool allowNegative}) {
    if (raw is num) {
      return money.scaledFromNum(raw, scale: scale, field: field, allowNegative: allowNegative);
    }
    return money.parseScaled(raw.toString(), scale: scale, field: field, allowNegative: allowNegative);
  }

  String _formatScaled(int value, {required int scale}) {
    final bool negative = value < 0;
    final int absolute = value.abs();
    var divisor = 1;
    for (var i = 0; i < scale; i++) {
      divisor *= 10;
    }
    final String integerPart = (absolute ~/ divisor).toString();
    final String fraction = (absolute % divisor).toString().padLeft(scale, '0');
    return '${negative ? '-' : ''}$integerPart.$fraction';
  }
}

class _BuchungsLine {
  const _BuchungsLine({
    required this.bezeichnung,
    required this.menge,
    required this.einzelpreis,
    required this.rate,
    required this.inputMode,
    required this.nettoCents,
    required this.ustCents,
    required this.bruttoCents,
    this.kontoId,
  });

  final String bezeichnung;
  final String menge;
  final String einzelpreis;
  final String rate;
  final String inputMode;
  final int nettoCents;
  final int ustCents;
  final int bruttoCents;
  final int? kontoId;
}
