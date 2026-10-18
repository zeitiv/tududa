import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/retry_policy.dart';
import 'package:tududa/core/sync/sync_engine.dart';
import 'package:tududa/core/sync/sync_handler.dart';
import 'package:tududa/core/time/user_clock.dart';
import 'package:tududa/notes/data/note_sync_handler.dart';
import 'package:tududa/notes/data/offline_note_repository.dart';
import 'package:tududa/tags/data/offline_tag_repository.dart';
import 'package:tududa/tags/data/tag_sync_handler.dart';

import '../support/api_stack.dart';
import '../support/fake_tududi/fake_tududi.dart';
import '../support/fake_tududi/routes/notes_routes.dart';

/// A signed-in stack against a fake server that serves notes and tags.
Future<TestStack> signedInStack() async {
  final server = FakeTududi()..addUser('a@b.c', 'pw');
  registerNoteRoutes(server);
  final stack = TestStack(server);
  Future<bool> login() async {
    await stack.dio.post('/login', data: {'email': 'a@b.c', 'password': 'pw'});
    return true;
  }

  stack.callbacks.onReauth = login;
  await login();
  return stack;
}

Future<ApiError> errorOf(Future<Object?> f) async {
  try {
    await f;
  } on ApiError catch (e) {
    return e;
  }
  throw StateError('expected ApiError');
}

class _NoTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
}

/// The offline stack under test: in-memory db, offline repositories, the real
/// engine with the note and tag handlers, and the fake server behind it.
/// One clock [t] drives the repositories, the engine and the server.
class OfflineEnv {
  OfflineEnv._(this.stack, this.db) {
    stack.server.clock = () => t;
    notes = OfflineNoteRepository(db, now: () => t);
    tags = OfflineTagRepository(db, now: () => t);
    engine = SyncEngine(
      db: db,
      handlers: [NoteSyncHandler(), TagSyncHandler()],
      dio: () => stack.dio,
      clock: UserClock(now: () => t, zoneName: 'UTC'),
      reauthenticate: () async => true,
      isOnline: () => online,
      now: () => t,
      retryPolicy: RetryPolicy(random: FixedRandom()),
      createTimer: (_, _) => _NoTimer(),
    );
  }

  static Future<OfflineEnv> create() async {
    final stack = await signedInStack();
    final env = OfflineEnv._(
      stack,
      AppDatabase.forTesting(NativeDatabase.memory()),
    );
    await env.engine.start();
    return env;
  }

  final TestStack stack;
  final AppDatabase db;
  late final OfflineNoteRepository notes;
  late final OfflineTagRepository tags;
  late final SyncEngine engine;
  DateTime t = DateTime.utc(2025, 6, 1, 12);
  bool online = true;

  FakeTududi get server => stack.server;
  NotesStore get remote => notesStoreOf(server);

  void advance([Duration d = const Duration(seconds: 10)]) => t = t.add(d);

  /// A manual sync cycle (also retries failed entries).
  Future<void> sync() => engine.requestSync(SyncReason.manual);

  /// Waits past the edit debounce, then syncs.
  Future<void> syncLater() {
    advance();
    return sync();
  }

  SyncContext context() => SyncContext(
    db: db,
    dio: () => stack.dio,
    clock: UserClock(now: () => t, zoneName: 'UTC'),
    now: t,
    onNotice: notices.add,
  );

  final List<dynamic> notices = [];

  Future<List<OutboxEntry>> outbox() => db.outboxDao.all();

  int count(String method, String path) => stack.count(method, path);

  /// A project row that has no uid yet.
  Future<void> insertProject(String localId, {String? uid}) => db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          localId: localId,
          uid: Value(uid),
          name: const Value('Proj'),
        ),
      );

  Future<void> dispose() async {
    await engine.dispose();
    await db.close();
  }
}
