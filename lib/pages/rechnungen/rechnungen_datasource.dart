import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

class RechnungenDataSource {
  const RechnungenDataSource(this.executor);

  final QueryExecutor executor;

  Future<void> _ensureExtraColumns() async {
    final alters = <String>[
      'ALTER TABLE rechnungen ADD COLUMN storno_grund TEXT',
      'ALTER TABLE rechnungen ADD COLUMN storno_datum TEXT',
      'ALTER TABLE rechnungen ADD COLUMN gutschrift_von INTEGER REFERENCES rechnungen(id)',
      'ALTER TABLE rechnungen ADD COLUMN ersatz_fuer INTEGER REFERENCES rechnungen(id)',
      'ALTER TABLE rechnungen ADD COLUMN ersatzrechnung_id INTEGER REFERENCES rechnungen(id)',
      'ALTER TABLE rechnungen ADD COLUMN konvertiert_von INTEGER REFERENCES rechnungen(id)',
      'ALTER TABLE rechnungen ADD COLUMN konvertiert_zu INTEGER REFERENCES rechnungen(id)',
      'ALTER TABLE rechnungen ADD COLUMN original_pdf_pfad TEXT',
      'ALTER TABLE rechnungen ADD COLUMN rabatt_prozent NUMERIC(12,2) DEFAULT 0',
      'ALTER TABLE rechnungen ADD COLUMN rabatt_betrag NUMERIC(12,2) DEFAULT 0',
      'ALTER TABLE rechnungen ADD COLUMN lieferadresse_id INTEGER REFERENCES kunden_lieferadressen(id)',
      'ALTER TABLE rechnungspositionen ADD COLUMN rabatt_prozent NUMERIC(12,2) DEFAULT 0',
    ];
    for (final sql in alters) {
      try {
        await executor.runCustom(sql);
      } catch (_) {}
    }
  }

  Future<int> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
    String typ = 'rechnung',
    String eingabemodus = 'netto',
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    await _ensureExtraColumns();
    final preview = VorschauService.calculate(
      eingabemodus: eingabemodus,
      positionen: positionen,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final invoiceId = await transaction.runInsert(
        '''
INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, netto_betrag, brutto_betrag, ust_betrag, rabatt_prozent, rabatt_betrag, lieferadresse_id)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        <Object?>[
          null,
          typ,
          'entwurf',
          datum,
          1,
          eingabemodus,
          preview.nettoBetrag.toStringAsFixed(2),
          preview.bruttoBetrag.toStringAsFixed(2),
          preview.ustBetrag.toStringAsFixed(2),
          (rabattProzent ?? 0).toStringAsFixed(2),
          (rabattBetrag ?? 0).toStringAsFixed(2),
          lieferadresseId,
        ],
      );

      for (var index = 0; index < positionen.length; index++) {
        final position = positionen[index];
        await transaction.runInsert(
          '''
INSERT INTO rechnungspositionen (
  rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            (position.rabattProzent ?? 0).toStringAsFixed(2),
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

  Future<int> createDokument({
    required String typ,
    required String datum,
    required List<RechnungPositionItem> positionen,
    String eingabemodus = 'netto',
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    await _ensureExtraColumns();
    const allowed = {'rechnung', 'angebot', 'auftrag', 'proforma', 'lieferschein', 'gutschrift', 'storno'};
    if (!allowed.contains(typ)) {
      throw StateError('Unbekannter Dokumenttyp');
    }
    if (typ == 'lieferschein') {
      final preview = VorschauService.calculate(
        eingabemodus: eingabemodus,
        positionen: positionen,
        rabattProzent: rabattProzent,
        rabattBetrag: rabattBetrag,
      );
      final transaction = executor.beginTransaction();
      try {
        await transaction.ensureOpen(_NoopTransactionUser());
        final nummer = await _allocateNumberForTyp(transaction, typ, datum);
        final invoiceId = await transaction.runInsert(
          '''
INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, netto_betrag, brutto_betrag, ust_betrag, lieferadresse_id, nummernkreis_id, ausgegeben_am, original_pdf_pfad)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
          <Object?>[
            nummer.nummer,
            typ,
            'entwurf',
            datum,
            1,
            eingabemodus,
            preview.nettoBetrag.toStringAsFixed(2),
            preview.bruttoBetrag.toStringAsFixed(2),
            preview.ustBetrag.toStringAsFixed(2),
            lieferadresseId,
            nummer.kreisId,
            DateTime.now().toUtc().toIso8601String(),
            'pdfs/${nummer.nummer}.pdf',
          ],
        );
        for (var index = 0; index < positionen.length; index++) {
          final p = positionen[index];
          await transaction.runInsert(
            'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              invoiceId,
              p.artikelId,
              p.bezeichnung,
              p.menge.toStringAsFixed(2),
              p.einzelpreis.toStringAsFixed(2),
              p.gesamt.toStringAsFixed(2),
              p.ustSatz.toStringAsFixed(2),
              p.position ?? index,
              (p.rabattProzent ?? 0).toStringAsFixed(2),
            ],
          );
        }
        await transaction.runUpdate('UPDATE rechnungen SET ist_entwurf = 0, status = ? WHERE id = ?', <Object?>[
          'offen',
          invoiceId,
        ]);
        await _reserveNumber(transaction, nummer);
        await transaction.send();
        return invoiceId;
      } catch (e, st) {
        try {
          await transaction.rollback();
        } catch (re, rst) {
          Error.throwWithStackTrace(re, rst);
        }
        Error.throwWithStackTrace(e, st);
      }
    }
    return createDraftRechnung(
      datum: datum,
      positionen: positionen,
      typ: typ,
      eingabemodus: eingabemodus,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  Future<int> finalizeRechnung({required int rechnungId}) async {
    await _ensureExtraColumns();
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final invoiceRows = await transaction.runSelect(
        '''
SELECT id, ist_entwurf, datum, unternehmen_id, typ, eingabemodus, rabatt_prozent, rabatt_betrag
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
      final typ = invoice['typ']?.toString() ?? 'rechnung';
      final eingabemodus = invoice['eingabemodus']?.toString() ?? 'netto';
      final posRows = await transaction.runSelect(
        'SELECT artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, rabatt_prozent FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      final positionen = posRows
          .map(
            (r) => RechnungPositionItem(
              bezeichnung: r['bezeichnung'] as String,
              menge: _asNum(r['menge']),
              einzelpreis: _asNum(r['einzelpreis']),
              gesamt: _asNum(r['gesamt']),
              ustSatz: _asNum(r['ust_satz']),
              rabattProzent: r['rabatt_prozent'] == null ? null : _asNum(r['rabatt_prozent']),
              artikelId: r['artikel_id'] == null ? null : _asInt(r['artikel_id']),
            ),
          )
          .toList();
      final rabattProzent = _asNum(invoice['rabatt_prozent']);
      final rabattBetrag = _asNum(invoice['rabatt_betrag']);
      final preview = VorschauService.calculate(
        eingabemodus: eingabemodus,
        positionen: positionen,
        rabattProzent: rabattProzent == 0 ? null : rabattProzent,
        rabattBetrag: rabattBetrag == 0 ? null : rabattBetrag,
      );
      final kreisTyp = _nummernkreisTypFor(typ);
      final rangeRows = await transaction.runSelect(
        '''
SELECT id, format, naechste_nummer, aktiv
FROM nummernkreise
WHERE typ = ? AND aktiv = 1
ORDER BY id
LIMIT 1
''',
        <Object?>[kreisTyp],
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

      for (final p in posRows) {
        final artikelId = p['artikel_id'];
        if (artikelId == null) continue;
        final menge = _asNum(p['menge']);
        await transaction.runUpdate('UPDATE artikel SET bestand = bestand - ? WHERE id = ?', <Object?>[
          menge,
          artikelId,
        ]);
      }

      final pdfPath = 'pdfs/$documentNumber.pdf';
      final invoiceUpdated = await transaction.runUpdate(
        '''
UPDATE rechnungen
SET rechnungsnummer = ?, nummernkreis_id = ?, ist_entwurf = 0, status = ?, absender_snapshot = ?, ausgegeben_am = ?, netto_betrag = ?, ust_betrag = ?, brutto_betrag = ?, original_pdf_pfad = ?
WHERE id = ? AND ist_entwurf = 1
''',
        <Object?>[
          documentNumber,
          range['id'],
          'offen',
          senderSnapshot,
          issuedAt,
          preview.nettoBetrag.toStringAsFixed(2),
          preview.ustBetrag.toStringAsFixed(2),
          preview.bruttoBetrag.toStringAsFixed(2),
          pdfPath,
          rechnungId,
        ],
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

  Future<int> stornoRechnung({required int rechnungId, required String grund}) async {
    await _ensureExtraColumns();
    final trimmed = grund.trim();
    if (trimmed.isEmpty) {
      throw StateError('Stornogrund ist Pflicht');
    }
    if (trimmed.length > 500) {
      throw StateError('Stornogrund zu lang');
    }
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final origRows = await transaction.runSelect(
        'SELECT id, ist_entwurf, typ, status, datum, storno_datum, storno_grund FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      if (origRows.isEmpty) throw StateError('Rechnung nicht gefunden');
      final orig = origRows.single;
      if (_asInt(orig['ist_entwurf']) == 1) {
        throw StateError('Dokument ist bereits finalisiert: nur finalisierte Dokumente können storniert werden');
      }
      if (orig['storno_datum'] != null || orig['status'] == 'storniert') {
        throw StateError('Rechnung ist bereits storniert');
      }
      final datum = DateTime.now().toIso8601String().substring(0, 10);
      final kreisTyp = 'stornorechnung';
      final rangeRows = await transaction.runSelect(
        'SELECT id, format, naechste_nummer FROM nummernkreise WHERE typ = ? AND aktiv = 1 ORDER BY id LIMIT 1',
        <Object?>[kreisTyp],
      );
      if (rangeRows.isEmpty) throw StateError('Stornorechnung-Nummernkreis fehlt');
      final range = rangeRows.single;
      final format = range['format'].toString();
      final seq = _sequenceMatchesForFormat(format);
      if (seq == null || seq.length != 1)
        throw StateError('Stornorechnung-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
      final stored = _asInt(range['naechste_nummer']) ?? 1;
      final invDate = DateTime.tryParse(orig['datum'].toString()) ?? DateTime.now();
      final latestRows = await transaction.runSelect(
        'SELECT datum FROM rechnungen WHERE nummernkreis_id = ? AND rechnungsnummer IS NOT NULL',
        <Object?>[range['id']],
      );
      DateTime? latest;
      for (final r in latestRows) {
        final d = DateTime.tryParse(r['datum'].toString());
        if (d != null && (latest == null || d.isAfter(latest))) latest = d;
      }
      final nextNo = (latest != null && latest.year < invDate.year) ? 1 : stored;
      final docNo = _formatNumber(format, invDate.year, nextNo);
      final updated = await transaction.runUpdate(
        'UPDATE nummernkreise SET naechste_nummer = ? WHERE id = ? AND naechste_nummer = ?',
        <Object?>[nextNo + 1, range['id'], stored],
      );
      if (updated != 1) throw StateError('Nummernkreis konnte nicht reserviert werden');
      final posRows = await transaction.runSelect(
        'SELECT artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      final origTyp = orig['typ'].toString();
      final isGutschrift = origTyp == 'gutschrift';
      var nettoSum = 0.0;
      for (final r in posRows) {
        final gesamt = _asNum(r['gesamt']);
        nettoSum += isGutschrift ? gesamt.abs() : -gesamt.abs();
      }
      final stornoId = await transaction.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id, storno_von, storno_grund, storno_datum, netto_betrag, brutto_betrag, ust_betrag, ausgegeben_am, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          docNo,
          'storno',
          'entwurf',
          datum,
          1,
          'netto',
          range['id'],
          rechnungId,
          trimmed,
          datum,
          nettoSum.toStringAsFixed(2),
          nettoSum.toStringAsFixed(2),
          '0.00',
          DateTime.now().toUtc().toIso8601String(),
          'pdfs/$docNo.pdf',
        ],
      );
      for (final r in posRows) {
        final gesamt = _asNum(r['gesamt']);
        final negGesamt = isGutschrift ? gesamt.abs() : -gesamt.abs();
        await transaction.runInsert(
          'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            stornoId,
            r['artikel_id'],
            r['bezeichnung'],
            r['menge'].toString(),
            r['einzelpreis'].toString(),
            negGesamt.toStringAsFixed(2),
            r['ust_satz'].toString(),
            r['position'],
            r['rabatt_prozent']?.toString() ?? '0.00',
          ],
        );
      }
      await transaction.runUpdate('UPDATE rechnungen SET ist_entwurf = 0, status = ? WHERE id = ?', <Object?>[
        'offen',
        stornoId,
      ]);
      for (final r in posRows) {
        if (r['artikel_id'] == null) continue;
        final menge = _asNum(r['menge']);
        await transaction.runUpdate('UPDATE artikel SET bestand = bestand + ? WHERE id = ?', <Object?>[
          menge,
          r['artikel_id'],
        ]);
      }
      await transaction.runUpdate(
        'UPDATE rechnungen SET status = ?, storno_datum = ?, storno_grund = ? WHERE id = ?',
        <Object?>['storniert', datum, trimmed, rechnungId],
      );
      await transaction.send();
      return stornoId;
    } catch (e, st) {
      try {
        await transaction.rollback();
      } catch (re, rst) {
        Error.throwWithStackTrace(re, rst);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<int> createGutschrift({
    int? vonRechnungId,
    String? datum,
    List<RechnungPositionItem>? positionen,
    String grund = '',
  }) async {
    await _ensureExtraColumns();
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      List<Map<String, Object?>> posRows = [];
      String useDatum = datum ?? DateTime.now().toIso8601String().substring(0, 10);
      List<RechnungPositionItem> usePos = positionen ?? [];
      int? linkId;
      if (vonRechnungId != null) {
        final orig = await transaction.runSelect(
          'SELECT id, ist_entwurf, datum FROM rechnungen WHERE id = ?',
          <Object?>[vonRechnungId],
        );
        if (orig.isEmpty) throw StateError('Rechnung nicht gefunden');
        if (_asInt(orig.single['ist_entwurf']) == 1)
          throw StateError('Nur finalisierte Rechnung kann gutgeschrieben werden');
        useDatum = orig.single['datum'].toString();
        linkId = vonRechnungId;
        posRows = await transaction.runSelect(
          'SELECT artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent FROM rechnungspositionen WHERE rechnung_id = ?',
          <Object?>[vonRechnungId],
        );
        usePos = posRows
            .map(
              (r) => RechnungPositionItem(
                bezeichnung: r['bezeichnung'] as String,
                menge: _asNum(r['menge']),
                einzelpreis: _asNum(r['einzelpreis']),
                gesamt: _asNum(r['gesamt']),
                ustSatz: _asNum(r['ust_satz']),
                rabattProzent: r['rabatt_prozent'] == null ? null : _asNum(r['rabatt_prozent']),
                artikelId: r['artikel_id'] == null ? null : _asInt(r['artikel_id']),
              ),
            )
            .toList();
      } else {
        if (usePos.isEmpty) throw StateError('Positionen erforderlich');
      }
      final kreisTyp = 'gutschrift';
      final rangeRows = await transaction.runSelect(
        'SELECT id, format, naechste_nummer FROM nummernkreise WHERE typ = ? AND aktiv = 1 ORDER BY id LIMIT 1',
        <Object?>[kreisTyp],
      );
      if (rangeRows.isEmpty) throw StateError('Gutschrift-Nummernkreis fehlt');
      final range = rangeRows.single;
      final format = range['format'].toString();
      final seq = _sequenceMatchesForFormat(format);
      if (seq == null || seq.length != 1)
        throw StateError('Gutschrift-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
      final stored = _asInt(range['naechste_nummer']) ?? 1;
      final invDate = DateTime.tryParse(useDatum) ?? DateTime.now();
      final latestRows = await transaction.runSelect(
        'SELECT datum FROM rechnungen WHERE nummernkreis_id = ? AND rechnungsnummer IS NOT NULL',
        <Object?>[range['id']],
      );
      DateTime? latest;
      for (final r in latestRows) {
        final d = DateTime.tryParse(r['datum'].toString());
        if (d != null && (latest == null || d.isAfter(latest))) latest = d;
      }
      final nextNo = (latest != null && latest.year < invDate.year) ? 1 : stored;
      final docNo = _formatNumber(format, invDate.year, nextNo);
      await transaction.runUpdate(
        'UPDATE nummernkreise SET naechste_nummer = ? WHERE id = ? AND naechste_nummer = ?',
        <Object?>[nextNo + 1, range['id'], stored],
      );
      var sum = 0.0;
      for (final p in usePos) sum += -p.gesamt.abs();
      final gsId = await transaction.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id, gutschrift_von, netto_betrag, brutto_betrag, ust_betrag, ausgegeben_am, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          docNo,
          'gutschrift',
          'entwurf',
          useDatum,
          1,
          'netto',
          range['id'],
          linkId,
          sum.toStringAsFixed(2),
          sum.toStringAsFixed(2),
          '0.00',
          DateTime.now().toUtc().toIso8601String(),
          'pdfs/$docNo.pdf',
        ],
      );
      if (posRows.isNotEmpty) {
        for (final r in posRows) {
          final gesamt = _asNum(r['gesamt']);
          await transaction.runInsert(
            'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              gsId,
              r['artikel_id'],
              r['bezeichnung'],
              r['menge'].toString(),
              r['einzelpreis'].toString(),
              (-gesamt.abs()).toStringAsFixed(2),
              r['ust_satz'].toString(),
              r['position'],
              r['rabatt_prozent']?.toString() ?? '0.00',
            ],
          );
        }
      } else {
        for (var i = 0; i < usePos.length; i++) {
          final p = usePos[i];
          await transaction.runInsert(
            'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              gsId,
              p.artikelId,
              p.bezeichnung,
              p.menge.toStringAsFixed(2),
              p.einzelpreis.toStringAsFixed(2),
              (-p.gesamt.abs()).toStringAsFixed(2),
              p.ustSatz.toStringAsFixed(2),
              p.position ?? i,
              (p.rabattProzent ?? 0).toStringAsFixed(2),
            ],
          );
        }
      }
      await transaction.runUpdate('UPDATE rechnungen SET ist_entwurf = 0, status = ? WHERE id = ?', <Object?>[
        'offen',
        gsId,
      ]);
      await transaction.send();
      return gsId;
    } catch (e, st) {
      try {
        await transaction.rollback();
      } catch (re, rst) {
        Error.throwWithStackTrace(re, rst);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<int> createErsatzRechnung({required int vonRechnungId}) async {
    await _ensureExtraColumns();
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final origRows = await transaction.runSelect(
        'SELECT id, status, storno_datum FROM rechnungen WHERE id = ?',
        <Object?>[vonRechnungId],
      );
      if (origRows.isEmpty) throw StateError('Rechnung nicht gefunden');
      final orig = origRows.single;
      if (orig['status'] != 'storniert' || orig['storno_datum'] == null) {
        throw StateError('Ersatzrechnung nur aus stornierter Rechnung möglich');
      }
      if (orig['ersatzrechnung_id'] != null) {
        throw StateError('Ersatzrechnung bereits vorhanden');
      }
      final posRows = await transaction.runSelect(
        'SELECT artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[vonRechnungId],
      );
      final datum = DateTime.now().toIso8601String().substring(0, 10);
      final ersatzId = await transaction.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, ersatz_fuer) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[null, 'rechnung', 'entwurf', datum, 1, 'netto', vonRechnungId],
      );
      for (final r in posRows) {
        await transaction.runInsert(
          'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            ersatzId,
            r['artikel_id'],
            r['bezeichnung'],
            r['menge'].toString(),
            r['einzelpreis'].toString(),
            r['gesamt'].toString(),
            r['ust_satz'].toString(),
            r['position'],
            r['rabatt_prozent']?.toString() ?? '0.00',
          ],
        );
      }
      await transaction.runUpdate('UPDATE rechnungen SET ersatzrechnung_id = ? WHERE id = ?', <Object?>[
        ersatzId,
        vonRechnungId,
      ]);
      await transaction.send();
      return ersatzId;
    } catch (e, st) {
      try {
        await transaction.rollback();
      } catch (re, rst) {
        Error.throwWithStackTrace(re, rst);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<int> konvertiereDokument({required int quelleId, required String zielTyp}) async {
    await _ensureExtraColumns();
    const allowed = {
      'angebot': {'auftrag', 'proforma', 'rechnung'},
      'auftrag': {'lieferschein', 'rechnung'},
      'lieferschein': {'rechnung'},
      'proforma': {'rechnung'},
      'rechnung': <String>{},
      'gutschrift': <String>{},
      'storno': <String>{},
    };
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final srcRows = await transaction.runSelect(
        'SELECT id, typ, eingabemodus, lieferadresse_id, ist_entwurf FROM rechnungen WHERE id = ?',
        <Object?>[quelleId],
      );
      if (srcRows.isEmpty) throw StateError('Quelldokument nicht gefunden');
      final src = srcRows.single;
      final srcTyp = src['typ'].toString();
      if (!allowed.containsKey(srcTyp)) throw StateError('Unbekannter Dokumenttyp');
      if (!allowed[srcTyp]!.contains(zielTyp)) {
        throw StateError(
          'Lieferschein kann nicht in Angebot konvertiert werden'.contains('Lieferschein') &&
                  srcTyp == 'lieferschein' &&
                  zielTyp == 'angebot'
              ? 'Lieferschein kann nicht in Angebot konvertiert werden'
              : '$srcTyp kann nicht in $zielTyp konvertiert werden',
        );
      }
      final posRows = await transaction.runSelect(
        'SELECT artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[quelleId],
      );
      final eingabemodus = src['eingabemodus'].toString();
      final lieferadresseId = src['lieferadresse_id'];
      final datum = DateTime.now().toIso8601String().substring(0, 10);
      int zielId;
      String? nummer;
      int? kreisId;
      if (zielTyp == 'lieferschein') {
        final alloc = await _allocateNumberForTyp(transaction, zielTyp, datum);
        nummer = alloc.nummer;
        kreisId = alloc.kreisId;
        final preview = VorschauService.calculate(
          eingabemodus: eingabemodus,
          positionen: posRows
              .map(
                (r) => RechnungPositionItem(
                  bezeichnung: r['bezeichnung'] as String,
                  menge: _asNum(r['menge']),
                  einzelpreis: _asNum(r['einzelpreis']),
                  gesamt: _asNum(r['gesamt']),
                  ustSatz: _asNum(r['ust_satz']),
                ),
              )
              .toList(),
        );
        zielId = await transaction.runInsert(
          'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, lieferadresse_id, nummernkreis_id, ausgegeben_am, original_pdf_pfad, netto_betrag, brutto_betrag, ust_betrag, konvertiert_von) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            nummer,
            zielTyp,
            'entwurf',
            datum,
            1,
            eingabemodus,
            lieferadresseId,
            kreisId,
            DateTime.now().toUtc().toIso8601String(),
            'pdfs/$nummer.pdf',
            preview.nettoBetrag.toStringAsFixed(2),
            preview.bruttoBetrag.toStringAsFixed(2),
            preview.ustBetrag.toStringAsFixed(2),
            quelleId,
          ],
        );
        for (final r in posRows) {
          await transaction.runInsert(
            'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              zielId,
              r['artikel_id'],
              r['bezeichnung'],
              r['menge'].toString(),
              r['einzelpreis'].toString(),
              r['gesamt'].toString(),
              r['ust_satz'].toString(),
              r['position'],
              r['rabatt_prozent']?.toString() ?? '0.00',
            ],
          );
        }
        await transaction.runUpdate('UPDATE rechnungen SET ist_entwurf = 0, status = ? WHERE id = ?', <Object?>[
          'offen',
          zielId,
        ]);
        await _reserveNumber(transaction, alloc);
        await transaction.runUpdate('UPDATE rechnungen SET konvertiert_zu = ? WHERE id = ?', <Object?>[
          zielId,
          quelleId,
        ]);
        await transaction.send();
        return zielId;
      } else {
        zielId = await transaction.runInsert(
          'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, lieferadresse_id, konvertiert_von) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[null, zielTyp, 'entwurf', datum, 1, eingabemodus, lieferadresseId, quelleId],
        );
      }
      for (final r in posRows) {
        await transaction.runInsert(
          'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            zielId,
            r['artikel_id'],
            r['bezeichnung'],
            r['menge'].toString(),
            r['einzelpreis'].toString(),
            r['gesamt'].toString(),
            r['ust_satz'].toString(),
            r['position'],
            r['rabatt_prozent']?.toString() ?? '0.00',
          ],
        );
      }
      await transaction.runUpdate('UPDATE rechnungen SET konvertiert_zu = ? WHERE id = ?', <Object?>[zielId, quelleId]);
      await transaction.send();
      return zielId;
    } catch (e, st) {
      try {
        await transaction.rollback();
      } catch (re, rst) {
        Error.throwWithStackTrace(re, rst);
      }
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<Map<String, Object?>?> findRechnungById(int id) async {
    await _ensureExtraColumns();
    final rows = await executor.runSelect(
      '''
SELECT id, rechnungsnummer, typ, status, ist_entwurf, eingabemodus, datum, lieferadresse_id
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
SELECT id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent
FROM rechnungspositionen
WHERE rechnung_id = ?
ORDER BY position, id
''',
      <Object?>[rechnungId],
    );
  }

  Future<_AllocatedNumber> _allocateNumberForTyp(TransactionExecutor transaction, String typ, String datum) async {
    final kreisTyp = _nummernkreisTypFor(typ);
    final rangeRows = await transaction.runSelect(
      'SELECT id, format, naechste_nummer, aktiv FROM nummernkreise WHERE typ = ? AND aktiv = 1 ORDER BY id LIMIT 1',
      <Object?>[kreisTyp],
    );
    if (rangeRows.isEmpty) throw StateError('$kreisTyp-Nummernkreis fehlt');
    final range = rangeRows.single;
    final format = range['format'].toString().trim();
    final seq = _sequenceMatchesForFormat(format);
    if (seq == null || seq.length != 1)
      throw StateError('$kreisTyp-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
    final stored = _asInt(range['naechste_nummer']) ?? 1;
    final invDate = DateTime.tryParse(datum) ?? DateTime.now();
    final latestRows = await transaction.runSelect(
      'SELECT datum FROM rechnungen WHERE nummernkreis_id = ? AND rechnungsnummer IS NOT NULL',
      <Object?>[range['id']],
    );
    DateTime? latest;
    for (final r in latestRows) {
      final d = DateTime.tryParse(r['datum'].toString());
      if (d != null && (latest == null || d.isAfter(latest))) latest = d;
    }
    final nextNo = (latest != null && latest.year < invDate.year) ? 1 : stored;
    final width = _sequenceWidth(seq.single);
    if (width > 9 || nextNo > _maximumForWidth(width)) throw StateError('$kreisTyp-Nummernkreis ist erschöpft');
    final nummer = _formatNumber(format, invDate.year, nextNo);
    return _AllocatedNumber(nummer: nummer, kreisId: range['id'] as int, nextNo: nextNo, stored: stored);
  }

  Future<void> _reserveNumber(TransactionExecutor transaction, _AllocatedNumber alloc) async {
    final upd = await transaction.runUpdate(
      'UPDATE nummernkreise SET naechste_nummer = ? WHERE id = ? AND naechste_nummer = ?',
      <Object?>[alloc.nextNo + 1, alloc.kreisId, alloc.stored],
    );
    if (upd != 1) throw StateError('Nummernkreis konnte nicht reserviert werden');
  }

  String _nummernkreisTypFor(String typ) {
    switch (typ) {
      case 'rechnung':
        return 'rechnung_ausgang';
      case 'storno':
        return 'stornorechnung';
      case 'gutschrift':
        return 'gutschrift';
      case 'angebot':
        return 'angebot';
      case 'auftrag':
        return 'auftrag';
      case 'proforma':
        return 'proforma';
      case 'lieferschein':
        return 'lieferschein';
      default:
        return typ;
    }
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

  static num _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '0') ?? 0;
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

class _AllocatedNumber {
  const _AllocatedNumber({required this.nummer, required this.kreisId, required this.nextNo, required this.stored});
  final String nummer;
  final int kreisId;
  final int nextNo;
  final int stored;
}

final RegExp _formatTokenPattern = RegExp(r'\{(?:YYYY|YY|#+|N+)\}|YYYY|YY|#+|(?<![A-Za-z])N+(?![A-Za-z])|[^{}#]');
final RegExp _sequenceTokenPattern = RegExp(r'\{(#+|N+)\}|#+|(?<![A-Za-z])N+(?![A-Za-z])');

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
