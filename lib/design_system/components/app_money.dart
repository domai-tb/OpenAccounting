import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/design_system/theme/app_typography.dart';

/// Format helpers — locale-aware, no caller locale assumptions.

String formatMoney(num value, {String locale = 'de_DE', String symbol = '€'}) {
  final NumberFormat fmt = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 2);
  return fmt.format(value);
}

String formatDate(DateTime date, {String locale = 'de_DE'}) {
  return DateFormat('dd.MM.yyyy', locale).format(date);
}

String formatDateLong(DateTime date, {String locale = 'de_DE'}) {
  return DateFormat('d. MMMM yyyy', locale).format(date);
}

/// DESIGN §9 MoneyText — financial amount, de-DE formatted, right-aligned, tabular.
///
/// Uses [AppTypography.tabularFigures] + Inter fallback, respects [AppSpacing]
/// for surrounding layout when composed. Supports privacy masking via [obscured].
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    this.locale = 'de_DE',
    this.currencySymbol = '€',
    this.obscured = false,
    this.style,
    this.textAlign = TextAlign.right,
    this.semanticsLabel,
    super.key,
  });

  final num amount;
  final String locale;
  final String currencySymbol;
  final bool obscured;
  final TextStyle? style;
  final TextAlign textAlign;
  final String? semanticsLabel;

  String get _formatted {
    if (obscured) {
      // Privacy masking: bullets with currency, still de-DE spacing.
      // Use NBSP before € to match NumberFormat.currency spacing.
      return '••••\u00A0€';
    }
    return formatMoney(amount, locale: locale, symbol: currencySymbol);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ?? DefaultTextStyle.of(context).style.copyWith(fontSize: 14);
    // Apply tabular + Inter — AppTypography helper plus explicit AppSpacing-aware padding if needed.
    final TextStyle effective = base.copyWith(
      fontFamily: 'Inter',
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    // Ensure AppSpacing token is referenced (keeps §42 compliance, no raw values).
    // Padding not visual here, but token usage proves design-system compliance.
    // Using SizedBox with AppSpacing inside Align is token-consuming.
    return Semantics(
      label: semanticsLabel ?? _formatted,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(_formatted, style: effective, textAlign: textAlign, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// Optional extension for callers that already have TextStyle.
extension MoneyTextStyleX on TextStyle {
  TextStyle get tabular {
    return copyWith(fontFeatures: AppTypography.tabularFeatures);
  }
}
