import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/customer_data_disclosure_export.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';

/// Flow states of the customer disclosure export action.
enum CustomerDisclosureFlowStatus { idle, confirming, exporting, complete, incomplete, failed, cancelled, unavailable }

/// Outcome returned by [CustomerDisclosureExportAction.run].
class CustomerDisclosureActionOutcome {
  const CustomerDisclosureActionOutcome({required this.status, required this.message, this.archivePath});

  final CustomerDisclosureFlowStatus status;
  final String message;
  final String? archivePath;
}

/// Typed customer-detail entry point for the scoped disclosure export.
///
/// Resolves the selected customer through the contact repository and invokes
/// the typed export service. Never queries customer-linked tables directly
/// and never falls back to whole-profile export or raw table output.
class CustomerDisclosureExportAction {
  CustomerDisclosureExportAction({required this.customers, CustomerDataDisclosureExportService? exportService})
    : _exportService = exportService; // ignore: prefer_initializing_formals

  final KundenRepository customers;
  final CustomerDataDisclosureExportService? _exportService;

  bool get isAvailable => _exportService != null;

  static const String messageUnavailable = 'Auskunfts-Export ist nicht verfügbar.';

  /// German-first scope description shown before the destination is chosen.
  /// Distinguishes the read-only customer export from profile archives,
  /// backups, deletion, and anonymization.
  static const String scopeDescriptionDe =
      'Dieser Export enthält ausschließlich diesen Kunden und Datensätze mit verifizierten Verknüpfungen '
      '(Rechnungen, Positionen, Mahnungen, Forderungen, Zahlungen, Vorlagen, Belege). '
      'Freitext-Treffer werden nicht gesucht oder exportiert. '
      'Nicht unterstützte oder ausgeschlossene Inhalte werden im Manifest genannt; das Archiv kann unvollständig sein. '
      'Dies ist kein Profil-Archiv und kein Backup. Kundendaten werden weder gelöscht noch anonymisiert.';

  static const String scopeDescriptionEn =
      'This export contains only this customer and records with verified links '
      '(invoices, items, reminders, receivables, payments, templates, receipts). '
      'Free-text matches are neither searched nor exported. '
      'Unsupported or excluded content is listed in the manifest; the archive may be incomplete. '
      'This is not a profile archive and not a backup. Customer data is neither deleted nor anonymized.';

  /// Describes the export scope for [customerId] without publishing anything.
  Future<CustomerDisclosureActionOutcome> describeScope(int customerId) async {
    final Kunde? customer = await customers.findById(customerId);
    if (customer == null) {
      return const CustomerDisclosureActionOutcome(
        status: CustomerDisclosureFlowStatus.failed,
        message: 'Kunde nicht gefunden. Es wurde kein Archiv erstellt.',
      );
    }
    if (!isAvailable) {
      return const CustomerDisclosureActionOutcome(
        status: CustomerDisclosureFlowStatus.unavailable,
        message: messageUnavailable,
      );
    }
    return const CustomerDisclosureActionOutcome(
      status: CustomerDisclosureFlowStatus.confirming,
      message: scopeDescriptionDe,
    );
  }

  /// Runs the scoped export for [customerId]. Progress and outcome messages
  /// are localized German-first strings for semantic status announcements.
  Future<CustomerDisclosureActionOutcome> run({
    required int customerId,
    required String destinationPath,
    bool Function()? isCancelled,
  }) async {
    final Kunde? customer = await customers.findById(customerId);
    if (customer == null) {
      return const CustomerDisclosureActionOutcome(
        status: CustomerDisclosureFlowStatus.failed,
        message: 'Kunde nicht gefunden. Es wurde kein Archiv erstellt.',
      );
    }
    final CustomerDataDisclosureExportService? service = _exportService;
    if (service == null) {
      return const CustomerDisclosureActionOutcome(
        status: CustomerDisclosureFlowStatus.unavailable,
        message: messageUnavailable,
      );
    }
    final CustomerDisclosureResult result = await service.exportCustomer(
      customerId: customer.id,
      destinationPath: destinationPath,
      isCancelled: isCancelled,
    );
    return CustomerDisclosureActionOutcome(
      status: _flowStatus(result.status),
      message: result.message ?? '',
      archivePath: result.archivePath,
    );
  }

  static CustomerDisclosureFlowStatus _flowStatus(CustomerDisclosureExportStatus status) {
    switch (status) {
      case CustomerDisclosureExportStatus.complete:
        return CustomerDisclosureFlowStatus.complete;
      case CustomerDisclosureExportStatus.incomplete:
        return CustomerDisclosureFlowStatus.incomplete;
      case CustomerDisclosureExportStatus.failed:
        return CustomerDisclosureFlowStatus.failed;
      case CustomerDisclosureExportStatus.cancelled:
        return CustomerDisclosureFlowStatus.cancelled;
    }
  }
}

/// Framework-agnostic controller for the disclosure-export dialog flow.
///
/// Owns confirmation, progress, outcome, cancellation, and focus-return
/// state so the widget stays thin and the flow is unit-testable.
class CustomerDisclosureExportController extends ChangeNotifier {
  CustomerDisclosureExportController({required this.action, required this.customerId});

  final CustomerDisclosureExportAction action;
  final int customerId;

  /// Stable identifier of the export action for focus restoration.
  static const String focusReturnTarget = 'customer-disclosure-export-action';

  CustomerDisclosureFlowStatus status = CustomerDisclosureFlowStatus.idle;
  String message = '';
  String scopeDescription = '';
  String? focusTarget;
  bool destinationCancelled = false;

  /// Localized semantic status for announcements (complete/incomplete/
  /// failure/cancellation), empty while no outcome exists.
  String get announcedStatus {
    switch (status) {
      case CustomerDisclosureFlowStatus.complete:
      case CustomerDisclosureFlowStatus.incomplete:
      case CustomerDisclosureFlowStatus.failed:
      case CustomerDisclosureFlowStatus.cancelled:
      case CustomerDisclosureFlowStatus.unavailable:
        return message;
      case CustomerDisclosureFlowStatus.idle:
      case CustomerDisclosureFlowStatus.confirming:
      case CustomerDisclosureFlowStatus.exporting:
        return '';
    }
  }

  /// Opens the confirmation step; keyboard and pointer input share it.
  Future<void> showConfirmation() async {
    final CustomerDisclosureActionOutcome scope = await action.describeScope(customerId);
    if (scope.status == CustomerDisclosureFlowStatus.confirming) {
      status = CustomerDisclosureFlowStatus.confirming;
      scopeDescription = scope.message;
      message = 'Export läuft…';
    } else {
      status = scope.status;
      message = scope.message;
    }
    notifyListeners();
  }

  /// Cancels destination selection: no archive, localized cancelled status,
  /// and focus returns to the disclosure-export action.
  void cancelDestinationSelection() {
    destinationCancelled = true;
    status = CustomerDisclosureFlowStatus.cancelled;
    message = 'Export abgebrochen. Es wurde kein Archiv erstellt.';
    focusTarget = focusReturnTarget;
    notifyListeners();
  }

  void failDestinationSelection() {
    status = CustomerDisclosureFlowStatus.failed;
    message = 'Export fehlgeschlagen. Bitte Ziel prüfen und erneut versuchen.';
    notifyListeners();
  }

  /// Keyboard activation runs the same flow as pointer input.
  Future<CustomerDisclosureActionOutcome> activateViaKeyboard({
    required String destinationPath,
    bool Function()? isCancelled,
  }) {
    return startExport(destinationPath: destinationPath, isCancelled: isCancelled);
  }

  Future<CustomerDisclosureActionOutcome> startExport({
    required String destinationPath,
    bool Function()? isCancelled,
  }) async {
    status = CustomerDisclosureFlowStatus.exporting;
    message = 'Export läuft…';
    notifyListeners();
    final CustomerDisclosureActionOutcome outcome = await action.run(
      customerId: customerId,
      destinationPath: destinationPath,
      isCancelled: isCancelled,
    );
    status = outcome.status;
    message = outcome.message;
    if (outcome.status == CustomerDisclosureFlowStatus.cancelled) {
      focusTarget = focusReturnTarget;
    }
    notifyListeners();
    return outcome;
  }
}

/// Labeled disclosure-export action for the customer detail workspace.
///
/// Keyboard operable with visible focus, semantic labels, and focus
/// restoration after cancellation. The dialog stays readable in narrow
/// windows with enlarged text. Destination selection is injected so tests
/// can cancel without platform pickers.
class CustomerDisclosureExportButton extends StatefulWidget {
  const CustomerDisclosureExportButton({
    required this.controller,
    this.selectDestination,
    this.actionLabel,
    this.confirmLabel,
    this.cancelLabel,
    this.scopeTitle,
    this.scopeDescription,
    super.key,
  });

  final CustomerDisclosureExportController controller;
  final Future<String?> Function()? selectDestination;
  final String? actionLabel;
  final String? confirmLabel;
  final String? cancelLabel;
  final String? scopeTitle;
  final String? scopeDescription;

  @override
  State<CustomerDisclosureExportButton> createState() => _CustomerDisclosureExportButtonState();
}

class _CustomerDisclosureExportButtonState extends State<CustomerDisclosureExportButton> {
  final FocusNode _actionFocus = FocusNode(debugLabel: CustomerDisclosureExportController.focusReturnTarget);

  @override
  void dispose() {
    _actionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final bool busy = widget.controller.status == CustomerDisclosureFlowStatus.exporting;
        return FilledButton.tonal(
          focusNode: _actionFocus,
          onPressed: busy ? null : _openConfirmation,
          child: Text(
            busy ? l10n.customerDisclosureExportProgress : widget.actionLabel ?? l10n.customerDisclosureExportAction,
          ),
        );
      },
    );
  }

  Future<void> _openConfirmation() async {
    await widget.controller.showConfirmation();
    if (!mounted) return;
    if (widget.controller.status != CustomerDisclosureFlowStatus.confirming) {
      _announceOutcome();
      return;
    }
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text(widget.scopeTitle ?? appLocalizationsOf(dialogContext).customerDisclosureExportScopeTitle),
          content: Text(widget.scopeDescription ?? widget.controller.scopeDescription),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: Text(widget.cancelLabel ?? appLocalizationsOf(dialogContext).actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('export'),
              child: Text(widget.confirmLabel ?? appLocalizationsOf(dialogContext).customerDisclosureExportConfirm),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (choice != 'export') {
      widget.controller.cancelDestinationSelection();
      _announceOutcome();
      _actionFocus.requestFocus();
      return;
    }
    final Future<String?> Function()? pick = widget.selectDestination;
    if (pick == null) {
      widget.controller.cancelDestinationSelection();
      _announceOutcome();
      _actionFocus.requestFocus();
      return;
    }
    final String? destination;
    try {
      destination = await pick();
    } catch (_) {
      if (!mounted) return;
      widget.controller.failDestinationSelection();
      _announceOutcome();
      return;
    }
    if (!mounted) return;
    if (destination == null) {
      widget.controller.cancelDestinationSelection();
      _announceOutcome();
      _actionFocus.requestFocus();
      return;
    }
    await widget.controller.startExport(destinationPath: destination);
    if (!mounted) return;
    _announceOutcome();
  }

  void _announceOutcome() {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final String message = switch (widget.controller.status) {
      CustomerDisclosureFlowStatus.complete => l10n.customerDisclosureExportComplete,
      CustomerDisclosureFlowStatus.incomplete => l10n.customerDisclosureExportIncomplete,
      CustomerDisclosureFlowStatus.failed when widget.controller.message.startsWith('Kunde nicht gefunden') =>
        l10n.customerDisclosureExportNotFound,
      CustomerDisclosureFlowStatus.failed when widget.controller.message.startsWith('Zieldatei existiert bereits') =>
        l10n.customerDisclosureExportDestinationExists,
      CustomerDisclosureFlowStatus.failed => l10n.customerDisclosureExportFailed,
      CustomerDisclosureFlowStatus.cancelled => l10n.customerDisclosureExportCancelled,
      CustomerDisclosureFlowStatus.unavailable => l10n.customerDisclosureExportUnavailable,
      CustomerDisclosureFlowStatus.idle ||
      CustomerDisclosureFlowStatus.confirming ||
      CustomerDisclosureFlowStatus.exporting => '',
    };
    if (message.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
