# Offline sync: lane contract

Reads come from drift tables (`lib/core/db/tables`), writes go to the table and
the outbox together, and `SyncEngine` moves data to and from the server.

## Writing a mutation (one `db.transaction`)
```dart
await db.transaction(() async {
  final row = await dao.byLocalId(id);
  final dirty = DirtyFields.decode(row.dirtyFields).mark('name', nowMs);
  await dao.update(id, name: newName, dirtyFields: dirty.encode(), localUpdatedAt: now);
  await db.outboxDao.enqueue(entity: SyncEntity.task, localId: id,
      op: OutboxOp.update, notBefore: now.add(const Duration(seconds: 5))); // undo window
});
```
- Creates: generate `LocalId.generate()`, insert the row with all fields dirty,
  enqueue `create`. `uid`/`server_id` stay null until the push.
- Deletes: set `pending_delete = true` (hide it in queries) and enqueue `delete`.
  `create`+`delete` cancels out and removes the row (delete children yourself).
- `complete` carries `extra_json {"completed": true|false}`; `false` cancels a
  queued `true`. Mark `status`/`completed_at` dirty as well.
- Never bypass the outbox; never use `INSERT OR REPLACE` (search index
  triggers). Use `insertOnConflictUpdate`.
- The write trigger fires from outbox inserts; no manual `notifyWrite` needed.

## Handlers (`SyncHandler`, registered in `syncHandlersProvider`)
- `push`: read the row *now*; build the request from the dirty fields only
  (PATCH body), resolve references at send time:
  `ctx.ids.requireUid(SyncEntity.project, row.projectLocalId!)` throws
  `DependencyPendingException` (engine retries after other entries ran).
  Throw `ApiError` (wrap calls in `guard`); the engine classifies it.
- After a successful push: store uid/server_id/server_updated_at, replace
  `base_json`, and clear only what you sent: `dirty.clearSent(sentMap)`
  (a field edited during the push stays dirty). Return `PushResult.ok`.
  `PushResult.dropped` when there is nothing to send.
- `pull`/`fullReconcile`: fetch (`pullPaged` for `updated_at desc` lists), then
  per row: no local row -> insert (new local id, `base_json` = server snapshot);
  clean row -> overwrite; dirty row -> `mergeFields(base, local, server, dirty,
  ...)`, store `value`, `dirtyFields`, report `notices` via `ctx.notice`.
  Honour `resolveRow` for pending deletes and server deletions.
  `fullReconcile` ends with `db.removeCleanMissing(entity, serverUids)`.
- `rollback` (server answered 400/404/409/422): restore `base_json` and clear
  dirty fields, or delete the row if it never reached the server; then
  `ctx.notice(ConflictNotice.rolledBack(...))`. The engine removes the entry.

## Engine behaviour you can rely on
- Cycle = pull (areas, projects, tags, tasks, notes, inbox) then push due
  entries oldest first; `not_before` and retry times are honoured; waiting
  entries are retried in the same cycle once something else made progress.
- Transient errors back off 2 s..5 min; 10 attempts -> `stuck` (manual sync
  retries). 401 -> one re-login, else `SyncPhase.signedOut` with all entries
  kept. Entries are only deleted by `engine.onAccountChanged()` (wipes the DB).
- UI: `ref.read(syncEngineProvider).requestSync(SyncReason.manual)`,
  `ref.watch(syncStatusProvider)`, `db.outboxDao.watchAll()` / `cancel(id)` /
  `retryNow(id: ...)`. Start `syncTriggersProvider` once at the app root.
- Dates: `due_date` `YYYY-MM-DD` and `due_time` `HH:mm` are text; instants are
  UTC `DateTime`. Search: `db.searchIndex(ftsQuery(text), 50)`.
