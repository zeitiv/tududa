import '../../../core/time/calendar_date.dart';
import '../recurrence/recurrence_rule.dart';

/// Priority recognised by quick add (`!`, `!!`, `!!!`, `!low`, ...).
enum QuickPriority { low, medium, high }

enum TokenKind { date, time, priority, project, area, tag, recurrence }

/// One recognised piece of the input, with offsets into the ORIGINAL string
/// (`input.substring(start, end) == text`).
///
/// [value] by kind: date -> [CalendarDate], time -> [LocalTime],
/// priority -> [QuickPriority], project/area/tag -> `String`,
/// recurrence -> [RecurrenceRule] (the same final rule for every recurrence
/// token of one parse: base phrase, `until ...` clause, completion clause).
class ParsedToken {
  const ParsedToken({
    required this.kind,
    required this.start,
    required this.end,
    required this.text,
    this.value,
  });

  final TokenKind kind;
  final int start;
  final int end;
  final String text;
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is ParsedToken &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.text == text &&
      other.value == value;

  @override
  int get hashCode => Object.hash(kind, start, end, text, value);

  @override
  String toString() => 'ParsedToken($kind, $start..$end, "$text", $value)';
}

class ParseResult {
  const ParseResult({
    required this.title,
    this.dueDate,
    this.dueTime,
    this.priority,
    this.projectName,
    this.areaName,
    this.tags = const [],
    this.recurrence,
    this.tokens = const [],
    this.hint,
    this.dueDateImpliedByRecurrence = false,
  });

  /// The input minus recognised tokens, whitespace collapsed and trimmed.
  final String title;
  final CalendarDate? dueDate;
  final LocalTime? dueTime;
  final QuickPriority? priority;
  final String? projectName;
  final String? areaName;
  final List<String> tags;
  final RecurrenceRule? recurrence;

  /// Sorted by [ParsedToken.start].
  final List<ParsedToken> tokens;

  /// Short English key for a UI message, e.g. `recurrence.yearly_unsupported`.
  final String? hint;

  /// True when [dueDate] was derived from [recurrence] (no explicit date).
  final bool dueDateImpliedByRecurrence;

  @override
  String toString() =>
      'ParseResult(title: "$title", due: $dueDate $dueTime, prio: $priority, '
      'project: $projectName, area: $areaName, tags: $tags, '
      'recurrence: $recurrence, hint: $hint, tokens: $tokens)';
}
