import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/design_system/tokens/duration.dart';
import 'package:openaccounting/design_system/tokens/radius.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

void main() {
  group('Design Tokens — DESIGN §42', () {
    test('test_spacing_tokens', () {
      expect(AppSpacing.xs, 4, reason: 'AppSpacing.xs must be 4 per §42');
      expect(AppSpacing.sm, 8, reason: 'AppSpacing.sm must be 8 per §42');
      expect(AppSpacing.md, 12, reason: 'AppSpacing.md must be 12 per §42');
      expect(AppSpacing.lg, 16, reason: 'AppSpacing.lg must be 16 per §42');
      expect(AppSpacing.xl, 24, reason: 'AppSpacing.xl must be 24 per §42');
      expect(AppSpacing.xxl, 32, reason: 'AppSpacing.xxl must be 32 per §42');
      expect(AppSpacing.xxxl, 48, reason: 'AppSpacing.xxxl must be 48 per §42');
    });

    test('test_radius_tokens', () {
      expect(AppRadius.control, 8, reason: 'AppRadius.control must be 8 per §42');
      expect(AppRadius.card, 12, reason: 'AppRadius.card must be 12 per §42');
      expect(AppRadius.dialog, 14, reason: 'AppRadius.dialog must be 14 per §42');
    });

    test('test_duration_tokens', () {
      expect(AppDuration.fast, const Duration(milliseconds: 120), reason: 'fast must be 120ms per §42');
      expect(AppDuration.normal, const Duration(milliseconds: 200), reason: 'normal must be 200ms per §42');
      expect(AppDuration.slow, const Duration(milliseconds: 240), reason: 'slow must be 240ms per §42');
    });

    test('test_shell_uses_tokens_not_raw', () {
      final String spacingSource = File('lib/design_system/tokens/spacing.dart').readAsStringSync();
      expect(spacingSource.contains('AppSpacing'), isTrue, reason: 'spacing.dart must define AppSpacing');
      expect(spacingSource.contains('xs'), isTrue, reason: 'spacing.dart must contain xs token');
      final String radiusSource = File('lib/design_system/tokens/radius.dart').readAsStringSync();
      expect(radiusSource.contains('AppRadius'), isTrue, reason: 'radius.dart must define AppRadius');
      expect(radiusSource.contains('card'), isTrue, reason: 'radius.dart must contain card token');
      final String durationSource = File('lib/design_system/tokens/duration.dart').readAsStringSync();
      expect(durationSource.contains('AppDuration'), isTrue, reason: 'duration.dart must define AppDuration');
      expect(durationSource.contains('normal'), isTrue, reason: 'duration.dart must contain normal token');

      final List<String> shellFiles = <String>[
        'lib/design_system/components/app_page.dart',
        'lib/design_system/components/app_page_header.dart',
        'lib/design_system/components/app_inspector.dart',
        'lib/design_system/components/app_sidebar.dart',
        'lib/app/app_shell.dart',
        'lib/core/theme/app_theme.dart',
      ];
      for (final String path in shellFiles) {
        final String content = File(path).readAsStringSync();
        final bool usesTokens =
            content.contains('AppSpacing.') || content.contains('AppRadius.') || content.contains('AppDuration.');
        expect(
          usesTokens,
          isTrue,
          reason: '$path must reference AppSpacing/AppRadius/AppDuration, not raw 16/12/200 per §42',
        );
      }

      final String appThemeSource = File('lib/core/theme/app_theme.dart').readAsStringSync();
      expect(
        appThemeSource.contains('design_system/tokens'),
        isTrue,
        reason: 'app_theme.dart must re-export or import from design_system/tokens per D3/D4',
      );

      final String appPageSource = File('lib/design_system/components/app_page.dart').readAsStringSync();
      expect(
        appPageSource.contains('AppSpacing.'),
        isTrue,
        reason: 'AppPage must use AppSpacing tokens for padding per §42',
      );
      final String inspectorSource = File('lib/design_system/components/app_inspector.dart').readAsStringSync();
      expect(
        inspectorSource.contains('AppDuration.normal'),
        isTrue,
        reason: 'AppInspector must use AppDuration.normal 200ms per §42',
      );
    });

    test('test_tokens_lint_no_hardcoded_raw_in_components', () {
      final String headerSource = File('lib/design_system/components/app_page_header.dart').readAsStringSync();
      expect(
        headerSource.contains('AppRadius.control'),
        isTrue,
        reason: 'AppPageHeader must use AppRadius.control not BorderRadius.circular(8) raw',
      );
      expect(headerSource.contains('AppSpacing.lg'), isTrue, reason: 'AppPageHeader must use AppSpacing.lg not 16 raw');
    });
  });
}
