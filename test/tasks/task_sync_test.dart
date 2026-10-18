import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/domain/new_task.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/domain/task_views.dart';

import 'offline_rig.dart';

void main() {
  late OfflineRig rig;

  Map<String, dynamic> serverTask(String uid) => rig.net.server.tasks[uid]!;

  setUp(() async {
    rig = OfflineRig();
    await rig.init();
  });

  group('push', () {
    test(
      'create offline is visible at once; sync fills uid, clears dirty',
      () async {
        final day = rig.today();
        final emitted = <List<Task>>[];
        final sub = rig.dao
            .watchView(TaskView.all, today: day.date, day: day)
            .listen(emitted.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();
        expect(emitted.last, isEmpty);

        final t = await rig.repo.create(
          const NewTask(name: 'Offline task', tags: ['home']),
        );
        await pumpEventQueue();
        expect(emitted.last.map((e) => e.name), ['Offline task']);
        expect(emitted.last.single.hasPendingSync, isTrue);

        // Inside the undo window nothing is sent.
        await rig.sync();
        expect(rig.net.server.tasks, isEmpty);

        await rig.flush();
        final server = rig.net.server.tasks.values.single;
        expect(server['name'], 'Offline task');
        expect((server['tags'] as List).map((e) => (e as Map)['name']), [
          'home',
        ]);

        final row = await rig.row(t.uid.value);
        expect(row.uid, server['uid']);
        expect(row.serverId, server['id']);
        expect(row.dirtyFields, '{}');
        expect(row.baseJson, isNotNull);
        expect(await rig.outbox(), isEmpty);
        await pumpEventQueue();
        expect(emitted.last.single.hasPendingSync, isFalse);
        expect(emitted.last.single.uid.value, server['uid']);
        expect((await rig.db.select(rig.db.tags).getSingle()).uid, 'tag-home');
      },
    );

    test('a subtask waits for its offline parent, then is created', () async {
      final parent = await rig.repo.create(const NewTask(name: 'Parent'));
      await rig.repo.createSubtaskOf(parent.uid, 'Child');
      rig.net.server.failNext('/task', 500);

      await rig.flush();
      expect(rig.net.sent('POST', '/task'), hasLength(1));
      expect(
        rig.net.sent('POST', '/task').single.body,
        containsPair('name', 'Parent'),
      );
      expect(rig.net.server.tasks, isEmpty);
      expect(await rig.outbox(), hasLength(2));

      await rig.sync();
      expect(rig.net.server.tasks, hasLength(2));
      final p = rig.net.server.tasks.values.firstWhere(
        (t) => t['name'] == 'Parent',
      );
      final c = rig.net.server.tasks.values.firstWhere(
        (t) => t['name'] == 'Child',
      );
      expect(c['parent_task_id'], p['id']);
      expect(await rig.outbox(), isEmpty);

      final child = await rig.row(
        (await rig.dao.byUid(c['uid'] as String))!.localId,
      );
      expect(
        child.parentLocalId,
        (await rig.dao.byUid(p['uid'] as String))!.localId,
      );
      final shown = await rig.dao.fetchView(TaskView.all, rig.today());
      expect(shown.single.subtasks.map((s) => s.name), ['Child']);
    });

    test(
      'update sends only dirty fields; due_date brings the time along',
      () async {
        rig.net.server.seedTask(
          uid: 'a',
          name: 'A',
          note: 'keep',
          dueDate: '2026-03-01',
          dueTime: '09:30',
        );
        await rig.sync();

        await rig.repo.postpone(
          const TaskUid('a'),
          CalendarDate(2026, 3, 5),
          keepTime: const LocalTime(9, 30),
        );
        await rig.flush();
        final patch = rig.net.sent('PATCH', '/task/a').single.body as Map;
        expect(patch, {'due_date': '2026-03-05', 'due_time': '09:30'});
        expect(serverTask('a')['due_time'], '09:30');

        await rig.repo.postpone(const TaskUid('a'), CalendarDate(2026, 3, 6));
        await rig.flush();
        final second = rig.net.sent('PATCH', '/task/a').last.body as Map;
        expect(second, {'due_date': '2026-03-06', 'due_time': null});
        expect(serverTask('a')['due_time'], isNull);
        expect((await rig.row('a')).dirtyFields, '{}');
      },
    );

    test('complete and uncomplete restore the earlier status', () async {
      rig.net.server.seedTask(uid: 'a', status: 1);
      await rig.sync();
      await rig.repo.complete(const TaskUid('a'));
      await rig.flush();
      expect(serverTask('a')['status'], 2);
      expect(serverTask('a')['completed_at'], isNotNull);

      await rig.repo.uncomplete(const TaskUid('a'));
      await rig.flush();
      expect(serverTask('a')['status'], 1);
      final row = await rig.row('a');
      expect(row.status, 1);
      expect(row.completedAt, isNull);
      expect(row.dirtyFields, '{}');
    });

    test('delete is sent and the row disappears', () async {
      rig.net.server.seedTask(uid: 'a');
      await rig.sync();
      await rig.repo.delete(const TaskUid('a'));
      await rig.flush();
      expect(rig.net.server.tasks, isEmpty);
      expect(await rig.dao.allRows(), isEmpty);
      expect(await rig.outbox(), isEmpty);
    });

    test('skip occurrence is sent and the new due date arrives', () async {
      rig.net.server.seedTask(
        uid: 'r',
        dueDate: '2026-03-01',
        extra: {'recurrence_type': 'daily'},
      );
      await rig.sync();
      await rig.repo.skipOccurrence(const TaskUid('r'));
      await rig.flush();
      expect(rig.net.sent('POST', '/task/r/skip-occurrence'), hasLength(1));
      expect((await rig.row('r')).dueDate, '2026-03-02');
    });

    test('a project created offline is resolved at send time', () async {
      final now = rig.t;
      await rig.db
          .into(rig.db.projects)
          .insert(
            ProjectsCompanion.insert(
              localId: 'proj-local',
              name: const Value('P'),
              localUpdatedAt: Value(now),
            ),
          );
      final t = await rig.repo.create(
        NewTask(name: 'a', projectUid: const ProjectUid('proj-local')),
      );
      await rig.flush();
      // The project has no uid yet: the create waits.
      expect(rig.net.server.tasks, isEmpty);
      expect(await rig.outbox(), hasLength(1));

      await (rig.db.update(rig.db.projects))
          .write(const ProjectsCompanion(uid: Value('p-srv')));
      await rig.sync();
      expect(rig.net.server.tasks.values.single['project_uid'], 'p-srv');
      expect((await rig.row(t.uid.value)).uid, isNotNull);
    });
  });

  group('rollback', () {
    test('a rejected update restores the server version', () async {
      rig.net.server.seedTask(uid: 'a', name: 'Server name', note: 'n');
      await rig.sync();
      await rig.repo.update(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('Local name')),
      );
      rig.net.server.failNext('/task/a', 422);
      await rig.flush();

      final row = await rig.row('a');
      expect(row.name, 'Server name');
      expect(row.dirtyFields, '{}');
      expect(await rig.outbox(), isEmpty);
      final notices = rig.engine.status.notices;
      expect(notices.single.field, '*');
      expect(notices.single.entity, 'task');
    });

    test('a rejected create deletes the never-synced row', () async {
      final t = await rig.repo.create(const NewTask(name: 'x', tags: ['t']));
      rig.net.server.failNext('/task', 400);
      await rig.flush();
      expect(await rig.dao.byLocalId(t.uid.value), isNull);
      expect(await rig.outbox(), isEmpty);
      expect(rig.engine.status.notices, hasLength(1));
    });

    test('404 on update means the server lost it: row is dropped', () async {
      rig.net.server.seedTask(uid: 'a');
      await rig.sync();
      await rig.repo.update(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('new')),
      );
      rig.net.server.tasks.remove('a');
      await rig.flush();
      expect(await rig.dao.allRows(), isEmpty);
      expect(rig.engine.status.notices, hasLength(1));
    });

    test('a refused delete brings the task back', () async {
      rig.net.server.seedTask(uid: 'a');
      await rig.sync();
      await rig.repo.delete(const TaskUid('a'));
      rig.net.server.failNext('/task/a', 422);
      await rig.flush();
      expect((await rig.row('a')).pendingDelete, isFalse);
      expect(await rig.dao.taskByAnyId('a'), isNotNull);
    });
  });

  group('pull and merge', () {
    test('new server tasks are stored with tags, subtasks and stubs', () async {
      final parent = rig.net.server.seedTask(
        uid: 'p',
        name: 'Parent',
        tags: ['x', 'y'],
        projectUid: 'proj-1',
        extra: {'area_uid': 'area-1'},
      );
      rig.net.server.seedTask(
        uid: 'c',
        name: 'Child',
        extra: {'parent_task_id': parent['id']},
      );
      await rig.sync();

      final p = await rig.row('p');
      expect(p.dirtyFields, '{}');
      expect(p.baseJson, isNotNull);
      expect(await rig.dao.tagNames(p.localId), ['x', 'y']);
      final project = await rig.db.select(rig.db.projects).getSingle();
      expect(project.uid, 'proj-1');
      expect(p.projectLocalId, project.localId);
      final area = await rig.db.select(rig.db.areas).getSingle();
      expect(area.uid, 'area-1');
      expect(p.areaLocalId, area.localId);
      final c = await rig.row('c');
      expect(c.parentLocalId, p.localId);

      final all = await rig.dao.fetchView(TaskView.all, rig.today());
      expect(all.map((t) => t.name), ['Parent']);
      expect(all.single.subtasks.map((t) => t.name), ['Child']);
      expect(all.single.projectUid, const ProjectUid('proj-1'));
    });

    test('completed tasks older than 30 days are not stored', () async {
      final old = rig.t.subtract(const Duration(days: 60));
      rig.net.server
        ..seedTask(
          uid: 'old',
          status: 2,
          updatedAt: old,
          extra: {'completed_at': old.toIso8601String()},
        )
        ..seedTask(
          uid: 'recent',
          status: 2,
          updatedAt: rig.t,
          extra: {'completed_at': rig.t.toIso8601String()},
        );
      await rig.sync();
      expect((await rig.dao.allRows()).map((r) => r.uid), ['recent']);
    });

    test(
      'edits made offline merge per field with a newer server version',
      () async {
        rig.net.server.seedTask(
          uid: 'a',
          name: 'Base',
          note: 'base note',
          updatedAt: rig.t.subtract(const Duration(hours: 1)),
        );
        await rig.sync();

        // Local edits one hour from now (they are the newest).
        rig.advance(const Duration(hours: 1));
        await rig.repo.update(
          const TaskUid('a'),
          const TaskPatch(
            name: Patch.set('Local name'),
            priority: Patch.set(Priority.high),
          ),
        );
        // The server changed the name and the note meanwhile.
        serverTask('a')
          ..['name'] = 'Server name'
          ..['original_name'] = 'Server name'
          ..['note'] = 'server note'
          ..['updated_at'] = rig.t
              .subtract(const Duration(minutes: 5))
              .toIso8601String();

        await rig.sync(); // pull merges; the edits are not due yet
        final row = await rig.row('a');
        expect(row.name, 'Local name'); // newer local edit wins
        expect(row.note, 'server note'); // untouched locally: server value
        expect(row.priority, 2);
        expect(DirtyFields.decode(row.dirtyFields).fields, {
          'name',
          'priority',
        });
        final notice = rig.engine.status.notices.single;
        expect(notice.field, 'name');
        expect(notice.winner, ConflictWinner.local);
        expect(notice.serverValue, 'Server name');

        await rig.flush();
        expect(serverTask('a')['name'], 'Local name');
        expect(serverTask('a')['priority'], 2);
        expect((await rig.row('a')).dirtyFields, '{}');
      },
    );

    test('the server wins when its edit is newer', () async {
      rig.net.server.seedTask(uid: 'a', name: 'Base');
      await rig.sync();
      await rig.repo.update(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('Local name')),
      );
      serverTask('a')
        ..['name'] = 'Server name'
        ..['original_name'] = 'Server name'
        ..['updated_at'] = rig.t
            .add(const Duration(minutes: 30))
            .toIso8601String();
      await rig.sync();
      final row = await rig.row('a');
      expect(row.name, 'Server name');
      expect(row.dirtyFields, '{}');
      expect(rig.engine.status.notices.single.winner, ConflictWinner.server);
    });

    test('tags merge as sets', () async {
      rig.net.server.seedTask(uid: 'a', tags: ['one', 'two']);
      await rig.sync();
      await rig.repo.update(
        const TaskUid('a'),
        const TaskPatch(tags: Patch.set(['one', 'two', 'mine'])),
      );
      // The server adds a tag of its own.
      serverTask('a')
        ..['tags'] = [
          {'name': 'one'},
          {'name': 'two'},
          {'name': 'theirs'},
        ]
        ..['updated_at'] = rig.t
            .add(const Duration(minutes: 1))
            .toIso8601String();
      await rig.sync();
      expect((await rig.repo.get(const TaskUid('a'))).tags.map((t) => t.name), [
        'mine',
        'one',
        'theirs',
        'two',
      ]);
      expect(rig.engine.status.notices, isEmpty);
    });

    test(
      'full reconcile removes clean rows the server lost, keeps dirty ones',
      () async {
        rig.net.server
          ..seedTask(uid: 'keep')
          ..seedTask(uid: 'gone')
          ..seedTask(uid: 'edited');
        await rig.sync();
        await rig.repo.update(
          const TaskUid('edited'),
          const TaskPatch(name: Patch.set('mine')),
        );
        final offline = await rig.repo.create(const NewTask(name: 'new'));
        rig.net.server.tasks
          ..remove('gone')
          ..remove('edited');

        await rig.engine.requestSync(SyncReason.login); // full reconcile
        final rows = {
          for (final r in await rig.dao.allRows()) r.uid ?? r.localId,
        };
        expect(rows, {'keep', 'edited', offline.uid.value});
      },
    );
  });

  group('undo', () {
    test(
      'within the window the entry is cancelled and the row restored',
      () async {
        rig.net.server.seedTask(uid: 'a', name: 'Before');
        await rig.sync();
        final change = await rig.repo.updateTracked(
          const TaskUid('a'),
          const TaskPatch(name: Patch.set('After')),
        );
        expect(await rig.outbox(), hasLength(1));
        rig.advance(const Duration(seconds: 2));
        expect(await rig.repo.undo(change.undo!), isTrue);

        final row = await rig.row('a');
        expect(row.name, 'Before');
        expect(row.dirtyFields, '{}');
        expect(await rig.outbox(), isEmpty);
        expect(await rig.repo.undo(change.undo!), isFalse); // only once

        await rig.flush();
        expect(rig.net.sent('PATCH', '/task/a'), isEmpty);
      },
    );

    test('undo of an edit keeps the create it was absorbed into', () async {
      final t = await rig.repo.create(const NewTask(name: 'Before'));
      final change = await rig.repo.updateTracked(
        t.uid,
        const TaskPatch(name: Patch.set('After')),
      );
      await rig.repo.undo(change.undo!);
      expect((await rig.outbox()).map((e) => e.op), [OutboxOp.create]);
      expect((await rig.row(t.uid.value)).name, 'Before');
      await rig.flush();
      expect(rig.net.server.tasks.values.single['name'], 'Before');
    });

    test('undo of complete / delete / create inside the window', () async {
      rig.net.server.seedTask(uid: 'a', status: 1);
      await rig.sync();

      final done = await rig.repo.completeTracked(const TaskUid('a'));
      await rig.repo.undo(done.undo!);
      expect((await rig.row('a')).status, 1);
      expect(await rig.outbox(), isEmpty);

      final del = await rig.repo.deleteTracked(const TaskUid('a'));
      expect((await rig.row('a')).pendingDelete, isTrue);
      await rig.repo.undo(del.undo!);
      expect((await rig.row('a')).pendingDelete, isFalse);
      expect(await rig.outbox(), isEmpty);

      final created = await rig.repo.createTracked(const NewTask(name: 'n'));
      await rig.repo.undo(created.undo!);
      expect(await rig.dao.allRows(), hasLength(1));
      expect(await rig.outbox(), isEmpty);
    });

    test(
      'undo after the delete of a never-synced task brings it back',
      () async {
        final t = await rig.repo.create(const NewTask(name: 'x', tags: ['t']));
        final del = await rig.repo.deleteTracked(t.uid);
        expect(await rig.dao.allRows(), isEmpty);
        await rig.repo.undo(del.undo!);
        expect((await rig.repo.get(t.uid)).tags.map((g) => g.name), ['t']);
        expect((await rig.outbox()).map((e) => e.op), [OutboxOp.create]);
      },
    );

    test('after it was sent, undo queues the inverse change', () async {
      rig.net.server.seedTask(uid: 'a', name: 'Before');
      await rig.sync();
      final change = await rig.repo.updateTracked(
        const TaskUid('a'),
        const TaskPatch(name: Patch.set('After')),
      );
      await rig.flush();
      expect(serverTask('a')['name'], 'After');
      expect(await rig.outbox(), isEmpty);

      expect(await rig.repo.undo(change.undo!), isTrue);
      expect((await rig.row('a')).name, 'Before');
      final box = await rig.outbox();
      expect(box.map((e) => e.op), [OutboxOp.update]);
      await rig.flush();
      expect(serverTask('a')['name'], 'Before');
    });

    test('undo of a sent completion reopens the task', () async {
      rig.net.server.seedTask(uid: 'a', status: 4);
      await rig.sync();
      final done = await rig.repo.completeTracked(const TaskUid('a'));
      await rig.flush();
      expect(serverTask('a')['status'], 2);

      await rig.repo.undo(done.undo!);
      expect((await rig.outbox()).single.op, OutboxOp.complete);
      await rig.flush();
      expect(serverTask('a')['status'], 4);
      expect((await rig.row('a')).status, 4);
    });

    test('undo of a sent delete creates the task again', () async {
      rig.net.server.seedTask(uid: 'a', name: 'Keep me');
      await rig.sync();
      final del = await rig.repo.deleteTracked(const TaskUid('a'));
      await rig.flush();
      expect(rig.net.server.tasks, isEmpty);

      await rig.repo.undo(del.undo!);
      await rig.flush();
      final task = rig.net.server.tasks.values.single;
      expect(task['name'], 'Keep me');
      expect(task['uid'], isNot('a'));
    });

    test('undo of a sent create deletes the task again', () async {
      final created = await rig.repo.createTracked(const NewTask(name: 'n'));
      await rig.flush();
      expect(rig.net.server.tasks, hasLength(1));
      await rig.repo.undo(created.undo!);
      await rig.flush();
      expect(rig.net.server.tasks, isEmpty);
      expect(await rig.dao.allRows(), isEmpty);
    });
  });
}
