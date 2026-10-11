import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/inventory/stocktake_entity.dart';
import 'package:openaccounting/features/inventory/stocktake_providers.dart';
import 'package:openaccounting/features/inventory/stocktake_repository.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Typed `/inventory` workspace: drafts, recording, and read-only history.
/// Recorded history stays readable while inventory is disabled (sole
/// global-toggle exception); new drafts and edits stay unavailable then.
/// Book quantities, variances, and valuation render as explicit unavailable
/// states — current stock or prices are never substituted.
class StocktakeWorkspacePage extends ConsumerWidget {
  const StocktakeWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AsyncValue<bool> enabled = ref.watch(stocktakeEnabledProvider);
    return enabled.when(
      loading: () => AppPage(
        header: AppPageHeader(title: l10n.inventoryTitle, showFilterToolbar: false),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) =>
          _StocktakeError(onRetry: () => ref.invalidate(stocktakeEnabledProvider)),
      data: (bool isEnabled) {
        if (!isEnabled) return const _DisabledStocktakeView();
        return const _EnabledStocktakeView();
      },
    );
  }
}

/// Disabled inventory: recorded history stays readable, everything else is
/// unavailable. With no history this is exactly the established boundary.
class _DisabledStocktakeView extends ConsumerWidget {
  const _DisabledStocktakeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Stocktake>> history = ref.watch(stocktakeHistoryProvider);
    return history.when(
      loading: () => AppPage(
        header: AppPageHeader(title: appLocalizationsOf(context).inventoryTitle, showFilterToolbar: false),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) =>
          _StocktakeError(onRetry: () => ref.invalidate(stocktakeHistoryProvider)),
      data: (List<Stocktake> items) {
        if (items.isEmpty) return const InventoryUnavailablePage();
        final AppLocalizations l10n = appLocalizationsOf(context);
        return AppPage(
          header: AppPageHeader(title: l10n.inventoryTitle, subtitle: l10n.stocktakeHistoryTitle),
          child: ListView(
            children: <Widget>[
              AppCard(
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.block_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.stocktakeDisabledNew, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(l10n.inventoryReadOnly, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final Stocktake item in items) ...<Widget>[_RecordedCard(item: item), const SizedBox(height: 12)],
            ],
          ),
        );
      },
    );
  }
}

class _EnabledStocktakeView extends ConsumerWidget {
  const _EnabledStocktakeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AsyncValue<List<Stocktake>> drafts = ref.watch(stocktakeDraftsProvider);
    final AsyncValue<List<Stocktake>> history = ref.watch(stocktakeHistoryProvider);
    void refresh() {
      ref.invalidate(stocktakeDraftsProvider);
      ref.invalidate(stocktakeHistoryProvider);
    }

    return AppPage(
      header: AppPageHeader(title: l10n.inventoryTitle, subtitle: l10n.stocktakeHistoryTitle),
      child: ListView(
        children: <Widget>[
          _NewDraftCard(onCreated: refresh),
          const SizedBox(height: 16),
          drafts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => _StocktakeErrorInline(onRetry: refresh),
            data: (List<Stocktake> items) => Column(
              children: <Widget>[
                for (final Stocktake item in items) ...<Widget>[_DraftCard(item: item, onChanged: refresh)],
              ],
            ),
          ),
          const SizedBox(height: 16),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => _StocktakeErrorInline(onRetry: refresh),
            data: (List<Stocktake> items) {
              if (items.isEmpty && (drafts.asData?.value ?? const <Stocktake>[]).isEmpty) {
                return AppCard(child: Center(child: Text(l10n.stocktakeEmpty)));
              }
              return Column(
                children: <Widget>[
                  for (final Stocktake item in items) ...<Widget>[
                    _RecordedCard(item: item),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NewDraftCard extends ConsumerStatefulWidget {
  const _NewDraftCard({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_NewDraftCard> createState() => _NewDraftCardState();
}

class _NewDraftCardState extends ConsumerState<_NewDraftCard> {
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String stichtag = _dateController.text.trim();
    if (!_isIsoDate(stichtag)) {
      setState(() => _error = l10n.stocktakeInvalidDate);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(stocktakeUseCasesProvider).startDraft(stichtag: stichtag);
      widget.onCreated();
    } on StocktakeNoCountableArticlesException {
      if (mounted) setState(() => _error = l10n.stocktakeNoCountable);
    } on StocktakeException catch (error) {
      if (mounted) setState(() => _error = _technicalMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.stocktakeNewAction, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _dateController,
            decoration: InputDecoration(
              labelText: l10n.stocktakeStichtagLabel,
              hintText: '2026-01-31',
              errorText: _error,
            ),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _create,
            icon: _saving
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: Text(l10n.stocktakeNewAction),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends ConsumerStatefulWidget {
  const _DraftCard({required this.item, required this.onChanged});

  final Stocktake item;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends ConsumerState<_DraftCard> {
  final Map<int, TextEditingController> _controllers = <int, TextEditingController>{};
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(StocktakePosition position) {
    return _controllers.putIfAbsent(position.artikelId, () {
      final Object? menge = position.mengeGezaehlt;
      return TextEditingController(text: menge == null ? '' : menge.toString());
    });
  }

  num? _parseCount(String value) {
    final String normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return num.tryParse(normalized);
  }

  Future<void> _saveAndRecord({required bool record}) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final useCases = ref.read(stocktakeUseCasesProvider);
      final Map<int, num?> counts = <int, num?>{};
      for (final StocktakePosition position in widget.item.positionen) {
        final String input = _controllerFor(position).text;
        final num? menge = _parseCount(input);
        if (input.trim().isNotEmpty && menge == null) throw const StocktakeException('count-invalid');
        if (menge != null) {
          if (!menge.isFinite) throw const StocktakeException('count-not-finite');
          if (menge < 0) throw const StocktakeException('count-negative');
          final double scaled = menge * 1000;
          if (!scaled.isFinite || (scaled - scaled.round()).abs() > 1e-9) {
            throw const StocktakeException('count-precision');
          }
        }
        counts[position.artikelId] = menge;
      }
      await useCases.saveCounts(inventurId: widget.item.id, counts: counts, record: record);
      widget.onChanged();
    } on StocktakeMissingCountException {
      if (mounted) setState(() => _error = l10n.stocktakeMissingCount);
    } on StocktakeNoCountableArticlesException {
      if (mounted) setState(() => _error = l10n.stocktakeNoCountable);
    } on StocktakeException catch (error) {
      if (mounted) setState(() => _error = _technicalMessage(l10n, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String locale = localeTag(Localizations.localeOf(context));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${l10n.stocktakeStichtagLabel}: ${_formatIsoDate(widget.item.stichtag, locale)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppStatusChip(status: AppStatus.draft, label: l10n.stocktakeDraftStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text('${l10n.stocktakeArticleColumn} (${widget.item.positionen.length})'),
          const SizedBox(height: 8),
          for (final StocktakePosition position in widget.item.positionen)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _controllerFor(position),
                decoration: InputDecoration(
                  labelText: '${position.bezeichnungSnapshot} · ${position.einheitSnapshot}',
                  hintText: l10n.stocktakeCountLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _saveAndRecord(record: false),
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.actionSave),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _saveAndRecord(record: true),
                icon: const Icon(Icons.check),
                label: Text(l10n.stocktakeRecordAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recorded result: physical counts for the reporting date. Book quantity and
/// variance stay unavailable; valuation stays unavailable without a policy.
class _RecordedCard extends StatelessWidget {
  const _RecordedCard({required this.item});

  final Stocktake item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String locale = localeTag(Localizations.localeOf(context));
    return Semantics(
      label: '${l10n.stocktakeRecordedStatus} ${item.stichtag}',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${l10n.stocktakeStichtagLabel}: ${_formatIsoDate(item.stichtag, locale)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                AppStatusChip(status: AppStatus.neutral, label: l10n.stocktakeRecordedStatus),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.stocktakeCapturedAt}: ${_formatIsoTimestamp(item.erstelltAm, locale)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            for (final StocktakePosition position in item.positionen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text('${position.bezeichnungSnapshot} · ${position.einheitSnapshot}')),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          _formatCount(position.mengeGezaehlt, locale),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(l10n.stocktakePhysicalCount, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            _UnavailableRow(icon: Icons.block_outlined, text: l10n.stocktakeBookUnavailable),
            const SizedBox(height: 4),
            _UnavailableRow(icon: Icons.block_outlined, text: l10n.stocktakeVarianceUnavailable),
            const SizedBox(height: 4),
            _UnavailableRow(icon: Icons.block_outlined, text: l10n.stocktakeValuationUnavailable),
            const SizedBox(height: 4),
            Text(l10n.stocktakeValuationDescription, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(l10n.stocktakeCorrectionHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _UnavailableRow extends StatelessWidget {
  const _UnavailableRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}

class _StocktakeError extends StatelessWidget {
  const _StocktakeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      header: AppPageHeader(title: l10n.inventoryTitle, showFilterToolbar: false),
      child: AppCard(child: _StocktakeErrorBody(onRetry: onRetry)),
    );
  }
}

class _StocktakeErrorInline extends StatelessWidget {
  const _StocktakeErrorInline({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppCard(child: _StocktakeErrorBody(onRetry: onRetry));
}

class _StocktakeErrorBody extends StatelessWidget {
  const _StocktakeErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(l10n.loadError, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.databaseUnavailable, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(l10n.actionRetry)),
        ],
      ),
    );
  }
}

bool _isIsoDate(String value) {
  final DateTime? parsed = DateTime.tryParse(value);
  return parsed != null && value.length == 10 && parsed.toIso8601String().substring(0, 10) == value;
}

String _formatIsoDate(String value, String locale) {
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return formatDate(parsed, locale: locale);
}

String _formatIsoTimestamp(String value, String locale) {
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${formatDate(parsed, locale: locale)} ${parsed.toIso8601String().substring(11, 16)}';
}

/// Locale-aware count display; storage stays locale-independent.
String _formatCount(num? value, String locale) {
  if (value == null) return '—';
  return intl.NumberFormat('0.###', locale).format(value);
}

/// Maps technical guard failures to localized validation copy.
String _technicalMessage(AppLocalizations l10n, StocktakeException error) {
  return switch (error.message) {
    'count-invalid' => l10n.stocktakeInvalidCount,
    'count-not-finite' => l10n.stocktakeInvalidCount,
    'count-negative' => l10n.stocktakeNegativeForbidden,
    'count-precision' => l10n.stocktakePrecisionInvalid,
    'invalid-stichtag' => l10n.stocktakeInvalidDate,
    'missing-count' => l10n.stocktakeMissingCount,
    'recorded-immutable' => l10n.stocktakeCorrectionHint,
    'inventory-disabled' => l10n.stocktakeDisabledNew,
    'no-countable-articles' => l10n.stocktakeNoCountable,
    _ => l10n.dataLoadError,
  };
}
