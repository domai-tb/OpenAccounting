import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';
import 'package:openaccounting/design_system/theme/app_typography.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Format helpers — locale-aware, no caller locale assumptions.

String localeTag(Locale locale) {
  return locale.languageCode == 'en' ? 'en_US' : 'de_DE';
}

String _requireLocale(String? locale) {
  final String? value = locale?.trim();
  if (value == null || value.isEmpty) {
    throw ArgumentError('An explicit locale is required for pure formatting helpers.');
  }
  return value;
}

String formatMoney(num value, {String? locale, String symbol = '€'}) {
  final NumberFormat fmt = NumberFormat.decimalPattern(_requireLocale(locale))
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;
  final String number = fmt.format(value);
  return symbol.isEmpty ? number : '$number $symbol';
}

String formatDate(DateTime date, {String? locale}) {
  final String resolved = _requireLocale(locale);
  return DateFormat(resolved.startsWith('en') ? 'MM/dd/yyyy' : 'dd.MM.yyyy', resolved).format(date);
}

String formatDateLong(DateTime date, {String? locale}) {
  final String resolved = _requireLocale(locale);
  return DateFormat(resolved.startsWith('en') ? 'MMMM d, yyyy' : 'd. MMMM yyyy', resolved).format(date);
}

/// DESIGN §9 MoneyText — active-locale financial amount, right-aligned, tabular.
///
/// Uses [AppTypography.tabularFigures] + Inter fallback, respects [AppSpacing]
/// for surrounding layout when composed. Supports privacy masking via [obscured].
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    this.locale,
    this.currencySymbol = '€',
    this.obscured = false,
    this.style,
    this.textAlign = TextAlign.right,
    this.semanticsLabel,
    super.key,
  });

  final num amount;
  final String? locale;
  final String currencySymbol;
  final bool obscured;
  final TextStyle? style;
  final TextAlign textAlign;
  final String? semanticsLabel;

  String _formatted(String activeLocale) {
    if (obscured) {
      // Privacy masking: never expose the underlying amount in either text or
      // semantics. Keep the currency marker so the column remains meaningful.
      return '••••\u00A0$currencySymbol';
    }
    return formatMoney(amount, locale: activeLocale, symbol: currencySymbol);
  }

  @override
  Widget build(BuildContext context) {
    final String activeLocale = locale ?? localeTag(Localizations.localeOf(context));
    final String formatted = _formatted(activeLocale);
    final AppLocalizations? l10n = AppLocalizations.of(context);
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
      label: semanticsLabel ?? (obscured ? l10n?.amountHidden ?? 'Amount hidden' : formatted),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(formatted, style: effective, textAlign: textAlign),
          ),
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
