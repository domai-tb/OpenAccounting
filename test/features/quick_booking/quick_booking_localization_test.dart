import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _quickBookingKeys = <String>[
  'actionRetry',
  'quickBookingsTitle',
  'quickBookingNew',
  'quickBookingEdit',
  'quickBookingDelete',
  'quickBookingSave',
  'quickBookingCancel',
  'quickBookingName',
  'quickBookingDirection',
  'quickBookingDirectionIn',
  'quickBookingDirectionOut',
  'quickBookingAccount',
  'quickBookingCategory',
  'quickBookingTaxRate',
  'quickBookingModus',
  'quickBookingModusNetto',
  'quickBookingModusBrutto',
  'quickBookingAmount',
  'quickBookingDescription',
  'quickBookingExecute',
  'quickBookingReviewRequired',
  'quickBookingUnavailable',
  'quickBookingEnterAmount',
  'quickBookingEmpty',
];

void main() {
  test('quick-booking keys have meaningful English and German translations', () {
    for (final locale in const <String>['en', 'de']) {
      final arbPath = 'assets/l10n/l10n_$locale.arb';
      final translations = jsonDecode(File(arbPath).readAsStringSync()) as Map<String, Object?>;
      final missing = _quickBookingKeys
          .where((key) {
            final value = translations[key];
            return value is! String || value.trim().isEmpty || value.trim() == key;
          })
          .toList(growable: false);

      expect(missing, isEmpty, reason: '$locale has missing or empty quick-booking translations: $missing');
    }
  });
}
