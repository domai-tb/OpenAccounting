import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/desktop/desktop_capability.dart';
import 'package:openaccounting/features/bank_import/banking_usecase.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_availability.dart';
import 'package:openaccounting/features/einkommen/forderungen_usecases.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_einstellungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/features/setup/profile_export_service.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';
import 'package:openaccounting/pages/stammdaten/unternehmen_repository.dart';
import 'package:path/path.dart' as p;

/// Aggregated use-cases for the application.
/// Pages resolve from here instead of constructing repositories directly.
class AppServices {
  AppServices(this._db, {DesktopCapabilityRegistry? desktopCapabilities})
    : desktopCapabilities = desktopCapabilities ?? DesktopCapabilityRegistry();

  final AppDatabase _db;
  final DesktopCapabilityRegistry desktopCapabilities;

  late final RechnungenUseCases rechnungen = RechnungenUseCases(
    RechnungenRepository(RechnungenDataSource(_db.executor, profileDir: _db.profileDir)),
  );

  late final ForderungenUseCases forderungen = ForderungenUseCases(ForderungenRepository(_db.executor));

  late final BuchungsVorlagenRepository buchungsVorlagen = BuchungsVorlagenRepository(_db.executor);

  late final RechnungsVorlagenRepository rechnungsVorlagen = RechnungsVorlagenRepository(_db.executor);

  late final KundenRepository kunden = KundenRepository(_db.executor);

  late final LieferantenRepository lieferanten = LieferantenRepository(_db.executor);

  late final ArtikelRepository artikel = ArtikelRepository(_db.executor);

  late final UnternehmenRepository unternehmen = UnternehmenRepository(_db.executor, profileDir: _db.profileDir);

  late final KategorienRepository kategorien = KategorienRepository(_db.executor, categoryWorkspaceAvailable: true);

  late final CustomerWorkspaceUseCase customerWorkspace = CustomerWorkspaceUseCase(kunden);

  late final SupplierWorkspaceUseCase supplierWorkspace = SupplierWorkspaceUseCase(lieferanten);

  late final ContactDetailUseCase contactDetail = ContactDetailUseCase(kunden: kunden, lieferanten: lieferanten);

  late final ContactFormUseCase contactForm = ContactFormUseCase(kunden: kunden, lieferanten: lieferanten);

  late final ArticleWorkspaceUseCase articleWorkspace = ArticleWorkspaceUseCase(artikel);

  late final ArticleGroupWorkspaceUseCase articleGroupWorkspace = ArticleGroupWorkspaceUseCase(artikel);

  late final ArticleDetailUseCase articleDetail = ArticleDetailUseCase(artikel);

  late final CompanySettingsUseCase companySettings = CompanySettingsUseCase(unternehmen);

  late final CategoryWorkspaceUseCase categoryWorkspace = CategoryWorkspaceUseCase(kategorien);

  late final BankAccountWorkspaceUseCase bankAccounts = BankAccountWorkspaceUseCase(
    BankAccountRepository(_db.executor),
  );

  late final TaxRateWorkspaceUseCase taxRates = TaxRateWorkspaceUseCase(TaxRateRepository(_db.executor));

  late final NumberRangeWorkspaceUseCase numberRanges = NumberRangeWorkspaceUseCase(
    NumberRangeRepository(_db.executor),
  );

  late final MahnungenRepository mahnungen = MahnungenRepository(_db.executor, profileDir: _db.profileDir);
  late final MahnstufenRepository mahnstufen = MahnstufenRepository(_db.executor);
  late final MahnwesenEinstellungenRepository mahnwesenEinstellungen = MahnwesenEinstellungenRepository(_db.executor);
  late final SperrungService sperrung = SperrungService(_db.executor);
  late final BankingUseCase banking = BankingUseCase(_db.executor);
  late final IncomeTaxScheduleAvailabilityUseCase incomeTax = const IncomeTaxScheduleAvailabilityUseCase();
  late final WizardService setup = WizardService(repository: SetupRepository(_db.executor), profileId: _db.profileDir);

  late final ProfileExportService profileExport = _createProfileExport();

  ProfileExportService _createProfileExport() {
    final String? directory = _db.profileDir;
    final String label = directory == null || directory.isEmpty ? 'Profil' : p.basename(directory);
    return ProfileExportService(executor: _db.executor, profileDir: directory ?? '', profileLabel: label);
  }
}

/// Provides the aggregated application services.
/// Throws if the database is not ready (not overridden with a ready instance).
final appServicesProvider = Provider<AppServices>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AppServices(db);
});
