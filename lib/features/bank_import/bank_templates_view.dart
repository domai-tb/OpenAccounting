import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/bank_import/bank_template.dart';
import 'package:openaccounting/features/bank_import/banking_usecase.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Banking template-management view over `bank_templates`.
///
/// Custom templates can be created, edited, and deleted; predefined CSV and
/// CAMT.053 templates are listed as protected. All controls are
/// keyboard-reachable with visible focus.
class BankTemplatesView extends StatefulWidget {
  const BankTemplatesView({required this.useCase, super.key});

  final BankingUseCase useCase;

  @override
  State<BankTemplatesView> createState() => _BankTemplatesViewState();
}

class _BankTemplatesViewState extends State<BankTemplatesView> {
  List<BankTemplate> _custom = <BankTemplate>[];
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
      final List<BankTemplate> custom = await widget.useCase.templates.listCustom();
      if (!mounted) return;
      setState(() {
        _custom = custom;
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

  Future<void> _openEditor({BankTemplate? template}) async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _TemplateEditorDialog(useCase: widget.useCase, template: template),
    );
    if (changed == true) await _reload();
  }

  Future<void> _delete(BankTemplate template) async {
    final AppLocalizations l10n = _l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.bankTemplateDelete),
        content: Text(template.name),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.bankRuleCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.bankTemplateDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.useCase.templates.delete(template.id);
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
        title: l10n.bankTemplatesTitle,
        actions: <Widget>[
          TextButton.icon(
            onPressed: _loading ? null : _openEditor,
            icon: const Icon(Icons.add),
            label: Text(l10n.bankTemplateNew),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: AppStatusChip(status: AppStatus.warning, label: _error!),
            )
          : ListView(
              children: <Widget>[
                ..._custom.map(
                  (BankTemplate t) => ListTile(
                    title: Text(t.name),
                    subtitle: Text('${t.typ} · ${t.delimiter} · ${t.encoding} · ${t.dateFormat}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: l10n.bankTemplateEdit,
                          onPressed: () => _openEditor(template: t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: l10n.bankTemplateDelete,
                          onPressed: () => _delete(t),
                        ),
                      ],
                    ),
                    onTap: () => _openEditor(template: t),
                  ),
                ),
                ...BankTemplate.predefined.map(
                  (BankTemplate t) =>
                      ListTile(title: Text(t.name), subtitle: Text('${t.typ} · ${l10n.bankTemplateProtected}')),
                ),
              ],
            ),
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({required this.useCase, this.template});

  final BankingUseCase useCase;
  final BankTemplate? template;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late final TextEditingController _name;
  String _delimiter = ';';
  String _encoding = 'utf-8';
  String _dateFormat = 'dd.MM.yyyy';
  late final TextEditingController _datum;
  late final TextEditingController _betrag;
  late final TextEditingController _zweck;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final BankTemplate? t = widget.template;
    _name = TextEditingController(text: t?.name ?? '');
    _delimiter = t?.delimiter ?? ';';
    _encoding = t?.encoding ?? 'utf-8';
    _dateFormat = t?.dateFormat ?? 'dd.MM.yyyy';
    _datum = TextEditingController(text: t?.fieldMapping['datum'] ?? 'Datum');
    _betrag = TextEditingController(text: t?.fieldMapping['betrag'] ?? 'Betrag');
    _zweck = TextEditingController(text: t?.fieldMapping['verwendungszweck'] ?? 'Verwendungszweck');
  }

  @override
  void dispose() {
    _name.dispose();
    _datum.dispose();
    _betrag.dispose();
    _zweck.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final Map<String, String> mapping = <String, String>{
      'datum': _datum.text,
      'betrag': _betrag.text,
      'verwendungszweck': _zweck.text,
    };
    try {
      if (widget.template == null) {
        await widget.useCase.templates.create(
          name: _name.text,
          delimiter: _delimiter,
          encoding: _encoding,
          dateFormat: _dateFormat,
          fieldMapping: mapping,
        );
      } else {
        await widget.useCase.templates.update(
          widget.template!.id,
          name: _name.text,
          delimiter: _delimiter,
          encoding: _encoding,
          dateFormat: _dateFormat,
          fieldMapping: mapping,
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
      title: Text(widget.template == null ? l10n.bankTemplateNew : l10n.bankTemplateEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.bankTemplateName),
            ),
            DropdownButtonFormField<String>(
              initialValue: _delimiter,
              decoration: const InputDecoration(labelText: 'Delimiter'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: ';', child: Text(';')),
                DropdownMenuItem<String>(value: ',', child: Text(',')),
              ],
              onChanged: (String? value) => setState(() => _delimiter = value ?? ';'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _encoding,
              decoration: const InputDecoration(labelText: 'Encoding'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'utf-8', child: Text('UTF-8')),
                DropdownMenuItem<String>(value: 'iso-8859-1', child: Text('ISO-8859-1')),
              ],
              onChanged: (String? value) => setState(() => _encoding = value ?? 'utf-8'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _dateFormat,
              decoration: const InputDecoration(labelText: 'Date format'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'dd.MM.yyyy', child: Text('dd.MM.yyyy')),
                DropdownMenuItem<String>(value: 'yyyy-MM-dd', child: Text('yyyy-MM-dd')),
              ],
              onChanged: (String? value) => setState(() => _dateFormat = value ?? 'dd.MM.yyyy'),
            ),
            TextField(
              controller: _datum,
              decoration: const InputDecoration(labelText: 'datum'),
            ),
            TextField(
              controller: _betrag,
              decoration: const InputDecoration(labelText: 'betrag'),
            ),
            TextField(
              controller: _zweck,
              decoration: const InputDecoration(labelText: 'verwendungszweck'),
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
