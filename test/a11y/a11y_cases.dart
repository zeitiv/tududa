import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/areas/screens/areas_screen.dart';
import 'package:tududa/auth/domain/user.dart';
import 'package:tududa/auth/providers/auth_provider.dart';
import 'package:tududa/auth/screens/login_screen.dart';
import 'package:tududa/auth/screens/server_config_screen.dart';
import 'package:tududa/core/ids.dart';
import 'package:tududa/inbox/domain/inbox_item.dart';
import 'package:tududa/inbox/providers/inbox_provider.dart';
import 'package:tududa/inbox/screens/inbox_screen.dart';
import 'package:tududa/notes/screens/note_editor_screen.dart';
import 'package:tududa/notes/screens/notes_screen.dart';
import 'package:tududa/projects/screens/project_detail_screen.dart';
import 'package:tududa/projects/screens/project_form_screen.dart';
import 'package:tududa/projects/screens/projects_screen.dart';
import 'package:tududa/search/command_palette/command_palette.dart';
import 'package:tududa/search/domain/search_result.dart';
import 'package:tududa/search/providers/search_provider.dart';
import 'package:tududa/search/screens/search_screen.dart';
import 'package:tududa/settings/screens/settings_screen.dart';
import 'package:tududa/settings/screens/sync_screen.dart';
import 'package:tududa/tasks/quick_add/quick_add_sheet.dart';
import 'package:tududa/tasks/screens/daily_review_screen.dart';
import 'package:tududa/tasks/screens/focus_screen.dart';
import 'package:tududa/tasks/screens/task_detail_screen.dart';
import 'package:tududa/tasks/screens/task_form_screen.dart';
import 'package:tududa/tasks/screens/task_list_screen.dart';
import 'package:tududa/tasks/screens/tasks_screen.dart';
import 'package:tududa/tasks/screens/today_screen.dart';
import 'package:tududa/tasks/widgets/postpone_sheet.dart';
import 'package:tududa/tasks/widgets/selection_controller.dart';

import 'a11y_support.dart';

/// In-memory inbox: the inbox is API-backed, so it has no offline rig.
class A11yInbox extends InboxNotifier {
  @override
  Future<InboxList> build() async => InboxList(
    items: [
      InboxItem(
        uid: const InboxUid('i1'),
        content: 'Call the plumber about the leaking tap',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      InboxItem(
        uid: const InboxUid('i2'),
        content: 'Idea: weekly review template',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ],
  );

  @override
  Future<void> loadMore() async {}
}

class _A11ySearch extends SearchNotifier {
  @override
  SearchState build() => const SearchState(
    text: 'milk',
    phase: SearchPhase.data,
    results: [
      TaskHit(uid: TaskUid('t1'), name: 'Buy milk', projectName: 'Home'),
      ProjectHit(uid: ProjectUid('p1'), name: 'Milk run'),
      AreaHit(uid: AreaUid('a1'), name: 'Kitchen'),
      NoteHit(uid: NoteUid('n1'), name: 'Groceries', description: 'milk'),
      TagHit(uid: TagUid('g1'), name: 'milky'),
    ],
  );
}

const _server = 'https://tududi.example.com';

Override _signedOut() => authProvider.overrideWith(
  (ref) => AuthNotifier()
    ..state = const AuthState(
      status: AuthStatus.unauthenticated,
      serverUrl: _server,
    ),
);

Override _signedIn() => authProvider.overrideWith(
  (ref) => AuthNotifier()
    ..state = const AuthState(
      status: AuthStatus.authenticated,
      serverUrl: _server,
      user: User(uid: 'u1', email: 'ada@example.com', name: 'Ada'),
    ),
);

Future<void> _tapKey(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
}

/// Every screen reachable in the app, plus the sheets, the palette and the
/// bulk bar. Sign-in screens run against the default (signed-out) session.
final a11yCases = <A11yCase>[
  A11yCase('login', (_) => const LoginScreen(), shows: 'Sign In'),
  A11yCase(
    'login_with_server',
    (_) => const LoginScreen(),
    overrides: (_) => [_signedOut()],
    shows: 'tududi.example.com',
  ),
  A11yCase(
    'server_config',
    (_) => const ServerConfigScreen(),
    shows: 'Connect',
  ),
  A11yCase('today', (_) => const TodayScreen(), shows: 'Pay rent'),
  A11yCase('focus', (_) => const FocusScreen(), shows: 'File taxes'),
  A11yCase(
    'daily_review',
    (_) => const DailyReviewScreen(),
    shows: 'File taxes',
  ),
  A11yCase(
    'upcoming',
    (_) => const TaskListScreen(view: TaskListView.upcoming),
    shows: 'Dentist',
  ),
  A11yCase(
    'overdue',
    (_) => const TaskListScreen(view: TaskListView.overdue),
    shows: 'File taxes',
  ),
  A11yCase(
    'someday',
    (_) => const TaskListScreen(view: TaskListView.someday),
    shows: 'Learn guitar',
  ),
  A11yCase(
    'completed',
    (_) => const TaskListScreen(view: TaskListView.completed),
    shows: 'Water plants',
  ),
  A11yCase('all_tasks', (_) => const TasksScreen(), shows: 'Pay rent'),
  A11yCase(
    'all_tasks_kanban',
    (_) => const TasksScreen(),
    open: (tester, _) =>
        _tapKey(tester, find.byIcon(Icons.view_kanban_rounded)),
    shows: 'Pay rent',
  ),
  A11yCase(
    'inbox',
    (_) => const InboxScreen(),
    overrides: (_) => [inboxProvider.overrideWith(A11yInbox.new)],
    shows: 'weekly review',
  ),
  A11yCase(
    'projects',
    (_) => const ProjectsScreen(),
    shows: 'Website relaunch',
  ),
  A11yCase(
    'project_detail',
    (d) => ProjectDetailScreen(projectId: d.projectId),
    shows: 'Website relaunch',
  ),
  A11yCase(
    'project_form_new',
    (_) => const ProjectFormScreen(),
    shows: 'Project Name',
  ),
  A11yCase(
    'project_form_edit',
    (d) => ProjectFormScreen(projectId: d.projectId),
    shows: 'Project Name',
  ),
  A11yCase('notes', (_) => const NotesScreen(), shows: 'Groceries'),
  A11yCase(
    'note_editor_new',
    (_) => const NoteEditorScreen(),
    shows: 'Note Title',
  ),
  A11yCase(
    'note_editor_edit',
    (d) => NoteEditorScreen(noteId: d.noteId),
    shows: 'Note Title',
  ),
  A11yCase('areas', (_) => const AreasScreen(), shows: 'Home'),
  A11yCase('settings', (_) => const SettingsScreen(), shows: 'Sync'),
  A11yCase(
    'settings_signed_in',
    (_) => const SettingsScreen(),
    overrides: (_) => [_signedIn()],
    shows: 'Sync',
  ),
  A11yCase('sync', (_) => const SyncScreen(), shows: 'Queued changes'),
  A11yCase(
    'search',
    (_) => const SearchScreen(),
    overrides: (_) => [searchControllerProvider.overrideWith(_A11ySearch.new)],
    shows: 'Buy milk',
  ),
  A11yCase(
    'task_detail',
    (d) => TaskDetailScreen(taskId: d.task.uid.value),
    shows: 'Pay rent',
  ),
  A11yCase('task_form_new', (_) => const TaskFormScreen(), shows: 'Task Name'),
  A11yCase(
    'task_form_edit',
    (d) => TaskFormScreen(taskId: d.task.uid.value),
    shows: 'Task Name',
  ),
  A11yCase(
    'quick_add',
    (_) => A11yLauncher(onOpen: (context, _) => showQuickAddSheet(context)),
    open: (tester, _) => tapLauncher(tester),
    shows: 'Quick add',
  ),
  A11yCase(
    'command_palette',
    (_) => A11yLauncher(onOpen: (context, _) => showCommandPalette(context)),
    open: (tester, _) => tapLauncher(tester),
    shows: 'Type a command',
  ),
  A11yCase(
    'postpone_sheet',
    (d) => A11yLauncher(
      onOpen: (context, ref) => showPostponeSheet(context, ref, [d.task]),
    ),
    open: (tester, _) => tapLauncher(tester),
    shows: 'Postpone',
  ),
  A11yCase(
    'bulk_bar',
    (_) => const TaskListScreen(view: TaskListView.upcoming),
    open: (tester, d) async {
      final element = tester.element(find.byType(TaskListScreen));
      ProviderScope.containerOf(element)
          .read(taskSelectionProvider.notifier)
          .start(d.task);
      await tester.pump();
    },
    shows: '1',
  ),
];

/// For tests that build the inbox provider override themselves.
A11yInbox testInbox() => A11yInbox();
