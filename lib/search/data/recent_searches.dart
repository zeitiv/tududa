import 'package:shared_preferences/shared_preferences.dart';

/// The last [limit] committed searches, newest first, stored in
/// SharedPreferences. Case-insensitive de-duplication moves a repeated query
/// to the front.
class RecentSearches {
  RecentSearches(this._prefs);
  final SharedPreferences _prefs;

  static const limit = 10;
  static const prefsKey = 'search.recent';

  List<String> load() => _prefs.getStringList(prefsKey) ?? const [];

  Future<List<String>> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return load();
    final next = [
      q,
      for (final r in load())
        if (r.toLowerCase() != q.toLowerCase()) r,
    ].take(limit).toList();
    await _prefs.setStringList(prefsKey, next);
    return next;
  }

  Future<List<String>> remove(String query) async {
    final next = [
      for (final r in load())
        if (r != query) r,
    ];
    await _prefs.setStringList(prefsKey, next);
    return next;
  }

  Future<void> clear() => _prefs.remove(prefsKey);
}
