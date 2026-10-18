import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/patch.dart';
import 'package:tududa/core/db/dirty_fields.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/core/platform/widget_bridge.dart';
import 'package:tududa/core/sync/widget_reconciler.dart';
import 'package:tududa/tasks/data/task_patch.dart';
import 'package:tududa/tasks/domain/task.dart';

import '../../tasks/offline_rig.dart';

void main() {
  late OfflineRig rig;
  late InMemoryWidgetBridge bridge;
  late WidgetReconciler reconciler;
  late List<List<String>> refetched;

  setUp(() async {
    rig = OfflineRig();
    await rig.init();
    bridge = InMemoryWidgetBridge();
    refetched = [];
    reconciler = WidgetReconciler(
      db: rig.db,
      bridge: bridge,
      refetch: (uids) async => refetched.add(uids),
      now: () => rig.t,
    );
  });

  Future<String> seedAndPull({String name = 'Buy milk'}) async {
    final t = rig.net.server.seedTask(name: name);
    await rig.sync();
    return t['uid'] as String;
  }

  test('a widget completion lands in Drift without an outbox entry', () async {
    final uid = await seedAndPull();
    bridge.logChange(uid, 2, atMillis: rig.t.millisecondsSinceEpoch);

    expect(await reconciler.reconcile(), 1);

    final row = await rig.row(uid);
    expect(row.status, 2);
    expect(row.completedAt, isNotNull);
    expect(row.statusBeforeDone, 0);
    expect(BaseJson.decode(row.baseJson)!['status'], 2);
    expect(await rig.outbox(), isEmpty);
    expect(refetched.single, [uid]);
    expect(bridge.acks, [1]);
    expect(await bridge.pendingChanges(0), isEmpty);
  });

  test('a local edit on the same task merges', () async {
    final uid = await seedAndPull();
    await rig.repo.update(
      TaskUid(uid),
      const TaskPatch(name: Patch.set('Buy oat milk')),
    );
    bridge.logChange(uid, 2);
    await reconciler.reconcile();

    final row = await rig.row(uid);
    expect(row.status, 2);
    expect(row.name, 'Buy oat milk');
    expect(DirtyFields.decode(row.dirtyFields).isDirty('name'), isTrue);
    expect(DirtyFields.decode(row.dirtyFields).isDirty('status'), isFalse);

    // The server has the completion; the queued rename goes out on sync.
    rig.net.server.tasks[uid]!['status'] = 2;
    await rig.flush();
    expect(rig.net.server.tasks[uid]!['name'], 'Buy oat milk');
    expect((await rig.row(uid)).status, 2);
    expect(await rig.outbox(), isEmpty);
  });

  test('a queued local status edit is not overwritten', () async {
    final uid = await seedAndPull();
    await rig.repo.update(
      TaskUid(uid),
      TaskPatch(status: Patch.set(TaskStatus.inProgress)),
    );
    bridge.logChange(uid, 2);
    await reconciler.reconcile();
    expect((await rig.row(uid)).status, 1);
    expect(await rig.outbox(), hasLength(1));
    expect(bridge.acks, [1]);
  });

  test('unknown uids are ignored but still acknowledged', () async {
    bridge.logChange('nope', 2);
    await reconciler.reconcile();
    expect(refetched, isEmpty);
    expect(bridge.acks, [1]);
    expect(await rig.db.select(rig.db.tasks).get(), isEmpty);
  });

  test('acks the last sequence and the newest change per task wins', () async {
    final a = rig.net.server.seedTask(name: 'A')['uid'] as String;
    final b = rig.net.server.seedTask(name: 'B')['uid'] as String;
    await rig.sync();
    final (uid, other) = (a, b);
    bridge
      ..logChange(uid, 2)
      ..logChange(other, 2)
      ..logChange(uid, 0);
    await reconciler.reconcile();
    expect(bridge.acks, [3]);
    expect((await rig.row(uid)).status, 0);
    expect((await rig.row(other)).status, 2);
    expect(refetched.single, unorderedEquals([uid, other]));
  });

  test('running again is idempotent', () async {
    final uid = await seedAndPull();
    bridge.logChange(uid, 2);
    await reconciler.reconcile();
    final first = await rig.row(uid);
    expect(await reconciler.reconcile(), 0);
    expect(await rig.row(uid), first);
    expect(refetched, hasLength(1));

    // Same log delivered twice (ack lost): still no duplicate effect.
    bridge.logChange(uid, 2);
    await reconciler.reconcile();
    expect((await rig.row(uid)).status, 2);
    expect(await rig.outbox(), isEmpty);
  });

  test('canRun false leaves the log alone', () async {
    final uid = await seedAndPull();
    bridge.logChange(uid, 2);
    final gated = WidgetReconciler(
      db: rig.db,
      bridge: bridge,
      refetch: (_) async {},
      canRun: () => false,
    );
    expect(await gated.reconcile(), 0);
    expect(bridge.acks, isEmpty);
    expect((await rig.row(uid)).status, 0);
  });

  test('event channel messages trigger a reconcile', () async {
    final uid = await seedAndPull();
    reconciler.start();
    await pumpEventQueue();
    bridge.logChange(uid, 2);
    await pumpEventQueue(times: 50);
    expect((await rig.row(uid)).status, 2);
    reconciler.dispose();
  });
}
