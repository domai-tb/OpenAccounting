import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Receipt inbox: import, review, preview, and link supporting evidence.
///
/// List/detail/preview layout at wide widths; responsive single-column with
/// sequential tabs below 900px. Preview never navigates away from the record
/// or changes its review status.
class ReceiptInboxPage extends ConsumerStatefulWidget {
  const ReceiptInboxPage({super.key});

  @override
  ConsumerState<ReceiptInboxPage> createState() => _ReceiptInboxPageState();
}

class _ReceiptInboxPageState extends ConsumerState<ReceiptInboxPage> {
  List<Map<String, Object?>> _inbox = const <Map<String, Object?>>[];
  Map<String, Object?>? _selected;
  String? _previewUnavailable;
  bool _loading = true;
  String? _error;

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<Map<String, Object?>> rows = await AppScope.of(context).services.receipts.listInbox();
      if (!mounted) return;
      setState(() {
        _inbox = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _preview(int belegId) async {
    final result = await AppScope.of(context).services.receipts.previewSource(belegId);
    if (!mounted) return;
    setState(() {
      _previewUnavailable = result.unavailable;
    });
    if (result.unavailable != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.unavailable!)));
    }
  }

  Future<void> _markReviewed(int belegId) async {
    await AppScope.of(context).services.receipts.markReviewed(belegId: belegId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      header: AppPageHeader(
        title: l10n.receiptInboxTitle,
        subtitle: l10n.receiptInboxSubtitle,
        showFilterToolbar: false,
        actions: <Widget>[IconButton(icon: const Icon(Icons.refresh), tooltip: l10n.actionReload, onPressed: _reload)],
      ),
      maxWidth: 1200,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(child: Text(_error!, semanticsLabel: _error));
          }
          if (_inbox.isEmpty) {
            return Center(child: Text(l10n.emptyEntries, semanticsLabel: l10n.emptyEntries));
          }
          final Widget list = _InboxList(
            inbox: _inbox,
            selectedId: _selected?['id'] as int?,
            onSelect: (Map<String, Object?> row) => setState(() {
              _selected = row;
              _previewUnavailable = null;
            }),
          );
          final Widget detail = _InboxDetail(
            selected: _selected,
            previewUnavailable: _previewUnavailable,
            onPreview: _preview,
            onReviewed: _markReviewed,
            onCreateIncomingInvoice: (int id) => context.go('/receipts/$id/capture'),
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 2, child: list),
                const VerticalDivider(),
                Expanded(flex: 3, child: detail),
              ],
            );
          }
          return DefaultTabController(
            length: 2,
            child: Column(
              children: <Widget>[
                TabBar(
                  tabs: <Widget>[
                    Tab(text: l10n.receiptInboxTitle),
                    Tab(text: l10n.receiptPreviewAction),
                  ],
                ),
                Expanded(child: TabBarView(children: <Widget>[list, detail])),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({required this.inbox, required this.selectedId, required this.onSelect});

  final List<Map<String, Object?>> inbox;
  final int? selectedId;
  final ValueChanged<Map<String, Object?>> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: inbox.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, Object?> row = inbox[index];
        final int id = (row['id']! as num).toInt();
        final String status = (row['status'] ?? 'neu').toString();
        return Semantics(
          button: true,
          selected: selectedId == id,
          label: 'Beleg $id, $status',
          child: ListTile(
            title: Text((row['original_name'] ?? row['dateiname'] ?? 'Beleg $id').toString()),
            subtitle: Text(status),
            trailing: AppStatusChip(
              status: status.startsWith('verknuepft')
                  ? AppStatus.paid
                  : status.startsWith('geprueft')
                  ? AppStatus.info
                  : AppStatus.draft,
              label: status,
            ),
            selected: selectedId == id,
            onTap: () => onSelect(row),
          ),
        );
      },
    );
  }
}

class _InboxDetail extends StatelessWidget {
  const _InboxDetail({
    required this.selected,
    required this.previewUnavailable,
    required this.onPreview,
    required this.onReviewed,
    required this.onCreateIncomingInvoice,
  });

  final Map<String, Object?>? selected;
  final String? previewUnavailable;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onReviewed;
  final ValueChanged<int> onCreateIncomingInvoice;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Map<String, Object?>? row = selected;
    if (row == null) {
      return Center(child: Text(l10n.emptyEntries, semanticsLabel: l10n.emptyEntries));
    }
    final int id = (row['id']! as num).toInt();
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.receiptDetailTitle('$id'),
            style: Theme.of(context).textTheme.titleLarge,
            semanticsLabel: l10n.receiptDetailTitle('$id'),
          ),
          const SizedBox(height: 8),
          if (previewUnavailable != null) AppStatusChip(status: AppStatus.warning, label: previewUnavailable!),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              FilledButton.tonal(onPressed: () => onPreview(id), child: Text(l10n.receiptPreviewAction)),
              OutlinedButton(onPressed: () => onReviewed(id), child: Text(l10n.receiptReviewAction)),
              if ((row['status']?.toString().startsWith('geprueft') ?? false) &&
                  ((row['original_name'] ?? row['dateiname'])?.toString().toLowerCase().endsWith('.pdf') == true ||
                      (row['original_name'] ?? row['dateiname'])?.toString().toLowerCase().endsWith('.xml') == true))
                FilledButton(
                  key: const ValueKey<String>('receipt_create_incoming_invoice'),
                  onPressed: () => onCreateIncomingInvoice(id),
                  child: Text(l10n.incomingInvoiceCaptureAction),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
