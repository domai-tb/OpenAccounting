import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/router/route_data_repository.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/design_system/components/skeleton.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

/// A consistent, task-oriented list surface for the accounting workspaces.
///
/// The database row stays at the data boundary. This widget deliberately
/// maps it to a small set of user-facing fields instead of exposing column
/// names or a diagnostic query status.
class FinanceListSurface extends ConsumerStatefulWidget {
  const FinanceListSurface({
    required this.table,
    required this.title,
    required this.icon,
    this.subtitle,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.emptyTitle,
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.filterTyp,
    this.filterStatus,
    this.onOpen,
    super.key,
  });

  final String table;
  final String title;
  final IconData icon;
  final String? subtitle;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final String? filterTyp;
  final String? filterStatus;
  final void Function(int id, Map<String, Object?> row)? onOpen;

  @override
  ConsumerState<FinanceListSurface> createState() => _FinanceListSurfaceState();
}

class _FinanceListSurfaceState extends ConsumerState<FinanceListSurface> {
  late final TextEditingController _searchController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RouteRecordsQuery? query = widget.filterTyp == null && widget.filterStatus == null
        ? null
        : RouteRecordsQuery(table: widget.table, typ: widget.filterTyp, status: widget.filterStatus);
    final FutureProvider<List<Map<String, Object?>>> source = query == null
        ? routeRecordsProvider(widget.table)
        : routeRecordsQueryProvider(query);
    final AsyncValue<List<Map<String, Object?>>> records = ref.watch(source);
    return AppPage(
      maxWidth: 1180,
      header: AppPageHeader(
        title: widget.title,
        subtitle: widget.subtitle,
        searchController: _searchController,
        searchHint: '${widget.title} durchsuchen…',
        onSearchChanged: (String value) => setState(() => _search = value.trim().toLowerCase()),
        primaryActionLabel: widget.primaryActionLabel,
        onPrimaryAction: widget.onPrimaryAction,
        resultCount: records.hasValue ? _filteredRows(records.value!).length : null,
        resultCountLabelBuilder: _countLabel,
      ),
      child: records.when(
        loading: _buildLoading,
        error: (Object error, StackTrace stackTrace) => _buildError(context, error, stackTrace, source),
        data: (List<Map<String, Object?>> rows) => _buildData(context, rows, source),
      ),
    );
  }

  Widget _buildLoading() {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < 5; index++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  SkeletonBox(width: 40, height: 40),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SkeletonBox(width: 220, height: 16),
                        SizedBox(height: AppSpacing.sm),
                        SkeletonBox(width: 320, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.lg),
                  SkeletonBox(width: 100, height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
    FutureProvider<List<Map<String, Object?>>> source,
  ) {
    debugPrint('route ${widget.table} failed: $error\n$stackTrace');
    return AppCard(
      child: _CenteredState(
        icon: Icons.cloud_off_outlined,
        title: 'Daten konnten nicht geladen werden',
        message: 'Prüfe die lokale Datenbank und versuche es erneut.',
        actionLabel: 'Erneut versuchen',
        onAction: () => ref.invalidate(source),
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    List<Map<String, Object?>> rows,
    FutureProvider<List<Map<String, Object?>>> source,
  ) {
    final List<Map<String, Object?>> filtered = _filteredRows(rows);
    if (filtered.isEmpty) {
      final bool isFiltered = _search.isNotEmpty;
      return AppCard(
        child: _CenteredState(
          icon: isFiltered ? Icons.search_off : widget.icon,
          title: isFiltered ? 'Keine Treffer' : (widget.emptyTitle ?? 'Noch keine Einträge'),
          message: isFiltered
              ? 'Passe deine Suche an oder setze sie zurück.'
              : (widget.emptyMessage ?? 'Sobald du Daten anlegst, erscheinen sie hier.'),
          actionLabel: isFiltered ? 'Suche zurücksetzen' : widget.emptyActionLabel,
          onAction: isFiltered
              ? () {
                  _searchController.clear();
                  setState(() => _search = '');
                }
              : widget.onEmptyAction,
          secondaryActionLabel: 'Aktualisieren',
          onSecondaryAction: () => ref.invalidate(source),
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _ListSummary(count: filtered.length, label: _countLabel(filtered.length)),
          const Divider(height: 1),
          for (int index = 0; index < filtered.length; index++) ...<Widget>[
            _FinanceRow(
              table: widget.table,
              row: filtered[index],
              onTap: () {
                final int? id = _recordId(filtered[index]);
                if (id != null) widget.onOpen?.call(id, filtered[index]);
              },
            ),
            if (index < filtered.length - 1) const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }

  List<Map<String, Object?>> _filteredRows(List<Map<String, Object?>> rows) {
    if (_search.isEmpty) return rows;
    return rows
        .where((Map<String, Object?> row) {
          final String text = row.values.map((Object? value) => value?.toString() ?? '').join(' ').toLowerCase();
          return text.contains(_search);
        })
        .toList(growable: false);
  }

  String _countLabel(int count) {
    final String noun = widget.table == 'rechnungen'
        ? 'Rechnungen'
        : widget.table == 'kunden'
        ? 'Kontakte'
        : widget.table == 'belege'
        ? 'Belege'
        : widget.table == 'journal'
        ? 'Buchungen'
        : 'Einträge';
    return '$count $noun';
  }
}

class _ListSummary extends StatelessWidget {
  const _ListSummary({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Text('$count Ergebnisse', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({required this.table, required this.row, this.onTap});

  final String table;
  final Map<String, Object?> row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final int? id = _recordId(row);
    final String title = _recordTitle(table, row, id);
    final String subtitle = _recordSubtitle(table, row);
    final String? amount = _recordAmount(table, row);
    final String? status = _recordStatus(row);
    final Widget leading = CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
      child: Icon(_iconFor(table), size: 20),
    );
    return Semantics(
      button: onTap != null,
      label: [title, subtitle, ?status, ?amount].join(', '),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: <Widget>[
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (status != null) ...<Widget>[
                AppStatusChip(status: _statusFor(status), label: status),
                const SizedBox(width: 16),
              ],
              if (amount != null)
                SizedBox(
                  width: 120,
                  child: Text(
                    amount,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
          if (secondaryActionLabel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!)),
          ],
        ],
      ),
    );
  }
}

int? _recordId(Map<String, Object?> row) {
  final Object? value = row['id'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _recordTitle(String table, Map<String, Object?> row, int? id) {
  final Object? value = switch (table) {
    'rechnungen' => row['rechnungsnummer'] ?? row['typ'],
    'kunden' => row['name'] ?? row['firma'],
    'belege' => row['dateiname'] ?? row['beschreibung'],
    'journal' => row['beschreibung'] ?? row['beleg_typ'],
    _ => row['name'] ?? row['beschreibung'] ?? row['typ'],
  };
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty) return 'Eintrag #${id ?? '?'}';
  if (table == 'rechnungen' && text == 'rechnung') return 'Entwurf #${id ?? '?'}';
  return text;
}

String _recordSubtitle(String table, Map<String, Object?> row) {
  final List<String> values = <String>[];
  if (table == 'rechnungen' || table == 'belege' || table == 'journal') {
    final String date = row['datum']?.toString().trim() ?? '';
    if (date.isNotEmpty) values.add(_formatDate(date));
  }
  if (table == 'rechnungen') {
    final String type = _documentTypeLabel(row['typ']?.toString());
    if (type.isNotEmpty) values.add(type);
  }
  if (table == 'kunden') {
    final String email = row['email']?.toString().trim() ?? '';
    final String city = row['ort']?.toString().trim() ?? '';
    if (email.isNotEmpty) values.add(email);
    if (city.isNotEmpty) values.add(city);
  }
  if (table == 'belege') {
    final String category = row['kategorie']?.toString().trim() ?? '';
    if (category.isNotEmpty) values.add(category);
  }
  return values.join(' · ');
}

String? _recordStatus(Map<String, Object?> row) {
  final String value = row['status']?.toString().trim() ?? '';
  return value.isEmpty ? null : _statusLabel(value);
}

String? _recordAmount(String table, Map<String, Object?> row) {
  if (table != 'rechnungen' && table != 'belege' && table != 'journal') return null;
  final Object? raw = row['brutto_betrag'] ?? row['betrag'] ?? row['summe'] ?? row['netto_betrag'];
  final num? value = raw is num ? raw : num.tryParse(raw?.toString().replaceAll(',', '.') ?? '');
  if (value == null) return null;
  return formatMoney(value);
}

IconData _iconFor(String table) {
  return switch (table) {
    'rechnungen' => Icons.receipt_long,
    'kunden' => Icons.person_outline,
    'belege' => Icons.receipt_outlined,
    'journal' => Icons.account_balance_outlined,
    _ => Icons.description_outlined,
  };
}

AppStatus _statusFor(String value) {
  final String normalized = value.toLowerCase();
  if (normalized.contains('bezahlt') || normalized.contains('paid')) return AppStatus.paid;
  if (normalized.contains('überf') || normalized.contains('overdue')) return AppStatus.overdue;
  if (normalized.contains('entwurf') || normalized.contains('draft')) return AppStatus.draft;
  if (normalized.contains('prüfung') || normalized.contains('review')) return AppStatus.warning;
  if (normalized.contains('offen') || normalized.contains('open')) return AppStatus.info;
  return AppStatus.neutral;
}

String _statusLabel(String value) {
  return switch (value.toLowerCase()) {
    'open' => 'Offen',
    'paid' => 'Bezahlt',
    'overdue' => 'Überfällig',
    'draft' => 'Entwurf',
    _ => value,
  };
}

String _documentTypeLabel(String? value) {
  return switch (value) {
    'rechnung' => 'Rechnung',
    'gutschrift' => 'Gutschrift',
    'storno' => 'Storno',
    'angebot' => 'Angebot',
    'auftrag' => 'Auftrag',
    'proforma' => 'Proforma',
    'lieferschein' => 'Lieferschein',
    _ => value ?? '',
  };
}

String _formatDate(String value) {
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final String day = parsed.day.toString().padLeft(2, '0');
  final String month = parsed.month.toString().padLeft(2, '0');
  return '$day.$month.${parsed.year}';
}
