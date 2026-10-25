import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import 'task_controller.dart';
import 'task_list_view.dart';

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Task'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (val.trim().length > 120) {
                    return 'Title cannot exceed 120 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await ref.read(taskControllerProvider.notifier).createTask(
                      titleController.text.trim(),
                      descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Task Manager'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(taskControllerProvider.notifier).loadTasks(),
        child: TaskListView(
          loading: taskState.loading && taskState.tasks.isEmpty,
          tasks: taskState.tasks,
          errorMessage: taskState.errorMessage,
          onRetry: () => ref.read(taskControllerProvider.notifier).loadTasks(),
          onToggle: (task) =>
              ref.read(taskControllerProvider.notifier).toggleTask(task),
          onDelete: (task) =>
              ref.read(taskControllerProvider.notifier).deleteTask(task),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Task',
        onPressed: () => _showAddTaskDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
