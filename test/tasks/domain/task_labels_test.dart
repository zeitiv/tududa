import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/domain/task_labels.dart';

void main() {
  test('labels exist and are localized for every value', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    final zh = await AppLocalizations.delegate.load(const Locale('zh'));
    for (final s in TaskStatus.values) {
      for (final l in [en, de, zh]) {
        expect(taskStatusLabel(l, s), isNotEmpty);
      }
    }
    for (final p in Priority.values) {
      for (final l in [en, de, zh]) {
        expect(taskPriorityLabel(l, p), isNotEmpty);
      }
    }
    expect(taskStatusLabel(en, TaskStatus.inProgress), 'In progress');
    expect(taskStatusLabel(zh, TaskStatus.waiting), '等待中');
    expect(taskPriorityLabel(de, Priority.high), 'Hoch');
  });
}
