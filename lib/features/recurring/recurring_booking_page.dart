import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/recurring_booking_workspace_usecases.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Recurring-booking workspace at the canonical `/recurring` route.
///
/// Creates and inspects booking templates plus review-only due instances.
/// Resolves everything through [RecurringBookingWorkspaceUseCases] and never
/// issues direct SQL writes from the page. Narrow-safe single column with
/// loading, populated, empty, and failure states plus the primary
/// `Neue Vorlage` action.
class RecurringBookingPage extends ConsumerStatefulWidget {
  const RecurringBookingPage({required this.routeUri, super.key});

  final Uri routeUri;

  @override
  ConsumerState<RecurringBookingPage> createState() => _RecurringBookingPageState();
}

class _RecurringBookingPageState extends ConsumerState<RecurringBookingPage> {
  List<BuchungsVorlage>? _templates;
  List<DueInstanceView>? _due;
  String? _error;
  bool _loading = true;
  int? _selectedTemplateId;

  RecurringBookingWorkspaceUseCases _useCases(BuildContext context) {
    final AppScope? scope = AppScope.maybeOf(context);
    if (scope != null) return scope.services.recurringBooking;
    return ref.read(appServicesProvider).recurringBooking;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final RecurringBookingWorkspaceUseCases useCases = _useCases(context);
      final List<BuchungsVorlage> templates = await useCases.listTemplates();
      final List<DueInstanceView> due = await useCases.refreshDueInstances();
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _due = due;
        _loading = false;
        if (_selectedTemplateId != null && templates.every((BuchungsVorlage t) => t.id != _selectedTemplateId)) {
          _selectedTemplateId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openForm() async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _RecurringTemplateDialog(useCases: _useCases(context)),
    );
    if (changed ?? false) await _reload();
  }

  Future<void> _execute(DueInstanceView view) async {
    try {
      if (view.modus == 'beleg') {
        await _useCases(context).requestBelegHandoff(vorlageId: view.vorlage.id, faelligkeit: view.faelligkeit);
      } else {
        await _useCases(context).requestDirectExecution(vorlageId: view.vorlage.id, faelligkeit: view.faelligkeit);
      }
      if (!mounted) return;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      maxWidth: 860,
      header: AppPageHeader(
        title: l10n.recurringTitle,
        subtitle: l10n.recurringSubtitle,
        showFilterToolbar: false,
        primaryActionLabel: l10n.recurringNewTemplate,
        onPrimaryAction: () => unawaited(_openForm()),
      ),
      child: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Database outage boundary: unavailable/retry, route preserved, no setup redirect.
    if (_error != null) {
      return AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.cloud_off_outlined),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.recurringLoadFailed)),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.routeUri.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: Text(l10n.actionRetry)),
          ],
        ),
      );
    }
    final List<BuchungsVorlage> templates = _templates ?? const <BuchungsVorlage>[];
    final List<DueInstanceView> due = _due ?? const <DueInstanceView>[];
    if (templates.isEmpty) {
      return AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.repeat_outlined, size: 40),
            const SizedBox(height: 12),
            Text(l10n.recurringEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => unawaited(_openForm()),
              icon: const Icon(Icons.add),
              label: Text(l10n.recurringNewTemplate),
            ),
          ],
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Semantics(header: true, child: Text(l10n.recurringTitle, style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 8),
        for (final BuchungsVorlage template in templates) _templateTile(context, l10n, template),
        const SizedBox(height: 16),
        Semantics(header: true, child: Text(l10n.recurringDueTitle, style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 8),
        if (due.isEmpty)
          AppCard(child: Text(l10n.recurringDueEmpty, textAlign: TextAlign.center))
        else
          for (final DueInstanceView view in due) _dueTile(context, l10n, view),
      ],
    );
  }

  Widget _templateTile(BuildContext context, AppLocalizations l10n, BuchungsVorlage template) {
    final bool selected = _selectedTemplateId == template.id;
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        selected: selected,
        autofocus: false,
        title: Text(template.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${template.art} · ${template.modus} · ${template.intervall} · ${template.naechsteFaelligkeit ?? '—'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: AppStatusChip(status: template.aktiv ? AppStatus.paid : AppStatus.warning, label: template.status),
        onTap: () => setState(() => _selectedTemplateId = selected ? null : template.id),
      ),
    );
  }

  Widget _dueTile(BuildContext context, AppLocalizations l10n, DueInstanceView view) {
    final String? reason = view.blockReason ?? view.handoffError;
    final bool failed = view.reviewStatus == 'failed';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${view.vorlage.name} · ${view.faelligkeit}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${view.art} · ${view.modus} · ${view.effektiverBetrag} · ${view.reviewStatus}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: AppStatusChip(
              status: view.isCompleted
                  ? AppStatus.paid
                  : failed
                  ? AppStatus.overdue
                  : AppStatus.draft,
              label: view.reviewStatus,
            ),
          ),
          if (view.warnung != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(view.warnung!, style: Theme.of(context).textTheme.bodySmall),
          ],
          // Block and handoff-failure displays read the persisted reason.
          if (reason != null) ...<Widget>[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                failed ? l10n.recurringHandoffError(reason) : l10n.recurringBlockedReason(reason),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: view.isCompleted ? null : () => unawaited(_execute(view)),
                icon: const Icon(Icons.check),
                label: Text(view.modus == 'beleg' ? l10n.recurringCreateDraft : l10n.recurringConfirmExecute),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create form with per-field validation. Saving a template stores its
/// configured values without creating a financial event; the use case
/// reports the invalid field.
class _RecurringTemplateDialog extends StatefulWidget {
  const _RecurringTemplateDialog({required this.useCases});

  final RecurringBookingWorkspaceUseCases useCases;

  @override
  State<_RecurringTemplateDialog> createState() => _RecurringTemplateDialogState();
}

class _RecurringTemplateDialogState extends State<_RecurringTemplateDialog> {
  late final TextEditingController _name;
  late final TextEditingController _due;
  late final TextEditingController _betrag;
  String _art = 'Ausgabe';
  String _modus = 'direkt';
  String _intervall = 'monatlich';
  String? _fieldError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _due = TextEditingController();
    _betrag = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _name.dispose();
    _due.dispose();
    _betrag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    setState(() {
      _saving = true;
      _fieldError = null;
    });
    try {
      await widget.useCases.createTemplate(
        name: _name.text,
        art: _art,
        modus: _modus,
        intervall: _intervall,
        naechsteFaelligkeit: _due.text.trim(),
        betrag: _betrag.text.trim().isEmpty ? '0.00' : _betrag.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _fieldError = l10n.recurringInvalidField(error.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AlertDialog(
      title: Text(l10n.recurringNewTemplate),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _art,
                decoration: const InputDecoration(labelText: 'Art'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'Ausgabe', child: Text('Ausgabe')),
                  DropdownMenuItem<String>(value: 'Einnahme', child: Text('Einnahme')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _art = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _modus,
                decoration: const InputDecoration(labelText: 'Modus'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'direkt', child: Text('direkt')),
                  DropdownMenuItem<String>(value: 'beleg', child: Text('beleg')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _modus = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _intervall,
                decoration: const InputDecoration(labelText: 'Intervall'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'monatlich', child: Text('monatlich')),
                  DropdownMenuItem<String>(value: 'quartalsweise', child: Text('quartalsweise')),
                  DropdownMenuItem<String>(value: 'jährlich', child: Text('jährlich')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _intervall = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _due,
                decoration: const InputDecoration(labelText: 'Nächste Fälligkeit', hintText: '2026-02-01'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _betrag,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Betrag'),
              ),
              if (_fieldError != null) ...<Widget>[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(_fieldError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
