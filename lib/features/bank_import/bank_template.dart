import 'dart:convert';

/// BankTemplate — predefined per spec §Bank Templates + DB fallback.
/// ponytail: in-code map is source of truth; DB rows merged if present.
class BankTemplate {
  const BankTemplate({
    required this.id,
    required this.name,
    required this.typ,
    required this.delimiter,
    required this.encoding,
    required this.dateFormat,
    required this.fieldMapping,
  });

  final int id;
  final String name;
  final String typ;
  final String delimiter;
  final String encoding;
  final String dateFormat;
  final Map<String, String> fieldMapping;

  /// Parse from DB row — bank_templates(konfiguration JSON).
  factory BankTemplate.fromRow(Map<String, Object?> row) {
    final int id = (row['id'] as num).toInt();
    final String name = row['name'] as String? ?? 'Unbekannt';
    final String typ = row['typ'] as String? ?? name.toLowerCase();
    final String rawKonfig = row['konfiguration'] as String? ?? '{}';
    Map<String, dynamic> cfg = <String, dynamic>{};
    try {
      final dynamic decoded = jsonDecode(rawKonfig);
      if (decoded is Map<String, dynamic>) cfg = decoded;
    } catch (_) {}
    final String delimiter = cfg['delimiter'] as String? ?? ';';
    final String encoding = cfg['encoding'] as String? ?? 'utf-8';
    final String dateFormat = cfg['dateFormat'] as String? ?? cfg['date_format'] as String? ?? 'dd.MM.yyyy';
    Map<String, String> mapping = <String, String>{};
    final dynamic mapRaw = cfg['fieldMapping'] ?? cfg['field_mapping'] ?? cfg['mapping'];
    if (mapRaw is Map) {
      for (final entry in mapRaw.entries) {
        mapping[entry.key.toString()] = entry.value.toString();
      }
    }
    // Fallback — generic header names if mapping empty.
    if (mapping.isEmpty) {
      mapping = <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      };
    }
    return BankTemplate(
      id: id,
      name: name,
      typ: typ,
      delimiter: delimiter,
      encoding: encoding,
      dateFormat: dateFormat,
      fieldMapping: mapping,
    );
  }

  Map<String, Object?> toKonfiguration() => <String, Object?>{
    'delimiter': delimiter,
    'encoding': encoding,
    'dateFormat': dateFormat,
    'fieldMapping': fieldMapping,
  };

  /// 7 predefined CSV templates per spec: Sparkasse, PayPal, N26, Vivid, ING, DKB, Commerzbank.
  /// ponytail: delimiter + dateFormat differ, mapping alias covers generic test header.
  static const List<BankTemplate> predefined = <BankTemplate>[
    BankTemplate(
      id: 1,
      name: 'Sparkasse',
      typ: 'sparkasse',
      delimiter: ';',
      encoding: 'iso-8859-1',
      dateFormat: 'dd.MM.yyyy',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
    BankTemplate(
      id: 2,
      name: 'PayPal',
      typ: 'paypal',
      delimiter: ',',
      encoding: 'utf-8',
      dateFormat: 'yyyy-MM-dd',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
    BankTemplate(
      id: 3,
      name: 'N26',
      typ: 'n26',
      delimiter: ',',
      encoding: 'utf-8',
      dateFormat: 'yyyy-MM-dd',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
    BankTemplate(
      id: 4,
      name: 'Vivid',
      typ: 'vivid',
      delimiter: ';',
      encoding: 'utf-8',
      dateFormat: 'dd.MM.yyyy',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
    BankTemplate(
      id: 5,
      name: 'ING',
      typ: 'ing',
      delimiter: ';',
      encoding: 'utf-8',
      dateFormat: 'dd.MM.yyyy',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
    BankTemplate(
      id: 6,
      name: 'DKB',
      typ: 'dkb',
      delimiter: ';',
      encoding: 'utf-8',
      dateFormat: 'dd.MM.yyyy',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
    BankTemplate(
      id: 7,
      name: 'Commerzbank',
      typ: 'commerzbank',
      delimiter: ';',
      encoding: 'utf-8',
      dateFormat: 'dd.MM.yyyy',
      fieldMapping: <String, String>{
        'datum': 'Datum',
        'betrag': 'Betrag',
        'verwendungszweck': 'Verwendungszweck',
        'partner': 'Partner',
        'gegenkonto': 'Gegenkonto',
      },
    ),
  ];

  /// Lookup by typ case-insensitive.
  static BankTemplate? byTyp(String typ) {
    final String lower = typ.toLowerCase();
    for (final t in predefined) {
      if (t.typ.toLowerCase() == lower) return t;
    }
    return null;
  }
}
