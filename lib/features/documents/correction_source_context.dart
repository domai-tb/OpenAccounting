/// Source-context preservation for correction and conversion drafts.
///
/// When creating a replacement or converting a document, the target SHALL
/// preserve the source relationship and source context: counterparty
/// identity, one-time customer address, delivery address, input mode,
/// introduction/closing texts, and every position field. The target remains
/// editable as a draft; later edits never rewrite the source. This helper
/// defines no monetary formulas or correction signs — arithmetic comes from
/// the accepted money contract.
class CorrectionSourceContext {
  const CorrectionSourceContext();

  /// Fields copied from source to target draft.
  static const List<String> preservedFields = <String>[
    'kunde_id',
    'lieferant_id',
    'lieferadresse_id',
    'eingabemodus',
    'einleitungstext',
    'schlusstext',
    'kunde_einmal_name',
    'kunde_einmal_firma',
    'kunde_einmal_strasse',
    'kunde_einmal_plz',
    'kunde_einmal_ort',
    'liefer_name',
    'liefer_strasse',
    'liefer_plz',
    'liefer_ort',
  ];

  /// Builds the target draft row from a source row. Copies preserved fields
  /// and positions; assigns draft state and the given link columns.
  static Map<String, Object?> buildTargetDraft({
    required Map<String, Object?> source,
    required String targetTyp,
    required String datum,
    required Map<String, Object?> links,
  }) {
    final Map<String, Object?> draft = <String, Object?>{
      'rechnungsnummer': null,
      'typ': targetTyp,
      'status': 'entwurf',
      'datum': datum,
      'ist_entwurf': 1,
    };
    for (final String field in preservedFields) {
      if (source.containsKey(field)) draft[field] = source[field];
    }
    draft.addAll(links);
    return draft;
  }

  /// Validates replacement eligibility: only a storniert source may produce
  /// a replacement. Returns a German error or null when eligible.
  static String? replacementEligibility(Map<String, Object?> source) {
    if (source['status'] != 'storniert' || source['storno_datum'] == null) {
      return 'Ersatzrechnung nur aus stornierter Rechnung möglich';
    }
    if (source['ersatzrechnung_id'] != null) {
      return 'Ersatzrechnung bereits vorhanden';
    }
    return null;
  }

  /// Allowed conversion targets per source type.
  static const Map<String, Set<String>> allowedConversions = <String, Set<String>>{
    'angebot': {'auftrag', 'proforma', 'rechnung'},
    'auftrag': {'lieferschein', 'rechnung'},
    'lieferschein': {'rechnung'},
    'proforma': {'rechnung'},
  };

  /// Validates a conversion request. Returns a German error or null.
  static String? conversionEligibility(String sourceTyp, String targetTyp) {
    final Set<String>? allowed = allowedConversions[sourceTyp];
    if (allowed == null) return 'Unbekannter Dokumenttyp';
    if (!allowed.contains(targetTyp)) return '$sourceTyp kann nicht in $targetTyp konvertiert werden';
    return null;
  }

  /// Copies position rows for the target draft (all position fields kept).
  static List<Map<String, Object?>> copyPositions(List<Map<String, Object?>> sourcePositions, int targetId) {
    return <Map<String, Object?>>[
      for (final Map<String, Object?> row in sourcePositions)
        <String, Object?>{
          'rechnung_id': targetId,
          'artikel_id': row['artikel_id'],
          'bezeichnung': row['bezeichnung'],
          'menge': row['menge']?.toString(),
          'einzelpreis': row['einzelpreis']?.toString(),
          'gesamt': row['gesamt']?.toString(),
          'ust_satz': row['ust_satz']?.toString(),
          'position': row['position'],
          'rabatt_prozent': row['rabatt_prozent']?.toString() ?? '0.00',
        },
    ];
  }
}
