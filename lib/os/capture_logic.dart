import '../data/links.dart' show looksLikeUrl;

/// Where a captured line can go.
enum Target { task, inbox, memo, bookmark, shopping }

const _buy = ['buy ', 'kaufen ', 'einkaufen ', 'shop ', '买'];

/// Guesses where a line belongs from what it looks like: a link is a
/// bookmark, "buy milk" is for the shopping list, a paragraph is a memo,
/// anything else a task. Only destinations that are connected count.
Target suggest(String text, Set<Target> on) {
  final t = text.trim();
  final lower = t.toLowerCase();
  if (on.contains(Target.bookmark) && looksLikeUrl(t)) return Target.bookmark;
  if (on.contains(Target.shopping) && _buy.any(lower.startsWith)) return Target.shopping;
  if (on.contains(Target.memo) && (t.contains('\n') || t.length > 120)) return Target.memo;
  return on.contains(Target.task) ? Target.task : on.first;
}

/// The item itself, without the word that sent it to the shopping list.
String shoppingName(String text) {
  final t = text.trim();
  final lower = t.toLowerCase();
  for (final p in _buy) {
    if (lower.startsWith(p)) return t.substring(p.length).trim();
  }
  return t;
}
