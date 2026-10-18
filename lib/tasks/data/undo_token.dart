import '../../core/db/app_database.dart';

/// How long a local change waits in the outbox before it is sent; undoing
/// inside this window cancels the entry.
const kUndoWindow = Duration(seconds: 5);

/// What a mutation did, for choosing the right reversal.
enum UndoKind { create, update, complete, uncomplete, delete, skipOccurrence }

/// A change together with the token that can revert it.
class Change<T> {
  const Change(this.value, [this.undo]);

  final T value;

  /// Null when nothing changed (no-op) or the change cannot be undone.
  final UndoToken? undo;
}

/// State of one task row before a mutation: enough to put the row, its tag
/// links and its outbox entries back exactly as they were.
class TaskSnapshot {
  TaskSnapshot({
    required this.localId,
    required this.row,
    required this.tagLocalIds,
    required this.outbox,
    this.fields = const {},
  });

  final String localId;

  /// The row before the change; null when the change created it.
  final TaskRow? row;
  final List<String> tagLocalIds;

  /// The outbox entries of this task before the change.
  final List<OutboxEntry> outbox;

  /// Fields the change marked dirty (what a post-send undo has to revert).
  final Set<String> fields;

  /// The outbox entry that represents the change (null if none remained).
  int? outboxId;
}

/// Handle for undoing one mutation of `OfflineTaskRepository`. Pass it to
/// `undo`: within [sendAfter] the queued entry is cancelled and the row is
/// restored; afterwards the inverse change is queued.
class UndoToken {
  UndoToken({
    required this.kind,
    required this.sendAfter,
    required this.snapshots,
  });

  final UndoKind kind;

  /// When the outbox may start sending the change (end of the undo window).
  final DateTime sendAfter;
  final List<TaskSnapshot> snapshots;

  /// Set once [undo] ran; a token works only once.
  bool used = false;

  /// Local ids of the tasks the change touched.
  List<String> get localIds => [for (final s in snapshots) s.localId];
}
