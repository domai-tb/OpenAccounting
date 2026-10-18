import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

/// Editable row of the shared outgoing-invoice editor.
class EditorPosition {
  const EditorPosition({
    required this.bezeichnung,
    required this.menge,
    required this.einzelpreis,
    required this.ustSatz,
    this.artikelId,
    this.rabattProzent,
    this.stableId,
    this.mengeText,
    this.einzelpreisText,
  });

  final String bezeichnung;
  final num menge;
  final num einzelpreis;
  final num ustSatz;
  final int? artikelId;
  final num? rabattProzent;
  final int? stableId;

  /// Raw text stays here while the user corrects an invalid numeric edit.
  final String? mengeText;
  final String? einzelpreisText;

  static num? parseNumericInput(String value) {
    final num? parsed = num.tryParse(value.replaceAll(',', '.'));
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  EditorPosition copyWith({
    String? bezeichnung,
    num? menge,
    num? einzelpreis,
    num? ustSatz,
    int? artikelId,
    num? rabattProzent,
    int? stableId,
    String? mengeText,
    String? einzelpreisText,
  }) {
    return EditorPosition(
      bezeichnung: bezeichnung ?? this.bezeichnung,
      menge: menge ?? this.menge,
      einzelpreis: einzelpreis ?? this.einzelpreis,
      ustSatz: ustSatz ?? this.ustSatz,
      artikelId: artikelId ?? this.artikelId,
      rabattProzent: rabattProzent ?? this.rabattProzent,
      stableId: stableId ?? this.stableId,
      mengeText: mengeText ?? this.mengeText,
      einzelpreisText: einzelpreisText ?? this.einzelpreisText,
    );
  }

  RechnungPositionItem toDomain({required int order}) {
    final num? parsedMenge = parseNumericInput(mengeText ?? '$menge');
    if (parsedMenge == null) {
      throw InvoiceMoneyValidationException(
        code: 'invalidNumber',
        message: 'Menge muss eine gültige Zahl sein',
        lineIndex: order,
        position: order,
        fields: const <String>['menge'],
      );
    }
    final num? parsedEinzelpreis = parseNumericInput(einzelpreisText ?? '$einzelpreis');
    if (parsedEinzelpreis == null) {
      throw InvoiceMoneyValidationException(
        code: 'invalidNumber',
        message: 'Einzelpreis muss eine gültige Zahl sein',
        lineIndex: order,
        position: order,
        fields: const <String>['einzelpreis'],
      );
    }
    return RechnungPositionItem(
      bezeichnung: bezeichnung.trim(),
      menge: parsedMenge,
      einzelpreis: parsedEinzelpreis,
      gesamt: VorschauService.lineTotal(
        quantity: parsedMenge,
        unitPrice: parsedEinzelpreis,
        rabattProzent: rabattProzent,
      ),
      ustSatz: ustSatz,
      artikelId: artikelId,
      position: order,
      rabattProzent: rabattProzent,
    );
  }
}

/// Shared editor state for the create and edit routes.
///
/// Owns header fields, ordered editable rows, field-level validation and
/// the latest authoritative domain preview result. Every mutation that
/// changes the document (add, edit, remove, reorder, mode or discount
/// change) invalidates the prior preview until a new domain result is
/// returned; widgets display only fields copied from that result.
class InvoiceEditorState {
  InvoiceEditorState({
    String? datum,
    this.leistungsdatum,
    this.eingabemodus = 'netto',
    this.rabattProzent,
    this.rabattBetrag,
    this.kundeId,
  }) : datum = datum ?? _todayIso();

  String datum;
  String? leistungsdatum;
  String eingabemodus;
  num? rabattProzent;
  num? rabattBetrag;
  int? kundeId;
  final List<EditorPosition> positionen = <EditorPosition>[];
  int _nextStablePositionId = 0;

  /// Latest authoritative domain preview result, or null when stale/invalid.
  VorschauResult? preview;

  /// True when the displayed preview no longer matches the form values.
  bool previewStale = true;

  /// Field-level validation messages keyed by field name.
  Map<String, String> fieldErrors = const <String, String>{};

  /// Summary-level validation messages.
  List<String> summaryErrors = const <String>[];

  static String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

  int _allocatePositionStableId() => _nextStablePositionId++;

  void addPosition(EditorPosition row) {
    positionen.add(row.copyWith(stableId: _allocatePositionStableId()));
    _invalidate();
  }

  void updatePosition(int index, EditorPosition row) {
    final int stableId = positionen[index].stableId ?? _allocatePositionStableId();
    positionen[index] = row.copyWith(stableId: stableId);
    _invalidate();
  }

  void removePosition(int index) {
    positionen.removeAt(index);
    _invalidate();
  }

  void movePosition(int from, int to) {
    if (from == to) return;
    final EditorPosition row = positionen.removeAt(from);
    positionen.insert(to.clamp(0, positionen.length), row);
    _invalidate();
  }

  void setEingabemodus(String mode) {
    eingabemodus = mode;
    _invalidate();
  }

  void setRabatt({num? prozent, num? betrag}) {
    rabattProzent = prozent;
    rabattBetrag = betrag;
    _invalidate();
  }

  void setKundeId(int? value) {
    kundeId = value;
    final Map<String, String> fields = Map<String, String>.of(fieldErrors)..remove('kundeId');
    fieldErrors = Map<String, String>.unmodifiable(fields);
    if (fields.isEmpty) summaryErrors = const <String>[];
    _invalidate();
  }

  bool validateCustomerRequired() {
    if (kundeId != null) return true;
    fieldErrors = Map<String, String>.unmodifiable(<String, String>{...fieldErrors, 'kundeId': 'customerRequired'});
    summaryErrors = const <String>['customerRequired'];
    return false;
  }

  bool validateDate() {
    final bool valid = _isValidIsoDate(datum);
    final Map<String, String> fields = Map<String, String>.of(fieldErrors)..remove('datum');
    if (!valid) fields['datum'] = 'invalidDate';
    fieldErrors = Map<String, String>.unmodifiable(fields);

    final List<String> summary = summaryErrors.where((String error) => error != 'invalidDate').toList();
    if (!valid) summary.add('invalidDate');
    summaryErrors = List<String>.unmodifiable(summary);
    return valid;
  }

  static bool _isValidIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return parsed.year == int.parse(value.substring(0, 4)) &&
        parsed.month == int.parse(value.substring(5, 7)) &&
        parsed.day == int.parse(value.substring(8, 10));
  }

  void _invalidate() {
    previewStale = true;
  }

  List<RechnungPositionItem> toDomainPositions() {
    return <RechnungPositionItem>[
      for (var index = 0; index < positionen.length; index++) positionen[index].toDomain(order: index),
    ];
  }

  /// Recalculates the authoritative preview via the domain calculator.
  ///
  /// On success the result is stored and marked current; on validation
  /// failure the previous result is cleared/marked stale and localized
  /// field plus summary states identify the rejected input.
  bool recalculate() {
    try {
      preview = VorschauService.calculate(
        eingabemodus: eingabemodus,
        positionen: toDomainPositions(),
        rabattProzent: rabattProzent,
        rabattBetrag: rabattBetrag,
      );
      previewStale = false;
      fieldErrors = const <String, String>{};
      summaryErrors = const <String>[];
      return true;
      // This domain validation type intentionally remains ArgumentError-derived for API compatibility.
      // ignore: avoid_catching_errors
    } on InvoiceMoneyValidationException catch (error) {
      applyValidationError(error);
      return false;
    }
  }

  void applyValidationError(InvoiceMoneyValidationException error) {
    // A failed preview clears the previous result so no stale total is
    // presented as current.
    preview = null;
    previewStale = true;
    final Map<String, String> fields = <String, String>{};
    for (final String field in error.fields) {
      if (error.lineIndex == null) fields[field] = error.code;
      if (error.lineIndex != null) {
        fields['position[${error.lineIndex}].$field'] = error.code;
      }
    }
    if (error.lineIndex != null && error.fields.isEmpty) {
      fields['position[${error.lineIndex}]'] = error.code;
    }
    fieldErrors = Map<String, String>.unmodifiable(fields);
    summaryErrors = List<String>.unmodifiable(<String>[error.code]);
  }

  /// Loads persisted draft values into the editor (reopen flow).
  void loadDraft(RechnungItem draft) {
    datum = draft.datum;
    leistungsdatum = draft.leistungsdatum;
    eingabemodus = draft.eingabemodus;
    rabattProzent = draft.rabattProzent;
    rabattBetrag = draft.rabattBetrag;
    _nextStablePositionId = 0;
    positionen
      ..clear()
      ..addAll(
        draft.positionen.map(
          (p) => EditorPosition(
            bezeichnung: p.bezeichnung,
            menge: p.menge,
            einzelpreis: p.einzelpreis,
            ustSatz: p.ustSatz,
            artikelId: p.artikelId,
            rabattProzent: p.rabattProzent,
            stableId: _allocatePositionStableId(),
          ),
        ),
      );
    _invalidate();
    recalculate();
  }
}
