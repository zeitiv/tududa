import '../../core/ids.dart';
import '../domain/note.dart';
import 'note_patch.dart';

/// Note access for the rest of the app. Notes are addressed by [NoteUid]
/// only. All failures are `ApiError`s.
abstract interface class NoteRepository {
  Future<List<Note>> list({ProjectUid? projectUid});
  Future<Note> get(NoteUid uid);
  Future<Note> create(NoteDraft draft);
  Future<Note> update(NoteUid uid, NotePatch patch);
  Future<void> delete(NoteUid uid);
}
