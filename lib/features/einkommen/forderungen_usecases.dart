import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

class ForderungenUseCases {
  const ForderungenUseCases(this.repo);
  final ForderungenRepository repo;

  Future<Forderung> forderungAnlegen({
    required String typ,
    required num betrag,
    required String partnerTyp,
    required int partnerId,
    int? rechnungId,
  }) => repo.create(typ: typ, betrag: betrag, partnerTyp: partnerTyp, partnerId: partnerId, rechnungId: rechnungId);

  Future<Forderung?> forderungFuerRechnung(int rechnungId) => repo.createForRechnung(rechnungId);

  Future<Forderung> zahlungBuchen({required int forderungId, required num betrag, String? datum}) =>
      repo.zahlungBuchen(forderungId: forderungId, betrag: betrag, datum: datum);

  Future<Forderung> forderungAusbuchen({required int forderungId, required String grund}) =>
      repo.ausbuchen(forderungId: forderungId, grund: grund);

  Future<List<Forderung>> offeneForderungen() => repo.listOffene();

  Future<List<KontokorrentEintrag>> kontokorrent({
    required String partnerTyp,
    required int partnerId,
    String? von,
    String? bis,
  }) => repo.kontokorrent(partnerTyp: partnerTyp, partnerId: partnerId, von: von, bis: bis);
}
