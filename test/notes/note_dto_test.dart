import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/api/page.dart';
import 'package:tududa/core/api/patch.dart' show Patch;
import 'package:tududa/core/ids.dart';
import 'package:tududa/notes/data/dto/note_dto.dart';
import 'package:tududa/notes/data/note_mapper.dart';
import 'package:tududa/notes/data/note_patch.dart';
import 'package:tududa/notes/domain/note.dart';

void main() {
  final full = {
    'id': 3,
    'uid': 'abc123',
    'title': 'T',
    'content': 'C',
    'color': '#FFD6D6',
    'project_uid': 'p1',
    'Project': {'id': 9, 'uid': 'p1', 'name': 'Home'},
    'tags': [
      {'name': 'x', 'uid': 'tg1', 'color': '#fff', 'pinned': true},
    ],
    'created_at': '2025-01-01T00:00:00.000Z',
    'updated_at': '2025-02-01T10:00:00.000Z',
  };

  test('full note maps to the domain', () {
    final n = NoteDto.fromJson(full).toDomain();
    expect(n.uid, const NoteUid('abc123'));
    expect(n.color, '#FFD6D6');
    expect(n.projectUid, const ProjectUid('p1'));
    expect(n.projectName, 'Home');
    expect(n.tags.single.name, 'x');
    expect(n.tags.single.uid, const TagUid('tg1'));
    expect(n.updatedAt, DateTime.utc(2025, 2, 1, 10));
  });

  test('nulls and missing fields', () {
    final n = NoteDto.fromJson({
      'uid': 'u',
      'title': null,
      'content': null,
      'color': null,
      'Project': null,
      'tags': null,
    }).toDomain();
    expect(n.title, isNull);
    expect(n.color, isNull);
    expect(n.projectUid, isNull);
    expect(n.projectName, isNull);
    expect(n.tags, isEmpty);
    expect(n.createdAt, isNull);
  });

  test('project uid falls back to the embedded Project, capital Tags', () {
    final n = NoteDto.fromJson({
      'uid': 'u',
      'Project': {'uid': 'p7', 'name': 'P'},
      'Tags': [
        {'name': 'a'},
      ],
    }).toDomain();
    expect(n.projectUid, const ProjectUid('p7'));
    expect(n.tags.single.name, 'a');
    expect(n.tags.single.uid, isNull);
  });

  test('list shapes: bare list and {notes: []}', () {
    final bare = Page.fromJson([full], NoteDto.fromJson, itemsKey: 'notes');
    final wrapped = Page.fromJson(
      {
        'notes': [full],
      },
      NoteDto.fromJson,
      itemsKey: 'notes',
    );
    expect(bare.items.single.uid, wrapped.items.single.uid);
  });

  test('NotePatch: unset leaves keys out, clear sends null, tags replace', () {
    expect(const NotePatch().toJson(), isEmpty);
    expect(
      const NotePatch(
        title: Patch.set('n'),
        color: Patch.clear(),
        projectUid: Patch.set(ProjectUid('p')),
        tags: Patch.set(['a', 'b']),
      ).toJson(),
      {
        'title': 'n',
        'color': null,
        'project_uid': 'p',
        'tags': [
          {'name': 'a'},
          {'name': 'b'},
        ],
      },
    );
    expect(const NotePatch(content: Patch.clear()).toJson(), {'content': null});
  });

  test('NoteDraft json', () {
    expect(const NoteDraft(title: 't', projectUid: ProjectUid('p')).toJson(), {
      'title': 't',
      'content': null,
      'color': null,
      'project_uid': 'p',
    });
  });
}
