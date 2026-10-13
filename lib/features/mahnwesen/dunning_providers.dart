import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/document_delivery/email_attempt_repository.dart';
import 'package:openaccounting/features/document_delivery/smtp_configuration_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_credential_vault.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/collection_package_service.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/dunning_exclusions_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_send_service.dart';
import 'package:openaccounting/features/mahnwesen/dunning_service.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

/// Riverpod seams for the `/mahnwesen` workspace. Pages resolve the dunning
/// capability through these instead of constructing repositories or SQL.
final settledBalanceSourceProvider = Provider<SettledBalanceSource>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return SettledBalanceSource(db.executor);
});

final dunningExclusionsRepositoryProvider = Provider<DunningExclusionsRepository>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return DunningExclusionsRepository(db.executor);
});

final dunningServiceProvider = Provider<DunningService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return DunningService(
    executor: db.executor,
    mahnungen: MahnungenRepository(db.executor, profileDir: db.profileDir),
    stufen: MahnstufenRepository(db.executor),
    balances: ref.watch(settledBalanceSourceProvider),
    exclusions: ref.watch(dunningExclusionsRepositoryProvider),
    sperrung: SperrungService(db.executor),
  );
});

final dunningSendServiceProvider = Provider<DunningSendService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return DunningSendService(
    executor: db.executor,
    mahnungen: MahnungenRepository(db.executor, profileDir: db.profileDir),
    configuration: SmtpConfigurationService(
      executor: db.executor,
      transport: const DartIoSmtpTransport(),
      migration: SmtpCredentialMigration(
        vault: const UnavailableVault(),
        legacyFile: LegacySecretFile(db.profileDir),
        identity: ProfileIdentityStore(db.profileDir),
      ),
    ),
    attempts: EmailAttemptRepository(db.executor),
    profileDir: db.profileDir,
  );
});

final collectionPackageServiceProvider = Provider<CollectionPackageService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return CollectionPackageService(
    executor: db.executor,
    mahnungen: MahnungenRepository(db.executor, profileDir: db.profileDir),
    balances: ref.watch(settledBalanceSourceProvider),
    forderungen: ForderungenRepository(db.executor),
    profileDir: db.profileDir,
  );
});
