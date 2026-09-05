import 'package:flutter/material.dart';
import 'package:openaccounting/design_system/tokens/radius.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

/// Static dashboard card per DESIGN §10.
///
/// Radius 12 ([AppRadius.card]), 1px subtle border (#E1E4E8 light / #2B3039 dark),
/// elevation 0 — no shadow. Static cards rely on border + surface contrast,
/// shadows only for floating menus/dialogs per §10 Shadows.
class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.padding, this.margin, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color borderColor = isDark ? const Color(0xFF2B3039) : const Color(0xFFE1E4E8);
    final Color bg = theme.cardColor;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        // ignore: avoid_redundant_argument_values — 1px explicit per DESIGN §10
        border: Border.all(color: borderColor, width: 1),
        // No boxShadow — elevation 0 per §10.
      ),
      child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.lg), child: child),
    );
  }
}
