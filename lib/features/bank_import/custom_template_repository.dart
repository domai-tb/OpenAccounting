import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:openaccounting/features/bank_import/bank_template.dart';

class CustomTemplateException implements Exception {
  const CustomTemplateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Profile-scoped custom CSV templates in `bank_templates` per
/// bank-import-confidence-and-rule-workspace. Custom type identifiers live in
/// the reserved `custom_` namespace, are generated once, and stay stable
/// across edits. Predefined template types are protected from edit/removal.
class CustomTemplateRepository {
  CustomTemplateRepository(this.executor);
  final QueryExecutor executor;

  static const Set<String> allowedDelimiters = <String>{',', ';'};
  static const Set<String> allowedEncodings = <String>{'utf-8', 'iso-8859-1'};
  static const Set<String> allowedDateFormats = <String>{'dd.MM.yyyy', 'yyyy-MM-dd'};
  static const List<String> requiredMappings = <String>['datum', 'betrag', 'verwendungszweck'];

  Future<List<BankTemplate>> listCustom() async {
    final rows = await executor.runSelect(
      r"SELECT id, name, typ, konfiguration FROM bank_templates WHERE typ LIKE 'custom\_%' ESCAPE '\' ORDER BY name",
      const <Object?>[],
    );
    return rows.map(BankTemplate.fromRow).toList(growable: false);
  }

  Future<BankTemplate> create({
    required String name,
    required String delimiter,
    required String encoding,
    required String dateFormat,
    required Map<String, String> fieldMapping,
  }) async {
    _validate(name: name, delimiter: delimiter, encoding: encoding, dateFormat: dateFormat, fieldMapping: fieldMapping);
    await _rejectDuplicateName(name, null);
    final typ = await _generateTyp(name);
    final id = await executor.runInsert(
      'INSERT INTO bank_templates (name, typ, konfiguration) VALUES (?, ?, ?)',
      <Object?>[
        name.trim(),
        typ,
        jsonEncode(<String, Object?>{
          'delimiter': delimiter,
          'encoding': encoding,
          'dateFormat': dateFormat,
          'fieldMapping': fieldMapping,
        }),
      ],
    );
    return _byId(id);
  }

  Future<BankTemplate> update(
    int id, {
    String? name,
    String? delimiter,
    String? encoding,
    String? dateFormat,
    Map<String, String>? fieldMapping,
  }) async {
    final current = await _byId(id);
    if (!current.typ.startsWith('custom_')) {
      throw const CustomTemplateException('Vordefinierte Templates sind geschützt');
    }
    final nextName = (name ?? current.name).trim();
    final nextDelimiter = delimiter ?? current.delimiter;
    final nextEncoding = encoding ?? current.encoding;
    final nextDateFormat = dateFormat ?? current.dateFormat;
    final nextMapping = fieldMapping ?? current.fieldMapping;
    _validate(
      name: nextName,
      delimiter: nextDelimiter,
      encoding: nextEncoding,
      dateFormat: nextDateFormat,
      fieldMapping: nextMapping,
    );
    await _rejectDuplicateName(nextName, id);
    await executor.runUpdate('UPDATE bank_templates SET name = ?, konfiguration = ? WHERE id = ?', <Object?>[
      nextName,
      jsonEncode(<String, Object?>{
        'delimiter': nextDelimiter,
        'encoding': nextEncoding,
        'dateFormat': nextDateFormat,
        'fieldMapping': nextMapping,
      }),
      id,
    ]);
    return _byId(id);
  }

  Future<void> delete(int id) async {
    final current = await _byId(id);
    if (!current.typ.startsWith('custom_')) {
      throw const CustomTemplateException('Vordefinierte Templates sind geschützt');
    }
    await executor.runDelete('DELETE FROM bank_templates WHERE id = ?', <Object?>[id]);
  }

  void _validate({
    required String name,
    required String delimiter,
    required String encoding,
    required String dateFormat,
    required Map<String, String> fieldMapping,
  }) {
    if (name.trim().isEmpty) throw const CustomTemplateException('Name ist Pflicht');
    if (!allowedDelimiters.contains(delimiter)) {
      throw CustomTemplateException('Trennzeichen nicht unterstützt: $delimiter');
    }
    if (!allowedEncodings.contains(encoding)) {
      throw CustomTemplateException('Kodierung nicht unterstützt: $encoding');
    }
    if (!allowedDateFormats.contains(dateFormat)) {
      throw CustomTemplateException('Datumsformat nicht unterstützt: $dateFormat');
    }
    for (final key in requiredMappings) {
      if ((fieldMapping[key] ?? '').trim().isEmpty) {
        throw CustomTemplateException('Feldzuordnung fehlt: $key');
      }
    }
  }

  Future<void> _rejectDuplicateName(String name, int? selfId) async {
    final rows = await executor.runSelect('SELECT id FROM bank_templates WHERE LOWER(name) = LOWER(?)', <Object?>[
      name.trim(),
    ]);
    for (final row in rows) {
      if (selfId == null || (row['id']! as num).toInt() != selfId) {
        throw const CustomTemplateException('Name bereits vergeben');
      }
    }
  }

  Future<String> _generateTyp(String name) async {
    final slug = name.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    final base = 'custom_${slug.isEmpty ? 'template' : slug}';
    String candidate = base;
    var suffix = 2;
    while (await _typExists(candidate)) {
      candidate = '${base}_$suffix';
      suffix++;
    }
    return candidate;
  }

  Future<bool> _typExists(String typ) async {
    final rows = await executor.runSelect('SELECT id FROM bank_templates WHERE LOWER(typ) = LOWER(?)', <Object?>[typ]);
    return rows.isNotEmpty;
  }

  Future<BankTemplate> _byId(int id) async {
    final rows = await executor.runSelect(
      'SELECT id, name, typ, konfiguration FROM bank_templates WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) throw const CustomTemplateException('Template nicht gefunden');
    return BankTemplate.fromRow(rows.single);
  }
}
