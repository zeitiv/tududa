import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/db/app_database.dart';
import '../../core/ids.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_handler.dart';
import '../data/note_patch.dart';
import '../data/offline_note_repository.dart';
import '../domain/note.dart';

/// Reads and writes go to the local database; `NoteSyncHandler` moves them to
/// the server.
final noteRepositoryProvider = Provider<OfflineNoteRepository>(
  (ref) => OfflineNoteRepository(ref.watch(appDatabaseProvider)),
);

/// All notes, live from the local database. Mutations return as soon as they
/// are stored locally.
class NoteListNotifier extends StreamNotifier<List<Note>> {
  OfflineNoteRepository get _repo => ref.read(noteRepositoryProvider);

  @override
  Stream<List<Note>> build() => ref.watch(noteRepositoryProvider).watchList();

  /// Pull-to-refresh: runs a sync cycle now.
  Future<void> refresh() =>
      ref.read(syncEngineProvider).requestSync(SyncReason.manual);

  Future<Note> create(NoteDraft draft) => _repo.create(draft);

  Future<Note> updateNote(NoteUid uid, NotePatch patch) =>
      _repo.update(uid, patch);

  /// For notes that may not have a uid yet.
  Future<Note> updateNoteLocal(LocalId id, NotePatch patch) =>
      _repo.updateByLocalId(id, patch);

  Future<void> deleteNote(NoteUid uid) => _repo.delete(uid);

  Future<void> deleteNoteLocal(LocalId id) => _repo.deleteByLocalId(id);
}

final noteListProvider = StreamNotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);

Stream<Note> _orNotFound(Stream<Note?> s) =>
    s.map((n) => n ?? (throw const NotFoundError('Note not found')));

/// One note by uid. Errors with `NotFoundError` while the note is unknown.
final noteByUidProvider = StreamProvider.family<Note, NoteUid>(
  (ref, uid) => _orNotFound(ref.watch(noteRepositoryProvider).watchByUid(uid)),
);

/// One note by local id; works before the note has a uid.
final noteByLocalIdProvider = StreamProvider.family<Note, LocalId>(
  (ref, id) =>
      _orNotFound(ref.watch(noteRepositoryProvider).watchByLocalId(id)),
);

/// Notes of one project (by the project's uid).
final projectNotesProvider = StreamProvider.family<List<Note>, ProjectUid>(
  (ref, uid) => ref.watch(noteRepositoryProvider).watchList(projectUid: uid),
);

/// Notes of one project by its local id (projects not synced yet).
final projectNotesByLocalIdProvider =
    StreamProvider.family<List<Note>, LocalId>(
      (ref, id) => ref.watch(noteRepositoryProvider).watchForProjectLocal(id),
    );
