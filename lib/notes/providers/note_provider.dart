import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/ids.dart';
import '../data/note_patch.dart';
import '../data/note_repository.dart';
import '../data/notes_api.dart';
import '../data/remote_note_repository.dart';
import '../domain/note.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => RemoteNoteRepository(NotesApi(ref.watch(dioProvider))),
);

/// All notes. Mutations rethrow the repository's `ApiError`.
class NoteListNotifier extends AsyncNotifier<List<Note>> {
  NoteRepository get _repo => ref.read(noteRepositoryProvider);

  @override
  Future<List<Note>> build() => ref.watch(noteRepositoryProvider).list();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repo.list);
  }

  List<Note> get _current => state.value ?? const [];

  Future<Note> create(NoteDraft draft) async {
    final note = await _repo.create(draft);
    state = AsyncData([note, ..._current]);
    return note;
  }

  Future<Note> updateNote(NoteUid uid, NotePatch patch) async {
    final updated = await _repo.update(uid, patch);
    state = AsyncData([
      for (final n in _current)
        if (n.uid == uid) updated else n,
    ]);
    ref.invalidate(noteByUidProvider(uid));
    return updated;
  }

  Future<void> deleteNote(NoteUid uid) async {
    await _repo.delete(uid);
    state = AsyncData([
      for (final n in _current)
        if (n.uid != uid) n,
    ]);
    ref.invalidate(noteByUidProvider(uid));
  }
}

final noteListProvider = AsyncNotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);

/// One note, loaded by uid (what the editor needs when opened from a link).
final noteByUidProvider = FutureProvider.family<Note, NoteUid>(
  (ref, uid) => ref.watch(noteRepositoryProvider).get(uid),
);

/// Notes of one project.
final projectNotesProvider = FutureProvider.family<List<Note>, ProjectUid>(
  (ref, uid) => ref.watch(noteRepositoryProvider).list(projectUid: uid),
);
