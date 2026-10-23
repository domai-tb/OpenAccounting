import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';
import 'package:openaccounting/features/mileage/mileage_entry_usecases.dart';
import 'package:openaccounting/l10n/l10n.dart';

class MileageEntryWorkspace extends StatefulWidget {
  const MileageEntryWorkspace({required this.useCases, super.key});

  final MileageEntryUseCases useCases;

  @override
  State<MileageEntryWorkspace> createState() => _MileageEntryWorkspaceState();
}

class _MileageEntryWorkspaceState extends State<MileageEntryWorkspace> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();

  List<MileageTrip> _trips = <MileageTrip>[];
  final Set<String> _confirmedPostedTripIds = <String>{};
  String _searchQuery = '';
  MileageTripState? _stateFilter;
  String? _selectedTripId;
  String? _errorMessage;
  String? _noticeMessage;
  bool _showForm = true;
  bool _isLoading = true;
  bool _isBusy = false;
  MileageTripKind? _tripKind;
  MileageVehicleSource? _vehicleSource;
  MileageVehicleClass? _vehicleClass;

  AppLocalizations get _l10n => appLocalizationsOf(context);

  @override
  void initState() {
    super.initState();
    unawaited(_loadTrips(showLoading: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dateController.dispose();
    _purposeController.dispose();
    _distanceController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips({bool showLoading = false}) async {
    if (showLoading && mounted) setState(() => _isLoading = true);
    try {
      final List<MileageTrip> trips = await widget.useCases.listTrips();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _confirmedPostedTripIds.clear();
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _l10n.mileageLoadError;
      });
    }
  }

  Future<List<MileageTrip>?> _refreshTripsAfterCommit() async {
    try {
      return await widget.useCases.listTrips();
    } catch (_) {
      return null;
    }
  }

  Future<void> _completeCommittedAction(
    MileageTrip trip, {
    required String? notice,
    String? actionError,
    bool hideForm = false,
    bool posted = false,
  }) async {
    final List<MileageTrip>? refreshedTrips = await _refreshTripsAfterCommit();
    if (!mounted) return;
    setState(() {
      if (refreshedTrips == null) {
        _trips = _mergeTrip(trip);
        if (posted) _confirmedPostedTripIds.add(trip.id);
      } else {
        _trips = refreshedTrips;
        _confirmedPostedTripIds.clear();
      }
      if (hideForm) {
        _selectedTripId = trip.id;
        _showForm = false;
      }
      _isBusy = false;
      _errorMessage = actionError ?? (refreshedTrips == null ? _l10n.mileageLoadError : null);
      _noticeMessage = notice;
    });
  }

  List<MileageTrip> _mergeTrip(MileageTrip trip) {
    final List<MileageTrip> merged = _trips.where((MileageTrip value) => value.id != trip.id).toList()..add(trip);
    merged.sort((MileageTrip a, MileageTrip b) {
      final int dateOrder = b.tripDate.compareTo(a.tripDate);
      return dateOrder == 0 ? b.id.compareTo(a.id) : dateOrder;
    });
    return merged;
  }

  MileageTripState _displayState(MileageTrip trip) =>
      _confirmedPostedTripIds.contains(trip.id) ? MileageTripState.posted : trip.state;

  List<MileageTrip> get _visibleTrips {
    final String query = _searchQuery.trim().toLowerCase();
    return _trips
        .where((MileageTrip trip) {
          final MileageTripState state = _displayState(trip);
          if (_stateFilter != null && state != _stateFilter) return false;
          if (query.isEmpty) return true;
          return <String>[
            trip.tripDate,
            trip.purpose,
            trip.businessContext,
            _formatDistance(trip.distanceHundredthsKm),
            _tripKindLabel(trip.tripKind),
            _vehicleSourceLabel(trip.vehicleSource),
            _vehicleClassLabel(trip.vehicleClass),
            _tripStateLabel(state),
            if (trip.calculatedAmount != null) _formatAmount(trip.calculatedAmount!),
          ].any((String value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
  }

  void _startNewTrip() {
    _dateController.clear();
    _purposeController.clear();
    _distanceController.clear();
    _contextController.clear();
    _formKey = GlobalKey<FormState>();
    setState(() {
      _selectedTripId = null;
      _tripKind = null;
      _vehicleSource = null;
      _vehicleClass = null;
      _showForm = true;
      _errorMessage = null;
      _noticeMessage = null;
    });
    _scrollToTop();
  }

  void _editTrip(MileageTrip trip) {
    if (!_canEdit(trip)) return;
    _dateController.text = trip.tripDate;
    _purposeController.text = trip.purpose;
    _distanceController.text = _formatDistance(trip.distanceHundredthsKm);
    _contextController.text = trip.businessContext;
    _formKey = GlobalKey<FormState>();
    setState(() {
      _selectedTripId = trip.id;
      _tripKind = trip.tripKind;
      _vehicleSource = trip.vehicleSource;
      _vehicleClass = trip.vehicleClass;
      _showForm = true;
      _errorMessage = null;
      _noticeMessage = null;
    });
    _scrollToTop();
  }

  Future<void> _saveTrip() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final int? distanceHundredthsKm = parseMileageDistanceHundredthsKm(_distanceController.text);
    final MileageTripKind? tripKind = _tripKind;
    final MileageVehicleSource? vehicleSource = _vehicleSource;
    final MileageVehicleClass? vehicleClass = _vehicleClass;
    if (distanceHundredthsKm == null || tripKind == null || vehicleSource == null || vehicleClass == null) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _noticeMessage = null;
    });
    final String? selectedId = _selectedTripId;
    late final MileageTrip trip;
    try {
      trip = selectedId == null
          ? await widget.useCases.recordBusinessTrip(
              tripDate: _dateController.text.trim(),
              purpose: _purposeController.text.trim(),
              distanceHundredthsKm: distanceHundredthsKm,
              businessContext: _contextController.text.trim(),
              tripKind: tripKind,
              vehicleSource: vehicleSource,
              vehicleClass: vehicleClass,
            )
          : await widget.useCases.editTripFacts(
              selectedId,
              tripDate: _dateController.text.trim(),
              purpose: _purposeController.text.trim(),
              distanceHundredthsKm: distanceHundredthsKm,
              businessContext: _contextController.text.trim(),
              tripKind: tripKind,
              vehicleSource: vehicleSource,
              vehicleClass: vehicleClass,
            );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = _l10n.mileageSaveError;
      });
      return;
    }
    await _completeCommittedAction(
      trip,
      hideForm: true,
      notice: selectedId == null ? _l10n.mileageSaved : _l10n.mileageUpdated,
    );
  }

  Future<void> _calculateTrip(MileageTrip trip) async {
    setState(() {
      _isBusy = true;
      _selectedTripId = trip.id;
      _errorMessage = null;
      _noticeMessage = null;
    });
    late final MileageTrip calculated;
    try {
      calculated = await widget.useCases.calculateTrip(trip.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = _l10n.mileageCalculateError;
      });
      return;
    }
    final bool ineligible = calculated.state == MileageTripState.unresolved;
    await _completeCommittedAction(
      calculated,
      actionError: ineligible ? _l10n.mileageIneligible : null,
      notice: ineligible ? null : _l10n.mileageCalculated,
    );
  }

  Future<void> _postTrip(MileageTrip trip) async {
    setState(() {
      _isBusy = true;
      _selectedTripId = trip.id;
      _errorMessage = null;
      _noticeMessage = null;
    });
    try {
      await widget.useCases.postTrip(trip.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = _l10n.mileagePostingUnavailable;
      });
      return;
    }
    await _completeCommittedAction(trip, posted: true, notice: _l10n.mileagePosted);
  }

  bool _canEdit(MileageTrip trip) {
    final MileageTripState state = _displayState(trip);
    return state == MileageTripState.unresolved || state == MileageTripState.calculated;
  }

  bool _isValidDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    final String canonical =
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    return canonical == value;
  }

  String? _validateDate(String? value) {
    final String raw = value?.trim() ?? '';
    return _isValidDate(raw) ? null : _l10n.mileageInvalidDate;
  }

  String? _validatePurpose(String? value) =>
      value == null || value.trim().isEmpty ? _l10n.mileagePurposeRequired : null;

  String? _validateDistance(String? value) =>
      parseMileageDistanceHundredthsKm(value ?? '') == null ? _l10n.mileageDistanceInvalid : null;

  String? _validateBusinessContext(String? value) =>
      value == null || value.trim().isEmpty ? _l10n.mileageContextRequired : null;

  String _formatAmount(String amount) =>
      Localizations.localeOf(context).languageCode == 'de' ? amount.replaceFirst('.', ',') : amount;

  String _formatDistance(int distanceHundredthsKm) {
    final String decimalSeparator = Localizations.localeOf(context).languageCode == 'de' ? ',' : '.';
    final int whole = distanceHundredthsKm ~/ 100;
    final String fraction = (distanceHundredthsKm % 100).toString().padLeft(2, '0');
    return '$whole$decimalSeparator$fraction';
  }

  String _tripKindLabel(MileageTripKind kind) => switch (kind) {
    MileageTripKind.businessTrip => _l10n.mileageKindBusinessTrip,
    MileageTripKind.commuting => _l10n.mileageKindCommuting,
    MileageTripKind.eksAllowance => _l10n.mileageKindEksAllowance,
    MileageTripKind.other => _l10n.mileageKindOther,
    MileageTripKind.unknown => _l10n.mileageKindUnknown,
  };

  String _vehicleSourceLabel(MileageVehicleSource source) => switch (source) {
    MileageVehicleSource.private => _l10n.mileageSourcePrivate,
    MileageVehicleSource.company => _l10n.mileageSourceCompany,
    MileageVehicleSource.unknown => _l10n.mileageSourceUnknown,
  };

  String _vehicleClassLabel(MileageVehicleClass vehicleClass) => switch (vehicleClass) {
    MileageVehicleClass.kraftwagen => _l10n.mileageClassKraftwagen,
    MileageVehicleClass.otherMotorVehicle => _l10n.mileageClassOtherMotorVehicle,
    MileageVehicleClass.unsupported => _l10n.mileageClassUnsupported,
    MileageVehicleClass.unknown => _l10n.mileageClassUnknown,
  };

  String _tripStateLabel(MileageTripState state) => switch (state) {
    MileageTripState.unresolved => _l10n.mileageStateUnresolved,
    MileageTripState.calculated => _l10n.mileageStateCalculated,
    MileageTripState.posted => _l10n.mileageStatePosted,
    MileageTripState.corrected => _l10n.mileageStateCorrected,
    MileageTripState.voided => _l10n.mileageStateVoided,
  };

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    unawaited(_scrollController.animateTo(0, duration: const Duration(milliseconds: 180), curve: Curves.easeOut));
  }

  Widget _buildForm() {
    final bool editing = _selectedTripId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                editing ? _l10n.mileageEditTrip : _l10n.mileageNewTrip,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey<String>('mileage-trip-date'),
                controller: _dateController,
                enabled: !_isBusy,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: _l10n.mileageTripDate, hintText: _l10n.mileageDateHint),
                validator: _validateDate,
              ),
              TextFormField(
                key: const ValueKey<String>('mileage-purpose'),
                controller: _purposeController,
                enabled: !_isBusy,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: _l10n.mileagePurpose),
                validator: _validatePurpose,
              ),
              TextFormField(
                key: const ValueKey<String>('mileage-distance'),
                controller: _distanceController,
                enabled: !_isBusy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
                decoration: InputDecoration(labelText: _l10n.mileageDistance),
                validator: _validateDistance,
              ),
              TextFormField(
                key: const ValueKey<String>('mileage-business-context'),
                controller: _contextController,
                enabled: !_isBusy,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: _l10n.mileageBusinessContext),
                validator: _validateBusinessContext,
              ),
              DropdownButtonFormField<MileageTripKind>(
                key: const ValueKey<String>('mileage-trip-kind'),
                initialValue: _tripKind,
                decoration: InputDecoration(labelText: _l10n.mileageTripKind),
                validator: (MileageTripKind? value) => value == null ? _l10n.mileageTripKind : null,
                items: <DropdownMenuItem<MileageTripKind>>[
                  for (final MileageTripKind kind in MileageTripKind.values)
                    DropdownMenuItem<MileageTripKind>(value: kind, child: Text(_tripKindLabel(kind))),
                ],
                onChanged: _isBusy ? null : (MileageTripKind? value) => setState(() => _tripKind = value),
              ),
              DropdownButtonFormField<MileageVehicleSource>(
                key: const ValueKey<String>('mileage-vehicle-source'),
                initialValue: _vehicleSource,
                decoration: InputDecoration(labelText: _l10n.mileageVehicleSource),
                validator: (MileageVehicleSource? value) => value == null ? _l10n.mileageVehicleSource : null,
                items: <DropdownMenuItem<MileageVehicleSource>>[
                  for (final MileageVehicleSource source in MileageVehicleSource.values)
                    DropdownMenuItem<MileageVehicleSource>(value: source, child: Text(_vehicleSourceLabel(source))),
                ],
                onChanged: _isBusy ? null : (MileageVehicleSource? value) => setState(() => _vehicleSource = value),
              ),
              DropdownButtonFormField<MileageVehicleClass>(
                key: const ValueKey<String>('mileage-vehicle-class'),
                initialValue: _vehicleClass,
                decoration: InputDecoration(labelText: _l10n.mileageVehicleClass),
                validator: (MileageVehicleClass? value) => value == null ? _l10n.mileageVehicleClass : null,
                items: <DropdownMenuItem<MileageVehicleClass>>[
                  for (final MileageVehicleClass vehicleClass in MileageVehicleClass.values)
                    DropdownMenuItem<MileageVehicleClass>(
                      value: vehicleClass,
                      child: Text(_vehicleClassLabel(vehicleClass)),
                    ),
                ],
                onChanged: _isBusy ? null : (MileageVehicleClass? value) => setState(() => _vehicleClass = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('mileage-save'),
                      onPressed: _isBusy ? null : _saveTrip,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(editing ? _l10n.mileageUpdate : _l10n.mileageSave),
                    ),
                  ),
                  if (editing) ...<Widget>[
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _isBusy ? null : _startNewTrip, child: Text(_l10n.actionCancel)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(MileageTrip trip) {
    final MileageTripState state = _displayState(trip);
    final bool canCalculate = state == MileageTripState.unresolved;
    final bool canPost = state == MileageTripState.calculated;
    final String actionKeySuffix = '-${trip.id}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(trip.purpose, style: Theme.of(context).textTheme.titleSmall),
                      Text('${trip.tripDate} · ${_formatDistance(trip.distanceHundredthsKm)} km'),
                      Text(
                        '${_tripKindLabel(trip.tripKind)} · ${_vehicleSourceLabel(trip.vehicleSource)} · ${_vehicleClassLabel(trip.vehicleClass)}',
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(_tripStateLabel(state))),
              ],
            ),
            if (trip.calculatedAmount != null)
              Text('${_l10n.mileageAmount}: ${_formatAmount(trip.calculatedAmount!)} €'),
            if (_errorMessage != null && _selectedTripId == trip.id) _buildMessage(_errorMessage!, isError: true),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: ValueKey<String>('mileage-edit-${trip.id}'),
                  onPressed: _isBusy || !_canEdit(trip) ? null : () => _editTrip(trip),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_l10n.mileageEdit),
                ),
                OutlinedButton.icon(
                  key: ValueKey<String>('mileage-calculate$actionKeySuffix'),
                  onPressed: _isBusy || !canCalculate ? null : () => _calculateTrip(trip),
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(_l10n.mileageCalculate),
                ),
                FilledButton.icon(
                  key: ValueKey<String>('mileage-post$actionKeySuffix'),
                  onPressed: _isBusy || !canPost ? null : () => _postTrip(trip),
                  icon: const Icon(Icons.post_add),
                  label: Text(_l10n.mileagePost),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {required bool isError}) {
    final Color color = isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(message, style: TextStyle(color: color)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('mileage-new-trip'),
            onPressed: _isBusy ? null : _startNewTrip,
            icon: const Icon(Icons.add),
            label: Text(_l10n.mileageNewTrip),
          ),
        ),
        if (_errorMessage != null && _selectedTripId == null) _buildMessage(_errorMessage!, isError: true),
        if (_noticeMessage != null) _buildMessage(_noticeMessage!, isError: false),
        if (_isLoading) const LinearProgressIndicator(),
        if (_showForm) _buildForm(),
        const SizedBox(height: 16),
        Text(_l10n.mileageTripListTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey<String>('mileage-search'),
          onChanged: (String value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            labelText: _l10n.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey<String>('mileage-search-clear'),
                    tooltip: _l10n.actionResetFilters,
                    onPressed: () => setState(() => _searchQuery = ''),
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(labelText: _l10n.filterStatusExact),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MileageTripState>(
                    key: const ValueKey<String>('mileage-state-filter'),
                    value: _stateFilter,
                    isExpanded: true,
                    items: <DropdownMenuItem<MileageTripState>>[
                      for (final MileageTripState state in MileageTripState.values)
                        DropdownMenuItem<MileageTripState>(value: state, child: Text(_tripStateLabel(state))),
                    ],
                    onChanged: _isBusy ? null : (MileageTripState? value) => setState(() => _stateFilter = value),
                  ),
                ),
              ),
            ),
            if (_stateFilter != null)
              IconButton(
                key: const ValueKey<String>('mileage-filter-reset'),
                tooltip: _l10n.actionResetFilters,
                onPressed: _isBusy ? null : () => setState(() => _stateFilter = null),
                icon: const Icon(Icons.filter_alt_off),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_visibleTrips.isEmpty && !_isLoading)
          Text(_trips.isEmpty ? _l10n.mileageNoTrips : _l10n.globalSearchNoResults),
        for (final MileageTrip trip in _visibleTrips) _buildTripCard(trip),
      ],
    );
  }
}

int? parseMileageDistanceHundredthsKm(String value) {
  final String normalized = value.trim();
  if (!RegExp(r'^[0-9]+(?:[.,][0-9]{1,2})?$').hasMatch(normalized)) return null;
  final String canonical = normalized.replaceFirst(',', '.');
  final List<String> parts = canonical.split('.');
  final int? whole = int.tryParse(parts.first);
  if (whole == null || whole > 9999999999) return null;
  final String fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  final int? fractionHundredths = int.tryParse(fraction);
  if (fractionHundredths == null) return null;
  final int total = whole * 100 + fractionHundredths;
  return total < 1 || total > 999999999999 ? null : total;
}
