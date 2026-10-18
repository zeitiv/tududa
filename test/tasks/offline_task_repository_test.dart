import 'package:flutter_test/flutter_test.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart' as ft show isNull, isNotNull;
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/data/task_query.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';

import 'offline_rig.dart';

void main() {
  late OfflineRig rig;

  setUp(() async {
    rig = OfflineRig();
    await rig.init();
  });

  test('create writes row, dirty marks and a delayed outbox entry', () async {
    final task = await rig.repo.create(
      const NewTask(name: ' Buy milk ', priority: Priority.high),
    );
    expect(task.name, 'Buy milk');
    expect(task.hasPendingSync, isTrue);
    final row = await rig.row(task.uid.value);
    expect(row.uid, ft.isNull);
    expect(row.localId, task.uid.value);
    final dirty = DirtyFields.decode(row.dirtyFields);
    expect(dirty.isDirty('name'), isTrue);
    expect(dirty.isDirty('priority'), isTrue);

    final box = await rig.outbox();
    expect(box, hasLength(1));
    expect(box.single.op, OutboxOp.create);
    expect(box.single.localId, row.localId);
    expect(box.single.notBefore, rig.t.add(const Duration(seconds: 5)));
  });

  test('a failing outbox write rolls the row back (one transaction)', () async {
    await rig.db.customStatement('DROP TABLE outbox');
    await expectLater(
      rig.repo.create(const NewTask(name: 'x')),
      throwsA(anything),
    );
    expect(await rig.dao.allRows(), isEmpty);
  });

  test(
    'update applies Patch.set / clear and marks only changed fields',
    () async {
      final t = await rig.repo.create(
        NewTask(name: 'a', note: 'n', dueDate: CalendarDate(2026, 1, 2)),
      );
      await rig.flush(); // create is on the server now
      final r = await rig.repo.update(
        t.uid,
        const TaskPatch(
          note: Patch.clear(),
          priority: Patch.set(Priority.medium),
          name: Patch.set('a'), // unchanged
        ),
      );
      expect(r.note, ft.isNull);
      expect(r.priority, Priority.medium);
      final row = await rig.row(t.uid.value);
      expect(DirtyFields.decode(row.dirtyFields).fields, {'note', 'priority'});
      final box = await rig.outbox();
      expect(box.map((e) => e.op), [OutboxOp.update]);
    },
  );

  test('an empty patch changes nothing and queues nothing', () async {
    final t = await rig.repo.create(const NewTask(name: 'a'));
    await rig.flush();
    final change = await rig.repo.updateTracked(
      t.uid,
      const TaskPatch(name: Patch.set('a')),
    );
    expect(change.undo, ft.isNull);
    expect(await rig.outbox(), isEmpty);
  });

  test('tags are created by name without outbox entries', () async {
    final t = await rig.repo.create(
      const NewTask(name: 'a', tags: ['home', 'urgent']),
    );
    expect(t.tags.map((g) => g.name), ['home', 'urgent']);
    final tagRows = await rig.db.select(rig.db.tags).get();
    expect(tagRows.map((e) => e.name).toSet(), {'home', 'urgent'});
    expect((await rig.outbox()).map((e) => e.entity), [SyncEntity.task]);

    await rig.repo.update(
      t.uid,
      const TaskPatch(tags: Patch.set(['home', 'new'])),
    );
    expect(
      (await rig.db.select(rig.db.tags).get()).map((e) => e.name).toSet(),
      {'home', 'urgent', 'new'},
    );
    expect((await rig.repo.get(t.uid)).tags.map((g) => g.name), [
      'home',
      'new',
    ]);
  });

  test('an unknown project uid gets a stub project row', () async {
    final t = await rig.repo.create(
      const NewTask(name: 'a', projectUid: ProjectUid('p-unknown')),
    );
    final project = await (rig.db.select(rig.db.projects)).getSingle();
    expect(project.uid, 'p-unknown');
    expect(t.projectUid, const ProjectUid('p-unknown'));
    expect((await rig.row(t.uid.value)).projectLocalId, project.localId);
  });

  test('complete then uncomplete cancels, restoring the old status', () async {
    final t = await rig.repo.create(
      const NewTask(name: 'a', status: TaskStatus.inProgress),
    );
    await rig.flush();
    expect(await rig.outbox(), isEmpty);

    final done = await rig.repo.complete(t.uid);
    expect(done.status, TaskStatus.done);
    expect(done.completedAt, ft.isNotNull);
    expect((await rig.row(t.uid.value)).statusBeforeDone, 1);
    expect((await rig.outbox()).single.op, OutboxOp.complete);

    final back = await rig.repo.uncomplete(t.uid);
    expect(back.status, TaskStatus.inProgress);
    expect(back.completedAt, ft.isNull);
    expect(await rig.outbox(), isEmpty);
  });

  test(
    'uncomplete defaults to not started when nothing was remembered',
    () async {
      final t = await rig.repo.create(
        const NewTask(name: 'a', status: TaskStatus.done),
      );
      final back = await rig.repo.uncomplete(t.uid);
      expect(back.status, TaskStatus.notStarted);
    },
  );

  test('delete hides the task; create+delete leaves nothing behind', () async {
    final t = await rig.repo.create(const NewTask(name: 'a', tags: ['x']));
    await rig.repo.delete(t.uid);
    expect(await rig.dao.allRows(), isEmpty);
    expect(await rig.outbox(), isEmpty);

    final synced = await rig.repo.create(const NewTask(name: 'b'));
    await rig.flush();
    await rig.repo.delete(synced.uid);
    final row = await rig.row(synced.uid.value);
    expect(row.pendingDelete, isTrue);
    expect((await rig.outbox()).single.op, OutboxOp.delete);
    expect(await rig.dao.taskByAnyId(synced.uid.value), ft.isNull);
    await expectLater(rig.repo.get(synced.uid), throwsA(anything));
  });

  test('postpone keeps or drops the time', () async {
    final t = await rig.repo.create(
      NewTask(
        name: 'a',
        dueDate: CalendarDate(2026, 1, 1),
        dueTime: const LocalTime(9, 30),
      ),
    );
    final kept = await rig.repo.postpone(
      t.uid,
      CalendarDate(2026, 1, 5),
      keepTime: const LocalTime(9, 30),
    );
    expect(kept.dueDate, CalendarDate(2026, 1, 5));
    expect(kept.dueTime, const LocalTime(9, 30));
    final dropped = await rig.repo.postpone(t.uid, CalendarDate(2026, 1, 6));
    expect(dropped.dueTime, ft.isNull);
  });

  test('bulk applies a patch to several tasks as one change', () async {
    final a = await rig.repo.create(const NewTask(name: 'a'));
    final b = await rig.repo.create(const NewTask(name: 'b'));
    final change = await rig.repo.bulk([
      a.uid,
      b.uid,
    ], const TaskPatch(priority: Patch.set(Priority.high)));
    expect(change.value.map((t) => t.priority), [Priority.high, Priority.high]);
    expect(change.undo!.localIds, hasLength(2));
  });

  test('fetch reads the database and never has more pages', () async {
    await rig.repo.create(const NewTask(name: 'a'));
    await rig.repo.create(const NewTask(name: 'b', status: TaskStatus.done));
    final open = await rig.repo.fetch(TaskQuery());
    expect(open.items.map((t) => t.name), ['a']);
    expect(open.hasMore, isFalse);
  });
}
