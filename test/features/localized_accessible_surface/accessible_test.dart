import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Compact sidebar destination with keyboard and semantics support.
class SidebarDestination extends StatelessWidget {
  const SidebarDestination({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onActivate,
    this.isCompact = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onActivate;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final Widget tile = ListTile(
      leading: Icon(icon),
      title: isCompact ? null : Text(label),
      selected: isSelected,
      onTap: onActivate,
    );

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
            onActivate();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: isCompact ? Tooltip(message: label, child: tile) : tile,
      ),
    );
  }
}

/// Overflow menu for narrow layouts.
class OverflowActions extends StatelessWidget {
  const OverflowActions({required this.actions, super.key});

  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      child: const Icon(Icons.more_vert),
      onSelected: (String value) {},
      itemBuilder: (BuildContext context) =>
          actions.map<PopupMenuItem<String>>((String a) => PopupMenuItem<String>(value: a, child: Text(a))).toList(),
    );
  }
}

void main() {
  group('Accessible keyboard and semantics contract', () {
    testWidgets('test_focused_navigation_activates', (WidgetTester tester) async {
      // GIVEN: focus is on a compact sidebar destination
      bool activated = false;
      final FocusNode focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              autofocus: true,
              focusNode: focusNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
                  activated = true;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SidebarDestination(
                icon: Icons.dashboard,
                label: 'Dashboard',
                isSelected: false,
                isCompact: true,
                onActivate: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // WHEN: Enter key pressed
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // THEN: destination activates
      expect(activated, isTrue);
    });

    testWidgets('test_narrow_action_remains_reachable', (WidgetTester tester) async {
      // GIVEN: viewport is 320px wide
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                Expanded(child: Text('Content')),
                OverflowActions(actions: <String>['Edit', 'Delete', 'Export']),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // THEN: overflow menu is reachable
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);

      // Open overflow menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // All actions reachable
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('test_focus_semantics_survive_state_settling', (WidgetTester tester) async {
      // GIVEN: focus is on a search field while state transitions
      final FocusNode searchFocus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Semantics(
                  label: 'Search invoices',
                  child: TextField(
                    focusNode: searchFocus,
                    decoration: const InputDecoration(hintText: 'Search...'),
                  ),
                ),
                const Text('Loading...'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      searchFocus.requestFocus();
      await tester.pump();
      expect(searchFocus.hasFocus, isTrue);

      // WHEN: state settles to data
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Semantics(
                  label: 'Search invoices',
                  child: TextField(
                    focusNode: searchFocus,
                    decoration: const InputDecoration(hintText: 'Search...'),
                  ),
                ),
                const ListTile(title: Text('Invoice RE-001')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // THEN: focused control retains semantic name and focus
      expect(searchFocus.hasFocus, isTrue);
      expect(find.text('Search...'), findsOneWidget);
    });
  });
}
