import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

/// Typed identifiers. Server uids are strings; server numeric ids are ints.
/// All are zero-cost extension types, so `TaskUid` and `ProjectUid` cannot be
/// mixed up at compile time. Each has a matching `JsonConverter` for use with
/// `@TaskUidConverter()` in json_serializable / freezed classes (plus a
/// `Nullable...` variant for optional fields).

extension type const TaskUid(String value) {}

class TaskUidConverter implements JsonConverter<TaskUid, String> {
  const TaskUidConverter();
  @override
  TaskUid fromJson(String json) => TaskUid(json);
  @override
  String toJson(TaskUid object) => object.value;
}

class NullableTaskUidConverter implements JsonConverter<TaskUid?, String?> {
  const NullableTaskUidConverter();
  @override
  TaskUid? fromJson(String? json) => json == null ? null : TaskUid(json);
  @override
  String? toJson(TaskUid? object) => object?.value;
}

extension type const ProjectUid(String value) {}

class ProjectUidConverter implements JsonConverter<ProjectUid, String> {
  const ProjectUidConverter();
  @override
  ProjectUid fromJson(String json) => ProjectUid(json);
  @override
  String toJson(ProjectUid object) => object.value;
}

class NullableProjectUidConverter
    implements JsonConverter<ProjectUid?, String?> {
  const NullableProjectUidConverter();
  @override
  ProjectUid? fromJson(String? json) => json == null ? null : ProjectUid(json);
  @override
  String? toJson(ProjectUid? object) => object?.value;
}

extension type const AreaUid(String value) {}

class AreaUidConverter implements JsonConverter<AreaUid, String> {
  const AreaUidConverter();
  @override
  AreaUid fromJson(String json) => AreaUid(json);
  @override
  String toJson(AreaUid object) => object.value;
}

class NullableAreaUidConverter implements JsonConverter<AreaUid?, String?> {
  const NullableAreaUidConverter();
  @override
  AreaUid? fromJson(String? json) => json == null ? null : AreaUid(json);
  @override
  String? toJson(AreaUid? object) => object?.value;
}

extension type const NoteUid(String value) {}

class NoteUidConverter implements JsonConverter<NoteUid, String> {
  const NoteUidConverter();
  @override
  NoteUid fromJson(String json) => NoteUid(json);
  @override
  String toJson(NoteUid object) => object.value;
}

class NullableNoteUidConverter implements JsonConverter<NoteUid?, String?> {
  const NullableNoteUidConverter();
  @override
  NoteUid? fromJson(String? json) => json == null ? null : NoteUid(json);
  @override
  String? toJson(NoteUid? object) => object?.value;
}

extension type const TagUid(String value) {}

class TagUidConverter implements JsonConverter<TagUid, String> {
  const TagUidConverter();
  @override
  TagUid fromJson(String json) => TagUid(json);
  @override
  String toJson(TagUid object) => object.value;
}

class NullableTagUidConverter implements JsonConverter<TagUid?, String?> {
  const NullableTagUidConverter();
  @override
  TagUid? fromJson(String? json) => json == null ? null : TagUid(json);
  @override
  String? toJson(TagUid? object) => object?.value;
}

extension type const InboxUid(String value) {}

class InboxUidConverter implements JsonConverter<InboxUid, String> {
  const InboxUidConverter();
  @override
  InboxUid fromJson(String json) => InboxUid(json);
  @override
  String toJson(InboxUid object) => object.value;
}

class NullableInboxUidConverter implements JsonConverter<InboxUid?, String?> {
  const NullableInboxUidConverter();
  @override
  InboxUid? fromJson(String? json) => json == null ? null : InboxUid(json);
  @override
  String? toJson(InboxUid? object) => object?.value;
}

const _uuid = Uuid();

/// Client-generated identifier (uuid v4) for rows that do not have a server
/// uid yet.
extension type const LocalId(String value) {
  factory LocalId.generate() => LocalId(_uuid.v4());
}

class LocalIdConverter implements JsonConverter<LocalId, String> {
  const LocalIdConverter();
  @override
  LocalId fromJson(String json) => LocalId(json);
  @override
  String toJson(LocalId object) => object.value;
}

/// Numeric database id assigned by the Tududi server (users of the API should
/// prefer uids; ids are only needed for a few endpoints, e.g. `parent_task_id`).
extension type const ServerId(int value) {}

class ServerIdConverter implements JsonConverter<ServerId, int> {
  const ServerIdConverter();
  @override
  ServerId fromJson(int json) => ServerId(json);
  @override
  int toJson(ServerId object) => object.value;
}

class NullableServerIdConverter implements JsonConverter<ServerId?, int?> {
  const NullableServerIdConverter();
  @override
  ServerId? fromJson(int? json) => json == null ? null : ServerId(json);
  @override
  int? toJson(ServerId? object) => object?.value;
}
