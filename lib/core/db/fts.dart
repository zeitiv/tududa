/// Turns free text typed by the user into a safe FTS5 `MATCH` expression:
/// every word is quoted (so operators like `-` or `:` are literal) and made a
/// prefix match, and words are AND-ed. Returns an empty string for blank
/// input; callers should skip the query then.
///
/// `ftsQuery('buy mi')` -> `"buy"* "mi"*`
String ftsQuery(String input) {
  final words = input
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll('"', '""').trim())
      .where((w) => w.isNotEmpty);
  return words.map((w) => '"$w"*').join(' ');
}
