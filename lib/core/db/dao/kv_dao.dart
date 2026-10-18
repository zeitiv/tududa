import 'dart:convert';

import '../app_database.dart';

/// JSON key/value cache in the `kv_settings` table.
class KvDao {
  KvDao(this._db);
  final AppDatabase _db;

  /// The decoded JSON value, or null when absent or unreadable.
  Future<Object?> get(String key) async {
    final row = await (_db.select(
      _db.kvSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> set(String key, Object? value) => _db
      .into(_db.kvSettings)
      .insertOnConflictUpdate(
        KvSettingsCompanion.insert(key: key, value: jsonEncode(value)),
      );

  Future<void> remove(String key) =>
      (_db.delete(_db.kvSettings)..where((t) => t.key.equals(key))).go();
}
