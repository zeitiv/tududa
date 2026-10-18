import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/task_dao.dart';
import 'package:tududa/tasks/domain/task_views.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a write that does not change the list does not re-emit', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.tasks).insert(TasksCompanion.insert(localId: 't1'));
    final dao = TaskDao(db);
    final emitted = <int>[];
    final sub = dao
        .watchView(TaskView.all, today: CalendarDate(2026, 6, 15))
        .listen((l) => emitted.add(l.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(emitted, [1]);

    // Unrelated tag: tables the view reads change, the view does not.
    await db.into(db.tags).insert(TagsCompanion.insert(localId: 'g1'));
    await pumpEventQueue();
    expect(emitted, [1]);

    await db.into(db.tasks).insert(TasksCompanion.insert(localId: 't2'));
    await pumpEventQueue();
    expect(emitted, [1, 2]);
  });
}
