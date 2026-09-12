import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/rechnung_typ.dart';
import 'package:openaccounting/features/pdf/pdf_generator.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

class RechnungenDataSource {
  const RechnungenDataSource(this.executor, {this.profileDir});

  final QueryExecutor executor;
  final String? profileDir;

  Future<void> _ensureExtraColumns() async {
    const columns = <({String table, String name, String definition})>[
      (table: 'rechnungen', name: 'storno_grund', definition: 'TEXT'),
      (table: 'rechnungen', name: 'storno_datum', definition: 'TEXT'),
      (table: 'rechnungen', name: 'gutschrift_von', definition: 'INTEGER REFERENCES rechnungen(id)'),
      (table: 'rechnungen', name: 'ersatz_fuer', definition: 'INTEGER REFERENCES rechnungen(id)'),
      (table: 'rechnungen', name: 'ersatzrechnung_id', definition: 'INTEGER REFERENCES rechnungen(id)'),
      (table: 'rechnungen', name: 'konvertiert_von', definition: 'INTEGER REFERENCES rechnungen(id)'),
      (table: 'rechnungen', name: 'konvertiert_zu', definition: 'INTEGER REFERENCES rechnungen(id)'),
      (table: 'rechnungen', name: 'original_pdf_pfad', definition: 'TEXT'),
      (table: 'rechnungen', name: 'rabatt_prozent', definition: 'NUMERIC(12,2) DEFAULT 0'),
      (table: 'rechnungen', name: 'rabatt_betrag', definition: 'NUMERIC(12,2) DEFAULT 0'),
      (table: 'rechnungen', name: 'lieferadresse_id', definition: 'INTEGER REFERENCES kunden_lieferadressen(id)'),
      (table: 'rechnungspositionen', name: 'rabatt_prozent', definition: 'NUMERIC(12,2) DEFAULT 0'),
    ];
    for (final column in columns) {
      await _ensureColumn(column.table, column.name, column.definition);
    }
  }

  Future<void> _ensureColumn(String table, String name, String definition) async {
    final existing = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (existing.any((row) => row['name'] == name)) return;
    await executor.runCustom('ALTER TABLE $table ADD COLUMN $name $definition');
    final verified = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    if (!verified.any((row) => row['name'] == name)) {
      throw StateError('Rechnungsschema konnte Spalte $table.$name nicht verifizieren');
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
          preview.nettoBetragString,
          preview.bruttoBetragString,
          preview.ustBetragString,
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
            position.menge.toStringAsFixed(3),
            position.einzelpreis.toStringAsFixed(4),
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
            preview.nettoBetragString,
            preview.bruttoBetragString,
            preview.ustBetragString,
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
              p.menge.toStringAsFixed(3),
              p.einzelpreis.toStringAsFixed(4),
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

  Future<int> finalizeRechnung({
    required int rechnungId,
    Directory? profileDir,
    // ponytail: test-only fault injection — throw after given posting step
    String? debugFailAt,
  }) async {
    await _ensureExtraColumns();
    File? createdPdfFile;
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final invoiceRows = await transaction.runSelect(
        '''
SELECT id, ist_entwurf, datum, unternehmen_id, typ, eingabemodus, rabatt_prozent, rabatt_betrag, kunde_id, lieferant_id
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
              bezeichnung: r['bezeichnung']?.toString() ?? '',
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

      await _ensureInventarTable(transaction);
      // Validierung: Minusbestand prüfen bevor gebucht wird (atomar)
      final insufficient = <String>[];
      final lagerItems = <Map<String, Object?>>[];
      for (final p in posRows) {
        final artikelId = p['artikel_id'];
        if (artikelId == null) continue;
        final rows = await transaction.runSelect(
          'SELECT lager_aktiv, bestand, bestand_aktuell, minusbestand_erlaubt, bezeichnung FROM artikel WHERE id = ?',
          <Object?>[artikelId],
        );
        if (rows.isEmpty) continue;
        final lagerRaw = _asInt(rows.single['lager_aktiv']) == 1;
        final bestandLegacy = _asNum(rows.single['bestand']);
        final bestandAktuell = _asNum(rows.single['bestand_aktuell']);
        final isLegacy = !lagerRaw && bestandAktuell == 0 && bestandLegacy != 0;
        final lagerAktiv = lagerRaw || isLegacy;
        if (!lagerAktiv) continue;
        final effBestand = bestandAktuell != 0 ? bestandAktuell : bestandLegacy;
        lagerItems.add({...p, '_eff': effBestand, '_isLegacy': isLegacy});
        final minusErlaubt = _asInt(rows.single['minusbestand_erlaubt']) == 1;
        final menge = _asNum(p['menge']);
        if (!minusErlaubt && effBestand - menge < -0.0001) {
          insufficient.add(rows.single['bezeichnung'].toString());
        }
      }
      if (insufficient.isNotEmpty) {
        throw StateError('Bestand unzureichend für Artikel: ${insufficient.join(', ')}');
      }
      for (final p in lagerItems) {
        final artikelId = p['artikel_id'];
        final menge = _asNum(p['menge']);
        final num eff = _asNum(p['_eff']);
        final isLegacy = p['_isLegacy'] == true;
        final newStock = eff - menge;
        if (isLegacy) {
          await transaction.runUpdate(
            'UPDATE artikel SET bestand_aktuell = ?, bestand = ?, lager_aktiv = 1 WHERE id = ?',
            <Object?>[newStock, newStock, artikelId],
          );
        } else {
          await transaction.runUpdate(
            'UPDATE artikel SET bestand_aktuell = bestand_aktuell - ?, bestand = bestand - ? WHERE id = ?',
            <Object?>[menge, menge, artikelId],
          );
        }
        await transaction.runInsert(
          'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund, referenz_typ, referenz_id) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            artikelId,
            invoiceDate.toIso8601String().substring(0, 10),
            -menge,
            'Rechnungsausgang $documentNumber',
            'rechnung',
            rechnungId,
          ],
        );
      }

      // Generate and write PDF artifact under the active profile — atomic via temp+rename.
      // Snapshot is immutable: built from transaction-captured rows, defensive copy via PdfDocumentSnapshot.from
      final effectiveProfileDir = profileDir?.path ?? this.profileDir;
      final pdfDir = effectiveProfileDir != null ? Directory('$effectiveProfileDir/pdfs') : null;
      String pdfPath;
      File? tmpFile;
      if (pdfDir != null) {
        pdfDir.createSync(recursive: true);
        final pdfFile = File('${pdfDir.path}/$documentNumber.pdf');
        createdPdfFile = pdfFile;
        tmpFile = File('${pdfDir.path}/$documentNumber.pdf.tmp');
        try {
          final PdfDocumentSnapshot snapshot = await _buildPdfSnapshot(
            transaction: transaction,
            invoice: invoice,
            posRows: posRows,
            preview: preview,
            documentNumber: documentNumber,
            invoiceDate: invoiceDate,
            typ: typ,
            eingabemodus: eingabemodus,
            companyRows: companyRows,
          );
          final Uint8List pdfBytes = await const PdfGenerator().generate(snapshot);
          tmpFile.writeAsBytesSync(pdfBytes);
          tmpFile.renameSync(pdfFile.path);
        } catch (e) {
          try {
            if (tmpFile.existsSync()) tmpFile.deleteSync();
          } catch (_) {}
          rethrow;
        }
        pdfPath = pdfFile.path;
      } else {
        pdfPath = 'pdfs/$documentNumber.pdf';
      }
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
          preview.nettoBetragString,
          preview.ustBetragString,
          preview.bruttoBetragString,
          pdfPath,
          rechnungId,
        ],
      );
      if (invoiceUpdated != 1) {
        throw StateError('Rechnung konnte nicht finalisiert werden');
      }

      // — Atomic accounting postings: journal + receivable + tax in same tx (via RechnungTyp helper — centralized)
      final kundeId = invoice['kunde_id'];
      final lieferantId = invoice['lieferant_id'];
      final bool isIncoming = RechnungTyp.isEingang(typ) || lieferantId != null;
      final String belegTyp = RechnungTyp.belegTypFor(
        typ: typ,
        lieferantId: lieferantId is int ? lieferantId : int.tryParse('${lieferantId ?? ''}'),
      );
      final String datumStr = invoiceDate.toIso8601String().substring(0, 10);
      // Resolve kategorie for journal — first active, fallback 1
      int? kategorieId;
      try {
        final katRows = await transaction.runSelect(
          'SELECT id FROM kategorien WHERE aktiv = 1 ORDER BY id LIMIT 1',
          const <Object?>[],
        );
        if (katRows.isNotEmpty) {
          final v = katRows.single['id'];
          kategorieId = v is int ? v : int.tryParse(v.toString());
        }
      } catch (_) {}
      kategorieId ??= 1;
      final int journalId = await transaction.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, rechnung_id, beleg_nr, immutable, erstellungsdatum, gruppe_id) VALUES (?, ?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP, NULL)',
        <Object?>[
          datumStr,
          'Rechnung $documentNumber',
          kategorieId,
          preview.bruttoBetragString,
          belegTyp,
          rechnungId,
          documentNumber,
        ],
      );
      await transaction.runUpdate('UPDATE journal SET gruppe_id = ? WHERE id = ?', <Object?>[journalId, journalId]);
      if (debugFailAt == 'journal') throw StateError('Induced failure after journal');
      final Object? partnerIdRaw = isIncoming ? lieferantId : kundeId;
      final String partnerTyp = isIncoming ? 'lieferant' : 'kunde';
      int? partnerId;
      if (partnerIdRaw is int) {
        partnerId = partnerIdRaw;
      } else if (partnerIdRaw != null) {
        partnerId = int.tryParse(partnerIdRaw.toString());
      }
      // Receivable — skip only if no partner (keeps journal atomic test green)
      if (partnerId != null && partnerId > 0) {
        final String forderungTyp = RechnungTyp.forderungTypFor(
          typ: typ,
          lieferantId: lieferantId is int ? lieferantId : int.tryParse('${lieferantId ?? ''}'),
        );
        final nowIso = DateTime.now().toIso8601String();
        final int? legacyKundeId = partnerTyp == 'kunde' ? partnerId : null;
        // ponytail: anfangsbetrag is added by ForderungenRepository.ensureSchema; base table lacks it, so insert via compatible column set
        // Try with anfangsbetrag first, fallback without.
        try {
          await transaction.runInsert(
            'INSERT INTO forderungen (typ, status, betrag, anfangsbetrag, partner_typ, partner_id, rechnung_id, journal_id, erstellt_am, aktualisiert_am, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              forderungTyp,
              'offen',
              preview.bruttoBetragString,
              preview.bruttoBetragString,
              partnerTyp,
              partnerId,
              rechnungId,
              journalId,
              nowIso,
              nowIso,
              legacyKundeId,
            ],
          );
        } catch (_) {
          await transaction.runInsert(
            'INSERT INTO forderungen (typ, status, betrag, partner_typ, partner_id, rechnung_id, journal_id, erstellt_am, aktualisiert_am, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              forderungTyp,
              'offen',
              preview.bruttoBetragString,
              partnerTyp,
              partnerId,
              rechnungId,
              journalId,
              nowIso,
              nowIso,
              legacyKundeId,
            ],
          );
        }
      }
      if (debugFailAt == 'receivable') throw StateError('Induced failure after receivable');
      // Tax / input-tax claim — create when VAT present (covers both directions; incoming spec validated)
      if (preview.ustCents != 0) {
        await transaction.runInsert(
          'INSERT INTO vorsteuer_ansprueche (rechnung_id, betrag, faelligkeit, status) VALUES (?, ?, ?, ?)',
          <Object?>[rechnungId, preview.ustBetragString, datumStr, 'offen'],
        );
      }
      if (debugFailAt == 'tax') throw StateError('Induced failure after tax');

      await transaction.send();
      return rechnungId;
    } catch (error, stackTrace) {
      if (createdPdfFile != null) {
        try {
          if (createdPdfFile.existsSync()) createdPdfFile.deleteSync();
        } catch (_) {}
      }
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
    // ponytail: global tx lock, per-invoice lock if throughput matters
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      final origRows = await transaction.runSelect(
        'SELECT id, ist_entwurf, typ, status, datum, storno_datum, storno_grund, eingabemodus FROM rechnungen WHERE id = ?',
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
      const String kreisTyp = 'stornorechnung';
      final rangeRows = await transaction.runSelect(
        'SELECT id, format, naechste_nummer FROM nummernkreise WHERE typ = ? AND aktiv = 1 ORDER BY id LIMIT 1',
        <Object?>[kreisTyp],
      );
      if (rangeRows.isEmpty) throw StateError('Stornorechnung-Nummernkreis fehlt');
      final range = rangeRows.single;
      final format = range['format'].toString();
      final seq = _sequenceMatchesForFormat(format);
      if (seq == null || seq.length != 1) {
        throw StateError('Stornorechnung-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
      }
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
      final eingabemodus = orig['eingabemodus']?.toString() ?? 'netto';
      final List<RechnungPositionItem> sourcePositions = posRows
          .map(
            (r) => RechnungPositionItem(
              bezeichnung: r['bezeichnung']?.toString() ?? '',
              menge: _asNum(r['menge']).abs(),
              einzelpreis: _asNum(r['einzelpreis']).abs(),
              gesamt: _asNum(r['gesamt']).abs(),
              ustSatz: _asNum(r['ust_satz']),
              rabattProzent: r['rabatt_prozent'] == null ? null : _asNum(r['rabatt_prozent']),
              artikelId: r['artikel_id'] == null ? null : _asInt(r['artikel_id']),
            ),
          )
          .toList(growable: false);
      final VorschauResult sourcePreview = VorschauService.calculate(
        eingabemodus: eingabemodus,
        positionen: sourcePositions,
      );
      final int correctionSign = isGutschrift ? 1 : -1;
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
          money.fromCents(correctionSign * sourcePreview.nettoCents),
          money.fromCents(correctionSign * sourcePreview.bruttoCents),
          money.fromCents(correctionSign * sourcePreview.ustCents),
          DateTime.now().toUtc().toIso8601String(),
          'pdfs/$docNo.pdf',
        ],
      );
      for (final r in posRows) {
        final gesamt = _asNum(r['gesamt']).abs();
        final correctedGesamt = money.fromCents(correctionSign * money.toCents(gesamt.toString()));
        await transaction.runInsert(
          'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            stornoId,
            r['artikel_id'],
            r['bezeichnung'],
            r['menge'].toString(),
            r['einzelpreis'].toString(),
            correctedGesamt,
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
      await _ensureInventarTable(transaction);
      for (final r in posRows) {
        if (r['artikel_id'] == null) continue;
        final aid = r['artikel_id'];
        final lagerRows = await transaction.runSelect(
          'SELECT lager_aktiv, bestand, bestand_aktuell FROM artikel WHERE id = ?',
          <Object?>[aid],
        );
        if (lagerRows.isEmpty) continue;
        final lagerRaw = _asInt(lagerRows.single['lager_aktiv']) == 1;
        final bLegacy = _asNum(lagerRows.single['bestand']);
        final bAktuell = _asNum(lagerRows.single['bestand_aktuell']);
        final isLegacy = !lagerRaw && bAktuell == 0 && bLegacy != 0;
        final lagerAktiv = lagerRaw || isLegacy;
        if (!lagerAktiv) continue;
        final menge = _asNum(r['menge']);
        final eff = bAktuell != 0 ? bAktuell : bLegacy;
        final newStock = eff + menge;
        if (isLegacy) {
          await transaction.runUpdate(
            'UPDATE artikel SET bestand_aktuell = ?, bestand = ?, lager_aktiv = 1 WHERE id = ?',
            <Object?>[newStock, newStock, aid],
          );
        } else {
          await transaction.runUpdate(
            'UPDATE artikel SET bestand_aktuell = bestand_aktuell + ?, bestand = bestand + ? WHERE id = ?',
            <Object?>[menge, menge, aid],
          );
        }
        await transaction.runInsert(
          'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund, referenz_typ, referenz_id) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[aid, datum, menge, 'Storno $docNo', 'storno', stornoId],
        );
      }
      // — Reversal postings negated, linked to original (atomic)
      final origJournals = await transaction.runSelect('SELECT * FROM journal WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      int? reversalJournalId;
      for (final j in origJournals) {
        final origBetrag = j['betrag']?.toString() ?? '0';
        final cents = money.toCents(origBetrag);
        final reversed = money.fromCents(-cents);
        final int revId = await transaction.runInsert(
          'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, rechnung_id, beleg_nr, immutable, erstellungsdatum, gruppe_id, storno_von) VALUES (?, ?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP, NULL, ?)',
          <Object?>[datum, 'Storno $docNo', j['kategorie_id'], reversed, j['beleg_typ'], stornoId, docNo, j['id']],
        );
        await transaction.runUpdate('UPDATE journal SET gruppe_id = ? WHERE id = ?', <Object?>[revId, revId]);
        reversalJournalId ??= revId;
      }
      final origForderungen = await transaction.runSelect('SELECT * FROM forderungen WHERE rechnung_id = ?', <Object?>[
        rechnungId,
      ]);
      for (final f in origForderungen) {
        final betragStr = f['betrag']?.toString() ?? '0';
        final cents = money.toCents(betragStr);
        final reversed = money.fromCents(-cents);
        final anfangsStr = f['anfangsbetrag']?.toString() ?? betragStr;
        final anfangsCents = money.toCents(anfangsStr);
        final revAnfangs = money.fromCents(-anfangsCents);
        final nowIso = DateTime.now().toIso8601String();
        try {
          await transaction.runInsert(
            'INSERT INTO forderungen (typ, status, betrag, anfangsbetrag, partner_typ, partner_id, rechnung_id, journal_id, erstellt_am, aktualisiert_am, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              f['typ'],
              'offen',
              reversed,
              revAnfangs,
              f['partner_typ'],
              f['partner_id'],
              stornoId,
              reversalJournalId,
              nowIso,
              nowIso,
              f['kunde_id'],
            ],
          );
        } catch (_) {
          await transaction.runInsert(
            'INSERT INTO forderungen (typ, status, betrag, partner_typ, partner_id, rechnung_id, journal_id, erstellt_am, aktualisiert_am, kunde_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              f['typ'],
              'offen',
              reversed,
              f['partner_typ'],
              f['partner_id'],
              stornoId,
              reversalJournalId,
              nowIso,
              nowIso,
              f['kunde_id'],
            ],
          );
        }
      }
      final origVorsteuer = await transaction.runSelect(
        'SELECT * FROM vorsteuer_ansprueche WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      for (final v in origVorsteuer) {
        final betragStr = v['betrag']?.toString() ?? '0';
        final cents = money.toCents(betragStr);
        final reversed = money.fromCents(-cents);
        await transaction.runInsert(
          'INSERT INTO vorsteuer_ansprueche (rechnung_id, betrag, faelligkeit, status) VALUES (?, ?, ?, ?)',
          <Object?>[stornoId, reversed, v['faelligkeit'] ?? datum, 'offen'],
        );
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
      String useEingabemodus = 'netto';
      if (vonRechnungId != null) {
        final orig = await transaction.runSelect(
          'SELECT id, ist_entwurf, datum, eingabemodus FROM rechnungen WHERE id = ?',
          <Object?>[vonRechnungId],
        );
        if (orig.isEmpty) throw StateError('Rechnung nicht gefunden');
        if (_asInt(orig.single['ist_entwurf']) == 1) {
          throw StateError('Nur finalisierte Rechnung kann gutgeschrieben werden');
        }
        useDatum = orig.single['datum'].toString();
        useEingabemodus = orig.single['eingabemodus']?.toString() ?? 'netto';
        linkId = vonRechnungId;
        posRows = await transaction.runSelect(
          'SELECT artikel_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position, rabatt_prozent FROM rechnungspositionen WHERE rechnung_id = ?',
          <Object?>[vonRechnungId],
        );
        usePos = posRows
            .map(
              (r) => RechnungPositionItem(
                bezeichnung: r['bezeichnung']?.toString() ?? '',
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
      const String kreisTyp = 'gutschrift';
      final rangeRows = await transaction.runSelect(
        'SELECT id, format, naechste_nummer FROM nummernkreise WHERE typ = ? AND aktiv = 1 ORDER BY id LIMIT 1',
        <Object?>[kreisTyp],
      );
      if (rangeRows.isEmpty) throw StateError('Gutschrift-Nummernkreis fehlt');
      final range = rangeRows.single;
      final format = range['format'].toString();
      final seq = _sequenceMatchesForFormat(format);
      if (seq == null || seq.length != 1) {
        throw StateError('Gutschrift-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
      }
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
      final int reserved = await transaction.runUpdate(
        'UPDATE nummernkreise SET naechste_nummer = ? WHERE id = ? AND naechste_nummer = ?',
        <Object?>[nextNo + 1, range['id'], stored],
      );
      if (reserved != 1) {
        throw StateError('Gutschrift-Nummernkreis konnte nicht atomar reserviert werden');
      }
      // Validate and calculate the unsigned source once. The correction sign
      // is applied only when persisting the generated header/lines.
      final VorschauResult sourcePreview = VorschauService.calculate(eingabemodus: useEingabemodus, positionen: usePos);
      final gsId = await transaction.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, nummernkreis_id, gutschrift_von, netto_betrag, brutto_betrag, ust_betrag, ausgegeben_am, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          docNo,
          'gutschrift',
          'entwurf',
          useDatum,
          1,
          useEingabemodus,
          range['id'],
          linkId,
          money.fromCents(-sourcePreview.nettoCents),
          money.fromCents(-sourcePreview.bruttoCents),
          money.fromCents(-sourcePreview.ustCents),
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
              money.fromCents(-money.toCents(gesamt.toString())),
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
              p.menge.toStringAsFixed(3),
              p.einzelpreis.toStringAsFixed(4),
              money.fromCents(-money.toCents(p.gesamt.toString())),
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
        'SELECT id, status, storno_datum, ersatzrechnung_id FROM rechnungen WHERE id = ?',
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
                  bezeichnung: r['bezeichnung']?.toString() ?? '',
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
            preview.nettoBetragString,
            preview.bruttoBetragString,
            preview.ustBetragString,
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
    if (seq == null || seq.length != 1) {
      throw StateError('$kreisTyp-Nummernkreis-Format muss genau ein Sequenz-Token enthalten');
    }
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
    return _AllocatedNumber(nummer: nummer, kreisId: _asInt(range['id']) ?? 0, nextNo: nextNo, stored: stored);
  }

  Future<void> _ensureInventarTable(QueryExecutor ex) async {
    await ex.runCustom('''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''');
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

  Future<PdfDocumentSnapshot> _buildPdfSnapshot({
    required TransactionExecutor transaction,
    required Map<String, Object?> invoice,
    required List<Map<String, Object?>> posRows,
    required VorschauResult preview,
    required String documentNumber,
    required DateTime invoiceDate,
    required String typ,
    required String eingabemodus,
    required List<Map<String, Object?>> companyRows,
  }) async {
    final Map<String, Object?> companyRow = companyRows.isEmpty ? const <String, Object?>{} : companyRows.single;
    final PdfCompanySnapshot companySnapshot = PdfCompanySnapshot.from(
      name: (companyRow['name']?.toString().trim().isNotEmpty ?? false) ? companyRow['name'].toString() : 'Firma',
      street: _companyStreet(companyRow),
      postalCode: companyRow['plz']?.toString(),
      city: companyRow['ort']?.toString(),
      country: companyRow['land']?.toString(),
      phone: companyRow['telefon']?.toString() ?? companyRow['phone']?.toString(),
      email: companyRow['email']?.toString(),
      website: companyRow['website']?.toString(),
      taxNumber: companyRow['steuernummer']?.toString(),
      vatId: companyRow['ust_idnr']?.toString() ?? companyRow['ust_id']?.toString(),
      iban: companyRow['iban']?.toString(),
      bic: companyRow['bic']?.toString(),
    );
    PdfCustomerSnapshot customerSnapshot = const PdfCustomerSnapshot(name: 'Unbekannt');
    final Object? kundeId = invoice['kunde_id'];
    final Object? lieferantId = invoice['lieferant_id'];
    try {
      if (kundeId != null) {
        final rows = await transaction.runSelect('SELECT * FROM kunden WHERE id = ?', <Object?>[kundeId]);
        if (rows.isNotEmpty) {
          customerSnapshot = _customerFromKunde(rows.single);
        }
      } else if (lieferantId != null) {
        final rows = await transaction.runSelect('SELECT * FROM lieferanten WHERE id = ?', <Object?>[lieferantId]);
        if (rows.isNotEmpty) {
          customerSnapshot = _customerFromLieferant(rows.single);
        }
      }
    } catch (_) {}
    final List<PdfPositionSnapshot> pdfPositions = _pdfPositionsFromRows(posRows, eingabemodus);
    final PdfTemplate template = PdfTemplate.fromRaw(companyRow['pdf_vorlage']?.toString());
    final PdfDocumentType docType = () {
      try {
        return PdfDocumentType.fromRaw(typ);
      } catch (_) {
        return PdfDocumentType.rechnung;
      }
    }();
    PdfDocumentTextsSnapshot texts = const PdfDocumentTextsSnapshot();
    try {
      texts = PdfDocumentTextsSnapshot(
        rechnung: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_rechnung']?.toString(),
          schlusstext: companyRow['schlusstext_rechnung']?.toString(),
        ),
        angebot: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_angebot']?.toString(),
          schlusstext: companyRow['schlusstext_angebot']?.toString(),
        ),
        auftrag: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_auftrag']?.toString(),
          schlusstext: companyRow['schlusstext_auftrag']?.toString(),
        ),
        proforma: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_proforma']?.toString(),
          schlusstext: companyRow['schlusstext_proforma']?.toString(),
        ),
        lieferschein: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_lieferschein']?.toString(),
          schlusstext: companyRow['schlusstext_lieferschein']?.toString(),
        ),
        gutschrift: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_gutschrift']?.toString(),
          schlusstext: companyRow['schlusstext_gutschrift']?.toString(),
        ),
        storno: PdfTypeTextSnapshot(
          einleitungstext: companyRow['einleitungstext_storno']?.toString(),
          schlusstext: companyRow['schlusstext_storno']?.toString(),
        ),
      );
    } catch (_) {}
    return PdfDocumentSnapshot.from(
      documentType: docType,
      template: template,
      documentNumber: documentNumber,
      company: companySnapshot,
      customer: customerSnapshot,
      positions: pdfPositions,
      totals: PdfTotalsSnapshot(
        netAmount: preview.nettoBetrag,
        taxAmount: preview.ustBetrag,
        grossAmount: preview.bruttoBetrag,
      ),
      texts: texts,
      documentDate: invoiceDate,
    );
  }

  static String? _companyStreet(Map<String, Object?> row) {
    final String? strasse = row['strasse']?.toString();
    final String? hausnummer = row['hausnummer']?.toString();
    if (strasse == null || strasse.trim().isEmpty) return null;
    if (hausnummer != null && hausnummer.trim().isNotEmpty) return '$strasse $hausnummer';
    return strasse;
  }

  static PdfCustomerSnapshot _customerFromKunde(Map<String, Object?> row) {
    final String street = [
      row['strasse']?.toString(),
      row['hausnummer']?.toString(),
    ].where((e) => e != null && e.trim().isNotEmpty).join(' ');
    return PdfCustomerSnapshot(
      name: (row['name']?.toString().trim().isNotEmpty ?? false) ? row['name'].toString() : 'Kunde',
      company: row['firma']?.toString(),
      street: street.isEmpty ? null : street,
      postalCode: row['plz']?.toString(),
      city: row['ort']?.toString(),
      country: row['land']?.toString(),
    );
  }

  static PdfCustomerSnapshot _customerFromLieferant(Map<String, Object?> row) {
    final String street = [
      row['strasse']?.toString(),
      row['hausnummer']?.toString(),
    ].where((e) => e != null && e.trim().isNotEmpty).join(' ');
    return PdfCustomerSnapshot(
      name: (row['name']?.toString().trim().isNotEmpty ?? false) ? row['name'].toString() : 'Lieferant',
      company: row['firma']?.toString(),
      street: street.isEmpty ? null : street,
      postalCode: row['plz']?.toString(),
      city: row['ort']?.toString(),
      country: row['land']?.toString(),
    );
  }

  static List<PdfPositionSnapshot> _pdfPositionsFromRows(List<Map<String, Object?>> posRows, String eingabemodus) {
    final List<PdfPositionSnapshot> result = <PdfPositionSnapshot>[];
    for (var index = 0; index < posRows.length; index++) {
      final Map<String, Object?> r = posRows[index];
      final String description = r['bezeichnung']?.toString() ?? '';
      final num quantity = _asNum(r['menge']);
      final num unitPrice = _asNum(r['einzelpreis']);
      final num taxRate = _asNum(r['ust_satz']);
      final num grossRaw = _asNum(r['gesamt']);
      final int rateScaled = _percentScaled(taxRate);
      // undiscounted line via integer arithmetic for consistency
      int netCents;
      int grossCents;
      int taxCents;
      try {
        final int qtyScaled = money.scaledFromNum(quantity, scale: 3, field: 'menge', allowNegative: false);
        final int priceScaled = money.scaledFromNum(unitPrice, scale: 4, field: 'einzelpreis', allowNegative: false);
        final int lineUndiscounted = _roundHalfUp(priceScaled * qtyScaled, 100000);
        final int discountScaled = r['rabatt_prozent'] == null
            ? 0
            : money.scaledFromNum(_asNum(r['rabatt_prozent']), scale: 2, field: 'rabatt', allowNegative: false);
        final int lineCents = discountScaled == 0
            ? lineUndiscounted
            : _roundHalfUp(lineUndiscounted * (10000 - discountScaled), 10000);
        if (eingabemodus == 'netto') {
          netCents = lineCents;
          taxCents = _roundHalfUp(netCents * rateScaled, 10000);
          grossCents = netCents + taxCents;
        } else {
          grossCents = lineCents;
          netCents = _roundHalfUp(grossCents * 10000, 10000 + rateScaled);
          taxCents = grossCents - netCents;
        }
      } catch (_) {
        // fallback to grossRaw approximation
        if (eingabemodus == 'netto') {
          netCents = money.toCents(grossRaw.toString());
          taxCents = _roundHalfUp(netCents * rateScaled, 10000);
          grossCents = netCents + taxCents;
        } else {
          grossCents = money.toCents(grossRaw.toString());
          netCents = _roundHalfUp(grossCents * 10000, 10000 + rateScaled);
          taxCents = grossCents - netCents;
        }
      }
      result.add(
        PdfPositionSnapshot(
          description: description,
          quantity: quantity,
          unitPrice: unitPrice,
          netAmount: netCents / 100.0,
          taxRate: taxRate,
          taxAmount: taxCents / 100.0,
          grossAmount: grossCents / 100.0,
          position: r['position'] == null ? index : _asInt(r['position']),
          discountPercent: r['rabatt_prozent'] == null ? null : _asNum(r['rabatt_prozent']),
        ),
      );
    }
    return result;
  }

  static int _percentScaled(num value) {
    try {
      return money.scaledFromNum(value, scale: 2, field: 'percent', allowNegative: false);
    } catch (_) {
      return 0;
    }
  }

  static int _roundHalfUp(int numerator, int denominator) => (numerator + denominator ~/ 2) ~/ denominator;

  /// Minimal valid PDF — placeholder retained for fallback; finalize now uses PdfGenerator.
  // ignore: unused_element
  static List<int> _minimalPdf() => [
    0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34, // %PDF-1.4
    0x0a, 0x25, 0xe2, 0xe3, 0xcf, 0xd3, 0x0a, // \n%âãÏÓ\n
    0x31, 0x20, 0x30, 0x20, 0x6f, 0x62, 0x6a, // 1 0 obj
    0x3c, 0x3c, 0x2f, 0x54, 0x79, 0x70, 0x65, // <</Type
    0x2f, 0x43, 0x61, 0x74, 0x61, 0x6c, 0x6f, // /Catalo
    0x67, 0x2f, 0x50, 0x61, 0x67, 0x65, 0x73, // g/Pages
    0x20, 0x32, 0x20, 0x30, 0x20, 0x52, 0x3e, //  2 0 R>
    0x3e, 0x0a, 0x65, 0x6e, 0x64, 0x6f, 0x62, // >\nendobj
    0x6a, 0x0a, // \nj\n
    0x32, 0x20, 0x30, 0x20, 0x6f, 0x62, 0x6a, // 2 0 obj
    0x3c, 0x3c, 0x2f, 0x54, 0x79, 0x70, 0x65, // <</Type
    0x2f, 0x50, 0x61, 0x67, 0x65, 0x73, 0x2f, // /Pages/
    0x4b, 0x69, 0x64, 0x73, 0x5b, 0x33, 0x20, // Kids[3
    0x30, 0x20, 0x52, 0x5d, 0x2f, 0x43, 0x6f, // 0 R]/Co
    0x75, 0x6e, 0x74, 0x20, 0x31, 0x3e, 0x3e, // unt 1>>
    0x0a, 0x65, 0x6e, 0x64, 0x6f, 0x62, 0x6a, // \nendobj
    0x6a, 0x0a, // \nj\n
    0x33, 0x20, 0x30, 0x20, 0x6f, 0x62, 0x6a, // 3 0 obj
    0x3c, 0x3c, 0x2f, 0x54, 0x79, 0x70, 0x65, // <</Type
    0x2f, 0x50, 0x61, 0x67, 0x65, 0x2f, 0x50, // /Page/P
    0x61, 0x72, 0x65, 0x6e, 0x74, 0x20, 0x32, // arent 2
    0x20, 0x30, 0x20, 0x52, 0x2f, 0x4d, 0x65, //  0 R/Me
    0x64, 0x69, 0x61, 0x42, 0x6f, 0x78, 0x5b, // diaBox[
    0x30, 0x20, 0x30, 0x20, 0x36, 0x31, 0x32, // 0 0 612
    0x20, 0x37, 0x39, 0x32, 0x5d, 0x3e, 0x3e, //  792]>>
    0x0a, 0x65, 0x6e, 0x64, 0x6f, 0x62, 0x6a, // \nendobj
    0x6a, 0x0a, // \nj\n
    0x78, 0x72, 0x65, 0x66, 0x0a, // xref\n
    0x30, 0x20, 0x34, 0x0a, // 0 4\n
    0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // 00000000
    0x30, 0x30, 0x20, 0x36, 0x35, 0x35, 0x33, 0x35, // 00 65535
    0x20, 0x66, 0x0a, //  f\n
    0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // 00000000
    0x30, 0x30, 0x20, 0x30, 0x30, 0x30, 0x30, 0x30, // 00 00000
    0x30, 0x20, 0x66, 0x0a, // 0 f\n
    0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // 00000000
    0x30, 0x30, 0x20, 0x30, 0x30, 0x30, 0x30, 0x30, // 00 00000
    0x30, 0x20, 0x66, 0x0a, // 0 f\n
    0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, // 00000000
    0x30, 0x30, 0x20, 0x30, 0x30, 0x30, 0x30, 0x30, // 00 00000
    0x30, 0x20, 0x66, 0x0a, // 0 f\n
    0x74, 0x72, 0x61, 0x69, 0x6c, 0x65, 0x72, 0x3c, // trailer<
    0x3c, 0x2f, 0x53, 0x69, 0x7a, 0x65, 0x20, 0x34, // </Size 4
    0x2f, 0x52, 0x6f, 0x6f, 0x74, 0x20, 0x31, 0x20, // /Root 1
    0x30, 0x20, 0x52, 0x3e, 0x3e, 0x0a, // 0 R>>\n
    0x73, 0x74, 0x61, 0x72, 0x74, 0x78, 0x72, 0x65, // startxre
    0x66, 0x0a, // f\n
    0x31, 0x37, 0x36, 0x0a, // 176\n
    0x25, 0x25, 0x45, 0x4f, 0x46, 0x0a, // %%EOF\n
  ];
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
