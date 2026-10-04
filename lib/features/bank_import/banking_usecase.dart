import 'package:drift/drift.dart';

import 'package:openaccounting/features/bank_import/bank_import_mode_repository.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';
import 'package:openaccounting/features/bank_import/category_rule_repository.dart';
import 'package:openaccounting/features/bank_import/custom_template_repository.dart';

/// Application-scope Banking use case per
/// bank-import-confidence-and-rule-workspace (design decision 1).
/// Coordinates upload, score preview, rule management, profile mode, history
/// queries, retry, and review actions through typed repositories. SQL
/// executors and row maps stay below the page.
class BankingUseCase {
  BankingUseCase(QueryExecutor executor)
    : service = BankImportService(executor),
      modes = BankImportModeRepository(executor),
      rules = CategoryRuleRepository(executor),
      templates = CustomTemplateRepository(executor);

  final BankImportService service;
  final BankImportModeRepository modes;
  final CategoryRuleRepository rules;
  final CustomTemplateRepository templates;
}
