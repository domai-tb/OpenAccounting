import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/accounting/reporting/report_catalog_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';
import 'package:openaccounting/l10n/l10n.dart';

class ReportWorkspacePage extends StatefulWidget {
  const ReportWorkspacePage({required this.uri, required this.workspace, super.key});

  final Uri uri;
  final ReportingWorkspaceUseCase workspace;

  @override
  State<ReportWorkspacePage> createState() => _ReportWorkspacePageState();
}

class _ReportWorkspacePageState extends State<ReportWorkspacePage> {
  late final ReportCatalogKind? _kind = _kindFor(widget.uri);
  late final Future<ReportWorkspaceResult<ReportWorkspaceValue>> _result = _resolve();

  Future<ReportWorkspaceResult<ReportWorkspaceValue>> _resolve() {
    final Map<String, String> query = widget.uri.queryParameters;
    if (widget.uri.queryParametersAll.values.any((List<String> values) => values.length != 1)) {
      return Future<ReportWorkspaceResult<ReportWorkspaceValue>>.value(
        const ReportWorkspaceResult<ReportWorkspaceValue>.invalidSelection('duplicateRouteParameter'),
      );
    }
    if (query['view'] == 'history') {
      return Future<ReportWorkspaceResult<ReportWorkspaceValue>>.value(
        const ReportWorkspaceResult<ReportWorkspaceValue>.unavailable('ReportExportHistoryUseCase unavailable'),
      );
    }
    final String? report = query['report'];
    final String path = widget.uri.path;
    switch ((path, report)) {
      case ('/reports', 'euer'):
        final int? year = int.tryParse(query['year'] ?? '');
        return year == null ? _invalid('missingYear') : widget.workspace.resolve(ReportSelection.euer(jahr: year));
      case ('/reports', 'eks'):
        return widget.workspace.resolve(const ReportSelection.eks());
      case ('/reports', 'guv'):
        final int? year = int.tryParse(query['year'] ?? '');
        return year == null ? _invalid('missingYear') : widget.workspace.resolve(ReportSelection.guv(jahr: year));
      case ('/taxes', 'zm'):
        final String? month = query['month'];
        return month == null ? _invalid('missingMonth') : widget.workspace.resolve(ReportSelection.zm(month: month));
      case ('/taxes', 'ustva'):
        return Future<ReportWorkspaceResult<ReportWorkspaceValue>>.value(
          const ReportWorkspaceResult<ReportWorkspaceValue>.unavailable('configuredUstvaRhythmusRequired'),
        );
      case ('/reports', 'datev'):
        return Future<ReportWorkspaceResult<ReportWorkspaceValue>>.value(
          const ReportWorkspaceResult<ReportWorkspaceValue>.unavailable('datevProfileConfigurationRequired'),
        );
      default:
        return _invalid('unknownReportSelection');
    }
  }

  Future<ReportWorkspaceResult<ReportWorkspaceValue>> _invalid(String reason) =>
      Future<ReportWorkspaceResult<ReportWorkspaceValue>>.value(
        ReportWorkspaceResult<ReportWorkspaceValue>.invalidSelection(reason),
      );

  ReportCatalogKind? _kindFor(Uri uri) {
    if (uri.queryParameters['view'] == 'history') return ReportCatalogKind.history;
    return switch ((uri.path, uri.queryParameters['report'])) {
      ('/reports', 'euer') => ReportCatalogKind.euer,
      ('/reports', 'eks') => ReportCatalogKind.eks,
      ('/reports', 'guv') => ReportCatalogKind.guv,
      ('/reports', 'datev') => ReportCatalogKind.datev,
      ('/taxes', 'ustva') => ReportCatalogKind.ustva,
      ('/taxes', 'zm') => ReportCatalogKind.zm,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String title = widget.uri.path == '/taxes' ? l10n.routeTaxes : l10n.routeReports;
    return AppPage(
      header: AppPageHeader(title: title, showFilterToolbar: false),
      child: FutureBuilder<ReportWorkspaceResult<ReportWorkspaceValue>>(
        future: _result,
        builder: (BuildContext context, AsyncSnapshot<ReportWorkspaceResult<ReportWorkspaceValue>> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.workspaceUnavailable));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ReportWorkspaceResult<ReportWorkspaceValue> result = snapshot.data!;
          final ReportWorkspaceValue? value = result.value;
          final String status = switch (result.availability) {
            ReportAvailability.available => l10n.reportStatusAvailable,
            ReportAvailability.unavailable => l10n.reportStatusUnavailable,
            ReportAvailability.invalidSelection => l10n.reportSelectionInvalid,
          };
          final List<Widget> children = <Widget>[
            ListTile(
              key: ValueKey<String>(
                result.availability == ReportAvailability.invalidSelection
                    ? 'report-workspace-invalid'
                    : 'report-workspace-${_kind?.name ?? 'invalid'}',
              ),
              title: Text(_titleFor(l10n, _kind)),
              subtitle: Text(status),
            ),
          ];
          if (value != null) {
            children.add(Text('${value.periodStart} – ${value.periodEnd}'));
            if (value.sourceVersions.isNotEmpty) {
              children.add(
                Text(
                  value.sourceVersions.entries.map((MapEntry<String, String> e) => '${e.key}: ${e.value}').join(', '),
                ),
              );
            }
          }
          if (result.reasonCode != null && result.availability != ReportAvailability.invalidSelection) {
            children.add(Text(result.reasonCode!));
          }
          return ListView(
            key: const ValueKey<String>('report-workspace-result'),
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, ReportCatalogKind? kind) => switch (kind) {
    ReportCatalogKind.euer => l10n.reportCatalogEuer,
    ReportCatalogKind.eks => l10n.reportCatalogEks,
    ReportCatalogKind.guv => l10n.reportCatalogGuv,
    ReportCatalogKind.datev => l10n.reportCatalogDatev,
    ReportCatalogKind.history => l10n.reportCatalogHistory,
    ReportCatalogKind.ustva => l10n.reportCatalogUstva,
    ReportCatalogKind.zm => l10n.reportCatalogZm,
    null => l10n.reportStatusUnavailable,
  };
}
