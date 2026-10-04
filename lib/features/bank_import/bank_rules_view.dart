import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/bank_import/banking_usecase.dart';
import 'package:openaccounting/features/bank_import/category_rule_repository.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Banking rule-management view over `auto_filter_regeln`.
///
/// Lists, creates, edits, enables/disables, prioritizes, and deletes
/// category rules behind the typed [BankingUseCase] boundary. All controls
/// are keyboard-reachable with visible focus; status is textual, never
/// color-only.
class BankRulesView extends StatefulWidget {
  const BankRulesView({required this.useCase, required this.categories, super.key});

  final BankingUseCase useCase;

  /// Available categories as (id, name) records for the rule editor.
  final List<({int id, String name})> categories;

  @override
  State<BankRulesView> createState() => _BankRulesViewState();
}

class _BankRulesViewState extends State<BankRulesView> {
  List<CategoryRule> _rules = <CategoryRule>[];
  bool _loading = true;
  String? _error;

  AppLocalizations get _l10n => appLocalizationsOf(context);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<CategoryRule> rules = await widget.useCase.rules.list();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openEditor({CategoryRule? rule}) async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _RuleEditorDialog(useCase: widget.useCase, categories: widget.categories, rule: rule),
    );
    if (changed == true) await _reload();
  }

  Future<void> _toggle(CategoryRule rule, bool value) async {
    try {
      await widget.useCase.rules.update(rule.id, aktiv: value);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _delete(CategoryRule rule) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(appLocalizationsOf(context).bankRuleDelete),
        content: Text(rule.pattern),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(appLocalizationsOf(context).bankRuleCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(appLocalizationsOf(context).bankRuleDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.useCase.rules.delete(rule.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10n;
    return AppPage(
      header: AppPageHeader(
        title: l10n.bankRulesTitle,
        actions: <Widget>[
          TextButton.icon(
            onPressed: _loading ? null : _openEditor,
            icon: const Icon(Icons.add),
            label: Text(l10n.bankRuleNew),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppStatusChip(status: AppStatus.warning, label: _error!),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            )
          : _rules.isEmpty
          ? Center(child: Text(l10n.bankRuleEmpty))
          : ListView.builder(
              itemCount: _rules.length,
              itemBuilder: (BuildContext context, int index) {
                final CategoryRule rule = _rules[index];
                final List<String> names = widget.categories
                    .where((c) => c.id == rule.kategorieId)
                    .map((c) => c.name)
                    .toList(growable: false);
                final String categoryName = names.isEmpty ? '${rule.kategorieId}' : names.first;
                return ListTile(
                  title: Text(rule.pattern),
                  subtitle: Text('$categoryName · ${l10n.bankRulePriority}: ${rule.prioritaet}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (!rule.aktiv)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppStatusChip(status: AppStatus.neutral, label: l10n.bankRuleDisabled),
                        ),
                      Semantics(
                        label: l10n.bankRuleActive,
                        child: Switch(value: rule.aktiv, onChanged: (bool value) => _toggle(rule, value)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: l10n.bankRuleEdit,
                        onPressed: () => _openEditor(rule: rule),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: l10n.bankRuleDelete,
                        onPressed: () => _delete(rule),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(rule: rule),
                );
              },
            ),
    );
  }
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({required this.useCase, required this.categories, this.rule});

  final BankingUseCase useCase;
  final List<({int id, String name})> categories;
  final CategoryRule? rule;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late final TextEditingController _pattern;
  late final TextEditingController _priority;
  int? _kategorieId;
  bool _aktiv = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pattern = TextEditingController(text: widget.rule?.pattern ?? '');
    _priority = TextEditingController(text: '${widget.rule?.prioritaet ?? 0}');
    _kategorieId = widget.rule?.kategorieId;
    _aktiv = widget.rule?.aktiv ?? true;
  }

  @override
  void dispose() {
    _pattern.dispose();
    _priority.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final int? priority = int.tryParse(_priority.text.trim());
    if (_kategorieId == null || priority == null) {
      setState(() => _error = l10n.bankRuleEdit);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.rule == null) {
        await widget.useCase.rules.create(
          pattern: _pattern.text,
          kategorieId: _kategorieId!,
          prioritaet: priority,
          aktiv: _aktiv,
        );
      } else {
        await widget.useCase.rules.update(
          widget.rule!.id,
          pattern: _pattern.text,
          kategorieId: _kategorieId,
          prioritaet: priority,
          aktiv: _aktiv,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AlertDialog(
      title: Text(widget.rule == null ? l10n.bankRuleNew : l10n.bankRuleEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _pattern,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.bankRulePattern),
              onSubmitted: (_) => _save(),
            ),
            DropdownButtonFormField<int>(
              initialValue: _kategorieId,
              decoration: InputDecoration(labelText: l10n.bankRuleCategory),
              items: <DropdownMenuItem<int>>[
                for (final c in widget.categories) DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (int? value) => setState(() => _kategorieId = value),
            ),
            TextField(
              controller: _priority,
              decoration: InputDecoration(labelText: l10n.bankRulePriority),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _save(),
            ),
            SwitchListTile(
              value: _aktiv,
              onChanged: (bool value) => setState(() => _aktiv = value),
              title: Text(l10n.bankRuleActive),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.bankRuleCancel),
        ),
        TextButton(onPressed: _saving ? null : _save, child: Text(l10n.bankRuleSave)),
      ],
    );
  }
}
