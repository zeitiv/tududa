import '../../../core/time/calendar_date.dart';

/// Recurrence kinds supported by the Tududi backend (there is no yearly type).
enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  monthlyWeekday,
  monthlyLastDay;

  /// The backend's `recurrence_type` string.
  String get backendValue => switch (this) {
    RecurrenceType.none => 'none',
    RecurrenceType.daily => 'daily',
    RecurrenceType.weekly => 'weekly',
    RecurrenceType.monthly => 'monthly',
    RecurrenceType.monthlyWeekday => 'monthly_weekday',
    RecurrenceType.monthlyLastDay => 'monthly_last_day',
  };

  static RecurrenceType fromBackend(String? value) {
    for (final t in RecurrenceType.values) {
      if (t.backendValue == value) return t;
    }
    return RecurrenceType.none;
  }
}

/// An immutable recurrence rule mirroring the Tududi task fields.
class RecurrenceRule {
  RecurrenceRule({
    this.type = RecurrenceType.none,
    this.interval = 1,
    Set<int> weekdays = const {},
    this.monthDay,
    this.weekOfMonth,
    this.weekday,
    this.endDate,
    this.completionBased = false,
  }) : weekdays = Set.unmodifiable(weekdays),
       assert(interval >= 1, 'interval must be >= 1'),
       assert(monthDay == null || (monthDay >= 1 && monthDay <= 31)),
       assert(weekOfMonth == null || (weekOfMonth >= 1 && weekOfMonth <= 5)),
       assert(weekday == null || (weekday >= 1 && weekday <= 7));

  /// The "does not repeat" rule.
  factory RecurrenceRule.none() => RecurrenceRule();

  final RecurrenceType type;

  /// Repeat every N days / weeks / months (>= 1).
  final int interval;

  /// ISO weekdays 1..7 (Monday = 1); used by [RecurrenceType.weekly].
  /// Empty means "the weekday of the anchor date".
  final Set<int> weekdays;

  /// Day of month 1..31 for [RecurrenceType.monthly] (clamped to month length).
  /// Null means "the day of the anchor date".
  final int? monthDay;

  /// 1..5 (5 = last) for [RecurrenceType.monthlyWeekday].
  final int? weekOfMonth;

  /// ISO weekday for [RecurrenceType.monthlyWeekday].
  final int? weekday;

  /// Last day (inclusive) on which an occurrence may fall.
  final CalendarDate? endDate;

  /// Next occurrence is computed from the completion date, not the schedule.
  final bool completionBased;

  bool get isRecurring => type != RecurrenceType.none;

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    Set<int>? weekdays,
    int? monthDay,
    int? weekOfMonth,
    int? weekday,
    CalendarDate? endDate,
    bool clearEndDate = false,
    bool? completionBased,
  }) => RecurrenceRule(
    type: type ?? this.type,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    monthDay: monthDay ?? this.monthDay,
    weekOfMonth: weekOfMonth ?? this.weekOfMonth,
    weekday: weekday ?? this.weekday,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    completionBased: completionBased ?? this.completionBased,
  );

  /// Fields to send to the Tududi API. Inapplicable fields are null.
  Map<String, Object?> toBackendFields() {
    final sorted = weekdays.toList()..sort();
    return {
      'recurrence_type': type.backendValue,
      'recurrence_interval': interval,
      'recurrence_weekday': type == RecurrenceType.monthlyWeekday
          ? weekday
          : null,
      'recurrence_weekdays': type == RecurrenceType.weekly && sorted.isNotEmpty
          ? sorted
          : null,
      'recurrence_month_day': type == RecurrenceType.monthly ? monthDay : null,
      'recurrence_week_of_month': type == RecurrenceType.monthlyWeekday
          ? weekOfMonth
          : null,
      'recurrence_end_date': endDate?.toIso(),
      'completion_based': completionBased,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule &&
      other.type == type &&
      other.interval == interval &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays) &&
      other.monthDay == monthDay &&
      other.weekOfMonth == weekOfMonth &&
      other.weekday == weekday &&
      other.endDate == endDate &&
      other.completionBased == completionBased;

  @override
  int get hashCode => Object.hash(
    type,
    interval,
    Object.hashAllUnordered(weekdays),
    monthDay,
    weekOfMonth,
    weekday,
    endDate,
    completionBased,
  );

  @override
  String toString() =>
      'RecurrenceRule(${type.backendValue}, every $interval'
      '${weekdays.isEmpty ? '' : ', weekdays ${(weekdays.toList()..sort())}'}'
      '${monthDay == null ? '' : ', day $monthDay'}'
      '${weekOfMonth == null ? '' : ', week $weekOfMonth'}'
      '${weekday == null ? '' : ', weekday $weekday'}'
      '${endDate == null ? '' : ', until $endDate'}'
      '${completionBased ? ', completion-based' : ''})';
}
