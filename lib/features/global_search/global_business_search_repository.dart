import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/global_search/global_search_entity.dart';

/// Reads only the fields surfaced by the global search palette.
class GlobalBusinessSearchRepository {
  const GlobalBusinessSearchRepository(this.executor);

  final QueryExecutor executor;

  static const int resultLimit = 10;

  Future<List<GlobalBusinessSearchResult>> searchInvoices(String query) async {
    final String needle = query.trim();
    final String pattern = '%$needle%';
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT invoice.id, invoice.rechnungsnummer, invoice.datum, invoice.status, invoice.brutto_betrag, '
      "COALESCE(NULLIF(customer.firma, ''), customer.name, NULLIF(supplier.firma, ''), supplier.name, '') "
      'AS party_name FROM rechnungen AS invoice '
      'LEFT JOIN kunden AS customer ON customer.id = invoice.kunde_id '
      'LEFT JOIN lieferanten AS supplier ON supplier.id = invoice.lieferant_id '
      "WHERE COALESCE(invoice.rechnungsnummer, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(customer.name, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(customer.firma, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(supplier.name, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(supplier.firma, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(invoice.datum, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(invoice.status, '') LIKE ? COLLATE NOCASE "
      'OR CAST(COALESCE(invoice.brutto_betrag, 0) AS TEXT) LIKE ? COLLATE NOCASE '
      'ORDER BY CASE WHEN invoice.rechnungsnummer = ? COLLATE NOCASE THEN 0 ELSE 1 END, '
      'invoice.datum DESC, invoice.id DESC LIMIT ?',
      <Object?>[pattern, pattern, pattern, pattern, pattern, pattern, pattern, pattern, needle, resultLimit],
    );
    return rows.map((Map<String, Object?> row) => _invoiceResult(row, needle)).toList(growable: false);
  }

  Future<List<GlobalBusinessSearchResult>> searchContacts(String query) async {
    final String needle = query.trim();
    final String pattern = '%$needle%';
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, kundennummer, name, firma FROM kunden '
      "WHERE COALESCE(kundennummer, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(name, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(firma, '') LIKE ? COLLATE NOCASE "
      'ORDER BY CASE WHEN kundennummer = ? COLLATE NOCASE THEN 0 ELSE 1 END, '
      'name COLLATE NOCASE, id LIMIT ?',
      <Object?>[pattern, pattern, pattern, needle, resultLimit],
    );
    return rows.map((Map<String, Object?> row) => _contactResult(row, needle)).toList(growable: false);
  }

  Future<List<GlobalBusinessSearchResult>> searchReceipts(String query) async {
    final String needle = query.trim();
    final String pattern = '%$needle%';
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT receipt.id, receipt.belegnummer, receipt.beschreibung, receipt.datum, receipt.status, receipt.betrag, '
      "COALESCE(NULLIF(supplier.firma, ''), supplier.name, '') AS supplier_name "
      'FROM belege AS receipt LEFT JOIN lieferanten AS supplier ON supplier.id = receipt.lieferant_id '
      "WHERE COALESCE(receipt.belegnummer, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(receipt.beschreibung, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(supplier.name, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(supplier.firma, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(receipt.datum, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(receipt.status, '') LIKE ? COLLATE NOCASE "
      'OR CAST(receipt.betrag AS TEXT) LIKE ? COLLATE NOCASE '
      'ORDER BY CASE WHEN receipt.belegnummer = ? COLLATE NOCASE THEN 0 ELSE 1 END, '
      'receipt.datum DESC, receipt.id DESC LIMIT ?',
      <Object?>[pattern, pattern, pattern, pattern, pattern, pattern, pattern, needle, resultLimit],
    );
    return rows.map((Map<String, Object?> row) => _receiptResult(row, needle)).toList(growable: false);
  }

  Future<List<GlobalBusinessSearchResult>> searchBankTransactions(String query) async {
    final String needle = query.trim();
    final String pattern = '%$needle%';
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, datum, betrag, verwendungszweck, gegenkonto, gegenkonto_name, status FROM bank_transaktionen '
      "WHERE COALESCE(gegenkonto_name, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(gegenkonto, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(verwendungszweck, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(datum, '') LIKE ? COLLATE NOCASE "
      "OR COALESCE(status, '') LIKE ? COLLATE NOCASE "
      'OR CAST(betrag AS TEXT) LIKE ? COLLATE NOCASE '
      'ORDER BY id DESC LIMIT ?',
      <Object?>[pattern, pattern, pattern, pattern, pattern, pattern, resultLimit],
    );
    return rows.map((Map<String, Object?> row) => _bankTransactionResult(row, needle)).toList(growable: false);
  }

  GlobalBusinessSearchResult _invoiceResult(Map<String, Object?> row, String query) {
    final String identifier = _text(row['rechnungsnummer']);
    final int id = _integer(row['id']);
    final String party = _text(row['party_name']);
    final String date = _text(row['datum']);
    final String status = _text(row['status']);
    final String amount = _text(row['brutto_betrag']);
    return GlobalBusinessSearchResult(
      kind: GlobalSearchRecordKind.invoice,
      recordId: id,
      label: identifier,
      summary: _join(<String>[party, date, status, amount]),
      exactIdentifierMatch: identifier.toLowerCase() == query.toLowerCase(),
      sortDate: date,
    );
  }

  GlobalBusinessSearchResult _contactResult(Map<String, Object?> row, String query) {
    final int id = _integer(row['id']);
    final String name = _text(row['name']);
    final String company = _text(row['firma']);
    final String number = _text(row['kundennummer']);
    return GlobalBusinessSearchResult(
      kind: GlobalSearchRecordKind.contact,
      recordId: id,
      label: company.isEmpty ? name : company,
      summary: _join(<String>[if (company.isNotEmpty) name, number]),
      exactIdentifierMatch: number.isNotEmpty && number.toLowerCase() == query.toLowerCase(),
      sortDate: '',
    );
  }

  GlobalBusinessSearchResult _receiptResult(Map<String, Object?> row, String query) {
    final String identifier = _text(row['belegnummer']);
    final int id = _integer(row['id']);
    return GlobalBusinessSearchResult(
      kind: GlobalSearchRecordKind.receipt,
      recordId: id,
      label: identifier,
      summary: _join(<String>[
        _text(row['beschreibung']),
        _text(row['supplier_name']),
        _text(row['datum']),
        _text(row['status']),
        _text(row['betrag']),
      ]),
      exactIdentifierMatch: identifier.toLowerCase() == query.toLowerCase(),
      sortDate: _text(row['datum']),
    );
  }

  GlobalBusinessSearchResult _bankTransactionResult(Map<String, Object?> row, String query) {
    final int id = _integer(row['id']);
    final String counterparty = _text(row['gegenkonto_name']);
    final String account = _text(row['gegenkonto']);
    return GlobalBusinessSearchResult(
      kind: GlobalSearchRecordKind.bankTransaction,
      recordId: id,
      label: counterparty.isEmpty ? account : counterparty,
      summary: _join(<String>[
        account,
        _text(row['verwendungszweck']),
        _text(row['datum']),
        _text(row['status']),
        _text(row['betrag']),
      ]),
      exactIdentifierMatch: false,
      sortDate: _text(row['datum']),
    );
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  int _integer(Object? value) {
    final int? id = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (id == null || id <= 0) throw StateError('Invalid typed global-search projection');
    return id;
  }

  String _join(List<String> values) => values.where((String value) => value.isNotEmpty).join(' · ');
}

final globalBusinessSearchRepositoryProvider = Provider<GlobalBusinessSearchRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return GlobalBusinessSearchRepository(db.executor);
});
