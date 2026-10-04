import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_year_repository.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Company fiscal-year control for Settings: start-month dropdown (1–12)
/// with explicit Save, success/error announcements, and focus restoration.
/// Reads and writes only through [FiscalYearRepository]; never issues
/// database queries from UI code.
class FiscalYearSettingsSection extends StatefulWidget {
  const FiscalYearSettingsSection({required this.repository, super.key});

  final FiscalYearRepository repository;

  @override
  State<FiscalYearSettingsSection> createState() => _FiscalYearSettingsSectionState();
}

class _FiscalYearSettingsSectionState extends State<FiscalYearSettingsSection> {
  int? _saved;
  int? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;
  final FocusNode _saveFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveFocus.dispose();
    super.dispose();
  }

  static bool _dateDataReady = false;

  Future<void> _load() async {
    try {
      if (!_dateDataReady) {
        await initializeDateFormatting('de');
        await initializeDateFormatting('en');
        _dateDataReady = true;
      }
      final int month = await widget.repository.getStartMonth();
      if (!mounted) return;
      setState(() {
        _saved = month;
        _selected = month;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _monthName(BuildContext context, int month) {
    final String locale = Localizations.localeOf(context).languageCode;
    return DateFormat.MMMM(locale).format(DateTime(2000, month));
  }

  Future<void> _save() async {
    final int? selected = _selected;
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (selected == null || selected < 1 || selected > 12) {
      setState(() => _error = l10n.fiscalYearInvalid);
      _saveFocus.requestFocus();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.repository.setStartMonth(selected);
      if (!mounted) return;
      setState(() {
        _saved = selected;
        _saving = false;
        _notice = l10n.fiscalYearSaved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _selected = _saved;
        _error = l10n.fiscalYearError;
      });
      _saveFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (_loading) {
      return const LinearProgressIndicator();
    }
    return Semantics(
      liveRegion: true,
      label: _notice ?? _error ?? l10n.fiscalYearTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.fiscalYearTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selected,
            decoration: InputDecoration(labelText: l10n.fiscalYearStartMonth, helperText: l10n.fiscalYearHint),
            items: <DropdownMenuItem<int>>[
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem<int>(value: m, child: Text('$m – ${_monthName(context, m)}')),
            ],
            onChanged: (int? value) => setState(() {
              _selected = value;
              _error = null;
              _notice = null;
            }),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              semanticsLabel: _error,
            ),
          if (_notice != null) Text(_notice!, semanticsLabel: _notice),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              focusNode: _saveFocus,
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(l10n.fiscalYearSave),
            ),
          ),
        ],
      ),
    );
  }
}
