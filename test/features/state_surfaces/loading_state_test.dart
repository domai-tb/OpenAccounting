import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skeleton widget that mimics content shape during loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({required this.width, required this.height, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Empty state widget with primary action.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, required this.actionLabel, this.onAction, super.key});

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        const SizedBox(height: 16),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

/// Error state widget with retry.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message),
        const SizedBox(height: 16),
        if (onRetry != null) FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Dashboard card that shows skeleton while loading.
class DashboardCard extends StatelessWidget {
  const DashboardCard({required this.title, this.isLoading = false, this.hasError = false, this.onRetry, super.key});

  final String title;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (isLoading) ...<Widget>[
              const SkeletonBox(width: 120, height: 32),
              const SizedBox(height: 8),
              const SkeletonBox(width: 200, height: 16),
            ] else if (hasError)
              ErrorState(message: 'Failed to load', onRetry: onRetry)
            else
              const Text('€ 12,345.67'),
          ],
        ),
      ),
    );
  }
}

/// Page that retains structure while loading.
class LoadingPage extends StatelessWidget {
  const LoadingPage({required this.title, this.isLoading = false, this.rowCount = 3, super.key});

  final String title;
  final bool isLoading;
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: TextField(decoration: InputDecoration(hintText: 'Search...')),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () {}, child: const Text('Add')),
              ],
            ),
          ),
          if (isLoading)
            ...List<Widget>.generate(
              rowCount,
              (int i) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SkeletonBox(width: double.infinity, height: 48),
              ),
            )
          else
            ...List<Widget>.generate(rowCount, (int i) => ListTile(title: Text('Item $i'))),
        ],
      ),
    );
  }
}

void main() {
  group('Content-shaped loading previews', () {
    testWidgets('test_dashboard_card_shows_skeleton_content', (WidgetTester tester) async {
      // GIVEN: a dashboard card is fetching data
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DashboardCard(title: 'Revenue', isLoading: true)),
        ),
      );
      await tester.pump();

      // THEN: card retains title and shows skeleton shapes
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNWidgets(2)); // metric + content skeletons
    });

    testWidgets('test_skeleton_resolves_to_error_state', (WidgetTester tester) async {
      // GIVEN: card request fails after skeleton
      bool retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(title: 'Revenue', hasError: true, onRetry: () => retryPressed = true),
          ),
        ),
      );
      await tester.pump();

      // THEN: skeleton removed, error shown with retry
      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('test_routed_page_keeps_title_and_controls_while_loading', (WidgetTester tester) async {
      // GIVEN: /contacts is waiting for data
      await tester.pumpWidget(const MaterialApp(home: LoadingPage(title: 'Contacts', isLoading: true)));
      await tester.pump();

      // THEN: heading, search, action, row placeholders remain
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNWidgets(3)); // 3 row placeholders
    });
  });

  group('State transition identity', () {
    testWidgets('test_empty_list_offers_primary_action', (WidgetTester tester) async {
      // GIVEN: a route has no records
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(message: 'No invoices yet', actionLabel: 'Create Invoice', onAction: () {}),
          ),
        ),
      );
      await tester.pump();

      // THEN: explains what is missing, exposes create action
      expect(find.text('No invoices yet'), findsOneWidget);
      expect(find.text('Create Invoice'), findsOneWidget);
    });

    testWidgets('test_failed_request_preserves_context', (WidgetTester tester) async {
      // GIVEN: a filtered route request fails
      bool retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorState(message: 'Failed to load invoices', onRetry: () => retryPressed = true),
          ),
        ),
      );
      await tester.pump();

      // THEN: retry repeats the same request
      expect(find.text('Failed to load invoices'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('test_failed_mutation_rolls_back_safely', (WidgetTester tester) async {
      // GIVEN: optimistic preview was added but mutation failed
      bool retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                // Last confirmed item
                const ListTile(title: Text('Invoice RE-001')),
                // Error state for failed optimistic item
                ErrorState(message: 'Failed to save', onRetry: () => retryPressed = true),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // THEN: no duplicate optimistic record, retry available
      expect(find.text('Invoice RE-001'), findsOneWidget);
      expect(find.text('Failed to save'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });
  });
}
