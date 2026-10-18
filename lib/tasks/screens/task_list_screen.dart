import 'package:flutter/material.dart';

import 'tasks_screen.dart';

/// Which smart list a [TaskListScreen] shows.
enum TaskListView { upcoming, overdue, someday, completed }

/// Smart-list screen. Replaced by the full implementation (T5.4).
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key, required this.view});

  final TaskListView view;

  @override
  Widget build(BuildContext context) => const TasksScreen();
}
