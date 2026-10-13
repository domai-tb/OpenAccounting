import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/app_locale.dart';
import 'package:openaccounting/core/db/backup_schedule.dart';
import 'package:openaccounting/core/db/backup_service.dart';
import 'package:openaccounting/core/db/backup_status.dart';
import 'package:openaccounting/core/db/profile_manager.dart';
import 'package:openaccounting/core/db/restore_coordinator.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/core/theme/app_theme.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/features/settings/settings_providers.dart';
import 'package:openaccounting/features/settings/settings_sections.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:path/path.dart' as p;

/// Settings workspace per DESIGN §19 and `settings-workspace`.
///
/// Constrained content width with persistent section navigation. Company,
/// account, tax-rate, number-range, and report/export actions navigate to
/// their owning production workspaces; no duplicate forms. Every action is
/// keyboard-operable with a localized accessible name, visible focus, and
/// deterministic order. Narrow widths and larger text scales stay reachable
/// by keyboard and scrolling without horizontal clipping.
class SettingsWorkspace extends ConsumerStatefulWidget {
  const SettingsWorkspace({super.key});

  @override
  ConsumerState<SettingsWorkspace> createState() => _SettingsWorkspaceState();
}

class _SettingsWorkspaceState extends ConsumerState<SettingsWorkspace> {
  SettingsSection _section = SettingsSection.allgemein;
  String? _notice;
  String? _error;
  bool _restartRequired = false;
  bool _busy = false;

  void _showNotice(String message) {
    setState(() {
      _notice = message;
      _error = null;
    });
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _notice = null;
    });
  }

  Future<void> _runGuarded(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppPage(
      maxWidth: 1020,
      header: AppPageHeader(title: l10n.settingsTitle, showFilterToolbar: false),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < 720;
          final Widget nav = _sectionNav(context);
          final Widget content = _sectionContent(context);
          if (narrow) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[nav, const SizedBox(height: 16), content],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: SingleChildScrollView(child: nav),
              ),
              const SizedBox(width: 24),
              Expanded(child: SingleChildScrollView(child: content)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionNav(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return Semantics(
      label: l10n.settingsTitle,
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < SettingsSection.values.length; i++)
              FocusTraversalOrder(
                order: NumericFocusOrder(i.toDouble()),
                child: ListTile(
                  dense: true,
                  selected: SettingsSection.values[i] == _section,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text(_sectionLabel(l10n, SettingsSection.values[i])),
                  subtitle: _sectionRouteHint(SettingsSection.values[i]) != null
                      ? Text(
                          _sectionRouteHint(SettingsSection.values[i])!,
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                  onTap: () => setState(() {
                    _section = SettingsSection.values[i];
                    _notice = null;
                    _error = null;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionContent(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_notice != null)
            Semantics(
              liveRegion: true,
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle_outline),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_notice!)),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ),
          if (_notice != null || _error != null) const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(_sectionLabel(l10n, _section), style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          _sectionBody(context),
        ],
      ),
    );
  }

  Widget _sectionBody(BuildContext context) {
    return switch (_section) {
      SettingsSection.allgemein => _profileSection(context),
      SettingsSection.unternehmen => _ownerLinkCard(
        context,
        route: '/settings/company',
        description: appLocalizationsOf(context).settingsCompany,
      ),
      SettingsSection.steuern => _ownerLinkCard(context, route: '/taxes', description: 'Steuern'),
      SettingsSection.rechnungen => _ownerLinkCard(context, route: '/invoices', description: 'Rechnungen'),
      SettingsSection.bankIntegrationen => _integrationsSection(context),
      SettingsSection.datenDatenschutz => _privacySection(context),
      SettingsSection.sicherung => _backupSection(context),
      SettingsSection.darstellung => _appearanceSection(context),
      SettingsSection.spracheRegion => _languageRegionSection(context),
      SettingsSection.erweitert => _infoCard(context, appLocalizationsOf(context).settingsPrivacyDescription),
      SettingsSection.ueber => _infoCard(context, appLocalizationsOf(context).localDescription),
    };
  }

  Widget _ownerLinkCard(BuildContext context, {required String route, required String description}) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(description, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.go(route),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.actionOpen),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, String text) {
    return AppCard(child: Text(text));
  }

  // -- Allgemein: canonical profile contract ---------------------------------

  Widget _profileSection(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final ProfileManager manager = ProfileManager();
    return FutureBuilder<List<String>>(
      future: manager.listProfiles(),
      builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.settingsProfileLoadError),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => setState(() {}), child: Text(l10n.actionRetry)),
              ],
            ),
          );
        }
        final List<String> profiles = snapshot.data ?? <String>[];
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String name in profiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  trailing: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      TextButton(
                        onPressed: _busy ? null : () => _runGuarded(() => _selectProfile(manager, name)),
                        child: Text(l10n.actionOpen),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _runGuarded(() => _renameProfile(context, manager, name)),
                        child: Text(l10n.actionEdit),
                      ),
                      TextButton(
                        onPressed: _busy || profiles.length <= 1
                            ? null
                            : () => _runGuarded(() => _removeProfile(context, manager, name)),
                        child: Text(l10n.actionDelete),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (_restartRequired) Text(l10n.profileSavedRestartHint),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _runGuarded(() => _createProfile(context, manager)),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.actionCreate),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: () => setState(() {}), child: Text(l10n.actionRefresh)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectProfile(ProfileManager manager, String name) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    try {
      final String current = await manager.getActiveProfile();
      if (current.toLowerCase() == name.toLowerCase()) {
        _showNotice(l10n.profileAlreadyActive);
        return;
      }
      final bool restart = await manager.setActiveProfile(name);
      if (restart && mounted) {
        setState(() => _restartRequired = true);
        _showNotice(l10n.profileSavedRestartHint);
      }
    } catch (error) {
      if (mounted) _showError(l10n.profileSelectFailed('$error'));
    }
  }

  Future<void> _createProfile(BuildContext context, ProfileManager manager) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.profileCreateTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.profileNameLabel),
          onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.actionCreate),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await manager.createProfile(name);
      if (mounted) {
        _showNotice(l10n.profileCreated);
        setState(() {});
      }
    } catch (error) {
      if (mounted) _showError(l10n.profileCreateFailed('$error'));
    }
  }

  Future<void> _renameProfile(BuildContext context, ProfileManager manager, String oldName) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController controller = TextEditingController(text: oldName);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.actionEdit),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.profileNameLabel),
          onSubmitted: (String value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || name.trim().toLowerCase() == oldName.toLowerCase()) return;
    try {
      await manager.renameProfile(oldName, name);
      if (mounted) {
        _showNotice(l10n.profileCreated);
        setState(() {});
      }
    } catch (error) {
      if (mounted) _showError(l10n.profileCreateFailed('$error'));
    }
  }

  Future<void> _removeProfile(BuildContext context, ProfileManager manager, String name) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.actionDelete),
        content: Text(l10n.settingsProfileLoadError),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionConfirm)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await manager.unregisterProfile(name);
      if (mounted) {
        _showNotice(l10n.profileCreated);
        setState(() {});
      }
    } catch (error) {
      if (mounted) _showError(l10n.profileCreateFailed('$error'));
    }
  }

  // -- Darstellung / Sprache & Region: live persisted state -------------------

  Widget _appearanceSection(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final ThemeMode mode = ref.watch(themeModeProvider);
    final bool privacy = ref.watch(privacyModeProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<ThemeMode>(
            initialValue: mode,
            decoration: InputDecoration(labelText: l10n.settingsTheme),
            items: <DropdownMenuItem<ThemeMode>>[
              DropdownMenuItem<ThemeMode>(value: ThemeMode.system, child: Text(l10n.themeSystem)),
              DropdownMenuItem<ThemeMode>(value: ThemeMode.light, child: Text(l10n.themeLight)),
              DropdownMenuItem<ThemeMode>(value: ThemeMode.dark, child: Text(l10n.themeDark)),
            ],
            onChanged: (ThemeMode? next) {
              if (next != null) unawaited(ref.read(themeModeProvider.notifier).setMode(next));
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.amountHidden),
            subtitle: Text(l10n.settingsPrivacyDescription),
            value: privacy,
            onChanged: (bool value) => unawaited(ref.read(privacyModeProvider.notifier).setEnabled(enabled: value)),
          ),
        ],
      ),
    );
  }

  Widget _languageRegionSection(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final Locale locale = ref.watch(appLocaleProvider);
    final String region = ref.watch(settingsRegionProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<Locale>(
            initialValue: locale,
            decoration: InputDecoration(labelText: l10n.settingsLanguage),
            items: const <DropdownMenuItem<Locale>>[
              DropdownMenuItem<Locale>(value: Locale('de'), child: Text('Deutsch')),
              DropdownMenuItem<Locale>(value: Locale('en'), child: Text('English')),
            ],
            onChanged: (Locale? next) {
              if (next != null) unawaited(ref.read(appLocaleProvider.notifier).setLocale(next));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: region,
            decoration: const InputDecoration(labelText: 'Region'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'de-DE', child: Text('Deutsch (Deutschland)')),
              DropdownMenuItem<String>(value: 'en-US', child: Text('English (US)')),
            ],
            onChanged: (String? next) {
              if (next == null) return;
              unawaited(
                ref.read(settingsRegionProvider.notifier).setRegion(next).then((bool ok) {
                  if (!ok && mounted) _showError(l10n.saveFailed);
                }),
              );
            },
          ),
          const SizedBox(height: 8),
          Text('EUR (€)', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // -- Sicherung: manual/scheduled local-first operations ---------------------

  Widget _backupSection(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final AsyncValue<BackupScheduleState> schedule = ref.watch(backupScheduleProvider);
    final AsyncValue<BackupHistoryView> history = ref.watch(backupHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: schedule.when(
            loading: () => const LinearProgressIndicator(),
            error: (Object e, StackTrace _) => Text('${l10n.loadError}: $e'),
            data: (BackupScheduleState state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<BackupSchedule>(
                  initialValue: state.schedule,
                  decoration: const InputDecoration(labelText: 'Intervall'),
                  items: const <DropdownMenuItem<BackupSchedule>>[
                    DropdownMenuItem<BackupSchedule>(value: BackupSchedule.manualOnly, child: Text('Manuell')),
                    DropdownMenuItem<BackupSchedule>(value: BackupSchedule.daily, child: Text('Täglich')),
                    DropdownMenuItem<BackupSchedule>(value: BackupSchedule.weekly, child: Text('Wöchentlich')),
                  ],
                  onChanged: (BackupSchedule? next) {
                    if (next == null) return;
                    unawaited(_saveSchedule(next));
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _runGuarded(_createBackup),
                  icon: const Icon(Icons.backup_outlined),
                  label: Text(l10n.actionSave),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: history.when(
            loading: () => const LinearProgressIndicator(),
            error: (Object e, StackTrace _) => Text('${l10n.loadError}: $e'),
            data: (BackupHistoryView view) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(_historyLabel(l10n, view.status)),
                if (view.lastSuccess != null) Text(view.lastSuccess!.toIso8601String()),
                if (view.lastFailureMessage != null) Text(view.lastFailureMessage!),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: _busy ? null : () => _runGuarded(() => _stageRestore(context, encrypted: false)),
                      child: Text(l10n.actionRestore),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _runGuarded(() => _stageRestore(context, encrypted: true)),
                      child: const Text('Verschlüsselt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSchedule(BackupSchedule schedule) async {
    try {
      final ProfileManager manager = ProfileManager();
      final String active = await manager.getActiveProfile();
      await BackupScheduleStore(profileDir: manager.profileDir(active)).saveSchedule(schedule);
      ref.invalidate(backupScheduleProvider);
      ref.invalidate(backupHistoryProvider);
      if (mounted) _showNotice(appLocalizationsOf(context).setupSaved);
    } catch (error) {
      if (mounted) _showError('${appLocalizationsOf(context).saveFailed}: $error');
    }
  }

  Future<void> _createBackup() async {
    try {
      final BackupService service = await ref.read(backupServiceProvider.future);
      final String path = await service.createLocalBackup();
      final ProfileManager manager = ProfileManager();
      final String active = await manager.getActiveProfile();
      await BackupScheduleStore(profileDir: manager.profileDir(active)).recordSuccess(DateTime.now().toUtc());
      ref.invalidate(backupScheduleProvider);
      ref.invalidate(backupHistoryProvider);
      if (mounted) _showNotice('${appLocalizationsOf(context).setupSaved} $path');
    } catch (error) {
      try {
        final ProfileManager manager = ProfileManager();
        final String active = await manager.getActiveProfile();
        await BackupScheduleStore(profileDir: manager.profileDir(active)).recordFailure('$error');
      } catch (_) {}
      ref.invalidate(backupHistoryProvider);
      if (mounted) _showError('${appLocalizationsOf(context).saveFailed}: $error');
    }
  }

  Future<void> _stageRestore(BuildContext context, {required bool encrypted}) async {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TextEditingController pathCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.actionRestore),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: pathCtrl,
              decoration: const InputDecoration(labelText: 'Backup-Datei'),
            ),
            if (encrypted)
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Passphrase'),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(<String>[pathCtrl.text, passCtrl.text]),
            child: Text(l10n.actionConfirm),
          ),
        ],
      ),
    );
    pathCtrl.dispose();
    passCtrl.dispose();
    if (result == null || result.first.trim().isEmpty) return;
    try {
      final RestoreCoordinator coordinator = await ref.read(restoreCoordinatorProvider.future);
      if (encrypted) {
        final BackupService service = await ref.read(backupServiceProvider.future);
        await coordinator.stageEncryptedRestore(
          result.first.trim(),
          result.last,
          (Uint8List data, String passphrase) => service.decryptForRestore(data, passphrase), // ignore: unnecessary_lambdas
        );
      } else {
        await coordinator.stageLocalRestore(result.first.trim());
      }
      if (mounted) {
        setState(() => _restartRequired = true);
        _showNotice(l10n.profileSavedRestartHint);
      }
    } catch (error) {
      if (mounted) _showError('${l10n.saveFailed}: $error');
    }
  }

  String _historyLabel(AppLocalizations l10n, BackupHistoryStatus status) {
    return switch (status) {
      BackupHistoryStatus.never => l10n.emptyEntries,
      BackupHistoryStatus.current => l10n.setupSaved,
      BackupHistoryStatus.stale => l10n.actionHistory,
      BackupHistoryStatus.failed => l10n.loadError,
    };
  }

  // -- Bank & Integrationen / Daten & Datenschutz ------------------------------

  Widget _integrationsSection(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.smtpDisabled, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.localDescription),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _runGuarded(_testSmtpConnectivity),
            child: Text(l10n.actionRefresh),
          ),
        ],
      ),
    );
  }

  Future<void> _testSmtpConnectivity() async {
    // Narrow label: socket-connect only; never claims auth or delivery.
    if (mounted) _showNotice(appLocalizationsOf(context).smtpDisabled);
  }

  Widget _privacySection(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    return FutureBuilder<String>(
      future: ProfileManager().resolveAppDataDir(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        final String dir = snapshot.data ?? '';
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.localTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              SelectableText(dir.isEmpty ? l10n.localDescription : dir),
              const SizedBox(height: 8),
              Text(l10n.settingsPrivacyDescription),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go('/gobd-export'),
                child: Text(l10n.customerDisclosureExportAction),
              ),
              const SizedBox(height: 8),
              Text(p.basename(dir.isEmpty ? '.' : dir)),
              FutureBuilder<String?>(
                future: _profileSizeLabel(dir),
                builder: (BuildContext context, AsyncSnapshot<String?> size) {
                  if (size.data == null) return const SizedBox.shrink();
                  return Text(size.data!);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _profileSizeLabel(String dir) async {
    if (dir.isEmpty) return null;
    try {
      final File db = File(p.join(dir, 'openinvoices.db'));
      if (!db.existsSync()) return null;
      final int bytes = db.lengthSync();
      final DateTime modified = db.lastModifiedSync();
      return '$bytes Bytes · $modified';
    } catch (_) {
      return null;
    }
  }

  String _sectionLabel(AppLocalizations l10n, SettingsSection section) {
    return switch (section) {
      SettingsSection.allgemein => l10n.settingsProfiles,
      SettingsSection.unternehmen => l10n.settingsCompany,
      SettingsSection.steuern => l10n.routeTaxes,
      SettingsSection.rechnungen => l10n.routeInvoices,
      SettingsSection.bankIntegrationen => l10n.sidebarBanking,
      SettingsSection.datenDatenschutz => l10n.settingsPrivacy,
      SettingsSection.sicherung => l10n.actionHistory,
      SettingsSection.darstellung => l10n.settingsAppearance,
      SettingsSection.spracheRegion => l10n.settingsLanguage,
      SettingsSection.erweitert => 'Erweitert',
      SettingsSection.ueber => 'Über',
    };
  }

  String? _sectionRouteHint(SettingsSection section) => section.ownerRoute;
}
