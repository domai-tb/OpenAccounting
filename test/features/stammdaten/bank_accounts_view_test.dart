import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/master_data_more_pages.dart';

void main() {
  testWidgets('Sachkonto can be created without bank details', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
    addTearDown(db.close);

    final AppServices services = AppServices(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: AppScope(
          services: services,
          child: const MaterialApp(
            locale: Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BankAccountsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = lookupAppLocalizations(const Locale('de'));
    await tester.tap(find.text(l10n.actionCreateAccount).first);
    await tester.pumpAndSettle();

    final Finder accountType = find.byKey(const ValueKey<String>('bank_account_type'));
    expect(accountType, findsOneWidget);
    await tester.tap(accountType);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sachkonto').last);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Reisekosten');
    await tester.tap(find.text(l10n.actionCreate).last);
    await tester.pumpAndSettle();

    final account = (await services.bankAccounts.list()).single;
    expect(account.kontoart, 'Sachkonto');
    expect(account.iban, isNull);
    expect(account.bic, isNull);
    expect(find.text(l10n.bankAccountTypeSachkonto), findsOneWidget);
  });

  testWidgets('bank account creation keeps the existing optional IBAN behavior', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
    addTearDown(db.close);

    final AppServices services = AppServices(db);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: AppScope(
          services: services,
          child: const MaterialApp(
            locale: Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BankAccountsView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppLocalizations l10n = lookupAppLocalizations(const Locale('de'));
    await tester.tap(find.text(l10n.actionCreateAccount).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, 'Hausbank');
    await tester.enterText(find.byType(TextField).at(1), 'DE02120300000000202051');
    await tester.tap(find.text(l10n.actionCreate).last);
    await tester.pumpAndSettle();

    final account = (await services.bankAccounts.list()).single;
    expect(account.kontoart, isNull);
    expect(account.iban, 'DE02120300000000202051');
  });
}
