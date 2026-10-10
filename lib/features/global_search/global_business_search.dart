import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/features/global_search/global_business_search_repository.dart';
import 'package:openaccounting/features/global_search/global_search_entity.dart';

/// Composes independent local-profile search sources and reports partial failures.
class GlobalBusinessSearch {
  const GlobalBusinessSearch(this.repository);

  final GlobalBusinessSearchRepository repository;

  Future<GlobalBusinessSearchResponse> call(String rawQuery) async {
    final String query = rawQuery.trim();
    if (query.isEmpty) {
      return GlobalBusinessSearchResponse(
        results: const <GlobalBusinessSearchResult>[],
        failedSources: const <GlobalSearchSource>{},
      );
    }

    final List<_SourceResults> sources = await Future.wait<_SourceResults>(<Future<_SourceResults>>[
      _capture(GlobalSearchSource.invoices, () => repository.searchInvoices(query)),
      _capture(GlobalSearchSource.contacts, () => repository.searchContacts(query)),
      _capture(GlobalSearchSource.receipts, () => repository.searchReceipts(query)),
      _capture(GlobalSearchSource.bankTransactions, () => repository.searchBankTransactions(query)),
    ]);
    final List<GlobalBusinessSearchResult> results = <GlobalBusinessSearchResult>[
      for (final _SourceResults source in sources) ...source.results,
    ];
    results.sort((left, right) {
      if (left.exactIdentifierMatch != right.exactIdentifierMatch) {
        return left.exactIdentifierMatch ? -1 : 1;
      }
      final int typeOrder = left.kind.index.compareTo(right.kind.index);
      if (typeOrder != 0) return typeOrder;
      final int dateOrder = right.sortDate.compareTo(left.sortDate);
      if (dateOrder != 0) return dateOrder;
      return right.recordId.compareTo(left.recordId);
    });
    return GlobalBusinessSearchResponse(
      results: results,
      failedSources: <GlobalSearchSource>{
        for (final _SourceResults source in sources)
          if (source.failed) source.source,
      },
    );
  }

  Future<_SourceResults> _capture(
    GlobalSearchSource source,
    Future<List<GlobalBusinessSearchResult>> Function() search,
  ) async {
    try {
      return _SourceResults(source: source, results: await search());
    } catch (_) {
      return _SourceResults(source: source, results: const <GlobalBusinessSearchResult>[], failed: true);
    }
  }
}

final globalBusinessSearchProvider = Provider<GlobalBusinessSearch>((ref) {
  return GlobalBusinessSearch(ref.watch(globalBusinessSearchRepositoryProvider));
});

final globalBusinessSearchResultsProvider = FutureProvider.autoDispose.family<GlobalBusinessSearchResponse, String>((
  ref,
  query,
) async {
  final GlobalBusinessSearch search = ref.watch(globalBusinessSearchProvider);
  if (query.trim().isEmpty) return search.call(query);
  final Completer<void> debounce = Completer<void>();
  final Timer timer = Timer(const Duration(milliseconds: 200), debounce.complete);
  ref.onDispose(() {
    timer.cancel();
    if (!debounce.isCompleted) debounce.complete();
  });
  await debounce.future;
  if (!ref.mounted) {
    return GlobalBusinessSearchResponse(
      results: const <GlobalBusinessSearchResult>[],
      failedSources: const <GlobalSearchSource>{},
    );
  }
  return search.call(query);
});

class _SourceResults {
  const _SourceResults({required this.source, required this.results, this.failed = false});

  final GlobalSearchSource source;
  final List<GlobalBusinessSearchResult> results;
  final bool failed;
}
