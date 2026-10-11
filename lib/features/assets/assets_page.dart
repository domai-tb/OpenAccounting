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
import 'package:openaccounting/features/assets/asset_entity.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';
import 'package:openaccounting/features/assets/asset_usecases.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Fixed-asset register workspace at the canonical `/assets` route.
///
/// Typed list, create/edit form, and a selected-asset inspector with the
/// traceable annual schedule. Narrow-safe single column; never writes journal
/// rows or assigns posting accounts.
class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({required this.routeUri, super.key});

  final Uri routeUri;

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  List<FixedAsset>? _assets;
  String? _error;
  bool _loading = true;
  int? _selectedId;
  List<AssetScheduleRow>? _schedulePreview;

  AssetRegisterUseCases _useCases(BuildContext context) {
    final AppScope? scope = AppScope.maybeOf(context);
    if (scope != null) return scope.services.assets;
    return ref.read(appServicesProvider).assets;
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
      final List<FixedAsset> assets = await _useCases(context).listAssets();
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loading = false;
        if (_selectedId != null && assets.every((FixedAsset asset) => asset.id != _selectedId)) {
          _selectedId = null;
          _schedulePreview = null;
        }
      });
      if (_selectedId != null) await _loadSchedule(_selectedId!);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadSchedule(int id) async {
    try {
      final AssetRegisterUseCases useCases = _useCases(context);
      final FixedAsset? asset = await useCases.getAsset(id);
      if (!mounted || asset == null) return;
      const AssetScheduleService service = AssetScheduleService();
      final List<AssetScheduleRow> preview = asset.hasCanonicalInputs
          ? service.fullSchedule(asset)
          : <AssetScheduleRow>[service.computeRow(asset: asset, jahr: DateTime.now().year)];
      if (!mounted) return;
      setState(() {
        _schedulePreview = preview;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _select(int id) async {
    setState(() {
      _selectedId = id;
      _schedulePreview = null;
    });
    await _loadSchedule(id);
  }

  Future<void> _persistSchedule(int id) async {
    try {
      await _useCases(context).generateFullSchedule(id);
      if (!mounted) return;
      await _loadSchedule(id);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openForm({FixedAsset? existing}) async {
    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _AssetFormDialog(useCases: _useCases(context), existing: existing),
    );
    if (changed ?? false) await _reload();
  }

  Future<void> _delete(FixedAsset asset) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      await _useCases(context).deleteAsset(asset.id);
      if (!mounted) return;
      setState(() => _selectedId = null);
      await _reload();
    } on AssetInUseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.assetDeleteRefused)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _archive(FixedAsset asset) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      await _useCases(context).archiveAsset(asset.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.assetArchived)));
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
        title: l10n.assetRegisterTitle,
        subtitle: l10n.assetRegisterSubtitle,
        showFilterToolbar: false,
        primaryActionLabel: l10n.assetAdd,
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
                Expanded(child: Text(l10n.assetLoadFailed)),
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
    final List<FixedAsset> assets = _assets ?? const <FixedAsset>[];
    if (assets.isEmpty) {
      return AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inventory_2_outlined, size: 40),
            const SizedBox(height: 12),
            Text(l10n.assetEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => unawaited(_openForm()),
              icon: const Icon(Icons.add),
              label: Text(l10n.assetAdd),
            ),
          ],
        ),
      );
    }
    FixedAsset? selected;
    for (final FixedAsset candidate in assets) {
      if (candidate.id == _selectedId) selected = candidate;
    }
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        for (final FixedAsset asset in assets) _assetTile(context, l10n, asset, selected?.id == asset.id),
        if (selected != null) ...<Widget>[const SizedBox(height: 16), _inspector(context, l10n, selected)],
      ],
    );
  }

  Widget _assetTile(BuildContext context, AppLocalizations l10n, FixedAsset asset, bool isSelected) {
    final String readiness = !asset.hasCanonicalInputs
        ? l10n.assetUnresolved
        : asset.hasUnresolvedLegacy
        ? l10n.assetUnresolved
        : '${asset.assetTyp?.db ?? ''} · ${asset.kaufpreisNetto ?? ''}';
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        selected: isSelected,
        title: Text(asset.bezeichnung, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${asset.anschaffungsdatum} · ${asset.status} · $readiness',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: l10n.actionEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => unawaited(_openForm(existing: asset)),
            ),
            IconButton(
              tooltip: l10n.actionArchive,
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => unawaited(_archive(asset)),
            ),
            IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => unawaited(_delete(asset)),
            ),
          ],
        ),
        onTap: () => unawaited(_select(asset.id)),
      ),
    );
  }

  Widget _inspector(BuildContext context, AppLocalizations l10n, FixedAsset asset) {
    final List<AssetScheduleRow>? preview = _schedulePreview;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(asset.bezeichnung, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${asset.assetTyp?.db ?? '—'} · ${asset.kaufpreisNetto ?? asset.legacyAnschaffungskosten ?? '—'} · '
            '${asset.nutzungsdauerJahre ?? asset.legacyNutzungsdauer ?? '—'} · ${asset.status}',
          ),
          if (asset.hasUnresolvedLegacy) ...<Widget>[
            const SizedBox(height: 8),
            AppStatusChip(status: AppStatus.warning, label: l10n.assetUnresolved),
          ],
          const SizedBox(height: 12),
          Text(l10n.assetScheduleTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (preview == null)
            const LinearProgressIndicator()
          else
            for (final AssetScheduleRow row in preview) _scheduleRow(l10n, row),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => unawaited(_persistSchedule(asset.id)),
            icon: const Icon(Icons.calculate_outlined),
            label: Text(l10n.assetScheduleTitle),
          ),
        ],
      ),
    );
  }

  Widget _scheduleRow(AppLocalizations l10n, AssetScheduleRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 56, child: Text('${row.jahr}')),
          Expanded(
            child: row.isAvailable
                ? Text('${row.formel} = ${row.betrag}')
                : Text('${l10n.assetScheduleUnavailable}: ${row.blockierungsgrund ?? ''}'),
          ),
          const SizedBox(width: 8),
          AppStatusChip(
            status: row.isAvailable ? AppStatus.paid : AppStatus.warning,
            label: row.isAvailable ? (row.betrag ?? '') : l10n.assetScheduleUnavailable,
          ),
        ],
      ),
    );
  }
}

/// Create/edit form with per-field validation against the contract.
class _AssetFormDialog extends StatefulWidget {
  const _AssetFormDialog({required this.useCases, this.existing});

  final AssetRegisterUseCases useCases;
  final FixedAsset? existing;

  @override
  State<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<_AssetFormDialog> {
  late final TextEditingController _bezeichnung;
  late final TextEditingController _anschaffungsdatum;
  late final TextEditingController _kaufpreis;
  late final TextEditingController _nutzungsdauer;
  late final TextEditingController _privat;
  late final TextEditingController _kategorie;
  late final TextEditingController _verkauftAm;
  String _typ = 'EDV';
  String? _fieldError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final FixedAsset? existing = widget.existing;
    _bezeichnung = TextEditingController(text: existing?.bezeichnung ?? '');
    _typ = existing?.assetTyp?.db ?? 'EDV';
    _anschaffungsdatum = TextEditingController(text: existing?.anschaffungsdatum ?? '');
    _kaufpreis = TextEditingController(text: existing?.kaufpreisNetto ?? '');
    _nutzungsdauer = TextEditingController(text: existing?.nutzungsdauerJahre?.toString() ?? '');
    _privat = TextEditingController(text: existing?.privatAnteilProzent ?? '0');
    _kategorie = TextEditingController(text: existing?.kategorieId?.toString() ?? '');
    _verkauftAm = TextEditingController(text: existing?.verkauftAm ?? '');
  }

  @override
  void dispose() {
    _bezeichnung.dispose();
    _anschaffungsdatum.dispose();
    _kaufpreis.dispose();
    _nutzungsdauer.dispose();
    _privat.dispose();
    _kategorie.dispose();
    _verkauftAm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final int? life = int.tryParse(_nutzungsdauer.text.trim());
    final String? invalid = validateNewAssetInputs(
      bezeichnung: _bezeichnung.text,
      assetTyp: _typ,
      anschaffungsdatum: _anschaffungsdatum.text,
      kaufpreisNetto: _kaufpreis.text,
      nutzungsdauerJahre: life,
      afaMethode: 'linear',
      privatAnteilProzent: _privat.text.trim().isEmpty ? '0' : _privat.text,
    );
    if (invalid != null) {
      setState(() => _fieldError = l10n.assetInvalidField(invalid));
      return;
    }
    setState(() {
      _saving = true;
      _fieldError = null;
    });
    try {
      final AssetRegisterUseCases useCases = widget.useCases;
      final int? kategorieId = int.tryParse(_kategorie.text.trim());
      if (widget.existing == null) {
        await useCases.createAsset(
          bezeichnung: _bezeichnung.text,
          assetTyp: _typ,
          anschaffungsdatum: _anschaffungsdatum.text,
          kaufpreisNetto: _kaufpreis.text,
          nutzungsdauerJahre: life!,
          privatAnteilProzent: _privat.text.trim().isEmpty ? '0' : _privat.text,
          kategorieId: kategorieId,
          verkauftAm: _verkauftAm.text.trim().isEmpty ? null : _verkauftAm.text,
        );
      } else {
        await useCases.updateAsset(
          widget.existing!.id,
          bezeichnung: _bezeichnung.text,
          assetTyp: _typ,
          anschaffungsdatum: _anschaffungsdatum.text,
          kaufpreisNetto: _kaufpreis.text,
          nutzungsdauerJahre: life,
          privatAnteilProzent: _privat.text.trim().isEmpty ? '0' : _privat.text,
          kategorieId: kategorieId,
          verkauftAm: _verkauftAm.text.trim().isEmpty ? null : _verkauftAm.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final String field = error is AssetValidationException ? error.field : '';
      setState(() {
        _saving = false;
        _fieldError = field.isEmpty ? error.toString() : l10n.assetInvalidField(field);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.assetAdd : l10n.assetEdit),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _bezeichnung,
                decoration: InputDecoration(labelText: l10n.assetDescription),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _typ,
                decoration: InputDecoration(labelText: l10n.assetType),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'KFZ', child: Text('KFZ')),
                  DropdownMenuItem<String>(value: 'EDV', child: Text('EDV')),
                  DropdownMenuItem<String>(value: 'sonstig', child: Text('sonstig')),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _typ = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _anschaffungsdatum,
                decoration: InputDecoration(labelText: l10n.assetAcquisitionDate, hintText: '2022-06-15'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _kaufpreis,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.assetNetPrice),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nutzungsdauer,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.assetUsefulLife),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _privat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.assetPrivateShare),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _kategorie,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.assetCategory),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _verkauftAm,
                decoration: InputDecoration(labelText: l10n.assetDisposalDate, hintText: '2025-06-15'),
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
