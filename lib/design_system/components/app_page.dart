import 'package:flutter/material.dart';
import 'package:openaccounting/core/theme/app_theme.dart';

/// Content canvas per DESIGN §6.
/// Responsive padding via LayoutBuilder + 4px grid tokens.
/// Form cap 720–900, tables use larger maxWidth.
class AppPage extends StatelessWidget {
  const AppPage({required this.child, this.header, this.maxWidth = 900, this.padding, super.key});

  final Widget child;
  final PreferredSizeWidget? header;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget? appBar = header;
    final Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final EdgeInsetsGeometry effectivePadding = padding ?? _responsivePadding(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: effectivePadding, child: child),
          ),
        );
      },
    );
    if (appBar != null) {
      return Scaffold(appBar: appBar, body: content);
    }
    return Scaffold(body: content);
  }
}

EdgeInsets _responsivePadding(double maxWidth) {
  if (!maxWidth.isFinite) {
    return const EdgeInsets.all(AppSpacing.xxl);
  }
  if (maxWidth >= 1200) {
    return const EdgeInsets.all(AppSpacing.xxl);
  }
  if (maxWidth >= 900) {
    return const EdgeInsets.all(AppSpacing.xl);
  }
  return const EdgeInsets.all(AppSpacing.lg);
}
