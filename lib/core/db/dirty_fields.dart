import 'dart:convert';

/// The `dirty_fields` column: which fields of a row were edited locally and
/// have not been confirmed by the server, with the device-clock epoch
/// milliseconds of the last local edit of each.
///
/// Immutable: every mutator returns a new instance.
///
/// ```dart
/// final dirty = DirtyFields.decode(row.dirtyFields).mark('name', nowMs);
/// // ... companion: dirtyFields: Value(dirty.encode())
/// ```
class DirtyFields {
  const DirtyFields([this._map = const {}]);

  /// Reads the column value; null, empty or malformed text means "clean".
  factory DirtyFields.decode(String? json) {
    if (json == null || json.isEmpty) return const DirtyFields();
    try {
      final raw = jsonDecode(json);
      if (raw is! Map) return const DirtyFields();
      return DirtyFields({
        for (final e in raw.entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      });
    } on FormatException {
      return const DirtyFields();
    }
  }

  final Map<String, int> _map;

  /// Value to store in the column (`{}` when clean). Keys are sorted so equal
  /// sets encode equally.
  String encode() =>
      jsonEncode(Map.fromEntries(_map.entries.toList()..sort(_byKey)));

  static int _byKey(MapEntry<String, int> a, MapEntry<String, int> b) =>
      a.key.compareTo(b.key);

  /// Marks [field] as edited at [nowMs] (device clock, epoch ms).
  DirtyFields mark(String field, int nowMs) =>
      DirtyFields({..._map, field: nowMs});

  /// Marks every field in [fields] as edited at [nowMs].
  DirtyFields markAll(Iterable<String> fields, int nowMs) =>
      DirtyFields({..._map, for (final f in fields) f: nowMs});

  /// Removes [fields] (e.g. after the server confirmed them).
  DirtyFields clear(Iterable<String> fields) {
    final drop = fields.toSet();
    return DirtyFields({
      for (final e in _map.entries)
        if (!drop.contains(e.key)) e.key: e.value,
    });
  }

  /// Removes only those of [sent] whose edit time still equals the time that
  /// was sent. A field edited again while the push was in flight stays dirty.
  DirtyFields clearSent(Map<String, int> sent) => DirtyFields({
    for (final e in _map.entries)
      if (sent[e.key] != e.value) e.key: e.value,
  });

  bool isDirty(String field) => _map.containsKey(field);

  bool get isEmpty => _map.isEmpty;
  bool get isNotEmpty => _map.isNotEmpty;

  /// Names of the dirty fields.
  Set<String> get fields => _map.keys.toSet();

  /// Edit time of [field] (epoch ms), or null when clean.
  int? editedAt(String field) => _map[field];

  /// Copy of the field -> epoch ms map (what `mergeFields` takes).
  Map<String, int> toMap() => Map.of(_map);

  @override
  bool operator ==(Object other) =>
      other is DirtyFields && encode() == other.encode();

  @override
  int get hashCode => encode().hashCode;

  @override
  String toString() => 'DirtyFields(${encode()})';
}

/// Helpers for the `base_json` column: the last known server snapshot of a
/// row, as the field map handlers use for merging (keys = column-style field
/// names, values JSON-compatible).
abstract final class BaseJson {
  static String encode(Map<String, dynamic> snapshot) => jsonEncode(snapshot);

  /// The snapshot, or null when the row has never been seen on the server.
  static Map<String, dynamic>? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final raw = jsonDecode(json);
      return raw is Map ? Map<String, dynamic>.from(raw) : null;
    } on FormatException {
      return null;
    }
  }
}
