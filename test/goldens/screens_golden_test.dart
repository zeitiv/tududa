@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/common/widgets/async_states.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';
import 'package:tududa/inbox/widgets/inbox_item_card.dart';
import 'package:tududa/projects/data/project_tasks_source.dart';
import 'package:tududa/projects/widgets/kanban_board.dart';
import 'package:tududa/tasks/domain/task.dart';
import 'package:tududa/tasks/providers/today_provider.dart';
import 'package:tududa/tasks/quick_add/quick_add_sheet.dart';
import 'package:tududa/tasks/quick_add/quick_add_support.dart';
import 'package:tududa/tasks/widgets/today_header.dart';

import 'golden_harness.dart';

bool _de(Locale l) => l.languageCode == 'de';

Task _t(String uid, {bool done = false}) => Task(
  uid: TaskUid(uid),
  name: uid,
  status: done ? TaskStatus.done : TaskStatus.notStarted,
  estimatedMinutes: done ? null : 45,
);

void main() {
  setUpGoldens();

  goldenCase(
    'today_header',
    build: (_) => Padding(
      padding: const EdgeInsets.all(12),
      child: TodayHeader(
        date: goldenToday,
        sections: TodaySections(
          overdue: [_t('o1')],
          morning: [_t('m1'), _t('m2')],
          completed: [_t('c1', done: true), _t('c2', done: true)],
        ),
      ),
    ),
  );

  goldenCase(
    'async_loading',
    build: (_) => const SkeletonList(rows: 3),
    height: 260,
  );
  goldenCase(
    'async_empty',
    build: (l) => EmptyState(
      icon: Icons.inbox_outlined,
      title: _de(l) ? 'Alles erledigt, nichts mehr offen' : 'All clear',
      hint: _de(l)
          ? 'Fügen Sie Aufgaben über die Schnelleingabe hinzu.'
          : 'Add tasks with quick add.',
    ),
    height: 260,
  );
  goldenCase(
    'async_offline',
    build: (_) => OfflineState(onRetry: () {}),
    height: 420,
  );
  goldenCase(
    'async_error',
    build: (_) => ErrorState(error: Exception('boom'), onRetry: () {}),
    height: 420,
  );

  goldenCase(
    'quick_add_chips',
    build: (l) => QuickAddSheet(
      initialText: _de(l)
          ? 'Anna anrufen morgen 17 Uhr !!! #zuhause'
          : 'Call Anna tomorrow 5pm !!! #home',
      onClose: () {},
    ),
    overrides: (_) => [
      quickAddLookupsProvider.overrideWithValue(const QuickAddLookups()),
    ],
    height: 560,
  );

  goldenCase(
    'inbox_item_card',
    build: (l) => InboxItemCard(
      item: InboxItem(
        uid: InboxUid('i1'),
        content: _de(l)
            ? 'Geschenkidee für Omas Geburtstag nächste Woche überlegen und Blumen bestellen'
            : 'Think about a gift for grandma birthday next week and order flowers',
        createdAt: DateTime.utc(2026, 10, 14, 6),
      ),
      now: DateTime.utc(2026, 10, 14, 9),
      onConvertToTask: () {},
      onConvertToNote: () {},
      onAction: (_) {},
    ),
  );

  goldenCase(
    'kanban_column',
    build: (l) => KanbanBoard(
      tasks: [
        ProjectTaskRef(
          uid: TaskUid('k1'),
          name: _de(l) ? 'Wireframes entwerfen' : 'Sketch wireframes',
        ),
        ProjectTaskRef(
          uid: TaskUid('k2'),
          name: _de(l) ? 'Backend anbinden' : 'Wire up backend',
          status: 1,
          priority: 2,
        ),
        ProjectTaskRef(
          uid: TaskUid('k3'),
          name: _de(l) ? 'Release vorbereiten' : 'Prepare release',
          status: 2,
        ),
      ],
      onTaskStatusChanged: (_, _) {},
    ),
    height: 360,
  );
}
