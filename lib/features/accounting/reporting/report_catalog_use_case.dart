import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';

enum ReportCatalogScope { reports, taxes }

enum ReportCatalogKind { euer, eks, guv, datev, history, ustva, zm }

class ReportCatalogEntry {
  const ReportCatalogEntry({required this.kind, required this.route, required this.period, required this.availability});

  final ReportCatalogKind kind;
  final String route;
  final String period;
  final ReportAvailability availability;
}

class ReportCatalogUseCase {
  ReportCatalogUseCase(this.workspace);

  final ReportingWorkspaceUseCase workspace;

  Future<List<ReportCatalogEntry>> list(ReportCatalogScope scope) async {
    final List<ReportCatalogEntry> entries = <ReportCatalogEntry>[];

    Future<void> add(ReportCatalogKind kind, String route, String period, ReportSelection selection) async {
      final ReportWorkspaceResult<ReportWorkspaceValue> result = await workspace.resolve(selection);
      entries.add(ReportCatalogEntry(kind: kind, route: route, period: period, availability: result.availability));
    }

    if (scope == ReportCatalogScope.reports) {
      await add(
        ReportCatalogKind.euer,
        '/reports?report=euer&year=2025',
        '2025',
        const ReportSelection.euer(jahr: 2025),
      );
      await add(ReportCatalogKind.eks, '/reports?report=eks', '—', const ReportSelection.eks());
      await add(ReportCatalogKind.guv, '/reports?report=guv&year=2025', '2025', const ReportSelection.guv(jahr: 2025));
      entries.add(
        const ReportCatalogEntry(
          kind: ReportCatalogKind.datev,
          route: '/reports?report=datev&month=2025-01',
          period: '2025-01',
          availability: ReportAvailability.unavailable,
        ),
      );
      entries.add(
        const ReportCatalogEntry(
          kind: ReportCatalogKind.history,
          route: '/reports?view=history',
          period: '—',
          availability: ReportAvailability.available,
        ),
      );
    } else {
      entries.add(
        const ReportCatalogEntry(
          kind: ReportCatalogKind.ustva,
          route: '/taxes?report=ustva',
          period: '',
          availability: ReportAvailability.unavailable,
        ),
      );
      await add(
        ReportCatalogKind.zm,
        '/taxes?report=zm&month=2025-01',
        '2025-01',
        const ReportSelection.zm(month: '2025-01'),
      );
    }
    return entries;
  }
}
