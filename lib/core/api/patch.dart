/// Tri-state field for PATCH bodies: leave alone, set, or clear.
///
/// Tududi keeps fields that are absent from a PATCH and clears fields sent as
/// `null`, so "not provided" and "null" must stay distinct:
///
/// ```dart
/// final json = <String, Object?>{};
/// putPatch(json, 'due_date', patch.dueDate, (d) => d.toIso());
/// ```
///
/// NOTE: this library declares a class named `Set`, which shadows dart:core's
/// `Set` in any file that imports it. Import with `hide Set` or a prefix
/// (`import '.../patch.dart' as p;`) when you need both.
sealed class Patch<T> {
  const Patch();

  /// Leave the field out of the request.
  const factory Patch.unset() = Unset<T>;

  /// Send [value].
  const factory Patch.set(T value) = Set<T>;

  /// Send `null`, clearing the field on the server.
  const factory Patch.clear() = Set<T>.clear;

  /// True for [Set] (including clears); false for [Unset].
  bool get isSet => this is Set<T>;

  /// True only for a [Set] holding null.
  bool get isClear => switch (this) {
    Set<T>(:final value) => value == null,
    Unset<T>() => false,
  };
}

final class Unset<T> extends Patch<T> {
  const Unset();

  @override
  bool operator ==(Object other) => other is Unset<T>;
  @override
  int get hashCode => 0;
  @override
  String toString() => 'Patch.unset';
}

/// [value] null means "clear the field".
final class Set<T> extends Patch<T> {
  const Set(this.value);
  const Set.clear() : value = null;
  final T? value;

  @override
  bool operator ==(Object other) => other is Set<T> && other.value == value;
  @override
  int get hashCode => Object.hash(1, value);
  @override
  String toString() => value == null ? 'Patch.clear' : 'Patch.set($value)';
}

/// Writes [patch] into [json] under [key]: nothing for [Unset], `null` for a
/// clear, otherwise the value (run through [encode] when given).
void putPatch<T>(
  Map<String, Object?> json,
  String key,
  Patch<T> patch, [
  Object? Function(T)? encode,
]) {
  switch (patch) {
    case Unset<T>():
      return;
    case Set<T>(:final value):
      json[key] = value == null
          ? null
          : (encode == null ? value : encode(value as T));
  }
}
