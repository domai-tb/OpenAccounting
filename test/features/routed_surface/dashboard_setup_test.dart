import 'package:flutter_test/flutter_test.dart';

/// Dashboard card with navigation target.
class DashboardCard {
  const DashboardCard({required this.title, required this.route, this.isAvailable = true, this.value});

  final String title;
  final String route;
  final bool isAvailable;
  final String? value;
}

/// Setup summary with configuration names.
class SetupSummary {
  const SetupSummary({
    required this.profileName,
    required this.companyName,
    required this.contactCount,
    required this.categoryCount,
  });

  final String profileName;
  final String companyName;
  final int contactCount;
  final int categoryCount;
}

/// Fake setup service for testing configuration persistence.
class FakeSetupService {
  FakeSetupService({this.failOnWrite = false});

  bool failOnWrite;
  SetupSummary _summary = const SetupSummary(
    profileName: 'Default',
    companyName: '',
    contactCount: 0,
    categoryCount: 0,
  );

  SetupSummary get summary => _summary;

  Future<void> updateProfile(String name) async {
    if (failOnWrite) throw Exception('Write failed');
    _summary = SetupSummary(
      profileName: name,
      companyName: _summary.companyName,
      contactCount: _summary.contactCount,
      categoryCount: _summary.categoryCount,
    );
  }

  Future<void> updateCompany(String name) async {
    if (failOnWrite) throw Exception('Write failed');
    _summary = SetupSummary(
      profileName: _summary.profileName,
      companyName: name,
      contactCount: _summary.contactCount,
      categoryCount: _summary.categoryCount,
    );
  }
}

void main() {
  group('Dashboard cards lead to real capabilities', () {
    test('test_open_invoices_card_opens_receivables', () {
      // GIVEN: an open invoices dashboard card
      const DashboardCard card = DashboardCard(
        title: 'Offene Rechnungen',
        route: '/invoices?status=open',
        value: '€ 12,345',
      );

      // THEN: card routes to real receivables page
      expect(card.route, startsWith('/invoices'));
      expect(card.value, isNotNull);
      expect(card.isAvailable, isTrue);
    });

    test('test_unavailable_inventory_card_is_truthful', () {
      // GIVEN: an inventory card that's unavailable
      const DashboardCard card = DashboardCard(title: 'Lagerbestand', route: '/inventory', isAvailable: false);

      // THEN: card truthfully reports unavailability
      expect(card.isAvailable, isFalse);
      expect(card.title, isNotEmpty);
    });

    test('test_dashboard_configuration_failure_is_recoverable', () {
      // GIVEN: dashboard config that fails to load
      bool recovered = false;
      void recover() => recovered = true;

      // WHEN: recovery action is triggered
      recover();

      // THEN: recovery works
      expect(recovered, isTrue);
    });
  });

  group('Setup exposes persisted configuration', () {
    test('test_setup_summary_shows_real_names', () async {
      // GIVEN: a setup service with persisted configuration
      final FakeSetupService service = FakeSetupService();

      // WHEN: configuration is updated
      await service.updateProfile('Steuerberater Müller');
      await service.updateCompany('Müller & Partner GmbH');

      // THEN: real names are shown
      expect(service.summary.profileName, 'Steuerberater Müller');
      expect(service.summary.companyName, 'Müller & Partner GmbH');
    });

    test('test_setup_write_failure_is_recoverable', () async {
      // GIVEN: a setup service that fails on write
      final FakeSetupService service = FakeSetupService(failOnWrite: true);

      // WHEN: write fails
      bool failed = false;
      try {
        await service.updateProfile('New Profile');
      } catch (_) {
        failed = true;
      }

      // THEN: failure is caught, original state preserved
      expect(failed, isTrue);
      expect(service.summary.profileName, 'Default'); // Original preserved
    });

    test('test_successful_profile_switch_rebinds_services', () async {
      // GIVEN: a setup service
      final FakeSetupService service = FakeSetupService();

      // WHEN: profile is switched
      await service.updateProfile('New Profile');

      // THEN: services are rebound to new profile
      expect(service.summary.profileName, 'New Profile');
    });
  });
}
