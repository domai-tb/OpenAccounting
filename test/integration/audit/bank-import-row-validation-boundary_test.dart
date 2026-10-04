// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/bank_import_failure_payload.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';

const int _kontoId = 1;

Future<AppDatabase> _openConfiguredDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
    _kontoId,
    'Girokonto',
    'DE44500606000000000000',
    'EUR',
  ]);
  return db;
}

BankTemplate _sparkasseTemplate() {
  return BankTemplate.predefined.firstWhere((BankTemplate template) => template.typ == 'sparkasse');
}

Future<int> _transactionCount(AppDatabase db) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT COUNT(*) AS count FROM bank_transaktionen',
    const <Object?>[],
  );
  return (rows.single['count']! as num).toInt();
}

Future<List<Map<String, Object?>>> _history(AppDatabase db) {
  return db.executor.runSelect('SELECT * FROM bank_imports ORDER BY id', const <Object?>[]);
}

String _dateFixtureCsv() {
  return 'Datum;Betrag;Verwendungszweck;Partner\n'
      '15.03.2026;10,00;Valid CSV;A\n'
      'not-a-date;20,00;Bad CSV date;B\n'
      ';30,00;Empty CSV date;C\n';
}

String _amountFixtureCsv() {
  return 'Datum;Betrag;Verwendungszweck;Partner\n'
      '15.03.2026;10,00;Valid CSV;A\n'
      '16.03.2026;not-a-number;Bad CSV amount;B\n'
      '17.03.2026;;Empty CSV amount;C\n';
}

String _dateFixtureCamt() {
  return '''
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkToCstmrStmt><Stmt>
    <Ntry><Amt Ccy="EUR">10.00</Amt><BookgDt><Dt>2026-03-15</Dt></BookgDt><Ustrd>Valid CAMT</Ustrd></Ntry>
    <Ntry><Amt Ccy="EUR">20.00</Amt><BookgDt><Dt></Dt></BookgDt><Ustrd>Empty CAMT date</Ustrd></Ntry>
    <Ntry><Amt Ccy="EUR">30.00</Amt><BookgDt><Dt>not-a-date</Dt></BookgDt><Ustrd>Bad CAMT date</Ustrd></Ntry>
  </Stmt></BkToCstmrStmt>
</Document>''';
}

String _amountFixtureCamt() {
  return '''
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkToCstmrStmt><Stmt>
    <Ntry><Amt Ccy="EUR">10.00</Amt><BookgDt><Dt>2026-03-15</Dt></BookgDt><Ustrd>Valid CAMT</Ustrd></Ntry>
    <Ntry><Amt Ccy="EUR">bad</Amt><BookgDt><Dt>2026-03-16</Dt></BookgDt><Ustrd>Bad CAMT amount</Ustrd></Ntry>
    <Ntry><Amt Ccy="EUR"></Amt><BookgDt><Dt>2026-03-17</Dt></BookgDt><Ustrd>Empty CAMT amount</Ustrd></Ntry>
  </Stmt></BkToCstmrStmt>
</Document>''';
}

String _selfClosingCellFixtureCamt() {
  return '''
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkToCstmrStmt><Stmt>
    <Ntry><Amt Ccy="EUR">10.00</Amt><BookgDt><Dt>2026-03-15</Dt></BookgDt><Ustrd>Valid CAMT</Ustrd></Ntry>
    <Ntry><Amt Ccy="EUR"/><BookgDt><Dt>2026-03-16</Dt></BookgDt><Ustrd>Self closing CAMT amount</Ustrd></Ntry>
    <Ntry><Amt Ccy="EUR">30.00</Amt><BookgDt><Dt/></BookgDt><Ustrd>Self closing CAMT date</Ustrd></Ntry>
  </Stmt></BkToCstmrStmt>
</Document>''';
}

Future<ImportResult> _importCsv(BankImportService service, String csv, BankTemplate template) async {
  final List<RawTx> rows = service.parseCsv(csv: csv, template: template, locale: 'de_DE');
  return service.importTransactions(kontoId: _kontoId, rawTxs: rows, template: template, locale: 'de_DE');
}

Future<ImportResult> _importCamt(BankImportService service, String xml) async {
  final List<RawTx> rows = service.parseCamtXml(xml, locale: 'de_DE');
  return service.importTransactions(kontoId: _kontoId, rawTxs: rows, locale: 'de_DE');
}

void main() {
  test('test_bank_import_row_validation_mixed_malformed_dates', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();

    final ImportResult csvResult = await _importCsv(service, _dateFixtureCsv(), template);
    final ImportResult camtResult = await _importCamt(service, _dateFixtureCamt());
    for (final ({ImportResult result, List<int> sourceRows}) fixture in <({ImportResult result, List<int> sourceRows})>[
      (result: csvResult, sourceRows: <int>[3, 4]),
      (result: camtResult, sourceRows: <int>[2, 3]),
    ]) {
      final ImportResult result = fixture.result;
      expect(result.imported, 1);
      expect(result.failedRows, hasLength(2));
      expect(result.failedRows.every((ImportRowFailure failure) => failure.error.contains('Datum ungültig')), isTrue);
      expect(result.failedRows.map((ImportRowFailure failure) => failure.rowNumber), <int>[2, 3]);
      expect(result.failedRows.map((ImportRowFailure failure) => failure.sourceRowNumber), fixture.sourceRows);
      for (final ImportRowFailure failure in result.failedRows) {
        final Map<String, Object?> json = failure.toJson();
        expect(json['source_row'], isNotNull);
        expect(json['raw_datum'], isA<String>());
        expect(json['raw_betrag'], isA<String>());
        expect(json['parsed_datum'], isNull);
      }
    }
    expect(await _transactionCount(db), 2, reason: 'Each fixture has exactly one valid row.');
  });

  test('test_bank_import_row_validation_mixed_malformed_amounts', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();

    final ImportResult csvResult = await _importCsv(service, _amountFixtureCsv(), template);
    final ImportResult camtResult = await _importCamt(service, _amountFixtureCamt());
    for (final ImportResult result in <ImportResult>[csvResult, camtResult]) {
      expect(result.imported, 1);
      expect(result.failedRows, hasLength(2));
      expect(result.failedRows.every((ImportRowFailure failure) => failure.error.contains('Betrag ungültig')), isTrue);
      expect(result.failedRows.map((ImportRowFailure failure) => failure.transaction.rawBetrag), isNotEmpty);
      expect(result.failedRows.any((ImportRowFailure failure) => failure.transaction.rawBetrag == ''), isTrue);
    }
    expect(await _transactionCount(db), 2, reason: 'Each fixture has exactly one valid row.');
  });

  test('test_bank_import_row_validation_self_closing_camt_cells_are_empty_row_failures', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);

    final ImportResult result = await _importCamt(service, _selfClosingCellFixtureCamt());

    expect(result.imported, 1);
    expect(result.failed, 2);
    expect(result.status, 'teilweise');
    expect(result.failedRows, hasLength(2));
    expect(result.failedRows[0].sourceRowNumber, 2);
    expect(result.failedRows[0].transaction.rawBetrag, '');
    expect(result.failedRows[0].diagnostics, <String>['Betrag ungültig']);
    expect(result.failedRows[1].sourceRowNumber, 3);
    expect(result.failedRows[1].transaction.rawDatum, '');
    expect(result.failedRows[1].diagnostics, <String>['Datum ungültig']);
    expect(await _transactionCount(db), 1);
  });

  test('test_bank_import_row_validation_history_status_counts_and_diagnostics', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();
    const String partialCsv =
        'Datum;Betrag;Verwendungszweck;Partner\n'
        '15.03.2026;10,00;Valid;A\n'
        ';20,00;Date only;B\n'
        ';;Both empty;C\n';

    final ImportResult partial = await _importCsv(service, partialCsv, template);
    expect(partial.imported, 1);
    expect(partial.failed, 2);
    expect(partial.status, 'teilweise');
    final List<Map<String, Object?>> partialHistory = await _history(db);
    final Map<String, Object?> partialRow = partialHistory.last;
    expect(partialRow['anzahl_transaktionen'], 1);
    expect(partialRow['anzahl_importiert'], 1);
    expect(partialRow['anzahl_fehlgeschlagen'], 2);
    expect(partialRow['duplikate'], 0);
    expect(partialRow['status'], 'teilweise');
    final Map<String, Object?> envelope = BankImportFailurePayload.decodeValidated(
      partialRow['fehler_details']! as String,
    );
    expect(envelope['kind'], 'rows');
    final List<dynamic> partialDetails = envelope['rows']! as List<dynamic>;
    expect(partialDetails, hasLength(2));
    expect(partialDetails.every((dynamic item) => item is Map<String, dynamic>), isTrue);
    expect(partialDetails.map((dynamic item) => (item as Map<String, dynamic>)['source_row']), <Object?>[3, 4]);
    final Map<String, dynamic> dual = partialDetails.last as Map<String, dynamic>;
    expect(dual['diagnostic_codes'], <String>['invalid_date', 'invalid_amount']);
    expect(dual['datum'], isNull);
    expect(dual['raw_datum'], '');
    expect(dual['raw_betrag'], '');

    const String allFailedCsv =
        'Datum;Betrag;Verwendungszweck;Partner\n'
        ';bad;Failed one;A\n'
        'not-a-date;;Failed two;B\n';
    final ImportResult allFailed = await _importCsv(service, allFailedCsv, template);
    expect(allFailed.imported, 0);
    expect(allFailed.failed, 2);
    expect(allFailed.status, 'fehlgeschlagen');
    final Map<String, Object?> allFailedRow = (await _history(db)).last;
    expect(allFailedRow['anzahl_transaktionen'], 0);
    expect(allFailedRow['anzahl_importiert'], 0);
    expect(allFailedRow['anzahl_fehlgeschlagen'], 2);
    expect(allFailedRow['status'], 'fehlgeschlagen');
  });

  test('test_bank_import_row_validation_corrected_retry_deduplicates_persisted_rows', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();
    final List<RawTx> firstRows = service.parseCsv(
      csv:
          'Datum;Betrag;Verwendungszweck;Partner\n'
          '15.03.2026;10,00;Already valid;A\n'
          'not-a-date;20,00;Correct me;B\n',
      template: template,
      locale: 'de_DE',
    );
    final ImportResult first = await service.importTransactions(
      kontoId: _kontoId,
      rawTxs: firstRows,
      template: template,
      locale: 'de_DE',
    );
    expect(first.imported, 1);
    expect(first.failedRows, hasLength(1));
    final RawTx corrected = first.failedRows.single.transaction.copyWith(datum: DateTime(2026, 3, 16));

    final ImportResult retry = await service.importTransactions(
      kontoId: _kontoId,
      rawTxs: <RawTx>[firstRows.first, corrected],
      template: template,
      locale: 'de_DE',
    );
    expect(retry.imported, 1);
    expect(retry.duplicatesSkipped, 1);
    expect(await _transactionCount(db), 2);
    final List<Map<String, Object?>> persisted = await db.executor.runSelect(
      'SELECT dedupe_hash, verwendungszweck FROM bank_transaktionen ORDER BY id',
      const <Object?>[],
    );
    expect(persisted.map((Map<String, Object?> row) => row['dedupe_hash']).toSet(), hasLength(2));
    expect(persisted.map((Map<String, Object?> row) => row['verwendungszweck']), contains('Correct me'));
  });

  test('test_bank_import_row_validation_malformed_structure_is_batch_rejection', () async {
    final AppDatabase db = await _openConfiguredDatabase();
    addTearDown(db.close);
    final BankImportService service = BankImportService(db.executor);
    final BankTemplate template = _sparkasseTemplate();
    const String validXmlPrefix =
        '<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02"><BkToCstmrStmt><Stmt>';
    const String validXmlSuffix = '</Stmt></BkToCstmrStmt></Document>';
    const String validNtry = '<Ntry><Amt>10.00</Amt><BookgDt><Dt>2026-03-15</Dt></BookgDt></Ntry>';
    final List<void Function()> parserCases = <void Function()>[
      () => service.parseCsv(csv: '', template: template, locale: 'de_DE'),
      () => service.parseCamtXml('', locale: 'de_DE'),
      () => service.parseCsv(csv: '15.03.2026;10,00;No header;A\n', template: template, locale: 'de_DE'),
      () => service.parseCsv(csv: 'Foo;Bar\n1;2\n', template: template, locale: 'de_DE'),
      () => service.parseCsv(
        csv: 'Datum;Betrag;Verwendungszweck;Partner\n"15.03.2026;10,00;Broken;A\n',
        template: template,
        locale: 'de_DE',
      ),
      () => service.parseCamtXml(
        '<Document><BkToCstmrStmt><Ntry><Amt>10.00</Amt></Ntry></BkToCstmrStmt></Document>',
        locale: 'de_DE',
      ),
      () => service.parseCamtXml(
        '$validXmlPrefix<Ntry><BookgDt><Dt>2026-03-15</Dt></BookgDt></Ntry>$validXmlSuffix',
        locale: 'de_DE',
      ),
      () => service.parseCamtXml(
        '$validXmlPrefix<Ntry><Amt>10.00</Amt><BookgDt><Dt>2026-03-15</ValDt></BookgDt></Ntry>$validXmlSuffix',
        locale: 'de_DE',
      ),
      () => service.parseCamtXml('$validXmlPrefix$validNtry', locale: 'de_DE'),
      () => service.parseCamtXml('<Document><BkToCstmrStmt><Stmt><Ntry><Amt>10.00</Amt>', locale: 'de_DE'),
    ];
    for (final void Function() parserCase in parserCases) {
      expect(parserCase, throwsA(isA<BankImportException>()));
    }
    final RawTx valid = RawTx(datum: DateTime(2026, 3, 15), betrag: '10.00', verwendungszweck: 'Valid', partner: 'A');
    await expectLater(
      service.importTransactions(kontoId: 0, rawTxs: <RawTx>[valid], locale: 'de_DE'),
      throwsA(isA<BankImportException>()),
    );
    await expectLater(
      service.importTransactions(kontoId: _kontoId, rawTxs: const <RawTx>[], locale: 'de_DE'),
      throwsA(isA<BankImportException>()),
    );
    expect(await _transactionCount(db), 0);
  });
}
