import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/ids.dart';

part 'inbox_item.freezed.dart';

/// Server status of an inbox item. `deleted`/`trashed` rows are never listed;
/// anything unrecognised maps to [unknown].
enum InboxStatus {
  added,
  processed,
  ignored,
  unknown;

  static InboxStatus parse(String? raw) => switch (raw) {
    null || 'added' => InboxStatus.added,
    'processed' => InboxStatus.processed,
    'ignored' => InboxStatus.ignored,
    _ => InboxStatus.unknown,
  };

  String get wire => switch (this) {
    InboxStatus.added => 'added',
    InboxStatus.processed => 'processed',
    InboxStatus.ignored => 'ignored',
    InboxStatus.unknown => 'added',
  };
}

@freezed
abstract class InboxItem with _$InboxItem {
  const InboxItem._();

  const factory InboxItem({
    required InboxUid uid,
    required String content,
    @Default(InboxStatus.added) InboxStatus status,
    @Default('manual') String source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _InboxItem;

  bool get isProcessed => status == InboxStatus.processed;
  bool get isIgnored => status == InboxStatus.ignored;
}

/// The one thing an inbox item became. Sent to `PATCH /inbox/:uid/process`
/// as `{task_uid|project_uid|note_uid}` so attachments move along.
sealed class InboxProcessTarget {
  const InboxProcessTarget();
  String get key;
  String get uid;
}

final class ProcessedAsTask extends InboxProcessTarget {
  const ProcessedAsTask(this.uid);
  @override
  final String uid;
  @override
  String get key => 'task_uid';
}

final class ProcessedAsProject extends InboxProcessTarget {
  const ProcessedAsProject(this.uid);
  @override
  final String uid;
  @override
  String get key => 'project_uid';
}

final class ProcessedAsNote extends InboxProcessTarget {
  const ProcessedAsNote(this.uid);
  @override
  final String uid;
  @override
  String get key => 'note_uid';
}

/// Result of `POST /inbox/analyze-text`. Only the fields the app uses are
/// typed; [raw] keeps the whole response.
class InboxAnalysis {
  const InboxAnalysis({
    required this.cleanedContent,
    required this.tags,
    required this.projects,
    this.dueDate,
    this.dueTime,
    this.suggestedType,
    this.raw = const {},
  });

  final String cleanedContent;
  final List<String> tags;
  final List<String> projects;

  /// `YYYY-MM-DD` as parsed by the server, if the text named a date.
  final String? dueDate;
  final String? dueTime;

  /// `task`, `note`, ... or null when the server has no suggestion.
  final String? suggestedType;
  final Map<String, dynamic> raw;

  factory InboxAnalysis.fromJson(Map<String, dynamic> json) {
    List<String> names(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is String)
            e
          else if (e is Map && e['name'] is String)
            e['name'] as String,
    ];
    return InboxAnalysis(
      cleanedContent: json['cleaned_content'] as String? ?? '',
      tags: names(json['parsed_tags']),
      projects: names(json['parsed_projects']),
      dueDate: json['parsed_due_date'] as String?,
      dueTime: json['parsed_due_time'] as String?,
      suggestedType: json['suggested_type'] as String?,
      raw: json,
    );
  }
}
