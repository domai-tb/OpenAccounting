import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_execution.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_repository.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Quick Bookings preset workspace: list, create, edit, review, and
/// contract-gated execution. Presets with missing required inputs stay
/// unchanged and review-required; execution never writes directly and shows
/// an unavailable state until the posting contract accepts. All controls are
/// keyboard-reachable with visible focus and localized announcements.
class QuickBookingsView extends StatefulWidget {
  const QuickBookingsView({
    required this.repository,
    required this.executorPort,
    required this.konten,
    required this.categories,
    required this.taxRates,
    super.key,
  });

  final QuickBookingRepository repository;
  final QuickBookingPostingPort executorPort;
  final List<({int id, String name})> konten;
  final List<({int id, String name})> categories;
  final List<({int id, String label})> taxRates;

  @override
  State<QuickBookingsView> createState() => _QuickBookingsViewState();
}

class _QuickBookingsViewState extends State<QuickBookingsView> {
  List<QuickBookingPreset> _presets = <QuickBookingPreset>[];
  bool _loading = true;
  String? _error;
  String? _notice;

  AppLocalizations get _l10n => appLocalizationsOf(context);

  bool _needsReview(QuickBookingPreset preset) =>
      preset.needsReview ||
      !widget.konten.any((konto) => konto.id == preset.kontoId) ||
      !widget.categories.any((category) => category.id == preset.kategorieId) ||
      !widget.taxRates.any((taxRate) => taxRate.id == preset.ustSatzId);

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
      final List<QuickBookingPreset> presets = await widget.repository.list();
      if (!mounted) return;
      setState(() {
        _presets = presets;
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

  Future<void> _openEditor({QuickBookingPreset? preset}) async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _PresetEditorDialog(
        repository: widget.repository,
        konten: widget.konten,
        categories: widget.categories,
        taxRates: widget.taxRates,
        preset: preset,
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _delete(QuickBookingPreset preset) async {
    final AppLocalizations l10n = _l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.quickBookingDelete),
        content: Text(preset.name),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.quickBookingCancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.quickBookingDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.delete(preset.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _execute(QuickBookingPreset preset) async {
    if (!widget.executorPort.isAvailable || _needsReview(preset)) return;
    final AppLocalizations l10n = _l10n;
    String? amount;
    if (preset.betrag == null) {
      amount = await showDialog<String>(
        context: context,
        builder: (BuildContext context) => const _AmountDialog(initial: null),
      );
      if (amount == null) return;
    }
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      final QuickBookingExecution execution = await executePreset(
        executor: widget.repository.executor,
        repository: widget.repository,
        port: widget.executorPort,
        presetId: preset.id,
        businessDate: DateTime.now().toIso8601String().substring(0, 10),
        betrag: amount,
      );
      if (!mounted) return;
      setState(() {
        _notice = execution.executed
            ? (execution.postingIdentity ?? l10n.quickBookingUnavailable)
            : (execution.unavailableReason ?? l10n.quickBookingUnavailable);
      });
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
        title: l10n.quickBookingsTitle,
        actions: <Widget>[
          TextButton.icon(
            onPressed: _loading ? null : _openEditor,
            icon: const Icon(Icons.add),
            label: Text(l10n.quickBookingNew),
          ),
        ],
      ),
      child: Semantics(
        liveRegion: true,
        label: _error != null
            ? l10n.databaseUnavailable
            : _notice ?? (!widget.executorPort.isAvailable ? l10n.quickBookingUnavailable : l10n.quickBookingsTitle),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _presets.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppStatusChip(status: AppStatus.warning, label: l10n.databaseUnavailable),
                    TextButton.icon(
                      onPressed: _loading ? null : _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.actionRetry),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: <Widget>[
                          AppStatusChip(status: AppStatus.warning, label: l10n.databaseUnavailable),
                          TextButton.icon(
                            onPressed: _loading ? null : _reload,
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.actionRetry),
                          ),
                        ],
                      ),
                    ),
                  if (!widget.executorPort.isAvailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppStatusChip(status: AppStatus.neutral, label: l10n.quickBookingUnavailable),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_notice!, semanticsLabel: _notice),
                    ),
                  if (_presets.isEmpty)
                    Text(l10n.quickBookingEmpty)
                  else
                    ..._presets.map(
                      (QuickBookingPreset preset) => Card(
                        child: ListTile(
                          title: Text(preset.name),
                          subtitle: Text(
                            <String>[
                              preset.direction?.db ?? '?',
                              if (preset.betrag != null) preset.betrag!,
                              if (_needsReview(preset)) l10n.quickBookingReviewRequired,
                            ].join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (_needsReview(preset))
                                AppStatusChip(status: AppStatus.warning, label: l10n.quickBookingReviewRequired),
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: l10n.quickBookingExecute,
                                onPressed: widget.executorPort.isAvailable && !_needsReview(preset)
                                    ? () => _execute(preset)
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: l10n.quickBookingEdit,
                                onPressed: () => _openEditor(preset: preset),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: l10n.quickBookingDelete,
                                onPressed: () => _delete(preset),
                              ),
                            ],
                          ),
                          onTap: () => _openEditor(preset: preset),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.initial});

  final String? initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AlertDialog(
      title: Text(l10n.quickBookingEnterAmount),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l10n.quickBookingAmount, suffixText: '€'),
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text.trim()),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.quickBookingCancel)),
        TextButton(
          onPressed: () {
            final String value = _controller.text.trim();
            if (value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.quickBookingExecute),
        ),
      ],
    );
  }
}

class _PresetEditorDialog extends StatefulWidget {
  const _PresetEditorDialog({
    required this.repository,
    required this.konten,
    required this.categories,
    required this.taxRates,
    this.preset,
  });

  final QuickBookingRepository repository;
  final List<({int id, String name})> konten;
  final List<({int id, String name})> categories;
  final List<({int id, String label})> taxRates;
  final QuickBookingPreset? preset;

  @override
  State<_PresetEditorDialog> createState() => _PresetEditorDialogState();
}

class _PresetEditorDialogState extends State<_PresetEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _betrag;
  late final TextEditingController _beschreibung;
  QuickBookingDirection? _direction;
  int? _kontoId;
  int? _kategorieId;
  int? _ustSatzId;
  QuickBookingModus? _modus;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final QuickBookingPreset? preset = widget.preset;
    _name = TextEditingController(text: preset?.name ?? '');
    _betrag = TextEditingController(text: preset?.betrag ?? '');
    _beschreibung = TextEditingController(text: preset?.beschreibung ?? '');
    _direction = preset?.direction;
    _kontoId = preset?.kontoId;
    _kategorieId = preset?.kategorieId;
    _ustSatzId = preset?.ustSatzId;
    _modus = preset?.modus;
  }

  @override
  void dispose() {
    _name.dispose();
    _betrag.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final String betrag = _betrag.text.trim();
      final String beschreibung = _beschreibung.text.trim();
      if (widget.preset == null) {
        await widget.repository.create(
          name: _name.text,
          direction: _direction,
          kontoId: _kontoId,
          kategorieId: _kategorieId,
          ustSatzId: _ustSatzId,
          modus: _modus,
          betrag: betrag.isEmpty ? null : betrag,
          beschreibung: beschreibung.isEmpty ? null : beschreibung,
        );
      } else {
        await widget.repository.update(
          widget.preset!.id,
          name: _name.text,
          direction: _direction,
          kontoId: _kontoId,
          kategorieId: _kategorieId,
          ustSatzId: _ustSatzId,
          modus: _modus,
          betrag: betrag,
          beschreibung: beschreibung,
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
    final int? selectedKontoId = _kontoId;
    final int? selectedKategorieId = _kategorieId;
    final int? selectedUstSatzId = _ustSatzId;
    final bool kontoUnavailable = selectedKontoId != null && !widget.konten.any((konto) => konto.id == selectedKontoId);
    final bool kategorieUnavailable =
        selectedKategorieId != null && !widget.categories.any((category) => category.id == selectedKategorieId);
    final bool ustSatzUnavailable =
        selectedUstSatzId != null && !widget.taxRates.any((taxRate) => taxRate.id == selectedUstSatzId);
    return AlertDialog(
      title: Text(widget.preset == null ? l10n.quickBookingNew : l10n.quickBookingEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.quickBookingName),
            ),
            DropdownButtonFormField<QuickBookingDirection>(
              initialValue: _direction,
              decoration: InputDecoration(labelText: l10n.quickBookingDirection),
              items: <DropdownMenuItem<QuickBookingDirection>>[
                DropdownMenuItem<QuickBookingDirection>(
                  value: QuickBookingDirection.einnahme,
                  child: Text(l10n.quickBookingDirectionIn),
                ),
                DropdownMenuItem<QuickBookingDirection>(
                  value: QuickBookingDirection.ausgabe,
                  child: Text(l10n.quickBookingDirectionOut),
                ),
              ],
              onChanged: (QuickBookingDirection? value) => setState(() => _direction = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: selectedKontoId,
              decoration: InputDecoration(labelText: l10n.quickBookingAccount),
              items: <DropdownMenuItem<int>>[
                for (final k in widget.konten) DropdownMenuItem<int>(value: k.id, child: Text(k.name)),
                if (kontoUnavailable)
                  DropdownMenuItem<int>(
                    value: selectedKontoId,
                    child: Text('${l10n.quickBookingReviewRequired} ($selectedKontoId)'),
                  ),
              ],
              onChanged: (int? value) => setState(() => _kontoId = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: selectedKategorieId,
              decoration: InputDecoration(labelText: l10n.quickBookingCategory),
              items: <DropdownMenuItem<int>>[
                for (final c in widget.categories) DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                if (kategorieUnavailable)
                  DropdownMenuItem<int>(
                    value: selectedKategorieId,
                    child: Text('${l10n.quickBookingReviewRequired} ($selectedKategorieId)'),
                  ),
              ],
              onChanged: (int? value) => setState(() => _kategorieId = value),
            ),
            DropdownButtonFormField<int>(
              initialValue: selectedUstSatzId,
              decoration: InputDecoration(labelText: l10n.quickBookingTaxRate),
              items: <DropdownMenuItem<int>>[
                for (final t in widget.taxRates) DropdownMenuItem<int>(value: t.id, child: Text(t.label)),
                if (ustSatzUnavailable)
                  DropdownMenuItem<int>(
                    value: selectedUstSatzId,
                    child: Text('${l10n.quickBookingReviewRequired} ($selectedUstSatzId)'),
                  ),
              ],
              onChanged: (int? value) => setState(() => _ustSatzId = value),
            ),
            DropdownButtonFormField<QuickBookingModus>(
              initialValue: _modus,
              decoration: InputDecoration(labelText: l10n.quickBookingModus),
              items: <DropdownMenuItem<QuickBookingModus>>[
                DropdownMenuItem<QuickBookingModus>(
                  value: QuickBookingModus.netto,
                  child: Text(l10n.quickBookingModusNetto),
                ),
                DropdownMenuItem<QuickBookingModus>(
                  value: QuickBookingModus.brutto,
                  child: Text(l10n.quickBookingModusBrutto),
                ),
              ],
              onChanged: (QuickBookingModus? value) => setState(() => _modus = value),
            ),
            TextField(
              controller: _betrag,
              decoration: InputDecoration(labelText: l10n.quickBookingAmount, suffixText: '€'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _beschreibung,
              decoration: InputDecoration(labelText: l10n.quickBookingDescription),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.quickBookingCancel),
        ),
        TextButton(onPressed: _saving ? null : _save, child: Text(l10n.quickBookingSave)),
      ],
    );
  }
}
