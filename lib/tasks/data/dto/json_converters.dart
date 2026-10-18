import 'package:json_annotation/json_annotation.dart';

/// Tududi sends `status` as a number, but some endpoints and older versions
/// send the name (`done`, `in_progress`, ...). Reads both, writes the number.
/// Unknown names read as null.
class StatusCodeConverter implements JsonConverter<int?, Object?> {
  const StatusCodeConverter();

  static const names = <String, int>{
    'not_started': 0,
    'in_progress': 1,
    'done': 2,
    'archived': 3,
    'waiting': 4,
    'cancelled': 5,
    'planned': 6,
  };

  @override
  int? fromJson(Object? json) {
    if (json is num) return json.toInt();
    if (json is String) return names[json] ?? int.tryParse(json);
    return null;
  }

  @override
  Object? toJson(int? object) => object;
}

/// `priority` as a number or `low` / `medium` / `high`; writes the number.
class PriorityCodeConverter implements JsonConverter<int?, Object?> {
  const PriorityCodeConverter();

  static const names = <String, int>{'low': 0, 'medium': 1, 'high': 2};

  @override
  int? fromJson(Object? json) {
    if (json is num) return json.toInt();
    if (json is String) return names[json] ?? int.tryParse(json);
    return null;
  }

  @override
  Object? toJson(int? object) => object;
}

/// ISO timestamps; anything unparseable reads as null instead of failing the
/// whole task.
class LenientDateTimeConverter implements JsonConverter<DateTime?, Object?> {
  const LenientDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) =>
      json is String ? DateTime.tryParse(json) : null;

  @override
  Object? toJson(DateTime? object) => object?.toUtc().toIso8601String();
}

/// A list of ints that tolerates nulls, numbers sent as strings and a
/// non-list value.
class IntListConverter implements JsonConverter<List<int>?, Object?> {
  const IntListConverter();

  @override
  List<int>? fromJson(Object? json) {
    if (json is! List) return null;
    return [
      for (final e in json)
        if (e is num)
          e.toInt()
        else if (e is String && int.tryParse(e) != null)
          int.parse(e),
    ];
  }

  @override
  Object? toJson(List<int>? object) => object;
}
