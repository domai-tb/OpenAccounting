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

  /// Short date de-DE: 30.08.2026 — no locale assumption in caller.
  static String formatDate(DateTime date, {String locale = 'de_DE'}) {
    return DateFormat('dd.MM.yyyy', locale).format(date);
  }

  /// Long date de-DE: 30. August 2026.
  static String formatDateLong(DateTime date, {String locale = 'de_DE'}) {
    return DateFormat('d. MMMM yyyy', locale).format(date);
  }

  /// Convenience for tests — mirrors app_money format.
  static String formatMoney(num value, {String locale = 'de_DE', String symbol = '€'}) {
    final NumberFormat fmt = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 2);
    return fmt.format(value);
  }
}
