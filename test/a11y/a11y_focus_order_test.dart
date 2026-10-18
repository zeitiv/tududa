import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/screens/login_screen.dart';
import 'package:tududa/auth/screens/server_config_screen.dart';
import 'package:tududa/notes/screens/note_editor_screen.dart';
import 'package:tududa/projects/screens/project_form_screen.dart';
import 'package:tududa/tasks/quick_add/quick_add_sheet.dart';
import 'package:tududa/tasks/screens/task_form_screen.dart';

import 'a11y_support.dart';

/// Keyboard and switch-access users move with Tab: it has to visit the
/// controls of a form top to bottom (left to right within a row, mirrored in
/// right-to-left locales) and every form field must be reachable.
///
/// The window is tall so nothing scrolls while tabbing and the focus rectangles
/// stay comparable.
const _tall = Size(412, 3200);

final _forms = <String, Widget Function(A11ySeed)>{
  'login': (_) => const LoginScreen(),
  'server_config': (_) => const ServerConfigScreen(),
  'task_form_new': (_) => const TaskFormScreen(),
  'task_form_edit': (d) => TaskFormScreen(taskId: d.task.uid.value),
  'project_form_new': (_) => const ProjectFormScreen(),
  'project_form_edit': (d) => ProjectFormScreen(projectId: d.projectId),
  'note_editor_new': (_) => const NoteEditorScreen(),
  'quick_add': (_) => Scaffold(body: QuickAddSheet(onClose: () {})),
};

/// Tabs through the screen once and returns the focus rectangles in order.
Future<List<Rect>> _tabThrough(WidgetTester tester) async {
  final seen = <FocusNode>[];
  final rects = <Rect>[];
  for (var i = 0; i < 60; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 50));
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node.context == null) continue;
    if (seen.contains(node)) break; // wrapped around
    seen.add(node);
    rects.add(node.rect);
  }
  return rects;
}

void main() {
  for (final entry in _forms.entries) {
    for (final locale in a11yLocales) {
      a11yTest('${entry.key} tab order ${locale.languageCode}', (
        tester,
        rig,
        data,
      ) async {
        await pumpA11y(
          tester,
          rig,
          home: entry.value(data),
          locale: locale,
          size: _tall,
        );
        final visited = await _tabThrough(tester);
        expect(visited.length, greaterThan(1), reason: 'nothing to tab to');
        // Tab is a cycle and a screen may autofocus its first field, so start
        // at the topmost control (the app bar's back/save buttons).
        var first = 0;
        for (var i = 1; i < visited.length; i++) {
          final a = visited[i], b = visited[first];
          if (a.center.dy < b.center.dy - 12 ||
              ((a.center.dy - b.center.dy).abs() <= 12 &&
                  a.center.dx < b.center.dx)) {
            first = i;
          }
        }
        final rects = [...visited.skip(first), ...visited.take(first)];

        const rowTolerance = 12.0;
        for (var i = 1; i < rects.length; i++) {
          final a = rects[i - 1], b = rects[i];
          final sameRow = (b.center.dy - a.center.dy).abs() < rowTolerance;
          if (sameRow) {
            // LTR: left to right. (Both locales here are LTR.)
            expect(
              b.center.dx,
              greaterThanOrEqualTo(a.center.dx - 1),
              reason: 'step $i: $a -> $b goes backwards within a row',
            );
          } else {
            expect(
              b.center.dy,
              greaterThan(a.center.dy),
              reason: 'step $i: $a -> $b jumps back up the form',
            );
          }
        }

        // Every text field can be reached by Tab.
        final fieldRects = [
          for (final f in find.byType(EditableText).evaluate())
            (f.renderObject! as RenderBox).localToGlobal(Offset.zero) &
                (f.renderObject! as RenderBox).size,
        ];
        for (final field in fieldRects) {
          expect(
            rects.any((r) => r.overlaps(field)),
            isTrue,
            reason: 'text field at $field is not in the tab order',
          );
        }
      });
    }
  }
}
