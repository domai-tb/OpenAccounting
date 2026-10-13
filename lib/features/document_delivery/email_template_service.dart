import 'package:drift/drift.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';

// Profile-local plain-text subject/body templates per first-release document
// type. Rendering expands only the finite allowlist from typed source values;
// unknown or unavailable tokens and header line breaks block preparation.
// Per-send overrides never mutate the stored template.

class DeliveryTemplateValues {
  const DeliveryTemplateValues({required this.subject, required this.body});

  final String subject;
  final String body;
}

class DeliveryTemplateContext {
  const DeliveryTemplateContext({required this.values, this.dueDate, this.companyName, this.locale = 'de_DE'});

  /// Typed source values; null means "unavailable for this document".
  final DeliveryTemplateValues values;
  final String? dueDate;
  final String? companyName;
  final String locale;
}

class RenderedTemplate {
  const RenderedTemplate({required this.subject, required this.body});

  final String subject;
  final String body;
}

/// Pure renderer: expands `{dokumentnummer}`, `{betrag}`, `{faelligkeit}`,
/// `{firma}` from typed values. `{betrag}` uses the persisted canonical total
/// with shared locale-aware money formatting.
class EmailTemplateRenderer {
  const EmailTemplateRenderer();

  RenderedTemplate render({
    required DeliveryTemplateValues template,
    required String dokumentnummer,
    required num betrag,
    String? faelligkeit,
    String? firma,
    String locale = 'de_DE',
  }) {
    requireHeaderLine(template.subject, field: 'Betreff');
    final Map<String, String?> assignable = <String, String?>{
      EmailPlaceholders.dokumentnummer: dokumentnummer,
      EmailPlaceholders.betrag: formatMoney(betrag, locale: locale),
      EmailPlaceholders.faelligkeit: faelligkeit,
      EmailPlaceholders.firma: firma,
    };
    return RenderedTemplate(
      subject: _expand(template.subject, assignable, field: 'Betreff'),
      body: _expand(template.body, assignable, field: 'Nachricht'),
    );
  }

  String _expand(String raw, Map<String, String?> assignable, {required String field}) {
    final Set<String> tokens = EmailPlaceholders.tokenPattern.allMatches(raw).map((Match m) => m.group(0)!).toSet();
    for (final String token in tokens) {
      if (!EmailPlaceholders.allowed.contains(token)) {
        throw DocumentDeliveryException('Unbekannter Platzhalter $token in $field', code: 'platzhalter_unbekannt');
      }
      if (assignable[token] == null || assignable[token]!.trim().isEmpty) {
        throw DocumentDeliveryException(
          'Platzhalter $token ist für dieses Dokument nicht verfügbar',
          code: 'platzhalter_fehlt',
        );
      }
    }
    String result = raw;
    for (final MapEntry<String, String?> entry in assignable.entries) {
      if (entry.value != null) result = result.replaceAll(entry.key, entry.value!);
    }
    return result;
  }
}

class EmailTemplateRepository {
  EmailTemplateRepository(this.executor);

  final QueryExecutor executor;
  Future<void>? _ready;

  Future<void> ensureSchema() => _ready ??= _ensure();

  Future<void> _ensure() async {
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS dokument_email_templates (
  typ TEXT PRIMARY KEY,
  betreff TEXT NOT NULL,
  text TEXT NOT NULL,
  aktualisiert_am TEXT NOT NULL
)''');
  }

  static const Map<String, DeliveryTemplateValues> defaults = <String, DeliveryTemplateValues>{
    DocumentEmailType.rechnung: DeliveryTemplateValues(
      subject: 'Ihre Rechnung {dokumentnummer} über {betrag}',
      body:
          'Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie unsere Rechnung {dokumentnummer} über {betrag}, '
          'fällig am {faelligkeit}.\n\nMit freundlichen Grüßen\n{firma}',
    ),
    DocumentEmailType.angebot: DeliveryTemplateValues(
      subject: 'Ihr Angebot {dokumentnummer} über {betrag}',
      body:
          'Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie unser Angebot {dokumentnummer} über {betrag}.\n\n'
          'Mit freundlichen Grüßen\n{firma}',
    ),
    DocumentEmailType.auftrag: DeliveryTemplateValues(
      subject: 'Ihre Auftragsbestätigung {dokumentnummer} über {betrag}',
      body:
          'Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie Ihre Auftragsbestätigung {dokumentnummer} über '
          '{betrag}.\n\nMit freundlichen Grüßen\n{firma}',
    ),
    DocumentEmailType.proforma: DeliveryTemplateValues(
      subject: 'Ihre Proforma-Rechnung {dokumentnummer} über {betrag}',
      body:
          'Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie unsere Proforma-Rechnung {dokumentnummer} über '
          '{betrag}.\n\nMit freundlichen Grüßen\n{firma}',
    ),
  };

  /// Deferred types expose no template action in the first release.
  void requireEditable(String typ) {
    if (DocumentEmailType.isDeferred(typ)) {
      throw const DocumentDeliveryException(
        'Für diesen Dokumenttyp gibt es noch keine Vorlage',
        code: 'typ_zurueckgestellt',
      );
    }
    if (!DocumentEmailType.isSupported(typ)) {
      throw const DocumentDeliveryException('Unbekannter Dokumenttyp', code: 'typ_unbekannt');
    }
  }

  Future<DeliveryTemplateValues> loadOrSeed(String typ) async {
    requireEditable(typ);
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT betreff, text FROM dokument_email_templates WHERE typ = ?',
      <Object?>[typ],
    );
    if (rows.isNotEmpty) {
      return DeliveryTemplateValues(subject: '${rows.single['betreff']}', body: '${rows.single['text']}');
    }
    final DeliveryTemplateValues seed = defaults[typ]!;
    await executor.runInsert(
      'INSERT INTO dokument_email_templates (typ, betreff, text, aktualisiert_am) VALUES (?, ?, ?, ?)',
      <Object?>[typ, seed.subject, seed.body, DateTime.now().toUtc().toIso8601String()],
    );
    return seed;
  }

  Future<DeliveryTemplateValues> save(String typ, DeliveryTemplateValues values) async {
    requireEditable(typ);
    await ensureSchema();
    if (values.subject.trim().isEmpty || values.body.trim().isEmpty) {
      throw const DocumentDeliveryException('Betreff und Nachricht sind Pflicht', code: 'vorlage_leer');
    }
    requireHeaderLine(values.subject, field: 'Betreff');
    _validateKnownTokens(values.subject, field: 'Betreff');
    _validateKnownTokens(values.body, field: 'Nachricht');
    await executor.runCustom(
      'INSERT INTO dokument_email_templates (typ, betreff, text, aktualisiert_am) VALUES (?, ?, ?, ?) '
      'ON CONFLICT(typ) DO UPDATE SET betreff = excluded.betreff, text = excluded.text, '
      'aktualisiert_am = excluded.aktualisiert_am',
      <Object?>[typ, values.subject, values.body, DateTime.now().toUtc().toIso8601String()],
    );
    return values;
  }

  void _validateKnownTokens(String raw, {required String field}) {
    final Set<String> tokens = EmailPlaceholders.tokenPattern.allMatches(raw).map((Match m) => m.group(0)!).toSet();
    for (final String token in tokens) {
      if (!EmailPlaceholders.allowed.contains(token)) {
        throw DocumentDeliveryException('Unbekannter Platzhalter $token in $field', code: 'platzhalter_unbekannt');
      }
    }
  }
}
