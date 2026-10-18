import '../../tags/data/tag_mapper.dart';
import '../domain/note.dart';
import '../../tags/data/dto/tag_dto.dart';
import 'dto/note_dto.dart';

extension NoteDtoMapper on NoteDto {
  Note toDomain() => Note(
    id: id,
    uid: uid,
    title: title,
    content: content,
    color: color,
    projectUid: projectUid ?? project?.uid,
    projectName: project?.name,
    tags: [for (final t in tags ?? const <TagDto>[]) t.toDomain()],
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension NoteDraftJson on NoteDraft {
  Map<String, Object?> toJson() => {
    'title': title,
    'content': content,
    'color': color,
    'project_uid': projectUid?.value,
    if (tagNames.isNotEmpty)
      'tags': [
        for (final n in tagNames) {'name': n},
      ],
  };
}
