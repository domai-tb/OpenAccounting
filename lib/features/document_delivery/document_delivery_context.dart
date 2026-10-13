import 'package:drift/drift.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';

// Typed delivery context assembled from the production `/invoices/:id` route
// record: document ID, finalized `RechnungItem` data, linked customer email,
// canonical total, and stored generated PDF artifact. Deferred types
// (`Lieferschein` without artifact provider, `Mahnung` without accepted route
// and contracts) stay unavailable: no send action may be offered for them.

class DocumentDeliveryContext {
  const DocumentDeliveryContext({
    required this.dokumentId,
    required this.dokumentTyp,
    required this.dokumentnummer,
    required this.betrag,
    required this.faelligkeit,
    required this.firma,
    required this.empfaenger,
    required this.hauptArtefaktPfad,
    required this.istEntwurf,
  });

  final int dokumentId;
  final String dokumentTyp;
  final String dokumentnummer;
  final num betrag;
  final String? faelligkeit;
  final String? firma;
  final String? empfaenger;
  final String? hauptArtefaktPfad;
  final bool istEntwurf;

  bool get istUnterstuetzt => DocumentEmailType.isSupported(dokumentTyp);
  bool get istZurueckgestellt => DocumentEmailType.isDeferred(dokumentTyp);
  bool get istFinalisiert => !istEntwurf;
  bool get hatArtefakt => hauptArtefaktPfad != null && hauptArtefaktPfad!.trim().isNotEmpty;

  /// Eligibility for the send action: finalized, supported, with artifact.
  bool get versandbereit => istUnterstuetzt && istFinalisiert && hatArtefakt;

  /// Blocking reason before any SMTP connection; null when review may start.
  String? blockierGrund() {
    if (istZurueckgestellt) return 'zurueckgestellt';
    if (!istUnterstuetzt) return 'typ_unbekannt';
    if (!istFinalisiert) return 'entwurf';
    if (!hatArtefakt) return 'artefakt_fehlt';
    if (empfaenger == null || empfaenger!.trim().isEmpty) return 'empfaenger_fehlt';
    try {
      parseSingleMailbox(empfaenger!, field: 'Empfänger');
    } on DocumentDeliveryException {
      return 'empfaenger_ungueltig';
    }
    return null;
  }
}

class DocumentDeliveryContextProvider {
  DocumentDeliveryContextProvider(this.executor);

  final QueryExecutor executor;

  Future<DocumentDeliveryContext> load(int dokumentId) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT r.id, r.rechnungsnummer, r.typ, r.ist_entwurf, r.status, r.datum, r.faelligkeit, '
      'r.brutto_betrag, r.original_pdf_pfad, r.kunde_id, k.email AS kunde_email, u.name AS firma '
      'FROM rechnungen r LEFT JOIN kunden k ON k.id = r.kunde_id '
      'LEFT JOIN unternehmen u ON u.id = 1 WHERE r.id = ?',
      <Object?>[dokumentId],
    );
    if (rows.isEmpty) {
      throw const DocumentDeliveryException('Dokument nicht gefunden', code: 'dokument_fehlt');
    }
    final Map<String, Object?> row = rows.single;
    final String typ = '${row['typ'] ?? ''}'.trim().toLowerCase();
    final Object? entwurfRaw = row['ist_entwurf'];
    final bool istEntwurf =
        (entwurfRaw is num ? entwurfRaw != 0 : '${entwurfRaw ?? ''}' == '1') ||
        '${row['status'] ?? ''}'.toLowerCase() == 'entwurf';
    return DocumentDeliveryContext(
      dokumentId: (row['id']! as num).toInt(),
      dokumentTyp: typ,
      dokumentnummer: (row['rechnungsnummer'] as String?) ?? 'Entwurf #$dokumentId',
      betrag: _asNum(row['brutto_betrag']),
      faelligkeit: row['faelligkeit'] as String?,
      firma: row['firma'] as String?,
      empfaenger: row['kunde_email'] as String?,
      hauptArtefaktPfad: row['original_pdf_pfad'] as String?,
      istEntwurf: istEntwurf,
    );
  }

  static num _asNum(Object? value) {
    if (value is num) return value;
    return num.tryParse('${value ?? '0'}') ?? 0;
  }
}
