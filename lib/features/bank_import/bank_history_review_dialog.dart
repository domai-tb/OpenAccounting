import 'package:flutter/material.dart';
import 'package:openaccounting/features/bank_import/banking_usecase.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Manual review dialog for one history attempt: unresolved rows with
/// category confirm and journal-link actions. Review never creates postings
/// or payments; confirmed rows leave the unresolved set.
class HistoryReviewDialog extends StatefulWidget {
  const HistoryReviewDialog({
    required this.banking,
    required this.importId,
    required this.initialRows,
    required this.categories,
    required this.onChanged,
    super.key,
  });

  final BankingUseCase banking;
  final int importId;
  final List<Map<String, Object?>> initialRows;
  final List<({int id, String name})> categories;
  final VoidCallback onChanged;

  @override
  State<HistoryReviewDialog> createState() => _HistoryReviewDialogState();
}

class _HistoryReviewDialogState extends State<HistoryReviewDialog> {
  late List<Map<String, Object?>> _rows;
  final Map<int, int?> _selectedCategories = <int, int?>{};
  final Map<int, TextEditingController> _journalControllers = <int, TextEditingController>{};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rows = List<Map<String, Object?>>.from(widget.initialRows);
  }

  @override
  void dispose() {
    for (final c in _journalControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _rowId(Map<String, Object?> row) => (row['id']! as num).toInt();

  Future<void> _reload() async {
    try {
      final List<Map<String, Object?>> rows = await widget.banking.service.unresolvedReviewRows(
        importId: widget.importId,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmCategory(Map<String, Object?> row) async {
    final int? kategorieId = _selectedCategories[_rowId(row)] ?? (row['kategorie_id'] as num?)?.toInt();
    if (kategorieId == null) {
      setState(() => _error = appLocalizationsOf(context).bankRuleCategory);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.banking.service.reviewTransaction(id: _rowId(row), kategorieId: kategorieId);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkJournal(Map<String, Object?> row) async {
    final TextEditingController controller = _journalControllers.putIfAbsent(_rowId(row), TextEditingController.new);
    final int? journalId = int.tryParse(controller.text.trim());
    if (journalId == null) {
      setState(() => _error = appLocalizationsOf(context).bankHistoryReview);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.banking.service.reviewTransaction(id: _rowId(row), journalId: journalId);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AlertDialog(
      title: Text(l10n.bankHistoryReview),
      content: SizedBox(
        width: 640,
        child: _rows.isEmpty
            ? Text(l10n.emptyEntries)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final row in _rows)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('${row['datum']} · ${row['betrag']} · ${row['verwendungszweck']}'),
                              DropdownButtonFormField<int>(
                                initialValue: (row['kategorie_id'] as num?)?.toInt(),
                                decoration: InputDecoration(labelText: l10n.bankRuleCategory),
                                items: <DropdownMenuItem<int>>[
                                  for (final c in widget.categories)
                                    DropdownMenuItem<int>(value: c.id, child: Text(c.name)),
                                ],
                                onChanged: (int? value) => setState(() => _selectedCategories[_rowId(row)] = value),
                              ),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: TextField(
                                      controller: _journalControllers.putIfAbsent(
                                        _rowId(row),
                                        TextEditingController.new,
                                      ),
                                      decoration: const InputDecoration(labelText: 'Journal-ID'),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy ? null : () => _confirmCategory(row),
                                    child: Text(l10n.bankHistoryReview),
                                  ),
                                  TextButton(
                                    onPressed: _busy ? null : () => _linkJournal(row),
                                    child: const Text('Link'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
      ),
      actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionClose))],
    );
  }
}
