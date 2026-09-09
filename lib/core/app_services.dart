import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_usecases.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_einstellungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';

/// Aggregated use-cases for the application.
/// Pages resolve from here instead of constructing repositories directly.
class AppServices {
  AppServices(this._db);

  final AppDatabase _db;

  late final RechnungenUseCases rechnungen = RechnungenUseCases(
    RechnungenRepository(RechnungenDataSource(_db.executor, profileDir: _db.profileDir)),
  );

  late final ForderungenUseCases forderungen = ForderungenUseCases(ForderungenRepository(_db.executor));

  late final BuchungsVorlagenRepository buchungsVorlagen = BuchungsVorlagenRepository(_db.executor);

  late final RechnungsVorlagenRepository rechnungsVorlagen = RechnungsVorlagenRepository(_db.executor);

  late final MahnungenRepository mahnungen = MahnungenRepository(_db.executor);
  late final MahnstufenRepository mahnstufen = MahnstufenRepository(_db.executor);
  late final MahnwesenEinstellungenRepository mahnwesenEinstellungen = MahnwesenEinstellungenRepository(_db.executor);
  late final SperrungService sperrung = SperrungService(_db.executor);
}

/// Provides the aggregated application services.
/// Throws if the database is not ready (not overridden with a ready instance).
final appServicesProvider = Provider<AppServices>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AppServices(db);
});
