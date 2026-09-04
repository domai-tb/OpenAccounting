import 'package:flutter/material.dart';

/// Optional inspector per DESIGN §14 — 360–440 px, overlay <900, Esc, focus trap.
/// Stub for RED phase 5.1: import succeeds but behavior wrong so tests fail for
/// right reason (width/overlay/Esc) not import error. Real impl replaces this.
class AppInspector extends StatelessWidget {
  const AppInspector({required this.child, required this.isOpen, required this.onClose, this.title, super.key});

  final Widget child;
  final bool isOpen;
  final VoidCallback onClose;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (!isOpen) {
      return const SizedBox.shrink();
    }
    // ponytail: stub — wrong width 200 (outside 360–440), no AnimatedContainer,
    // no overlay logic, no Esc handling, no FocusScope focus trap.
    return Container(
      width: 200,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) Padding(padding: const EdgeInsets.all(16), child: Text(title!)),
          Expanded(child: child),
        ],
      ),
    );
  }
}
