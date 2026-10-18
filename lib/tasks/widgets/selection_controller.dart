import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';

/// The tasks selected for a bulk action, by task uid value. Selection mode is
/// on while the set is not empty.
class TaskSelectionNotifier extends Notifier<Set<String>> {
  final Map<String, Task> _tasks = {};

  @override
  Set<String> build() => const {};

  /// Last known state of the selected tasks.
  List<Task> get tasks => [
    for (final id in state)
      if (_tasks[id] != null) _tasks[id]!,
  ];

  bool get active => state.isNotEmpty;

  static String keyOf(Task t) => t.uid.value;

  /// Adds [task] when not selected, removes it otherwise.
  void toggle(Task task) {
    final id = keyOf(task);
    if (state.contains(id)) {
      _tasks.remove(id);
      state = {...state}..remove(id);
    } else {
      _tasks[id] = task;
      state = {...state, id};
    }
  }

  /// Starts selection mode with [task] selected.
  void start(Task task) {
    if (!state.contains(keyOf(task))) toggle(task);
  }

  void clear() {
    _tasks.clear();
    state = const {};
  }
}

final taskSelectionProvider =
    NotifierProvider<TaskSelectionNotifier, Set<String>>(
      TaskSelectionNotifier.new,
    );
