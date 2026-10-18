import '../../core/ids.dart';
import '../domain/note.dart';
import 'note_mapper.dart';
import 'note_patch.dart';
import 'note_repository.dart';
import 'notes_api.dart';

class RemoteNoteRepository implements NoteRepository {
  RemoteNoteRepository(this._api);
  final NotesApi _api;

  @override
  Future<List<Note>> list({ProjectUid? projectUid}) async => [
    for (final d in await _api.list(projectUid: projectUid)) d.toDomain(),
  ];

  @override
  Future<Note> get(NoteUid uid) async => (await _api.get(uid)).toDomain();

  @override
  Future<Note> create(NoteDraft draft) async =>
      (await _api.create(draft.toJson())).toDomain();

  @override
  Future<Note> update(NoteUid uid, NotePatch patch) async =>
      (await _api.update(uid, patch)).toDomain();

  @override
  Future<void> delete(NoteUid uid) => _api.delete(uid);
}
