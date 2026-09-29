import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// DESIGN §9 Typography — Inter fallback + tabular financial numbers.
///
/// Provides [FontFeature.tabularFigures] for money, locale-aware
/// formatters (de-DE by default), and a money [TextStyle] helper.
abstract final class AppTypography {
  static const FontFeature tabularFigures = FontFeature.tabularFigures();

  static const List<FontFeature> tabularFeatures = <FontFeature>[tabularFigures];

  static TextStyle withTabular(TextStyle style) {
    return style.copyWith(fontFeatures: tabularFeatures);
  }

  /// Money style: Inter fallback, tabular, suitable for right-aligned amounts.
  static TextStyle moneyStyle([TextStyle? base]) {
    final TextStyle b = base ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
    return b.copyWith(fontFamily: 'Inter', fontFeatures: tabularFeatures);
  }

  static String _requireLocale(String? locale) {
    final String? value = locale?.trim();
    if (value == null || value.isEmpty) {
      throw ArgumentError('An explicit locale is required for pure formatting helpers.');
    }
    return value;
  }

  static String formatDate(DateTime date, {String? locale}) {
    final String resolved = _requireLocale(locale);
    return DateFormat(resolved.startsWith('en') ? 'MM/dd/yyyy' : 'dd.MM.yyyy', resolved).format(date);
  }

  static String formatDateLong(DateTime date, {String? locale}) {
    final String resolved = _requireLocale(locale);
    return DateFormat(resolved.startsWith('en') ? 'MMMM d, yyyy' : 'd. MMMM yyyy', resolved).format(date);
  }

  static String formatMoney(num value, {String? locale, String symbol = '€'}) {
    final NumberFormat fmt = NumberFormat.decimalPattern(_requireLocale(locale))
      ..minimumFractionDigits = 2
      ..maximumFractionDigits = 2;
    final String number = fmt.format(value);
    return symbol.isEmpty ? number : '$number $symbol';
  }
}
