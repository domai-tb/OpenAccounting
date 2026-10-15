import 'package:flutter/material.dart';

/// Render state of a report workspace.
enum ReportingWorkspaceViewState { loading, empty, unavailable, error, ready }

/// Localized strings for the workspace states and controls.
///
/// shortcut: strings are injected rather than read from the shared ARB until
/// the reporting l10n keys are merged; move to context.l10n afterwards.
class ReportingWorkspaceStrings {
  const ReportingWorkspaceStrings({
    required this.loading,
    required this.empty,
    required this.unavailable,
    required this.error,
    required this.periodLabel,
    required this.tableLabel,
  });

  final String loading;
  final String empty;
  final String unavailable;
  final String error;
  final String periodLabel;
  final String tableLabel;
}

/// One dense result-table row.
class ReportTableRowData {
  const ReportTableRowData({required this.label, required this.value});

  final String label;
  final String value;
}

/// Report workspace view: period controls plus a dense result table with
/// keyboard navigation, visible focus, and localized, semantics-labelled
/// loading/empty/unavailable/error states. Adapts without horizontal
/// clipping at narrow desktop widths via a horizontally scrollable table.
class ReportingWorkspaceView extends StatefulWidget {
  const ReportingWorkspaceView({
    super.key,
    required this.strings,
    required this.state,
    required this.periodOptions,
    required this.selectedPeriod,
    required this.onPeriodSelected,
    required this.rows,
  });

  final ReportingWorkspaceStrings strings;
  final ReportingWorkspaceViewState state;
  final List<String> periodOptions;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodSelected;
  final List<ReportTableRowData> rows;

  @override
  State<ReportingWorkspaceView> createState() => _ReportingWorkspaceViewState();
}

class _ReportingWorkspaceViewState extends State<ReportingWorkspaceView> {
  late final List<FocusNode> _periodNodes;

  @override
  void initState() {
    super.initState();
    // shortcut: nodes are built once for the widget's lifecycle; rebuild in
    // didUpdateWidget if period options ever change dynamically.
    _periodNodes = <FocusNode>[
      for (int i = 0; i < widget.periodOptions.length; i++) FocusNode(debugLabel: 'period-${widget.periodOptions[i]}'),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _periodNodes.isNotEmpty) {
        _periodNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final FocusNode node in _periodNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          label: widget.strings.periodLabel,
          child: Text(widget.strings.periodLabel, style: Theme.of(context).textTheme.titleMedium),
        ),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (int i = 0; i < widget.periodOptions.length; i++)
              TextButton(
                focusNode: _periodNodes[i],
                onPressed: () => widget.onPeriodSelected(widget.periodOptions[i]),
                child: Text(widget.periodOptions[i]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.state) {
      case ReportingWorkspaceViewState.loading:
        return _stateMessage(context, widget.strings.loading, liveRegion: true);
      case ReportingWorkspaceViewState.empty:
        return _stateMessage(context, widget.strings.empty);
      case ReportingWorkspaceViewState.unavailable:
        return _stateMessage(context, widget.strings.unavailable);
      case ReportingWorkspaceViewState.error:
        return _stateMessage(context, widget.strings.error);
      case ReportingWorkspaceViewState.ready:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Semantics(
            container: true,
            label: widget.strings.tableLabel,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Position')),
                DataColumn(label: Text('Wert')),
              ],
              rows: <DataRow>[
                for (int i = 0; i < widget.rows.length; i++)
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Focus(debugLabel: 'report-row-$i', child: Text(widget.rows[i].label))),
                      DataCell(Text(widget.rows[i].value)),
                    ],
                  ),
              ],
            ),
          ),
        );
    }
  }

  Widget _stateMessage(BuildContext context, String text, {bool liveRegion = false}) {
    return Center(
      child: Semantics(
        container: true,
        liveRegion: liveRegion,
        label: text,
        // The visible Text must not duplicate the explicit semantics label.
        child: ExcludeSemantics(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ),
    );
  }
}
