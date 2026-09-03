import 'package:flutter/material.dart';

/// Consistent page header per DESIGN §5.
/// Minimal for 1.2: title + optional subtitle + actions.
/// Full tabs/filter toolbar deferred to 3.2.
class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppPageHeader({required this.title, this.subtitle, this.actions, super.key});

  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, overflow: TextOverflow.ellipsis),
      actions: actions,
      bottom: subtitle != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize {
    final extra = subtitle != null ? 24.0 : 0.0;
    return Size.fromHeight(kToolbarHeight + extra);
  }
}
