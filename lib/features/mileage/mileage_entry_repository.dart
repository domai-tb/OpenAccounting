import 'package:drift/drift.dart';

import 'package:openaccounting/features/mileage/mileage_entry_entity.dart';

/// Mileage repository — raw SQL via drift executor, no codegen.
/// shortcut: migration disabled until portability/export accept inventory, tests call ensureTablesForTests only.
class MileageEntryRepository {
  MileageEntryRepository(this.executor);

  final QueryExecutor executor;

  Future<void> ensureTablesForTests() async {
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS mileage_trips (
  id TEXT PRIMARY KEY NOT NULL,
  trip_date TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (length(trim(purpose)) > 0),
  business_context TEXT NOT NULL CHECK (length(trim(business_context)) > 0),
  distance_hundredths_km INTEGER NOT NULL CHECK (distance_hundredths_km BETWEEN 1 AND 999999999999),
  state TEXT NOT NULL CHECK (state IN ('unresolved','calculated','posted','corrected','voided')),
  policy_id TEXT,
  policy_source TEXT,
  policy_version TEXT,
  policy_effective_from TEXT,
  policy_effective_to TEXT,
  calculated_amount NUMERIC(12,2),
  calculated_at TEXT,
  posting_event_id TEXT UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''', const <Object?>[]);
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS mileage_trip_corrections (
  id TEXT PRIMARY KEY NOT NULL,
  trip_id TEXT NOT NULL REFERENCES mileage_trips(id) ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK (kind IN ('replace','void')),
  replacement_trip_id TEXT UNIQUE REFERENCES mileage_trips(id) ON DELETE RESTRICT,
  reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
  state TEXT NOT NULL CHECK (state IN ('draft','applied','cancelled')),
  accounting_correction_id TEXT UNIQUE,
  created_at TEXT NOT NULL,
  applied_at TEXT
)''', const <Object?>[]);
  }

  Future<void> insertTrip(MileageTrip trip) async {
    await executor.runInsert(
      'INSERT INTO mileage_trips (id, trip_date, purpose, business_context, '
      'distance_hundredths_km, state, policy_id, policy_source, policy_version, '
      'policy_effective_from, policy_effective_to, calculated_amount, calculated_at, '
      'posting_event_id, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        trip.id,
        trip.tripDate,
        trip.purpose,
        trip.businessContext,
        trip.distanceHundredthsKm,
        trip.state.name,
        trip.policyId,
        trip.policySource,
        trip.policyVersion,
        trip.policyEffectiveFrom,
        trip.policyEffectiveTo,
        trip.calculatedAmount,
        trip.calculatedAt,
        trip.postingEventId,
        trip.createdAt,
        trip.updatedAt,
      ],
    );
  }

  Future<List<MileageTrip>> listTrips() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM mileage_trips ORDER BY trip_date DESC, id DESC',
      const <Object?>[],
    );
    return <MileageTrip>[for (final Map<String, Object?> r in rows) _fromRow(r)];
  }

  Future<MileageTrip?> getById(String id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM mileage_trips WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<void> updateUnresolvedFacts({
    required String id,
    required String purpose,
    required String tripDate,
    required int dist,
  }) async {
    await executor.runUpdate(
      'UPDATE mileage_trips SET purpose = ?, trip_date = ?, distance_hundredths_km = ?, '
      'updated_at = ? WHERE id = ? AND state = ?',
      <Object?>[purpose, tripDate, dist, DateTime.now().toUtc().toIso8601String(), id, 'unresolved'],
    );
  }

  Future<void> storeCalculation({
    required String id,
    required String policyId,
    required String policySource,
    required String policyVersion,
    required String policyFrom,
    required String policyTo,
    required String amount,
    required String calculatedAt,
  }) async {
    await executor.runUpdate(
      'UPDATE mileage_trips SET state = ?, policy_id = ?, policy_source = ?, policy_version = ?, '
      'policy_effective_from = ?, policy_effective_to = ?, calculated_amount = ?, calculated_at = ?, '
      'updated_at = ? WHERE id = ? AND state = ?',
      <Object?>[
        'calculated',
        policyId,
        policySource,
        policyVersion,
        policyFrom,
        policyTo,
        amount,
        calculatedAt,
        DateTime.now().toUtc().toIso8601String(),
        id,
        'unresolved',
      ],
    );
  }

  Future<void> storePosting({required String id, required String eventId}) async {
    await executor.runUpdate(
      'UPDATE mileage_trips SET state = ?, posting_event_id = ?, updated_at = ? '
      'WHERE id = ? AND state = ?',
      <Object?>['posted', eventId, DateTime.now().toUtc().toIso8601String(), id, 'calculated'],
    );
  }

  MileageTrip _fromRow(Map<String, Object?> r) {
    return MileageTrip(
      id: '${r['id']}',
      tripDate: '${r['trip_date']}',
      purpose: '${r['purpose']}',
      businessContext: '${r['business_context']}',
      distanceHundredthsKm: (r['distance_hundredths_km']! as num).toInt(),
      state: MileageTrip.stateFrom('${r['state']}'),
      createdAt: '${r['created_at']}',
      updatedAt: '${r['updated_at']}',
      policyId: r['policy_id']?.toString(),
      policySource: r['policy_source']?.toString(),
      policyVersion: r['policy_version']?.toString(),
      policyEffectiveFrom: r['policy_effective_from']?.toString(),
      policyEffectiveTo: r['policy_effective_to']?.toString(),
      calculatedAmount: r['calculated_amount']?.toString(),
      calculatedAt: r['calculated_at']?.toString(),
      postingEventId: r['posting_event_id']?.toString(),
    );
  }
}
