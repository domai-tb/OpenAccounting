import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';

enum TypedWorkspaceDomain { invoices, receipts, bankTransactions }

enum TypedWorkspaceFilterField { dateFrom, dateTo, amountFrom, amountTo }

@immutable
class TypedWorkspaceSearchCriteria {
  const TypedWorkspaceSearchCriteria({
    required this.domain,
    this.text = '',
    this.dateFrom,
    this.dateTo,
    this.status,
    this.amountFrom,
    this.amountTo,
    this.invoiceType,
    this.page = 1,
  });

  final TypedWorkspaceDomain domain;
  final String text;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;
  final num? amountFrom;
  final num? amountTo;
  final String? invoiceType;
  final int page;

  bool get hasFilters =>
      text.trim().isNotEmpty ||
      dateFrom != null ||
      dateTo != null ||
      (status?.trim().isNotEmpty ?? false) ||
      amountFrom != null ||
      amountTo != null ||
      (invoiceType?.trim().isNotEmpty ?? false);

  TypedWorkspaceSearchCriteria copyWith({
    String? text,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    String? status,
    bool clearStatus = false,
    num? amountFrom,
    bool clearAmountFrom = false,
    num? amountTo,
    bool clearAmountTo = false,
    String? invoiceType,
    bool clearInvoiceType = false,
    int? page,
  }) {
    return TypedWorkspaceSearchCriteria(
      domain: domain,
      text: text ?? this.text,
      dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
      dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
      status: clearStatus ? null : status ?? this.status,
      amountFrom: clearAmountFrom ? null : amountFrom ?? this.amountFrom,
      amountTo: clearAmountTo ? null : amountTo ?? this.amountTo,
      invoiceType: clearInvoiceType ? null : invoiceType ?? this.invoiceType,
      page: page ?? this.page,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TypedWorkspaceSearchCriteria &&
      other.domain == domain &&
      other.text == text &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.status == status &&
      other.amountFrom == amountFrom &&
      other.amountTo == amountTo &&
      other.invoiceType == invoiceType &&
      other.page == page;

  @override
  int get hashCode => Object.hash(domain, text, dateFrom, dateTo, status, amountFrom, amountTo, invoiceType, page);
}

@immutable
class TypedWorkspaceCriteriaParseResult {
  TypedWorkspaceCriteriaParseResult({required this.criteria, required Set<TypedWorkspaceFilterField> invalidFields})
    : invalidFields = Set<TypedWorkspaceFilterField>.unmodifiable(invalidFields);

  final TypedWorkspaceSearchCriteria criteria;
  final Set<TypedWorkspaceFilterField> invalidFields;
}

TypedWorkspaceCriteriaParseResult parseTypedWorkspaceRouteCriteria(
  TypedWorkspaceDomain domain,
  Map<String, String> parameters,
) {
  final Set<TypedWorkspaceFilterField> invalid = <TypedWorkspaceFilterField>{};
  DateTime? dateFrom = _parseRouteDate(parameters['dateFrom']);
  DateTime? dateTo = _parseRouteDate(parameters['dateTo']);
  num? amountFrom = _parseRouteAmount(parameters['amountFrom']);
  num? amountTo = _parseRouteAmount(parameters['amountTo']);
  if ((parameters['dateFrom']?.isNotEmpty ?? false) && dateFrom == null) {
    invalid.add(TypedWorkspaceFilterField.dateFrom);
  }
  if ((parameters['dateTo']?.isNotEmpty ?? false) && dateTo == null) invalid.add(TypedWorkspaceFilterField.dateTo);
  if ((parameters['amountFrom']?.isNotEmpty ?? false) && amountFrom == null) {
    invalid.add(TypedWorkspaceFilterField.amountFrom);
  }
  if ((parameters['amountTo']?.isNotEmpty ?? false) && amountTo == null) {
    invalid.add(TypedWorkspaceFilterField.amountTo);
  }
  if (dateFrom != null && dateTo != null && dateFrom.isAfter(dateTo)) {
    invalid
      ..add(TypedWorkspaceFilterField.dateFrom)
      ..add(TypedWorkspaceFilterField.dateTo);
    dateFrom = null;
    dateTo = null;
  }
  if (amountFrom != null && amountTo != null && amountFrom > amountTo) {
    invalid
      ..add(TypedWorkspaceFilterField.amountFrom)
      ..add(TypedWorkspaceFilterField.amountTo);
    amountFrom = null;
    amountTo = null;
  }
  final int page = int.tryParse(parameters['page'] ?? '') ?? 1;
  return TypedWorkspaceCriteriaParseResult(
    criteria: TypedWorkspaceSearchCriteria(
      domain: domain,
      text: parameters['q'] ?? '',
      dateFrom: dateFrom,
      dateTo: dateTo,
      status: _nullableTrim(parameters['status']),
      amountFrom: amountFrom,
      amountTo: amountTo,
      invoiceType: domain == TypedWorkspaceDomain.invoices ? _nullableTrim(parameters['typ']) : null,
      page: page < 1 ? 1 : page,
    ),
    invalidFields: invalid,
  );
}

Map<String, String> typedWorkspaceRouteParameters(Map<String, String> existing, TypedWorkspaceSearchCriteria criteria) {
  final Map<String, String> next = Map<String, String>.from(existing);
  _setQueryValue(next, 'q', criteria.text.trim());
  _setQueryValue(next, 'dateFrom', criteria.dateFrom == null ? '' : _canonicalDate(criteria.dateFrom!));
  _setQueryValue(next, 'dateTo', criteria.dateTo == null ? '' : _canonicalDate(criteria.dateTo!));
  _setQueryValue(next, 'status', criteria.status?.trim() ?? '');
  _setQueryValue(next, 'amountFrom', criteria.amountFrom?.toString() ?? '');
  _setQueryValue(next, 'amountTo', criteria.amountTo?.toString() ?? '');
  _setQueryValue(next, 'page', criteria.page <= 1 ? '' : '${criteria.page}');
  if (criteria.domain == TypedWorkspaceDomain.invoices) {
    _setQueryValue(next, 'typ', criteria.invoiceType?.trim() ?? '');
  }
  return next;
}

void _setQueryValue(Map<String, String> values, String key, String value) {
  if (value.isEmpty) {
    values.remove(key);
  } else {
    values[key] = value;
  }
}

String _canonicalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String typedWorkspaceRoute(String path, Map<String, String> parameters) =>
    Uri(path: path, queryParameters: parameters.isEmpty ? null : parameters).toString();

num? parseLocalizedWorkspaceAmount(String raw, String locale) {
  final String compact = raw.trim().replaceAll(' ', '').replaceAll('\u00a0', '');
  if (compact.isEmpty) return null;
  final bool german = locale.toLowerCase().startsWith('de');
  final bool hasDot = compact.contains('.');
  final bool hasComma = compact.contains(',');
  final String normalized;
  if (german && hasDot && hasComma) {
    normalized = compact.replaceAll('.', '').replaceAll(',', '.');
  } else if (german && hasComma) {
    normalized = compact.replaceAll(',', '.');
  } else if (german && RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(compact)) {
    normalized = compact.replaceAll('.', '');
  } else if (!german && hasDot && hasComma) {
    normalized = compact.replaceAll(',', '');
  } else if (!german && hasComma && RegExp(r'^-?\d{1,3}(,\d{3})+$').hasMatch(compact)) {
    normalized = compact.replaceAll(',', '');
  } else if (!german && hasComma) {
    normalized = compact.replaceAll(',', '.');
  } else {
    normalized = compact;
  }
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final num? value = num.tryParse(normalized);
  if (value == null || value.abs() > 9999999999.99) return null;
  return value;
}

DateTime? _parseRouteDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  final DateTime date = DateTime(parsed.year, parsed.month, parsed.day);
  return _canonicalDate(date) == value ? date : null;
}

num? _parseRouteAmount(String? value) {
  if (value == null || value.isEmpty || !RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) return null;
  final num? parsed = num.tryParse(value);
  return parsed != null && parsed.abs() <= 9999999999.99 ? parsed : null;
}

String? _nullableTrim(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

@immutable
sealed class TypedWorkspaceRecord {
  const TypedWorkspaceRecord({required this.id, required this.date, required this.status});

  final int id;
  final String date;
  final String status;
  num get amount;
}

@immutable
final class InvoiceWorkspaceRecord extends TypedWorkspaceRecord {
  const InvoiceWorkspaceRecord({
    required super.id,
    required super.date,
    required super.status,
    required this.number,
    required this.party,
    required this.grossAmount,
  });

  final String number;
  final String party;
  final num grossAmount;

  @override
  num get amount => grossAmount;
}

@immutable
final class ReceiptWorkspaceRecord extends TypedWorkspaceRecord {
  const ReceiptWorkspaceRecord({
    required super.id,
    required super.date,
    required super.status,
    required this.number,
    required this.description,
    required this.supplier,
    required this.receiptAmount,
  });

  final String number;
  final String description;
  final String supplier;
  final num receiptAmount;

  @override
  num get amount => receiptAmount;
}

@immutable
final class BankTransactionWorkspaceRecord extends TypedWorkspaceRecord {
  const BankTransactionWorkspaceRecord({
    required super.id,
    required super.date,
    required super.status,
    required this.counterpartyName,
    required this.counterpartyAccount,
    required this.remittance,
    required this.transactionAmount,
  });

  final String counterpartyName;
  final String counterpartyAccount;
  final String remittance;
  final num transactionAmount;

  @override
  num get amount => transactionAmount;
}

@immutable
class TypedWorkspaceSearchPage {
  TypedWorkspaceSearchPage({required List<TypedWorkspaceRecord> records, required this.totalCount, required this.page})
    : records = List<TypedWorkspaceRecord>.unmodifiable(records);

  final List<TypedWorkspaceRecord> records;
  final int totalCount;
  final int page;

  static const int pageSize = 25;
  int get pageCount => totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
}

class TypedWorkspaceSearchRepository {
  const TypedWorkspaceSearchRepository(this.executor);

  final QueryExecutor executor;

  Future<TypedWorkspaceSearchPage> search(TypedWorkspaceSearchCriteria criteria) async {
    final _WorkspaceQuery query = _buildQuery(criteria);
    final List<Object?> countArgs = List<Object?>.from(query.arguments);
    final List<Map<String, Object?>> countRows = await executor.runSelect(
      'SELECT COUNT(*) AS total_count ${query.fromAndWhere}',
      countArgs,
    );
    final Object? rawCount = countRows.single['total_count'];
    final int? parsedCount = rawCount is num ? rawCount.toInt() : int.tryParse(rawCount?.toString() ?? '');
    if (parsedCount == null || parsedCount < 0) throw StateError('Invalid typed workspace count projection');
    final int totalCount = parsedCount;
    final int page = criteria.page.clamp(1, 100000);
    final int lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ TypedWorkspaceSearchPage.pageSize) + 1;
    final int safePage = page > lastPage ? lastPage : page;
    final List<Object?> resultArgs = <Object?>[
      ...query.arguments,
      TypedWorkspaceSearchPage.pageSize,
      (safePage - 1) * TypedWorkspaceSearchPage.pageSize,
    ];
    final List<Map<String, Object?>> rows = await executor.runSelect(
      '${query.select} ${query.fromAndWhere} ${query.orderBy} LIMIT ? OFFSET ?',
      resultArgs,
    );
    return TypedWorkspaceSearchPage(
      records: rows.map((Map<String, Object?> row) => _record(criteria.domain, row)).toList(growable: false),
      totalCount: totalCount,
      page: safePage,
    );
  }

  _WorkspaceQuery _buildQuery(TypedWorkspaceSearchCriteria criteria) {
    final String from;
    final String select;
    final String orderBy;
    final List<String> textColumns;
    final String dateColumn;
    final String statusColumn;
    final String amountColumn;
    switch (criteria.domain) {
      case TypedWorkspaceDomain.invoices:
        from =
            'FROM rechnungen AS invoice '
            'LEFT JOIN kunden AS customer ON customer.id = invoice.kunde_id '
            'LEFT JOIN lieferanten AS supplier ON supplier.id = invoice.lieferant_id';
        select =
            'SELECT invoice.id, invoice.rechnungsnummer AS number, '
            "COALESCE(NULLIF(customer.firma, ''), customer.name, NULLIF(supplier.firma, ''), supplier.name, '') "
            'AS party, invoice.datum AS date, invoice.status, invoice.brutto_betrag AS amount';
        orderBy = 'ORDER BY invoice.datum DESC, invoice.id DESC';
        textColumns = <String>[
          "COALESCE(invoice.rechnungsnummer, '')",
          "COALESCE(customer.name, '')",
          "COALESCE(customer.firma, '')",
          "COALESCE(supplier.name, '')",
          "COALESCE(supplier.firma, '')",
          "COALESCE(invoice.datum, '')",
        ];
        dateColumn = 'invoice.datum';
        statusColumn = 'invoice.status';
        amountColumn = 'invoice.brutto_betrag';
      case TypedWorkspaceDomain.receipts:
        from = 'FROM belege AS receipt LEFT JOIN lieferanten AS supplier ON supplier.id = receipt.lieferant_id';
        select =
            'SELECT receipt.id, receipt.belegnummer AS number, receipt.beschreibung AS description, '
            "COALESCE(NULLIF(supplier.firma, ''), supplier.name, '') AS supplier, "
            'receipt.datum AS date, receipt.status, receipt.betrag AS amount';
        orderBy = 'ORDER BY receipt.datum DESC, receipt.id DESC';
        textColumns = <String>[
          "COALESCE(receipt.belegnummer, '')",
          "COALESCE(receipt.beschreibung, '')",
          "COALESCE(supplier.name, '')",
          "COALESCE(supplier.firma, '')",
        ];
        dateColumn = 'receipt.datum';
        statusColumn = 'receipt.status';
        amountColumn = 'receipt.betrag';
      case TypedWorkspaceDomain.bankTransactions:
        from = 'FROM bank_transaktionen AS tx';
        select =
            'SELECT tx.id, tx.gegenkonto_name AS counterparty_name, '
            'tx.gegenkonto AS counterparty_account, tx.verwendungszweck AS remittance, '
            'tx.datum AS date, tx.status, tx.betrag AS amount';
        orderBy = 'ORDER BY tx.datum DESC, tx.id DESC';
        textColumns = <String>[
          "COALESCE(tx.gegenkonto_name, '')",
          "COALESCE(tx.gegenkonto, '')",
          "COALESCE(tx.verwendungszweck, '')",
        ];
        dateColumn = 'tx.datum';
        statusColumn = 'tx.status';
        amountColumn = 'tx.betrag';
    }

    final List<String> predicates = <String>[];
    final List<Object?> arguments = <Object?>[];
    final String text = criteria.text.trim();
    if (text.isNotEmpty) {
      predicates.add('(${textColumns.map((String column) => "$column LIKE ? COLLATE NOCASE").join(' OR ')})');
      arguments.addAll(List<Object?>.filled(textColumns.length, '%$text%'));
    }
    if (criteria.domain == TypedWorkspaceDomain.invoices && (criteria.invoiceType?.isNotEmpty ?? false)) {
      predicates.add('invoice.typ = ?');
      arguments.add(criteria.invoiceType);
    }
    if (criteria.dateFrom != null) {
      predicates.add('date($dateColumn) >= date(?)');
      arguments.add(_dateString(criteria.dateFrom!));
    }
    if (criteria.dateTo != null) {
      predicates.add('date($dateColumn) <= date(?)');
      arguments.add(_dateString(criteria.dateTo!));
    }
    if (criteria.status != null && criteria.status!.trim().isNotEmpty) {
      predicates.add('$statusColumn = ?');
      arguments.add(criteria.status!.trim());
    }
    if (criteria.amountFrom != null) {
      predicates.add('$amountColumn >= ?');
      arguments.add(criteria.amountFrom);
    }
    if (criteria.amountTo != null) {
      predicates.add('$amountColumn <= ?');
      arguments.add(criteria.amountTo);
    }
    final String where = predicates.isEmpty ? '' : ' WHERE ${predicates.join(' AND ')}';
    return _WorkspaceQuery(select: select, fromAndWhere: '$from$where', orderBy: orderBy, arguments: arguments);
  }

  TypedWorkspaceRecord _record(TypedWorkspaceDomain domain, Map<String, Object?> row) {
    final int? id = _int(row['id']);
    final num? amount = _num(row['amount']);
    if (id == null || id <= 0 || amount == null) throw StateError('Invalid typed workspace projection');
    final String date = _text(row['date']);
    final String status = _text(row['status']);
    return switch (domain) {
      TypedWorkspaceDomain.invoices => InvoiceWorkspaceRecord(
        id: id,
        date: date,
        status: status,
        number: _text(row['number']),
        party: _text(row['party']),
        grossAmount: amount,
      ),
      TypedWorkspaceDomain.receipts => ReceiptWorkspaceRecord(
        id: id,
        date: date,
        status: status,
        number: _text(row['number']),
        description: _text(row['description']),
        supplier: _text(row['supplier']),
        receiptAmount: amount,
      ),
      TypedWorkspaceDomain.bankTransactions => BankTransactionWorkspaceRecord(
        id: id,
        date: date,
        status: status,
        counterpartyName: _text(row['counterparty_name']),
        counterpartyAccount: _text(row['counterparty_account']),
        remittance: _text(row['remittance']),
        transactionAmount: amount,
      ),
    };
  }

  int? _int(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  num? _num(Object? value) => value is num ? value : num.tryParse(value?.toString() ?? '');

  String _text(Object? value) => value?.toString().trim() ?? '';

  String _dateString(DateTime value) => _canonicalDate(value);
}

class _WorkspaceQuery {
  const _WorkspaceQuery({
    required this.select,
    required this.fromAndWhere,
    required this.orderBy,
    required this.arguments,
  });

  final String select;
  final String fromAndWhere;
  final String orderBy;
  final List<Object?> arguments;
}

final typedWorkspaceSearchRepositoryProvider = Provider<TypedWorkspaceSearchRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return TypedWorkspaceSearchRepository(db.executor);
});

final typedWorkspaceSearchResultsProvider = FutureProvider.autoDispose
    .family<TypedWorkspaceSearchPage, TypedWorkspaceSearchCriteria>((ref, criteria) async {
      final TypedWorkspaceSearchRepository repository = ref.watch(typedWorkspaceSearchRepositoryProvider);
      if (criteria.text.trim().isEmpty) {
        ref.keepAlive();
        return repository.search(criteria);
      }
      final Completer<void> debounce = Completer<void>();
      final Timer timer = Timer(const Duration(milliseconds: 200), debounce.complete);
      ref.onDispose(() {
        timer.cancel();
        if (!debounce.isCompleted) debounce.complete();
      });
      await debounce.future;
      if (!ref.mounted) {
        return TypedWorkspaceSearchPage(records: const <TypedWorkspaceRecord>[], totalCount: 0, page: 1);
      }
      return repository.search(criteria);
    });
