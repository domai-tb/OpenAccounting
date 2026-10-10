import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:openaccounting/features/setup/profile_export_service.dart';

/// One export action row in the Daten & Datenschutz section.
///
/// An action is only offered as available when its production runtime
/// ([onRun]) is registered. Entries without a runtime render with their true
/// scope label plus an unavailable note and no enabled affordance, so the
/// section never implies that DATEV, GoBD, backup, report, or
/// document-package workflows are available.
class ProfileDataExportAction {
  const ProfileDataExportAction({
    required this.id,
    required this.scopeTitle,
    required this.scopeDescription,
    this.onRun,
  });

  final String id;
  final String scopeTitle;
  final String scopeDescription;

  /// Registered production runtime; null means the workflow is not available.
  final Future<ProfileExportResult> Function(String destinationPath)? onRun;

  /// Whether a production runtime is registered for this action.
  bool get isRegistered => onRun != null;
}

/// Daten & Datenschutz section for Settings: exact export scope, truthful
/// availability, and last-result status with destination.
///
/// Shows only export scope and status. Destructive or masking controls stay
/// out: their policy is unresolved and lives in a separate approved contract.
class ProfileDataSection extends StatefulWidget {
  const ProfileDataSection({
    required this.exportService,
    this.additionalActions = const <ProfileDataExportAction>[],
    this.pickDestination,
    super.key,
  });

  /// Null when the export service is not registered; the section then shows
  /// the unavailable state and never claims an export happened.
  final ProfileExportService? exportService;

  /// Separately scoped actions with their own labels. Unregistered entries
  /// render as unavailable.
  final List<ProfileDataExportAction> additionalActions;

  /// Test seam for the save-location dialog.
  final Future<String?> Function()? pickDestination;

  @override
  State<ProfileDataSection> createState() => _ProfileDataSectionState();
}

class _ProfileDataSectionState extends State<ProfileDataSection> {
  Future<ProfileExportReadiness>? _readiness;
  bool _busy = false;
  String? _statusMessage;
  String? _statusDestination;

  @override
  void initState() {
    super.initState();
    final ProfileExportService? service = widget.exportService;
    if (service != null && Directory(service.profileDir).existsSync()) {
      _readiness = service.checkExportReadiness();
    }
  }

  bool get _available => widget.exportService != null && Directory(widget.exportService!.profileDir).existsSync();

  Future<void> _run(Future<ProfileExportResult> Function(String destinationPath) invoke) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final String? destination = await _selectDestination();
      if (!mounted) {
        return;
      }
      if (destination == null || destination.trim().isEmpty) {
        setState(() {
          _statusMessage = 'Export abgebrochen. Es wurde kein Archiv erstellt.';
          _statusDestination = null;
        });
        return;
      }
      final ProfileExportResult result = await invoke(destination);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = result.message;
        _statusDestination = result.archivePath;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Export konnte nicht abgeschlossen werden. Bitte erneut versuchen.';
        _statusDestination = null;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _selectDestination() async {
    if (widget.pickDestination != null) {
      return widget.pickDestination!();
    }
    try {
      final FileSaveLocation? location = await getSaveLocation(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(label: 'ZIP', extensions: <String>['zip']),
        ],
        suggestedName: 'profil_export.zip',
      );
      return location?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    if (!_available) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Daten & Datenschutz', style: text.titleMedium),
          const SizedBox(height: 8),
          const Text('Export ist nicht verfügbar.'),
          const SizedBox(height: 4),
          const Text(
            'Der Profil-Exportdienst ist nicht registriert oder das aktive Profil kann nicht gelesen werden. '
            'Es wurden keine Daten exportiert.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Daten & Datenschutz', style: text.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Das vollständige strukturierte Profilarchiv enthält Profildatensätze, Beziehungen und referenzierte '
          'Dateien des aktiven Profils als versioniertes ZIP-Archiv (manifest.json, records/*.jsonl, evidence/).',
        ),
        const SizedBox(height: 4),
        const Text('Dies ist kein DATEV-, GoBD-, Backup-, Berichts- oder Dokumentenpaket-Export.'),
        const SizedBox(height: 8),
        _archiveRow(),
        for (final ProfileDataExportAction action in widget.additionalActions) _actionRow(action),
        const SizedBox(height: 8),
        _readinessLine(),
        if (_statusMessage != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(_statusMessage!),
          if (_statusDestination != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(_statusDestination!, style: text.bodySmall),
          ],
        ],
      ],
    );
  }

  Widget _archiveRow() {
    final ProfileExportService service = widget.exportService!;
    return Card(
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: const Text('Vollständiges strukturiertes Profilarchiv'),
          subtitle: const Text('Alle unterstützten Tabellen und Nachweise des aktiven Profils.'),
          trailing: FilledButton(
            onPressed: _busy
                ? null
                : () => unawaited(_run((String destination) => service.exportProfile(destinationPath: destination))),
            child: const Text('Profil exportieren'),
          ),
        ),
      ),
    );
  }

  Widget _actionRow(ProfileDataExportAction action) {
    final Future<ProfileExportResult> Function(String destinationPath)? run = action.onRun;
    return Card(
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const Icon(Icons.outbox_outlined),
          title: Text(action.scopeTitle),
          subtitle: Text(
            run == null
                ? '${action.scopeDescription} Nicht verfügbar: kein registrierter Export.'
                : action.scopeDescription,
          ),
          trailing: run == null
              ? const OutlinedButton(onPressed: null, child: Text('Nicht verfügbar'))
              : OutlinedButton(onPressed: _busy ? null : () => unawaited(_run(run)), child: const Text('Starten')),
        ),
      ),
    );
  }

  Widget _readinessLine() {
    final Future<ProfileExportReadiness>? readiness = _readiness;
    if (readiness == null) {
      return const Text('Export-Bereitschaft wird geprüft ...');
    }
    return FutureBuilder<ProfileExportReadiness>(
      future: readiness,
      builder: (BuildContext context, AsyncSnapshot<ProfileExportReadiness> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Export-Bereitschaft wird geprüft ...');
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Export-Bereitschaft konnte nicht geprüft werden.');
        }
        final ProfileExportReadiness value = snapshot.data!;
        if (value.isReady) {
          return const Text('Export ist bereit.');
        }
        return Text(value.message);
      },
    );
  }
}
