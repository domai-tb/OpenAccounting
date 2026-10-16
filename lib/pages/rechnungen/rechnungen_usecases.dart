import 'package:openaccounting/features/accounting/rechnung_typ.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

/// Supported conversion targets per source type.
const Map<String, Set<String>> erlaubteKonvertierungen = <String, Set<String>>{
  'angebot': {'auftrag', 'proforma', 'rechnung'},
  'auftrag': {'lieferschein', 'rechnung'},
  'lieferschein': {'rechnung'},
  'proforma': {'rechnung'},
  'rechnung': {},
  'gutschrift': {},
  'storno': {},
};

class RechnungenUseCases {
  const RechnungenUseCases(this.repository);

  final RechnungenRepository repository;

  void _rejectGenericCorrectionDraft(String typ) {
    if (typ == 'gutschrift' || typ == 'storno') {
      throw InvoiceMoneyValidationException(
        code: 'unsupportedDocumentType',
        message: 'Korrekturdokumente müssen über ihren eigenen Erstellungsweg angelegt werden',
        fields: const ['typ'],
      );
    }
  }

  Future<RechnungItem> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
    String typ = 'rechnung',
    String eingabemodus = 'netto',
    int? kundeId,
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    _rejectGenericCorrectionDraft(typ);
    _validateDraftInput(
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    return repository.createDraftRechnung(
      datum: datum,
      positionen: positionen,
      typ: typ,
      eingabemodus: eingabemodus,
      kundeId: kundeId,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  /// Creates a supplier invoice draft linked to a reviewed source Beleg.
  Future<RechnungItem> createIncomingInvoiceDraft({
    required int lieferantId,
    required int belegId,
    required String datum,
    required List<RechnungPositionItem> positionen,
    String? faelligkeit,
    String? fremdRechnungsnummer,
  }) async {
    if (lieferantId <= 0 || belegId <= 0) throw ArgumentError('Lieferant und Beleg sind erforderlich');
    if (faelligkeit != null && !_isValidIsoDate(faelligkeit)) {
      throw ArgumentError.value(faelligkeit, 'faelligkeit', 'Erwartet ein gültiges ISO-Datum (YYYY-MM-DD).');
    }
    _validateDraftInput(datum: datum, positionen: positionen);
    return repository.createDraftRechnung(
      datum: datum,
      positionen: positionen,
      typ: RechnungTyp.eingang,
      lieferantId: lieferantId,
      belegId: belegId,
      faelligkeit: faelligkeit,
      fremdRechnungsnummer: fremdRechnungsnummer?.trim().isEmpty ?? true ? null : fremdRechnungsnummer!.trim(),
    );
  }

  /// Persists a full draft update atomically; rejected edits throw before
  /// any write so the saved draft stays untouched.
  Future<RechnungItem> updateDraftRechnung({
    required int rechnungId,
    required String datum,
    required List<RechnungPositionItem> positionen,
    String? eingabemodus,
    int? kundeId,
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    _validateDraftInput(
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus ?? 'netto',
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    final RechnungItem? existing = await repository.findById(rechnungId);
    if (existing == null) throw StateError('Rechnung nicht gefunden');
    if (!existing.istEntwurfDokument) {
      throw StateError('Nur Entwürfe können bearbeitet werden');
    }
    _rejectGenericCorrectionDraft(existing.typ);
    return repository.updateDraftRechnung(
      rechnungId: rechnungId,
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      kundeId: kundeId,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  /// Authoritative domain preview for live workspace totals.
  VorschauResult previewRechnung({
    required String eingabemodus,
    required List<RechnungPositionItem> positionen,
    num? rabattProzent,
    num? rabattBetrag,
  }) {
    return repository.previewRechnung(
      eingabemodus: eingabemodus,
      positionen: positionen,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  /// Correction/conversion actions stay unavailable until the real artifact
  /// transaction prerequisite is present.
  bool get correctionActionsAvailable => repository.correctionArtifactTransactionAvailable;

  bool kannFinalisieren(RechnungItem dokument) {
    if (!dokument.istEntwurfDokument) return false;
    final String typ = dokument.typ.trim().toLowerCase();
    if (typ == 'gutschrift' || typ == 'storno') return false;
    return true;
  }

  bool kannStorno(RechnungItem dokument) {
    if (!correctionActionsAvailable) return false;
    final String typ = dokument.typ.trim().toLowerCase();
    if (!RechnungTyp.isInvoice(typ) && typ != 'gutschrift') return false;
    if (dokument.istEntwurfDokument || dokument.istStorniert) return false;
    return true;
  }

  bool kannGutschrift(RechnungItem dokument) {
    if (!correctionActionsAvailable) return false;
    if (dokument.typ.trim().toLowerCase() != 'rechnung') return false;
    if (dokument.istEntwurfDokument) return false;
    return true;
  }

  bool kannErsatz(RechnungItem dokument) {
    if (!correctionActionsAvailable) return false;
    if (dokument.typ.trim().toLowerCase() != 'rechnung') return false;
    if (!dokument.istStorniert) return false;
    if (dokument.beziehungen.any((b) => b.kind == 'ersatz Ziel' && b.available)) return false;
    return true;
  }

  Set<String> konvertierZiele(RechnungItem dokument) {
    if (!correctionActionsAvailable) return const <String>{};
    return erlaubteKonvertierungen[dokument.typ.trim().toLowerCase()] ?? const <String>{};
  }

  Future<RechnungItem> createDokument({
    required String typ,
    required String datum,
    required List<RechnungPositionItem> positionen,
    String eingabemodus = 'netto',
    int? kundeId,
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    _rejectGenericCorrectionDraft(typ);
    _validateDraftInput(
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    const allowed = {'rechnung', 'angebot', 'auftrag', 'proforma', 'lieferschein', 'gutschrift', 'storno'};
    if (!allowed.contains(typ)) {
      throw StateError('Unbekannter Dokumenttyp');
    }
    return repository.createDokument(
      typ: typ,
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      kundeId: kundeId,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  Future<RechnungItem> finalizeRechnung({
    required int rechnungId,
    required String locale,
    String ausgabeformat = 'pdf',
  }) {
    return _finalize(rechnungId, locale, ausgabeformat);
  }

  Future<RechnungItem> _finalize(int rechnungId, String locale, String ausgabeformat) async {
    final RechnungItem? existing = await repository.findById(rechnungId);
    if (existing == null) throw StateError('Rechnung nicht gefunden');
    // Revalidate eligibility at the transactional boundary before any
    // numbering, PDF, stock or accounting write.
    if (!kannFinalisieren(existing)) {
      if (!existing.istEntwurfDokument) {
        throw StateError('Dokument ist bereits finalisiert');
      }
      throw StateError(
        'Unbekannter oder für generische Finalisierung nicht unterstützter Dokumenttyp: ${existing.typ}',
      );
    }
    final String normalizedFormat = ausgabeformat.trim().toLowerCase();
    if (normalizedFormat != 'pdf' && normalizedFormat != 'zugferd' && normalizedFormat != 'xrechnung') {
      throw ArgumentError.value(ausgabeformat, 'ausgabeformat', 'Unbekanntes Ausgabeformat');
    }
    // Invalid preview blocks finalization before confirmation side effects.
    VorschauService.calculate(eingabemodus: existing.eingabemodus, positionen: existing.positionen);
    return repository.finalizeRechnung(rechnungId: rechnungId, locale: locale, ausgabeformat: normalizedFormat);
  }

  /// Standalone XRechnung export for a finalized ordinary outgoing invoice.
  ///
  /// Validates the committed snapshot before any dialog or file write and
  /// never mutates the invoice. Returns the destination path, or null when
  /// the user cancels. The explicit [buyerReference] (e.g. Leitweg-ID) is
  /// user-supplied export input, never an inferred invoice value.
  Future<String?> exportXRechnung({
    required int rechnungId,
    EInvoiceSaveDialog? saveDialog,
    String? buyerReference,
    EInvoiceService service = const EInvoiceService(),
  }) async {
    final existing = await repository.findById(rechnungId);
    if (existing == null) throw StateError('Rechnung nicht gefunden');
    if (existing.istEntwurfDokument) {
      throw StateError('Entwürfe können nicht als XRechnung exportiert werden');
    }
    final snapshot = await repository.readCommittedEInvoiceSnapshot(rechnungId, buyerReference: buyerReference);
    return service.exportXRechnung(snapshot: snapshot, saveDialog: saveDialog ?? nativeEInvoiceSaveDialog);
  }

  /// Resolves the draft output default from the customer ZUGFeRD preference.
  /// The value preselects only; every format stays available per invoice.
  EInvoiceOutputFormat outputDefault({required bool zugferdAktiv}) {
    return defaultOutputFormat(zugferdAktiv: zugferdAktiv);
  }

  Future<RechnungItem?> findById(int id) {
    return repository.findById(id);
  }

  Future<RechnungItem> stornoRechnung({required int rechnungId, required String grund}) async {
    if (grund.trim().isEmpty) {
      throw StateError('Stornogrund ist Pflicht');
    }
    _requireCorrectionPrerequisite();
    return repository.stornoRechnung(rechnungId: rechnungId, grund: grund.trim());
  }

  Future<RechnungItem> createGutschrift({
    int? vonRechnungId,
    String? datum,
    List<RechnungPositionItem>? positionen,
    String grund = '',
  }) async {
    if (vonRechnungId == null) {
      if (datum == null || positionen == null || positionen.isEmpty) {
        throw ArgumentError('datum und positionen erforderlich für standalone Gutschrift');
      }
      _validateDraftInput(datum: datum, positionen: positionen);
    } else {
      _requireCorrectionPrerequisite();
      final RechnungItem? existing = await repository.findById(vonRechnungId);
      if (existing != null && !kannGutschrift(existing)) {
        throw StateError('Gutschrift ist für dieses Dokument nicht zulässig');
      }
    }
    return repository.createGutschrift(
      vonRechnungId: vonRechnungId,
      datum: datum,
      positionen: positionen,
      grund: grund,
    );
  }

  Future<RechnungItem> createErsatzRechnung({required int vonRechnungId}) async {
    _requireCorrectionPrerequisite();
    final RechnungItem? existing = await repository.findById(vonRechnungId);
    if (existing != null && !kannErsatz(existing)) {
      throw StateError('Ersatzrechnung nur aus stornierter Rechnung möglich');
    }
    return repository.createErsatzRechnung(vonRechnungId: vonRechnungId);
  }

  Future<RechnungItem> konvertiereDokument({required int quelleId, required String zielTyp}) async {
    const allowedTarget = {'rechnung', 'angebot', 'auftrag', 'proforma', 'lieferschein', 'gutschrift', 'storno'};
    if (!allowedTarget.contains(zielTyp)) {
      throw StateError('Unbekannter Dokumenttyp');
    }
    _requireCorrectionPrerequisite();
    final RechnungItem? existing = await repository.findById(quelleId);
    if (existing != null && !konvertierZiele(existing).contains(zielTyp)) {
      throw StateError('${existing.typ} kann nicht in $zielTyp konvertiert werden');
    }
    return repository.konvertiereDokument(quelleId: quelleId, zielTyp: zielTyp);
  }

  void _requireCorrectionPrerequisite() {
    if (!correctionActionsAvailable) {
      throw StateError('Korrekturaktionen sind derzeit nicht verfügbar');
    }
  }
}

void _validateDraftInput({
  required String datum,
  required List<RechnungPositionItem> positionen,
  String eingabemodus = 'netto',
  num? rabattProzent,
  num? rabattBetrag,
}) {
  if (!_isValidIsoDate(datum)) {
    throw ArgumentError.value(datum, 'datum', 'Erwartet ein gültiges ISO-Datum (YYYY-MM-DD).');
  }
  VorschauService.calculate(
    eingabemodus: eingabemodus,
    positionen: positionen,
    rabattProzent: rabattProzent,
    rabattBetrag: rabattBetrag,
  );
}

bool _isValidIsoDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  return parsed.year == int.parse(value.substring(0, 4)) &&
      parsed.month == int.parse(value.substring(5, 7)) &&
      parsed.day == int.parse(value.substring(8, 10));
}
