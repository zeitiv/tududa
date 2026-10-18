import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Who won a field conflict.
enum ConflictWinner { local, server }

/// A conflict that was resolved automatically; collected by the engine and
/// shown on the sync screen. Values are JSON-compatible.
@immutable
class ConflictNotice {
  const ConflictNotice({
    required this.entity,
    required this.localId,
    required this.field,
    required this.winner,
    this.localValue,
    this.serverValue,
    this.message,
  });

  /// The server rejected or deleted the row, so local edits were rolled back.
  /// [field] is `*` (the whole row).
  const ConflictNotice.rolledBack({
    required this.entity,
    required this.localId,
    this.message,
  }) : field = '*',
       winner = ConflictWinner.server,
       localValue = null,
       serverValue = null;

  final String entity;
  final String localId;

  /// Field name, or `*` for a whole-row rollback.
  final String field;
  final Object? localValue;
  final Object? serverValue;
  final ConflictWinner winner;
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is ConflictNotice &&
      other.entity == entity &&
      other.localId == localId &&
      other.field == field &&
      other.winner == winner &&
      const DeepCollectionEquality().equals(other.localValue, localValue) &&
      const DeepCollectionEquality().equals(other.serverValue, serverValue);

  @override
  int get hashCode => Object.hash(entity, localId, field, winner);

  @override
  String toString() =>
      'ConflictNotice($entity/$localId.$field, $winner, '
      'local: $localValue, server: $serverValue)';
}

/// Output of a merge: the merged value, the dirty fields that remain, the
/// conflicts that were resolved on the way, and local texts that lost against
/// the server but must not be thrown away.
class MergeResult<T> {
  const MergeResult({
    required this.value,
    this.dirtyFields = const {},
    this.notices = const [],
    this.conflictCopies = const {},
  });

  /// Merged field map (for [mergeFields]) or merged text.
  final T value;

  /// field -> local edit epoch ms, for the fields still waiting to be pushed.
  final Map<String, int> dirtyFields;
  final List<ConflictNotice> notices;

  /// field -> losing local value, only for `conflictCopyFields`.
  final Map<String, Object?> conflictCopies;

  /// The losing local text of a note-content merge, if any.
  String? get conflictCopy => conflictCopies.values.firstOrNull as String?;
}

const _eq = DeepCollectionEquality();

/// Field-level three-way merge of one row.
///
/// - [base]: last known server snapshot (`base_json`), null if there is none.
/// - [local]: the row as stored locally; [server]: the freshly pulled one.
///   All three are maps from field name to JSON-compatible value (use the
///   same keys and encodings; tags/lists compare deeply).
/// - [dirtyFields]: field -> local edit time (device epoch ms).
///
/// Per field:
/// 1. not dirty: the server value.
/// 2. dirty, server equals local: server value, no longer dirty.
/// 3. dirty, local equals base (an edit that was reverted): server value,
///    no longer dirty.
/// 4. dirty, server equals base (only we changed it): local value, still
///    dirty.
/// 5. both changed (or no base to tell): the newer edit wins. The local edit
///    time is moved to the server clock by adding [skew] (`server - device`)
///    and compared with [serverUpdatedAt]; a tie goes to the server. The
///    loser is reported as a [ConflictNotice]. A local winner stays dirty; a
///    server winner is dropped from the dirty set.
///
/// [setFields] (default `tags`) are merged as sets from [base]: the server's
/// elements, minus what we removed, plus what we added; no notice. Fields in
/// [conflictCopyFields] never let local win: the server value is taken and
/// the local value is returned in [MergeResult.conflictCopies].
MergeResult<Map<String, dynamic>> mergeFields(
  Map<String, dynamic>? base,
  Map<String, dynamic> local,
  Map<String, dynamic> server,
  Map<String, int> dirtyFields, {
  required String entity,
  required String localId,
  required DateTime serverUpdatedAt,
  required Duration skew,
  Set<String> setFields = const {'tags'},
  Set<String> conflictCopyFields = const {},
}) {
  final merged = <String, dynamic>{};
  final dirty = <String, int>{};
  final notices = <ConflictNotice>[];
  final copies = <String, Object?>{};
  final serverMs = serverUpdatedAt.millisecondsSinceEpoch;

  for (final k in {...local.keys, ...server.keys}) {
    final lv = local[k];
    final sv = server[k];
    final editedAt = dirtyFields[k];

    if (editedAt == null) {
      merged[k] = server.containsKey(k) ? sv : lv;
      continue;
    }
    if (!server.containsKey(k)) {
      merged[k] = lv;
      dirty[k] = editedAt;
      continue;
    }

    if (setFields.contains(k)) {
      final result = _mergeSet(base?[k], lv, sv);
      merged[k] = result;
      if (!_sameSet(result, sv)) dirty[k] = editedAt;
      continue;
    }

    final bv = base?[k];
    final hasBase = base != null;
    if (_eq.equals(sv, lv)) {
      merged[k] = sv;
    } else if (hasBase && _eq.equals(lv, bv)) {
      merged[k] = sv;
    } else if (hasBase && _eq.equals(sv, bv)) {
      merged[k] = lv;
      dirty[k] = editedAt;
    } else {
      final localMs = editedAt + skew.inMilliseconds;
      final localWins = !conflictCopyFields.contains(k) && localMs > serverMs;
      if (conflictCopyFields.contains(k)) copies[k] = lv;
      notices.add(
        ConflictNotice(
          entity: entity,
          localId: localId,
          field: k,
          localValue: lv,
          serverValue: sv,
          winner: localWins ? ConflictWinner.local : ConflictWinner.server,
        ),
      );
      if (localWins) {
        merged[k] = lv;
        dirty[k] = editedAt;
      } else {
        merged[k] = sv;
      }
    }
  }

  // Dirty marks for fields neither side carries are kept untouched.
  for (final e in dirtyFields.entries) {
    if (!local.containsKey(e.key) && !server.containsKey(e.key)) {
      dirty[e.key] = e.value;
    }
  }

  return MergeResult(
    value: merged,
    dirtyFields: dirty,
    notices: notices,
    conflictCopies: copies,
  );
}

/// Merge for the body text of a note. When both sides changed it, the server
/// text wins and the local text comes back as [MergeResult.conflictCopy] so
/// the caller can keep it (e.g. as a "conflict copy" note). Otherwise as
/// [mergeFields] for the single field [field].
MergeResult<String?> mergeNoteContent({
  required String? base,
  required String? local,
  required String? server,
  required Map<String, int> dirtyFields,
  required String localId,
  String field = 'content',
  String entity = 'note',
}) {
  final r = mergeFields(
    {field: base},
    {field: local},
    {field: server},
    {field: ?dirtyFields[field]},
    entity: entity,
    localId: localId,
    serverUpdatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    skew: Duration.zero,
    conflictCopyFields: {field},
  );
  return MergeResult(
    value: r.value[field] as String?,
    dirtyFields: {...dirtyFields}
      ..remove(field)
      ..addAll(r.dirtyFields),
    notices: r.notices,
    conflictCopies: r.conflictCopies,
  );
}

String _key(Object? e) => e is Map || e is List ? e.toString() : '$e';

List<Object?> _asList(Object? v) => v is List ? v : const [];

bool _sameSet(Object? a, Object? b) {
  final x = _asList(a).map(_key).toSet();
  final y = _asList(b).map(_key).toSet();
  return x.length == y.length && x.containsAll(y);
}

List<Object?> _mergeSet(Object? base, Object? local, Object? server) {
  final baseKeys = _asList(base).map(_key).toSet();
  final localKeys = _asList(local).map(_key).toSet();
  final removed = baseKeys.difference(localKeys);
  final result = <Object?>[];
  final seen = <String>{};
  for (final e in _asList(server)) {
    final k = _key(e);
    if (removed.contains(k) || !seen.add(k)) continue;
    result.add(e);
  }
  for (final e in _asList(local)) {
    final k = _key(e);
    if (!baseKeys.contains(k) && seen.add(k)) result.add(e);
  }
  return result;
}

/// What to do with a local row given the server's state of it.
enum RowResolution {
  /// Plain case: merge or overwrite with the server's row.
  applyServer,

  /// The user deleted it locally: the delete wins over any server edit; keep
  /// the row hidden and let the queued delete go out.
  keepPendingDelete,

  /// Gone on the server and nothing local to lose: remove the row.
  removeLocal,

  /// Gone on the server but with unsent local edits: keep it until its push
  /// fails with 404, then `rollback` removes it and reports a notice
  /// (`ConflictNotice.rolledBack`).
  keepForPush,
}

/// Decides how a pulled state meets a local row ([serverDeleted]: the server
/// no longer lists it, as found by a full reconcile).
RowResolution resolveRow({
  required bool pendingDelete,
  required bool serverDeleted,
  required bool hasDirtyFields,
}) {
  if (pendingDelete) {
    return serverDeleted
        ? RowResolution.removeLocal
        : RowResolution.keepPendingDelete;
  }
  if (!serverDeleted) return RowResolution.applyServer;
  return hasDirtyFields ? RowResolution.keepForPush : RowResolution.removeLocal;
}
