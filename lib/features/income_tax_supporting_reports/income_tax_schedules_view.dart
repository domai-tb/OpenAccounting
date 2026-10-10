import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_status_chip.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_availability.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Anlage S/G availability view: explicit schedule selection with a typed
/// unavailable state. Shows no numeric fields, no period picker, no exports,
/// and no filing status until an accepted contract exists.
class IncomeTaxSchedulesView extends StatefulWidget {
  const IncomeTaxSchedulesView({
    required this.useCase,
    required this.initialSchedule,
    required this.onScheduleChanged,
    super.key,
  });

  final IncomeTaxScheduleAvailabilityUseCase useCase;
  final IncomeTaxSchedule? initialSchedule;
  final ValueChanged<IncomeTaxSchedule?> onScheduleChanged;

  @override
  State<IncomeTaxSchedulesView> createState() => _IncomeTaxSchedulesViewState();
}

class _IncomeTaxSchedulesViewState extends State<IncomeTaxSchedulesView> {
  IncomeTaxSchedule? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSchedule;
  }

  @override
  void didUpdateWidget(IncomeTaxSchedulesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSchedule != widget.initialSchedule) {
      _selected = widget.initialSchedule;
    }
  }

  String _blockerText(AppLocalizations l10n, IncomeTaxBlocker blocker) {
    return switch (blocker) {
      IncomeTaxBlocker.formContract => l10n.incomeTaxBlockerForm,
      IncomeTaxBlocker.periodContract => l10n.incomeTaxBlockerPeriod,
      IncomeTaxBlocker.classification => l10n.incomeTaxBlockerClassification,
      IncomeTaxBlocker.accountingSource => l10n.incomeTaxBlockerSource,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final IncomeTaxSchedule? selected = _selected;
    final IncomeTaxAvailability? availability = selected == null ? null : widget.useCase.availability(selected);
    return AppPage(
      header: AppPageHeader(title: l10n.incomeTaxTitle, showFilterToolbar: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.incomeTaxSelectPrompt),
          const SizedBox(height: 12),
          SegmentedButton<IncomeTaxSchedule>(
            emptySelectionAllowed: true,
            segments: <ButtonSegment<IncomeTaxSchedule>>[
              ButtonSegment<IncomeTaxSchedule>(value: IncomeTaxSchedule.s, label: Text(l10n.incomeTaxScheduleS)),
              ButtonSegment<IncomeTaxSchedule>(value: IncomeTaxSchedule.g, label: Text(l10n.incomeTaxScheduleG)),
            ],
            selected: selected == null ? <IncomeTaxSchedule>{} : <IncomeTaxSchedule>{selected},
            onSelectionChanged: (Set<IncomeTaxSchedule> value) {
              final IncomeTaxSchedule? schedule = value.isEmpty ? null : value.single;
              setState(() => _selected = schedule);
              widget.onScheduleChanged(schedule);
            },
          ),
          const SizedBox(height: 16),
          if (selected == null)
            Text(l10n.incomeTaxSelectPrompt)
          else if (availability != null && !availability.available) ...<Widget>[
            AppStatusChip(status: AppStatus.warning, label: l10n.incomeTaxUnavailable),
            const SizedBox(height: 8),
            ...availability.blockers.map(
              (IncomeTaxBlocker blocker) =>
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${_blockerText(l10n, blocker)}')),
            ),
          ],
        ],
      ),
    );
  }
}
