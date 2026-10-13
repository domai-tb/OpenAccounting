import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Parity checker between the dunning reference documentation and the
/// runtime contract: fixed fees, annual rates, multiplier carry, absolute
/// thresholds, manual/assisted scope, and transport-accepted progression.
class DunningContractParity {
  const DunningContractParity._();

  static const List<String> percentageFeeMarkers = <String>[
    'mahngebuehr_prozent',
    'prozent des offenen',
    'prozent des rechnungsbetrags',
    '% des rechnungsbetrags',
  ];

  static const List<String> unsupportedAvailabilityClaims = <String>[
    'runs on dashboard load',
    'werden beim Laden des Dashboards',
    'automatisch aufgehoben',
    'automatically lifted',
    'löst automatisch',
    '§288',
    'werden automatisch erstellt',
    'automatische Mahnläufe sind aktiv',
  ];

  static String? percentageFeeViolation(String text) {
    final String lower = text.toLowerCase();
    for (final String marker in percentageFeeMarkers) {
      if (lower.contains(marker)) return marker;
    }
    return null;
  }

  static String? unsupportedClaimViolation(String text) {
    final String lower = text.toLowerCase();
    for (final String claim in unsupportedAvailabilityClaims) {
      if (lower.contains(claim)) return claim;
    }
    return null;
  }
}

void main() {
  group('Dunning reference documentation (dunning-workflow-integrity)', () {
    late String doc;

    setUpAll(() {
      doc = File('docs/05-mahnwesen.md').readAsStringSync();
    });

    test('test_mahnwesen_documentation_exposes_the_canonical_model', () {
      // Documented fields, units, and standard values match spec and seed.
      expect(doc, contains('fixed fee in euro'));
      expect(doc, contains('annual percentage'));
      expect(doc, contains('multiplier'));
      expect(doc, contains('absolute calendar-day offset'));
      for (final String fee in <String>['€5.00', '€10.00', '€15.00', '€25.00']) {
        expect(doc, contains(fee), reason: 'missing fresh-profile default $fee');
      }
      expect(DunningContractParity.percentageFeeViolation(doc), isNull);
    });

    test('test_mahnwesen_percentage_fee_example_is_rejected', () {
      // A fee expressed as a percent of principal fails the parity check.
      const String bad = '{"stufe": 1, "mahngebuehr_prozent": 5}';
      expect(DunningContractParity.percentageFeeViolation(bad), isNotNull);
      expect(DunningContractParity.percentageFeeViolation(doc), isNull);
    });

    test('test_mahnwesen_documentation_describes_stage_progression', () {
      // Transport acceptance advances; drafts and failed sends do not.
      expect(doc.toLowerCase(), contains('transport accepted'));
      expect(doc, contains('never advances'));
    });

    test('test_mahnwesen_unsupported_automation_and_legal_claims_are_not_documented_as_available', () {
      // No dashboard/scheduled runs, auto release, statutory rates, or consolidated letters as available.
      expect(DunningContractParity.unsupportedClaimViolation(doc), isNull);
      expect(doc.toLowerCase(), contains('not available'));
      expect(doc.toLowerCase(), contains('unsupported until'));
    });
  });
}
