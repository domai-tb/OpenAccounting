import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/accounting/reporting/report_catalog_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';
import 'package:openaccounting/l10n/l10n.dart';

class ReportCatalogPage extends StatefulWidget {
  const ReportCatalogPage({required this.scope, required this.catalog, super.key});

  final ReportCatalogScope scope;
  final ReportCatalogUseCase catalog;

  @override
  State<ReportCatalogPage> createState() => _ReportCatalogPageState();
}

class _ReportCatalogPageState extends State<ReportCatalogPage> {
  late final Future<List<ReportCatalogEntry>> _entries = widget.catalog.list(widget.scope);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String title = widget.scope == ReportCatalogScope.reports ? l10n.routeReports : l10n.routeTaxes;
    return AppPage(
      header: AppPageHeader(title: title, showFilterToolbar: false),
      child: FutureBuilder<List<ReportCatalogEntry>>(
        future: _entries,
        builder: (BuildContext context, AsyncSnapshot<List<ReportCatalogEntry>> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.workspaceUnavailable));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            key: const ValueKey<String>('report-catalog'),
            children: snapshot.data!
                .map((ReportCatalogEntry entry) {
                  final bool available = entry.availability == ReportAvailability.available;
                  final String period = entry.period.isEmpty ? '' : ' · ${entry.period}';
                  final String status = available ? l10n.reportStatusAvailable : l10n.reportStatusUnavailable;
                  return ListTile(
                    key: ValueKey<String>('report-catalog-${entry.kind.name}'),
                    title: Text(_titleFor(l10n, entry.kind)),
                    subtitle: Text('$status$period'),
                    trailing: Icon(available ? Icons.check_circle_outline : Icons.info_outline),
                    onTap: () => context.go(entry.route),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, ReportCatalogKind kind) => switch (kind) {
    ReportCatalogKind.euer => l10n.reportCatalogEuer,
    ReportCatalogKind.eks => l10n.reportCatalogEks,
    ReportCatalogKind.guv => l10n.reportCatalogGuv,
    ReportCatalogKind.datev => l10n.reportCatalogDatev,
    ReportCatalogKind.history => l10n.reportCatalogHistory,
    ReportCatalogKind.ustva => l10n.reportCatalogUstva,
    ReportCatalogKind.zm => l10n.reportCatalogZm,
  };
}
