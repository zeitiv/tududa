import 'package:drift/drift.dart';

import 'sync_columns.dart';

@DataClassName('NoteRow')
@TableIndex(name: 'idx_notes_project', columns: {#projectLocalId})
class Notes extends Table with SyncColumns {
  TextColumn get title => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get projectLocalId => text().nullable()();
}

/// Note <-> tag join (both sides are local ids).
@DataClassName('NoteTagRow')
@TableIndex(name: 'idx_note_tags_tag', columns: {#tagLocalId})
class NoteTags extends Table {
  TextColumn get noteLocalId => text()();
  TextColumn get tagLocalId => text()();

  @override
  Set<Column> get primaryKey => {noteLocalId, tagLocalId};
}
