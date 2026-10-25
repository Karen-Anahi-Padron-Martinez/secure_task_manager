import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_list_view.dart';

void main() {
  group('TaskListView Widget Tests', () {
    testWidgets('renders loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskListView(
              loading: true,
              tasks: const [],
              errorMessage: null,
              onRetry: () {},
              onToggle: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskListView(
              loading: false,
              tasks: const [],
              errorMessage: null,
              onRetry: () {},
              onToggle: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);
    });

    testWidgets('renders error state and handles retry',
        (WidgetTester tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskListView(
              loading: false,
              tasks: const [],
              errorMessage: 'Failed to fetch tasks',
              onRetry: () {
                retried = true;
              },
              onToggle: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Failed to fetch tasks'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('renders task list and triggers callbacks',
        (WidgetTester tester) async {
      Task? toggledTask;
      Task? deletedTask;

      final tasks = [
        const Task(
          id: '1',
          title: 'First task',
          description: 'A sample description',
          completed: false,
        ),
        const Task(
          id: '2',
          title: 'Second task',
          description: null,
          completed: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskListView(
              loading: false,
              tasks: tasks,
              errorMessage: null,
              onRetry: () {},
              onToggle: (t) => toggledTask = t,
              onDelete: (t) => deletedTask = t,
            ),
          ),
        ),
      );

      expect(find.text('First task'), findsOneWidget);
      expect(find.text('A sample description'), findsOneWidget);
      expect(find.text('Second task'), findsOneWidget);

      // Tap checkbox of first task
      await tester.tap(find.byType(Checkbox).first);
      expect(toggledTask?.id, '1');

      // Tap delete of first task
      await tester.tap(find.byTooltip('Delete task').first);
      expect(deletedTask?.id, '1');
    });
  });
}
