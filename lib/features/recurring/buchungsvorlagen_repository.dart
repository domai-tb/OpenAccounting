import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

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
    final String nextDue =
        naechsteFaelligkeit ?? _formatDate(_nextDueFrom(bezugsDatum ?? DateTime.now(), cleanIntervall));
    final int id = await executor.runInsert(
      'INSERT INTO buchungsvorlagen (name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, '
      'naechste_faelligkeit, art, lieferant_id, status, ust_satz, eingabemodus) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?)',
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
      'art, lieferant_id, status, ust_satz, eingabemodus FROM buchungsvorlagen WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<BuchungsVorlage>> list() async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, naechste_faelligkeit, '
      'art, lieferant_id, status, ust_satz, eingabemodus FROM buchungsvorlagen ORDER BY id',
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
    final String newName = name?.trim().isEmpty ?? true ? cur.name : name!.trim();
    if (newName.isEmpty) throw const BuchungsVorlagenException('Name ist Pflicht');
    final String? cleanBetrag = betrag == null ? null : _normalizeBetrag(betrag);
    await executor.runUpdate(
      'UPDATE buchungsvorlagen SET name = ?, betrag = ?, modus = ?, art = ?, intervall = ?, '
      'kategorie_id = ?, konto_id = ?, lieferant_id = ?, ust_satz = ?, eingabemodus = ? WHERE id = ?',
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
      final int amountCents = _parseCents(vorlage.betrag ?? '0.00');
      final int rateCents = _parseRateCents(vorlage.ustSatz);
      final int taxCents = vorlage.eingabemodus == 'brutto'
          ? _roundHalfUp(amountCents * rateCents, 10000 + rateCents)
          : _roundHalfUp(amountCents * rateCents, 10000);
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
            vorlage.ustSatz,
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
      // beleg Modus: pre-filled Rechnung Draft (Eingangsrechnung).
      final int amountCents = _parseCents(vorlage.betrag ?? '0.00');
      final int rateCents = _parseRateCents(vorlage.ustSatz);
      final int taxCents = vorlage.eingabemodus == 'brutto'
          ? _roundHalfUp(amountCents * rateCents, 10000 + rateCents)
          : _roundHalfUp(amountCents * rateCents, 10000);
      final int nettoCents = vorlage.eingabemodus == 'brutto' ? amountCents - taxCents : amountCents;
      final int bruttoCents = vorlage.eingabemodus == 'brutto' ? amountCents : amountCents + taxCents;
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
        final int rId = await executor.runInsert(
          'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, lieferant_id, datum, '
          'netto_betrag, brutto_betrag, ust_betrag, vorlage_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            null,
            'eingangsrechnung',
            'entwurf',
            1,
            vorlage.eingabemodus,
            vorlage.lieferantId,
            datumStr,
            money.fromCents(nettoCents),
            money.fromCents(bruttoCents),
            money.fromCents(taxCents),
            vorlage.id,
          ],
        );
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
}
