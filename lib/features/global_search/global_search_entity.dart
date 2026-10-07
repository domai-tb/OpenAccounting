import 'package:flutter/foundation.dart';

enum GlobalSearchRecordKind { invoice, contact, receipt, bankTransaction }

enum GlobalSearchSource { invoices, contacts, receipts, bankTransactions }

@immutable
sealed class GlobalSearchItem {
  const GlobalSearchItem({required this.label, required this.summary});

  final String label;
  final String summary;
}

@immutable
final class GlobalBusinessSearchResult extends GlobalSearchItem {
  const GlobalBusinessSearchResult({
    required super.label,
    required super.summary,
    required this.kind,
    required this.recordId,
    required this.exactIdentifierMatch,
    required this.sortDate,
  });

  final GlobalSearchRecordKind kind;
  final int recordId;
  final bool exactIdentifierMatch;
  final String sortDate;

  String get route => switch (kind) {
    GlobalSearchRecordKind.invoice => '/invoices/$recordId',
    GlobalSearchRecordKind.contact => '/contacts/$recordId',
    GlobalSearchRecordKind.receipt => '/receipts/$recordId',
    GlobalSearchRecordKind.bankTransaction => Uri(
      path: '/banking',
      queryParameters: <String, String>{'transactionId': '$recordId'},
    ).toString(),
  };
}

@immutable
final class GlobalSearchDestination extends GlobalSearchItem {
  const GlobalSearchDestination({required super.label, required super.summary, required this.route});

  final String route;
}

enum GlobalSearchCommandId { createInvoice }

@immutable
final class GlobalSearchCommand extends GlobalSearchItem {
  const GlobalSearchCommand({required super.label, required super.summary, required this.id});

  final GlobalSearchCommandId id;
}

@immutable
final class GlobalBusinessSearchResponse {
  GlobalBusinessSearchResponse({
    required List<GlobalBusinessSearchResult> results,
    required Set<GlobalSearchSource> failedSources,
  }) : results = List<GlobalBusinessSearchResult>.unmodifiable(results),
       failedSources = Set<GlobalSearchSource>.unmodifiable(failedSources);

  final List<GlobalBusinessSearchResult> results;
  final Set<GlobalSearchSource> failedSources;

  bool get hasFailures => failedSources.isNotEmpty;
}
