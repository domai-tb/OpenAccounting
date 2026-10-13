// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/setup/catalog_provenance.dart';
import 'package:openaccounting/features/setup/wizard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('settings-setup-workspace-completion onboarding integrity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('test_required_first_run_decisions_are_visible', () {
      expect(WizardStep.values, <WizardStep>[
        WizardStep.stammdaten,
        WizardStep.konten,
        WizardStep.kategorien,
        WizardStep.abschluss,
      ]);
    });

    test('test_blank_identity_is_handled_honestly', () {
      final WizardService svc = WizardService();
      expect(svc.validateStammdaten(name: '', locale: 'de'), isNotNull);
      expect(svc.validateKonten(accounts: const <BankAccount>[], kassenbestand: '0.00', locale: 'de'), isNotNull);
      expect(isSyntheticCategoryLabel('Kategorien 3'), isTrue);
    });
  });
}
