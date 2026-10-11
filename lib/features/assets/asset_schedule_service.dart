import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/assets/asset_entity.dart';

/// Result state of one annual schedule row.
enum AssetScheduleStatus { verfuegbar, nichtVerfuegbar }

/// One traceable annual AfA row: asset, year, source snapshot, formula, result.
class AssetScheduleRow {
  const AssetScheduleRow({
    required this.anlageId,
    required this.jahr,
    required this.quellSnapshot,
    required this.quellHash,
    required this.regelVersion,
    required this.status,
    this.formel,
    this.betrag,
    this.blockierungsgrund,
    required this.berechnetAm,
  });

  final int anlageId;
  final int jahr;
  final String quellSnapshot;
  final String quellHash;
  final String regelVersion;
  final AssetScheduleStatus status;
  final String? formel;
  final String? betrag;
  final String? blockierungsgrund;
  final String berechnetAm;

  bool get isAvailable => status == AssetScheduleStatus.verfuegbar;
}

/// Shared schedule owner for the asset workspace and the owning EÜR workflow.
///
/// Only full-year linear AfA per the maintained contract is supported:
/// `kaufpreis_netto / nutzungsdauer_jahre` rounded half-up to the cent,
/// computed independently per year with no final-year remainder adjustment.
/// At most `nutzungsdauer_jahre` full-year rows exist. Everything else fails
/// closed with a blocking reason; zero is never substituted.
class AssetScheduleService {
  const AssetScheduleService();

  /// Computes the schedule row for [asset] and [jahr] without touching the DB.
  AssetScheduleRow computeRow({required FixedAsset asset, required int jahr}) {
    final String snapshot = snapshotFor(asset);
    final String hash = hashForSnapshot(snapshot);
    final String now = DateTime.now().toUtc().toIso8601String();
    AssetScheduleRow unavailable(String reason) {
      return AssetScheduleRow(
        anlageId: asset.id,
        jahr: jahr,
        quellSnapshot: snapshot,
        quellHash: hash,
        regelVersion: assetRegelVersion,
        status: AssetScheduleStatus.nichtVerfuegbar,
        blockierungsgrund: reason,
        berechnetAm: now,
      );
    }

    // Unresolved legacy or missing canonical inputs fail closed first.
    if (!asset.hasCanonicalInputs) {
      if (asset.hasUnresolvedLegacy) {
        return unavailable(
          'unaufgeloeste-quelle: anschaffungskosten/nutzungsdauer/privatanteil ohne bestaetigte Zuordnung',
        );
      }
      return unavailable('unaufgeloeste-quelle: ${_missingInput(asset)}');
    }
    final DateTime acquisition = DateTime.parse(asset.anschaffungsdatum.trim().substring(0, 10));
    if (jahr <= acquisition.year) {
      if (jahr < acquisition.year) return unavailable('vor-anschaffung: jahr liegt vor anschaffungsdatum');
      return unavailable('anschaffungsjahr-teiljahr: keine Teiljahres-AfA ohne akzeptierte Regel');
    }
    // Disposal cutoff and remaining book value have no accepted contract.
    if (asset.verkauftAm != null && asset.verkauftAm!.trim().isNotEmpty) {
      final DateTime? disposal = DateTime.tryParse(asset.verkauftAm!.trim().substring(0, 10));
      if (disposal == null) return unavailable('entsorgung-ohne-vertrag: verkauft_am ist kein gueltiges Datum');
      if (jahr >= disposal.year) {
        return unavailable('entsorgung-ohne-vertrag: disposition cutoff ohne akzeptierte Regel');
      }
    }
    final int life = asset.nutzungsdauerJahre!;
    if (jahr > acquisition.year + life) {
      return unavailable('nutzungsdauer-ueberschritten: jahr liegt jenseits der $life vollen Jahre');
    }
    // Private-use reduction applies only to KFZ until a type rule is accepted.
    final double privat = double.parse(asset.privatAnteilProzent?.trim().replaceAll(',', '.') ?? '0');
    if (asset.assetTyp != AssetTyp.kfz && privat != 0) {
      return unavailable('privatanteil-ohne-regel: nicht-KFZ mit privat_anteil_prozent ohne akzeptierte Regel');
    }
    final int kostenCents = money.toCents(money.formatBetrag(asset.kaufpreisNetto!));
    final int baseCents = _roundHalfUp(kostenCents, life);
    final int privatCents = money.toCents(money.formatBetrag(privat.toStringAsFixed(2)));
    final int clampedPrivat = privatCents < 0 ? 0 : (privatCents > 10000 ? 10000 : privatCents);
    final int businessBps = 10000 - clampedPrivat;
    final int amountCents = _roundHalfUp(baseCents * businessBps, 10000);
    final String priceText = money.formatBetrag(asset.kaufpreisNetto!);
    final String formel = businessBps == 10000 ? '$priceText / $life' : '$priceText / $life × ${businessBps ~/ 100}%';
    return AssetScheduleRow(
      anlageId: asset.id,
      jahr: jahr,
      quellSnapshot: snapshot,
      quellHash: hash,
      regelVersion: assetRegelVersion,
      status: AssetScheduleStatus.verfuegbar,
      formel: formel,
      betrag: money.fromCents(amountCents),
      berechnetAm: now,
    );
  }

  /// Full-year rows for every supported year of [asset]'s useful life.
  List<AssetScheduleRow> fullSchedule(FixedAsset asset) {
    if (!asset.hasCanonicalInputs) return <AssetScheduleRow>[];
    final DateTime acquisition = DateTime.parse(asset.anschaffungsdatum.trim().substring(0, 10));
    return <AssetScheduleRow>[
      for (int offset = 1; offset <= asset.nutzungsdauerJahre!; offset++)
        computeRow(asset: asset, jahr: acquisition.year + offset),
    ];
  }

  /// Canonical source-input snapshot traced by every schedule row.
  static String snapshotFor(FixedAsset asset) {
    return jsonEncode(<String, Object?>{
      'bezeichnung': asset.bezeichnung,
      'asset_typ': asset.assetTyp?.db,
      'kaufpreis_netto': asset.kaufpreisNetto,
      'nutzungsdauer_jahre': asset.nutzungsdauerJahre,
      'afa_methode': asset.afaMethode,
      'privat_anteil_prozent': asset.privatAnteilProzent,
      'anschaffungsdatum': asset.anschaffungsdatum,
      'verkauft_am': asset.verkauftAm,
      'kategorie_id': asset.kategorieId,
    });
  }

  static String hashForSnapshot(String snapshot) {
    return sha256.convert(utf8.encode(snapshot)).toString().substring(0, 16);
  }

  static String _missingInput(FixedAsset asset) {
    if (asset.assetTyp == null) return 'asset_typ fehlt';
    if (asset.kaufpreisNetto == null) return 'kaufpreis_netto fehlt';
    if (asset.nutzungsdauerJahre == null) return 'nutzungsdauer_jahre fehlt';
    if (asset.afaMethode != 'linear') return 'afa_methode nicht linear';
    return 'anschaffungsdatum fehlt';
  }

  static int _roundHalfUp(int numerator, int denominator) {
    if (denominator <= 0) throw ArgumentError('denominator must be positive');
    if (numerator < 0) return -_roundHalfUp(-numerator, denominator);
    return (numerator + denominator ~/ 2) ~/ denominator;
  }
}
