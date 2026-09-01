import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';

void main() {
  group('Bank Import CAMT XML — parses correctly', () {
    late AppDatabase db;
    late BankImportService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert('INSERT INTO konten (id, name, iban, waehrung) VALUES (?, ?, ?, ?)', <Object?>[
        1,
        'Giro Sparkasse',
        'DE44500606000000000000',
        'EUR',
      ]);
      // bank_templates seeded via SeedData, fallback map covers offline case
      service = BankImportService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('parses single Ntry CAMT.053 minimal sample', () {
      const String xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkToCstmrStmt>
    <Stmt>
      <Ntry>
        <Amt Ccy="EUR">123.45</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <BookgDt><Dt>2025-08-15</Dt></BookgDt>
        <NtryDtls>
          <TxDtls>
            <RmtInf><Ustrd>Rechnung 123</Ustrd></RmtInf>
          </TxDtls>
        </NtryDtls>
      </Ntry>
    </Stmt>
  </BkToCstmrStmt>
</Document>
''';
      final List<RawTx> txs = service.parseCamtXml(xml);

      expect(txs, hasLength(1));
      expect(txs.first.datum, DateTime(2025, 8, 15));
      expect(txs.first.betrag, '123.45');
      expect(txs.first.verwendungszweck, contains('Rechnung 123'));
      // partner/gegenkonto may be empty for minimal sample
      expect(txs.first.partner, isA<String>());
      expect(txs.first.betrag, matches(RegExp(r'^-?\d+\.\d{2}$')));
    });

    test('parses single Ntry with partner Nm and gegenkonto IBAN', () {
      const String xml = '''
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  <BkToCstmrStmt>
    <Stmt>
      <Ntry>
        <Amt Ccy="EUR">250.00</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <BookgDt><Dt>2025-08-15</Dt></BookgDt>
        <NtryDtls>
          <TxDtls>
            <RltdPties><Dbtr><Nm>Max Mustermann</Nm></Dbtr></RltdPties>
            <RltdAcct><Id><IBAN>DE44500606000000000001</IBAN></Id></RltdAcct>
            <RmtInf><Ustrd>Rechnung 123</Ustrd></RmtInf>
          </TxDtls>
        </NtryDtls>
      </Ntry>
    </Stmt>
  </BkToCstmrStmt>
</Document>
''';
      final List<RawTx> txs = service.parseCamtXml(xml);

      expect(txs, hasLength(1));
      expect(txs.first.datum, DateTime(2025, 8, 15));
      expect(txs.first.betrag, '250.00');
      expect(txs.first.verwendungszweck, 'Rechnung 123');
      expect(txs.first.partner, 'Max Mustermann');
      expect(txs.first.gegenkonto, 'DE44500606000000000001');
    });

    test('parses multiple Ntry entries with different betrag and datum', () {
      const String xml = '''
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkToCstmrStmt>
    <Stmt>
      <Ntry>
        <Amt Ccy="EUR">100.00</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <BookgDt><Dt>2025-08-15</Dt></BookgDt>
        <NtryDtls><TxDtls><RmtInf><Ustrd>Rechnung 100</Ustrd></RmtInf></TxDtls></NtryDtls>
      </Ntry>
      <Ntry>
        <Amt Ccy="EUR">50.50</Amt>
        <CdtDbtInd>DBIT</CdtDbtInd>
        <BookgDt><Dt>2025-08-16</Dt></BookgDt>
        <NtryDtls><TxDtls><RmtInf><Ustrd>Miete August</Ustrd></RmtInf></TxDtls></NtryDtls>
      </Ntry>
    </Stmt>
  </BkToCstmrStmt>
</Document>
''';
      final List<RawTx> txs = service.parseCamtXml(xml);

      expect(txs, hasLength(2));
      expect(txs[0].datum, DateTime(2025, 8, 15));
      expect(txs[0].betrag, '100.00');
      expect(txs[0].verwendungszweck, 'Rechnung 100');
      expect(txs[1].datum, DateTime(2025, 8, 16));
      // DBIT => negative
      expect(txs[1].betrag, '-50.50');
      expect(txs[1].verwendungszweck, 'Miete August');
    });

    test('handles comma amounts and CdtDbtInd DBIT/CRDT', () {
      const String xmlComma = '''
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.02">
  <BkToCstmrStmt>
    <Stmt>
      <Ntry>
        <Amt Ccy="EUR">123,45</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <BookgDt><Dt>2025-08-15</Dt></BookgDt>
        <NtryDtls><TxDtls><RmtInf><Ustrd>Comma CRDT</Ustrd></RmtInf></TxDtls></NtryDtls>
      </Ntry>
      <Ntry>
        <Amt Ccy="EUR">123,45</Amt>
        <CdtDbtInd>DBIT</CdtDbtInd>
        <BookgDt><Dt>2025-08-16</Dt></BookgDt>
        <NtryDtls><TxDtls><RmtInf><Ustrd>Comma DBIT</Ustrd></RmtInf></TxDtls></NtryDtls>
      </Ntry>
    </Stmt>
  </BkToCstmrStmt>
</Document>
''';
      final List<RawTx> txs = service.parseCamtXml(xmlComma);

      expect(txs, hasLength(2));
      expect(txs[0].betrag, '123.45');
      expect(txs[1].betrag, '-123.45');
    });

    test('non-CAMT XML throws unsupported', () {
      const String xml = '<root><data>hello</data></root>';
      expect(
        () => service.parseCamtXml(xml),
        throwsA(predicate<Object>((e) => e is BankImportException && e.message.toLowerCase().contains('unsupported'))),
      );
    });

    test('non-CAMT Document without CAMT markers throws unsupported', () {
      const String xml = '<Document><Foo>bar</Foo></Document>';
      expect(
        () => service.parseCamtXml(xml),
        throwsA(predicate<Object>((e) => e is BankImportException && e.message.toLowerCase().contains('unsupported'))),
      );
    });

    test('invalid XML throws BankImportException', () {
      const String xml = 'not xml at all <<<';
      expect(() => service.parseCamtXml(xml), throwsA(isA<BankImportException>()));
    });

    test('malformed CAMT with unclosed Ntry throws invalid', () {
      const String xml = '<Document><BkToCstmrStmt><Stmt><Ntry><Amt>123.45</Amt>';
      expect(() => service.parseCamtXml(xml), throwsA(isA<BankImportException>()));
    });

    test('empty XML throws', () {
      expect(() => service.parseCamtXml(''), throwsA(isA<BankImportException>()));
      expect(() => service.parseCamtXml('   '), throwsA(isA<BankImportException>()));
    });
  });
}
