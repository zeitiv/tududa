import '../../core/time/calendar_date.dart';
import 'search_query.dart';
import 'search_result.dart';

const _closed = {'done', 'archived', 'cancelled'};

/// Applies the task-only syntax (`is:`, `priority:`, `due:`) to [hits]. Used
/// on server results and on local candidates alike, so both agree. Any such
/// filter drops every non-task hit. Unknown values on a hit (no priority sent
/// by the server) are kept.
List<SearchResult> applyTaskFilters(
  List<SearchResult> hits,
  ParsedSearch p,
  CalendarDate today,
) {
  if (!p.hasTaskFilters) return hits;
  return [
    for (final h in hits)
      if (h is TaskHit && _taskMatches(h, p, today)) h,
  ];
}

bool _taskMatches(TaskHit t, ParsedSearch p, CalendarDate today) {
  final due = t.dueDate;
  final open = !_closed.contains(t.status);
  for (final f in p.flags) {
    final ok = switch (f) {
      SearchIs.overdue => open && due != null && due.isBefore(today),
      SearchIs.today => due != null && due == today,
      SearchIs.done => t.status == 'done',
    };
    if (!ok) return false;
  }
  if (p.priority != null && t.priority != null && t.priority != p.priority) {
    return false;
  }
  switch (p.due) {
    case null:
      break;
    case SearchDue.today:
      if (due != today) return false;
    case SearchDue.tomorrow:
      if (due != today.addDays(1)) return false;
    case SearchDue.week:
      if (due == null || due.isBefore(today) || due.isAfter(today.addDays(7))) {
        return false;
      }
    case SearchDue.date:
      if (due != p.dueDate) return false;
  }
  return true;
}

/// Orders hits by type, then relevance: name prefix, name contains, then
/// description only. Stable for equal ranks.
List<SearchResult> rankResults(List<SearchResult> hits, String text) {
  final q = text.trim().toLowerCase();
  int rank(SearchResult h) {
    if (q.isEmpty) return 0;
    final n = h.name.toLowerCase();
    if (n.startsWith(q)) return 0;
    if (n.contains(q)) return 1;
    return 2;
  }

  final indexed = [for (var i = 0; i < hits.length; i++) (i, hits[i])];
  indexed.sort((a, b) {
    final t = a.$2.type.index.compareTo(b.$2.type.index);
    if (t != 0) return t;
    final r = rank(a.$2).compareTo(rank(b.$2));
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
