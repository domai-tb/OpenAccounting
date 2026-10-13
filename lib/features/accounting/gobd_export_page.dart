import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/accounting/gobd_export_service.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// GoBD audit export: period selection, export, and verification.
///
/// Displays the selected period, included/missing counts, generation and
/// verification state, and save action. Missing artifacts make the result
/// explicitly incomplete. Integrity success is never shown as legal
/// certification.
class GobdExportPage extends ConsumerStatefulWidget {
  const GobdExportPage({super.key});

  @override
  ConsumerState<GobdExportPage> createState() => _GobdExportPageState();
}

class _GobdExportPageState extends ConsumerState<GobdExportPage> {
  final TextEditingController _from = TextEditingController(text: '2026-01-01');
  final TextEditingController _to = TextEditingController(text: '2026-12-31');
  GobdInventory? _inventory;
  GobdExportResult? _result;
  GobdVerification? _verification;
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _working = true;
      _error = null;
      _result = null;
      _verification = null;
    });
    try {
      final GobdExportService service = AppScope.of(context).services.gobd;
      final GobdInventory inventory = await service.buildInventory(
        periodStart: _from.text.trim(),
        periodEnd: _to.text.trim(),
      );
      final GobdExportResult result = await service.generate(inventory);
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _result = result;
        _working = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _working = false;
      });
    }
  }

  void _verify() {
    final GobdExportResult? result = _result;
    if (result == null) return;
    setState(() {
      _verification = GobdExportService.verifyArchive(result.archiveBytes, result.manifest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      header: AppPageHeader(title: l10n.gobdExportTitle, subtitle: l10n.gobdExportSubtitle, showFilterToolbar: false),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _from,
                    decoration: const InputDecoration(labelText: 'Von (JJJJ-MM-TT)'),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _to,
                    decoration: const InputDecoration(labelText: 'Bis (JJJJ-MM-TT)'),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                FilledButton(onPressed: _working ? null : _generate, child: Text(l10n.actionImport)),
                OutlinedButton(onPressed: _result == null ? null : _verify, child: Text(l10n.gobdVerifyAction)),
              ],
            ),
            const SizedBox(height: 12),
            if (_working) const LinearProgressIndicator(),
            if (_error != null) AppStatusChip(status: AppStatus.overdue, label: _error!),
            if (_inventory != null)
              AppStatusChip(
                status: _inventory!.complete ? AppStatus.paid : AppStatus.warning,
                label: _inventory!.complete ? '${_inventory!.records.length} Datensätze' : l10n.gobdIncomplete,
              ),
            if (_inventory != null && _inventory!.missing.isNotEmpty)
              Semantics(
                label: l10n.gobdIncomplete,
                child: Text(_inventory!.missing.join('\n'), style: Theme.of(context).textTheme.bodySmall),
              ),
            if (_verification != null)
              AppStatusChip(
                status: _verification!.valid ? AppStatus.paid : AppStatus.overdue,
                label: _verification!.valid ? l10n.gobdVerifyAction : (_verification!.problem ?? l10n.gobdIncomplete),
              ),
          ],
        ),
      ),
    );
  }
}
