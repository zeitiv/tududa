@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/widgets/selection_controller.dart';
import 'package:tududa/tasks/widgets/task_tile.dart';

import 'golden_harness.dart';

class _Selected extends TaskSelectionNotifier {
  _Selected(this.ids);
  final Set<String> ids;
  @override
  Set<String> build() => ids;
}

Task _task(
  String name, {
  String uid = 't1',
  Priority priority = Priority.low,
  int overdueDays = 0,
  String recurrence = 'none',
  List<Task> subtasks = const [],
  List<TaskTag> tags = const [],
  TaskStatus status = TaskStatus.notStarted,
}) => Task(
  uid: TaskUid(uid),
  name: name,
  dueDate: overdueDays > 0 ? goldenToday.addDays(-overdueDays) : goldenToday,
  priority: priority,
  recurrenceType: recurrence,
  subtasks: subtasks,
  tags: tags,
  status: status,
);

String _name(Locale l, String en, String de) =>
    l.languageCode == 'de' ? de : en;

void main() {
  setUpGoldens();

  goldenCase(
    'task_tile_normal',
    build: (l) => TaskTile(
      task: _task(
        _name(
          l,
          'Buy groceries',
          'Lebensmittel für die gesamte Woche einkaufen gehen',
        ),
      ),
      onTap: () {},
    ),
  );

  goldenCase(
    'task_tile_overdue',
    build: (l) => TaskTile(
      task: _task(
        _name(l, 'Pay the invoice', 'Die Rechnung des Steuerberaters bezahlen'),
        overdueDays: 3,
        priority: Priority.high,
      ),
      onTap: () {},
    ),
  );

  goldenCase(
    'task_tile_rich',
    build: (l) => TaskTile(
      task: _task(
        _name(
          l,
          'Write quarterly report',
          'Quartalsbericht für die Geschäftsleitung schreiben',
        ),
        priority: Priority.medium,
        recurrence: 'weekly',
        subtasks: [
          _task('a', uid: 's1', status: TaskStatus.done),
          _task(
            _name(l, 'Collect numbers', 'Zahlen zusammentragen'),
            uid: 's2',
          ),
          _task(_name(l, 'Draft', 'Entwurf'), uid: 's3'),
        ],
        tags: const [
          TaskTag(name: 'work'),
          TaskTag(name: 'finance'),
          TaskTag(name: 'q4'),
        ],
      ),
      onTap: () {},
    ),
  );

  goldenCase(
    'task_tile_completed',
    build: (l) => TaskTile(
      task: _task(
        _name(l, 'Book the dentist', 'Zahnarzttermin vereinbaren'),
        status: TaskStatus.done,
      ),
      onTap: () {},
    ),
  );

  goldenCase(
    'task_tile_selected',
    build: (l) => TaskTile(
      task: _task(_name(l, 'Water the plants', 'Die Pflanzen gießen')),
      onTap: () {},
    ),
    overrides: (_) => [
      taskSelectionProvider.overrideWith(() => _Selected({'t1'})),
    ],
  );
}
