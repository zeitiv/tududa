import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/server_config_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../tasks/screens/tasks_screen.dart';
import '../../tasks/screens/today_screen.dart';
import '../../tasks/screens/focus_screen.dart';
import '../../tasks/screens/daily_review_screen.dart';
import '../../tasks/screens/task_list_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../tasks/screens/task_form_screen.dart';
import '../../tasks/quick_add/quick_add_support.dart' show QuickAddDraft;
import '../../projects/screens/projects_screen.dart';
import '../../projects/screens/project_detail_screen.dart';
import '../../projects/screens/project_form_screen.dart';
import '../../notes/screens/notes_screen.dart';
import '../../notes/screens/note_editor_screen.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../areas/screens/areas_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/screens/sync_screen.dart';
import '../../common/widgets/shell_scaffold.dart';
import '../../search/screens/search_screen.dart';
import 'auth_redirect.dart';
import 'deep_link.dart';
import 'router_refresh.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh();
  // Listen (not watch) so auth changes re-run redirect without rebuilding
  // the router and its navigator keys.
  ref.listen(authProvider, (_, _) => refresh.refresh());

  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/today',
    refreshListenable: refresh,
    redirect: (context, state) {
      final deepLink = deepLinkLocation(state.uri);
      if (deepLink != null) return deepLink;
      final authState = ref.read(authProvider);
      final serverUrl = authState.serverUrl;
      return authRedirect(
        status: authState.status,
        hasServer: serverUrl != null && serverUrl.isNotEmpty,
        location: state.uri,
      );
    },
    routes: [
      // Auth routes (full screen, no shell)
      GoRoute(
        path: '/server-config',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ServerConfigScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            SearchScreen(initialQuery: state.uri.queryParameters['q']),
      ),

      // Main app with shell (bottom navigation / rail), one stack per tab.
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'focus',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const FocusScreen(),
                  ),
                  GoRoute(
                    path: 'review',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const DailyReviewScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const InboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/upcoming',
                builder: (context, state) =>
                    const TaskListScreen(view: TaskListView.upcoming),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ProjectFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return ProjectDetailScreen(projectId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return ProjectFormScreen(projectId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'areas',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const AreasScreen(),
                  ),
                  GoRoute(
                    path: 'sync',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const SyncScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/overdue',
                builder: (context, state) =>
                    const TaskListScreen(view: TaskListView.overdue),
              ),
              GoRoute(
                path: '/someday',
                builder: (context, state) =>
                    const TaskListScreen(view: TaskListView.someday),
              ),
              GoRoute(
                path: '/completed',
                builder: (context, state) =>
                    const TaskListScreen(view: TaskListView.completed),
              ),
              GoRoute(
                path: '/notes',
                builder: (context, state) => const NotesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const NoteEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return NoteEditorScreen(noteId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final projectId = state.uri.queryParameters['projectId'];
                      // Project ids are uid strings; never parse them as ints.
                      final extra = state.extra;
                      return TaskFormScreen(
                        defaultProjectId: projectId,
                        draft: extra is QuickAddDraft ? extra : null,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return TaskDetailScreen(taskId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final id = state.pathParameters['id']!;
                          return TaskFormScreen(taskId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
