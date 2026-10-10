import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_catalog.dart';

/// Reviewed guidance catalog for field affordances and the Help glossary.
final contextualGuidanceCatalogProvider = Provider<ContextualGuidanceCatalog>((ref) {
  return ContextualGuidanceCatalog.reviewed();
});

/// Active glossary search text; filtering stays local, no network access.
class ContextualGuidanceQueryNotifier extends Notifier<String> {
  @override
  String build() {
    return '';
  }

  // ignore: avoid_setters_without_getters
  set query(String value) {
    state = value;
  }
}

final contextualGuidanceQueryProvider = NotifierProvider<ContextualGuidanceQueryNotifier, String>(
  ContextualGuidanceQueryNotifier.new,
);
