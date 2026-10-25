import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(apiClientProvider));
});

class TaskState {
  const TaskState({
    this.loading = false,
    this.tasks = const [],
    this.errorMessage,
  });

  final bool loading;
  final List<Task> tasks;
  final String? errorMessage;

  TaskState copyWith({
    bool? loading,
    List<Task>? tasks,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TaskState(
      loading: loading ?? this.loading,
      tasks: tasks ?? this.tasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TaskController extends StateNotifier<TaskState> {
  TaskController(this._repository) : super(const TaskState()) {
    loadTasks();
  }

  final TaskRepository _repository;

  Future<void> loadTasks() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final tasks = await _repository.list();
      state = state.copyWith(loading: false, tasks: tasks);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> createTask(String title, String? description) async {
    try {
      final newTask = await _repository.create(title, description);
      state = state.copyWith(tasks: [newTask, ...state.tasks]);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> toggleTask(Task task) async {
    try {
      final updated = await _repository.setCompleted(task, !task.completed);
      state = state.copyWith(
        tasks: state.tasks
            .map((t) => t.id == updated.id ? updated : t)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _repository.delete(task.id);
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != task.id).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final taskControllerProvider =
    StateNotifierProvider<TaskController, TaskState>((ref) {
  return TaskController(ref.watch(taskRepositoryProvider));
});
