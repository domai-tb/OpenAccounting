/// Physical stocktake count evidence — immutable once recorded.
/// A recorded count never carries a book quantity, variance, or valuation;
/// those stay unavailable until their own contracts land (fail-closed).
enum StocktakeStatus { entwurf, erfasst }

/// One snapshotted article line of a stocktake.
class StocktakePosition {
  const StocktakePosition({
    required this.id,
    required this.inventurId,
    required this.artikelId,
    required this.bezeichnungSnapshot,
    required this.einheitSnapshot,
    this.mengeGezaehlt,
  });

  final int id;
  final int inventurId;
  final int artikelId;
  final String bezeichnungSnapshot;
  final String einheitSnapshot;

  /// Explicit counted quantity; null means "not counted yet" (draft only).
  /// Null is never zero.
  final num? mengeGezaehlt;
}

/// A stocktake session: selected reporting date plus capture timestamp.
/// No book quantity, variance, or monetary value is stored here by design.
class Stocktake {
  const Stocktake({
    required this.id,
    required this.stichtag,
    required this.status,
    required this.erstelltAm,
    this.positionen = const <StocktakePosition>[],
  });

  final int id;
  final String stichtag;
  final StocktakeStatus status;
  final String erstelltAm;
  final List<StocktakePosition> positionen;

  bool get isRecorded => status == StocktakeStatus.erfasst;
}
