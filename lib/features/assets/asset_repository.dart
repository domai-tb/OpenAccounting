import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/assets/asset_entity.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';

/// Typed asset-register repository over `anlageverzeichnis`.
///
/// Reads treat `kaufpreis_netto` as canonical and never reinterpret legacy
/// columns. Every write that sets `kaufpreis_netto` also writes
/// `anschaffungskosten` with the same amount for the legacy NOT NULL column.
/// The repository never touches the journal.
class AssetRepository {
  AssetRepository(this.executor);

  final QueryExecutor executor;

  /// Idempotent additive schema guard for tests and repaired profiles.
  Future<void> ensureSchema() async {
    const Map<String, String> additions = <String, String>{
      'asset_typ': "TEXT CHECK (asset_typ IN ('KFZ','EDV','sonstig'))",
      'kaufpreis_netto': 'NUMERIC(12,2) CHECK (kaufpreis_netto >= 0)',
      'nutzungsdauer_jahre': 'INTEGER CHECK (nutzungsdauer_jahre > 0)',
      'afa_methode': "TEXT CHECK (afa_methode IN ('linear'))",
      'privat_anteil_prozent': 'NUMERIC(5,2) CHECK (privat_anteil_prozent BETWEEN 0 AND 100)',
      'verkauft_am': 'TEXT',
    };
    for (final MapEntry<String, String> entry in additions.entries) {
      final List<Map<String, Object?>> columns = await executor.runSelect(
        'PRAGMA table_info(anlageverzeichnis)',
        const <Object?>[],
      );
      if (columns.any((Map<String, Object?> column) => column['name'] == entry.key)) continue;
      await executor.runCustom('ALTER TABLE anlageverzeichnis ADD COLUMN ${entry.key} ${entry.value}');
    }
    await executor.runCustom(_scheduleTableSql);
    await executor.runCustom(_scheduleNoUpdateTrigger);
    await executor.runCustom(_scheduleNoDeleteTrigger);
  }

  Future<List<FixedAsset>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM anlageverzeichnis ORDER BY id',
      const <Object?>[],
    );
    return <FixedAsset>[for (final Map<String, Object?> row in rows) _toAsset(row)];
  }

  Future<FixedAsset?> findById(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT * FROM anlageverzeichnis WHERE id = ? LIMIT 1',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _toAsset(rows.single);
  }

  Future<FixedAsset> create({
    required String bezeichnung,
    required String assetTyp,
    required String anschaffungsdatum,
    required String kaufpreisNetto,
    required int nutzungsdauerJahre,
    String afaMethode = 'linear',
    String privatAnteilProzent = '0',
    int? kategorieId,
    int? unternehmenId,
    String? verkauftAm,
  }) async {
    final String? invalid = validateNewAssetInputs(
      bezeichnung: bezeichnung,
      assetTyp: assetTyp,
      anschaffungsdatum: anschaffungsdatum,
      kaufpreisNetto: kaufpreisNetto,
      nutzungsdauerJahre: nutzungsdauerJahre,
      afaMethode: afaMethode,
      privatAnteilProzent: privatAnteilProzent,
    );
    if (invalid != null) {
      throw AssetValidationException(invalid, 'Anlage ungültig: $invalid');
    }
    final String? disposalDate = verkauftAm?.trim();
    final String? normalizedDisposalDate = disposalDate == null || disposalDate.isEmpty ? null : disposalDate;
    // Compat write: the legacy required column carries the same amount.
    final int id = await executor.runInsert(
      'INSERT INTO anlageverzeichnis (bezeichnung, anschaffungsdatum, anschaffungskosten, nutzungsdauer, '
      'kategorie_id, unternehmen_id, status, privatanteil, asset_typ, kaufpreis_netto, nutzungsdauer_jahre, '
      'afa_methode, privat_anteil_prozent, verkauft_am) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        bezeichnung.trim(),
        anschaffungsdatum.trim(),
        kaufpreisNetto.trim(),
        nutzungsdauerJahre,
        kategorieId,
        unternehmenId,
        'aktiv',
        privatAnteilProzent.trim(),
        assetTyp,
        kaufpreisNetto.trim(),
        nutzungsdauerJahre,
        afaMethode,
        privatAnteilProzent.trim(),
        normalizedDisposalDate,
      ],
    );
    final FixedAsset? created = await findById(id);
    if (created == null) throw StateError('Anlage konnte nach dem Speichern nicht gelesen werden');
    return created;
  }

  Future<FixedAsset> update(
    int id, {
    String? bezeichnung,
    String? assetTyp,
    String? anschaffungsdatum,
    String? kaufpreisNetto,
    int? nutzungsdauerJahre,
    String? afaMethode,
    String? privatAnteilProzent,
    int? kategorieId,
    String? verkauftAm,
    String? status,
  }) async {
    final FixedAsset? current = await findById(id);
    if (current == null) throw StateError('Anlage $id nicht gefunden');
    final String nextTyp = assetTyp ?? current.assetTyp?.db ?? '';
    final String nextPrice = kaufpreisNetto ?? current.kaufpreisNetto ?? '';
    final int? nextLife = nutzungsdauerJahre ?? current.nutzungsdauerJahre;
    final String? invalid = validateNewAssetInputs(
      bezeichnung: bezeichnung ?? current.bezeichnung,
      assetTyp: nextTyp.isEmpty ? null : nextTyp,
      anschaffungsdatum: anschaffungsdatum ?? current.anschaffungsdatum,
      kaufpreisNetto: nextPrice.isEmpty ? null : nextPrice,
      nutzungsdauerJahre: nextLife,
      afaMethode: afaMethode ?? current.afaMethode,
      privatAnteilProzent: privatAnteilProzent ?? current.privatAnteilProzent ?? '0',
    );
    if (invalid != null) {
      throw AssetValidationException(invalid, 'Anlage ungültig: $invalid');
    }
    final String? newNetPrice = kaufpreisNetto?.trim();
    final String? currentNetPrice = current.kaufpreisNetto;
    final String? netPrice = newNetPrice == null || newNetPrice.isEmpty ? currentNetPrice : newNetPrice;
    final String? disposalDate = verkauftAm?.trim() ?? current.verkauftAm;
    final String? normalizedDisposalDate = disposalDate == null || disposalDate.isEmpty ? null : disposalDate;
    // Prior snapshots stay immutable; only the register row changes.
    await executor.runUpdate(
      'UPDATE anlageverzeichnis SET bezeichnung = ?, anschaffungsdatum = ?, anschaffungskosten = ?, '
      'nutzungsdauer = ?, kategorie_id = ?, status = ?, privatanteil = ?, asset_typ = ?, '
      'kaufpreis_netto = ?, nutzungsdauer_jahre = ?, afa_methode = ?, privat_anteil_prozent = ?, '
      'verkauft_am = ? WHERE id = ?',
      <Object?>[
        (bezeichnung ?? current.bezeichnung).trim(),
        (anschaffungsdatum ?? current.anschaffungsdatum).trim(),
        (kaufpreisNetto ?? current.kaufpreisNetto ?? current.legacyAnschaffungskosten ?? '0').trim(),
        nutzungsdauerJahre ?? current.nutzungsdauerJahre ?? current.legacyNutzungsdauer,
        kategorieId ?? current.kategorieId,
        status ?? current.status,
        (privatAnteilProzent ?? current.privatAnteilProzent ?? '0').trim(),
        assetTyp ?? current.assetTyp?.db,
        netPrice,
        nutzungsdauerJahre ?? current.nutzungsdauerJahre,
        afaMethode ?? current.afaMethode,
        (privatAnteilProzent ?? current.privatAnteilProzent ?? '0').trim(),
        normalizedDisposalDate,
        id,
      ],
    );
    final FixedAsset? updated = await findById(id);
    if (updated == null) throw StateError('Anlage $id konnte nach der Änderung nicht gelesen werden');
    return updated;
  }

  /// Archives instead of deleting once schedule history exists.
  Future<FixedAsset> archive(int id) async {
    final FixedAsset? current = await findById(id);
    if (current == null) throw StateError('Anlage $id nicht gefunden');
    await executor.runUpdate("UPDATE anlageverzeichnis SET status = 'archiviert' WHERE id = ?", <Object?>[id]);
    final FixedAsset? archived = await findById(id);
    if (archived == null) throw StateError('Anlage $id konnte nach der Archivierung nicht gelesen werden');
    return archived;
  }

  /// Hard deletion is only allowed before any schedule snapshot exists.
  Future<void> delete(int id) async {
    if (await hasScheduleHistory(id)) {
      throw const AssetInUseException(
        'Anlage kann nicht gelöscht werden: AfA-Jahreswerte vorhanden. Bitte archivieren.',
      );
    }
    await executor.runDelete('DELETE FROM anlageverzeichnis WHERE id = ?', <Object?>[id]);
  }

  Future<bool> hasScheduleHistory(int anlageId) async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT COUNT(*) AS c FROM anlage_afa_jahreswerte WHERE anlage_id = ?',
        <Object?>[anlageId],
      );
      final Object? value = rows.single['c'];
      if (value is num) return value.toInt() > 0;
      return (int.tryParse(value?.toString() ?? '0') ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> persistScheduleRow(AssetScheduleRow row) async {
    final String scheduleStatus = row.isAvailable ? 'verfuegbar' : 'nicht_verfuegbar';
    await executor.runInsert(
      'INSERT OR IGNORE INTO anlage_afa_jahreswerte (anlage_id, jahr, quell_snapshot, quell_hash, regel_version, '
      'status, formel, betrag, blockierungsgrund, berechnet_am) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        row.anlageId,
        row.jahr,
        row.quellSnapshot,
        row.quellHash,
        row.regelVersion,
        scheduleStatus,
        row.formel,
        row.betrag,
        row.blockierungsgrund,
        row.berechnetAm,
      ],
    );
  }

  Future<List<Map<String, Object?>>> scheduleHistory(int anlageId) async {
    return executor.runSelect('SELECT * FROM anlage_afa_jahreswerte WHERE anlage_id = ? ORDER BY jahr, id', <Object?>[
      anlageId,
    ]);
  }

  FixedAsset _toAsset(Map<String, Object?> row) {
    int? asInt(Object? value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    String? asText(Object? value) {
      if (value == null) return null;
      final String text = value.toString();
      return text.isEmpty ? null : text;
    }

    String? asMoney(Object? value) {
      final String? text = asText(value);
      if (text == null) return null;
      try {
        return money.formatBetrag(text);
      } on money.MoneyParseException {
        return null;
      }
    }

    return FixedAsset(
      id: (row['id']! as num).toInt(),
      bezeichnung: row['bezeichnung']?.toString() ?? '',
      assetTyp: row.containsKey('asset_typ') ? AssetTyp.fromDb(row['asset_typ']) : null,
      anschaffungsdatum: row['anschaffungsdatum']?.toString() ?? '',
      kaufpreisNetto: row.containsKey('kaufpreis_netto') ? asMoney(row['kaufpreis_netto']) : null,
      nutzungsdauerJahre: row.containsKey('nutzungsdauer_jahre') ? asInt(row['nutzungsdauer_jahre']) : null,
      afaMethode: row.containsKey('afa_methode') ? asText(row['afa_methode']) : null,
      privatAnteilProzent: row.containsKey('privat_anteil_prozent') ? asText(row['privat_anteil_prozent']) : null,
      kategorieId: asInt(row['kategorie_id']),
      unternehmenId: asInt(row['unternehmen_id']),
      verkauftAm: row.containsKey('verkauft_am') ? asText(row['verkauft_am']) : null,
      status: row['status']?.toString() ?? 'aktiv',
      legacyAnschaffungskosten: asText(row['anschaffungskosten']),
      legacyNutzungsdauer: asInt(row['nutzungsdauer']),
      legacyPrivatanteil: asText(row['privatanteil']),
    );
  }

  static const String _scheduleTableSql = '''
CREATE TABLE IF NOT EXISTS anlage_afa_jahreswerte (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  anlage_id INTEGER NOT NULL REFERENCES anlageverzeichnis(id) ON DELETE RESTRICT,
  jahr INTEGER NOT NULL,
  quell_snapshot TEXT NOT NULL,
  quell_hash TEXT NOT NULL,
  regel_version TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('verfuegbar', 'nicht_verfuegbar')),
  formel TEXT,
  betrag NUMERIC(12,2),
  blockierungsgrund TEXT,
  berechnet_am TEXT NOT NULL,
  CHECK ((status = 'verfuegbar' AND betrag IS NOT NULL AND blockierungsgrund IS NULL) OR (status = 'nicht_verfuegbar' AND betrag IS NULL AND blockierungsgrund IS NOT NULL AND trim(blockierungsgrund) <> '')),
  UNIQUE (anlage_id, jahr, quell_hash, regel_version)
)''';

  static const String _scheduleNoUpdateTrigger = '''
CREATE TRIGGER IF NOT EXISTS trg_anlage_afa_no_update
BEFORE UPDATE ON anlage_afa_jahreswerte
BEGIN SELECT RAISE(ABORT, 'anlage_afa_jahreswerte is append-only'); END''';

  static const String _scheduleNoDeleteTrigger = '''
CREATE TRIGGER IF NOT EXISTS trg_anlage_afa_no_delete
BEFORE DELETE ON anlage_afa_jahreswerte
BEGIN SELECT RAISE(ABORT, 'anlage_afa_jahreswerte is append-only'); END''';
}
