import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/data/links.dart';
import 'package:tududa/data/tududi.dart';
import 'package:tududa/os/capture_logic.dart';
import 'package:tududa/os/kit/dots.dart';
import 'package:tududa/os/kit/motion.dart';
import 'package:tududa/os/l10n.dart';
import 'package:tududa/os/os.dart';
import 'package:tududa/tasks/models/task_model.dart';

void main() {
  group('capture', () {
    const all = {Target.task, Target.inbox, Target.memo, Target.bookmark, Target.shopping};

    test('a link is a bookmark', () {
      expect(suggest('https://flutter.dev/docs', all), Target.bookmark);
      expect(suggest('karakeep.app', all), Target.bookmark);
      expect(suggest('mail me@example.com', all), Target.task);
    });

    test('"buy …" goes on the shopping list, in three languages', () {
      expect(suggest('buy oat milk', all), Target.shopping);
      expect(suggest('Kaufen Brot', all), Target.shopping);
      expect(shoppingName('buy oat milk'), 'oat milk');
      expect(shoppingName('Oat milk'), 'Oat milk');
    });

    test('a paragraph is a memo, a line is a task', () {
      expect(suggest('first line\nsecond line', all), Target.memo);
      expect(suggest('Call the dentist', all), Target.task);
    });

    test('only connected destinations are suggested', () {
      const core = {Target.task, Target.inbox};
      expect(suggest('https://flutter.dev', core), Target.task);
      expect(suggest('buy milk', core), Target.task);
    });
  });

  group('springs', () {
    test('settle on the target and stop', () {
      Motion.reduced = false;
      final s = Springs([0], spec: Spec.bouncy)..target[0] = 100;
      var steps = 0;
      var peak = 0.0;
      while (s.step(1 / 60) && steps < 600) {
        steps++;
        if (s.x[0] > peak) peak = s.x[0];
      }
      expect(s.x[0], 100);
      expect(s.atRest, isTrue);
      expect(peak, greaterThan(100), reason: 'a bouncy spring overshoots');
      expect(steps, lessThan(120), reason: 'and is done within two seconds');
    });

    test('reduced motion jumps', () {
      Motion.reduced = true;
      final s = Springs([0])..target[0] = 5;
      expect(s.step(1 / 60), isFalse);
      expect(s.x[0], 5);
      Motion.reduced = false;
    });
  });

  group('dot matrix', () {
    test('has a glyph for everything a readout shows', () {
      for (final ch in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:.-/%+ '.split('')) {
        expect(hasGlyph(ch), isTrue, reason: ch);
      }
    });

    test('lays glyphs out six columns apart', () {
      expect(dotsOf('1').length, 5 * 7);
      expect(dotsOf('12:30').length, (5 * 6 - 1) * 7);
      expect(dotsOf('8').where((d) => d).length, 17);
    });
  });

  group('windows', () {
    test('keep to what the screen fits, oldest out first', () {
      final os = OsNotifier()..max = 2;
      os.open(AppId.tasks);
      os.open(AppId.notes);
      os.open(AppId.memos);
      expect(os.state.open.map((w) => w.app), [AppId.notes, AppId.memos]);
      expect(os.state.wins.first.closing, isTrue);
      os.gone(AppId.tasks);
      expect(os.state.wins.length, 2);
      expect(os.closeTop(), isTrue);
      expect(os.state.open.single.app, AppId.notes);
    });
  });

  group('tasks', () {
    test('today is what is due, overdue or in progress', () {
      final now = DateTime.now();
      final s = TasksState(open: [
        Task(uid: 'a', name: 'due', dueDate: now),
        Task(uid: 'b', name: 'late', dueDate: now.subtract(const Duration(days: 3))),
        Task(uid: 'c', name: 'doing', status: 1),
        Task(uid: 'd', name: 'later', dueDate: now.add(const Duration(days: 3))),
        const Task(uid: 'e', name: 'someday'),
      ]);
      expect(s.todayTasks.map((t) => t.name), ['due', 'late', 'doing']);
      expect(s.upcoming.single.name, 'later');
    });

    test('a date and a project can be cleared', () {
      final t = Task(uid: 'a', name: 'x', dueDate: DateTime(2026), projectId: 3);
      final cleared = t.copyWith(clearDue: true, clearProject: true);
      expect(cleared.dueDate, isNull);
      expect(cleared.projectId, isNull);
    });
  });

  group('links', () {
    test('Karakeep bookmarks', () {
      final b = Bookmark.fromJson({
        'id': 'abc',
        'title': null,
        'favourited': true,
        'archived': false,
        'createdAt': '2026-11-01T10:00:00.000Z',
        'tags': [
          {'id': 't1', 'name': 'design'},
        ],
        'content': {
          'type': 'link',
          'url': 'https://www.example.com/post',
          'title': 'A post',
          'imageAssetId': 'img1',
        },
      }, base: 'https://keep.example');
      expect(b.title, 'A post');
      expect(b.host, 'example.com');
      expect(b.image, 'https://keep.example/api/assets/img1');
      expect(b.tags, ['design']);
      expect(b.fav, isTrue);

      final note = Bookmark.fromJson({
        'id': 'n',
        'content': {'type': 'text', 'text': 'remember this\nand that'},
      });
      expect(note.title, 'remember this');
      expect(note.url, isNull);
    });

    test('Memos', () {
      final m = Memo.fromJson({
        'name': 'memos/42',
        'content': 'hello **there**',
        'pinned': true,
        'displayTime': '2026-11-02T08:00:00Z',
        'tags': ['idea'],
      });
      expect(m.name, 'memos/42');
      expect(m.pinned, isTrue);
      expect(m.time, isNotNull);
    });

    test('Flatastic chores and shopping, as numbers or strings', () {
      final c = Chore.fromJson({'id': '7', 'title': 'Bins', 'currentUser': 3, 'timeLeftNext': -120, 'points': '2'});
      expect(c.id, 7);
      expect(c.late, isTrue);
      expect(c.points, 2);
      expect(ShopItem.fromJson({'id': 1, 'itemName': 'Milk', 'bought': 1}).bought, isTrue);
      expect(ShopItem.fromJson({'id': 2, 'itemName': 'Soap', 'bought': 0}).bought, isFalse);
    });

    test('addresses are tidied', () {
      expect(cleanUrl(' keep.example.com/ '), 'https://keep.example.com');
      expect(cleanUrl('http://10.0.0.2:3000'), 'http://10.0.0.2:3000');
    });
  });

  test('strings fill their values in every language', () {
    for (final code in L.names.keys) {
      L.code = code;
      expect(tr('{n} open', {'n': 3}), contains('3'));
      expect(tr('Tasks'), isNotEmpty);
    }
    L.code = 'de';
    expect(tr('Tasks'), 'Aufgaben');
    expect(tr('Something never translated'), 'Something never translated');
    L.code = 'en';
  });
}
