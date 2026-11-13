import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/links.dart';
import '../../data/tududi.dart';
import '../../tasks/models/task_model.dart';
import '../kit/controls.dart';
import '../kit/dots.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../window.dart';
import 'karakeep.dart' show NotLinked;
import 'tasks.dart';

/// When a chore is due, as people say it.
(String, bool) choreDue(int? seconds) {
  if (seconds == null) return ('', false);
  final late = seconds < 0;
  final s = seconds.abs();
  final amount = s >= 86400 ? '${(s / 86400).round()} d' : '${(s / 3600).ceil()} h';
  return (late ? tr('{t} late', {'t': amount}) : tr('in {t}', {'t': amount}), late);
}

enum _Tab { chores, shopping, people }

class FlatApp extends ConsumerStatefulWidget {
  const FlatApp({super.key});

  @override
  ConsumerState<FlatApp> createState() => _FlatAppState();
}

class _FlatAppState extends ConsumerState<FlatApp> {
  _Tab _tab = _Tab.chores;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(flatProvider);
    final f = ref.read(flatProvider.notifier);
    final os = ref.read(osProvider.notifier);
    if (s.status == Link.off || (s.status == Link.error && s.chores.isEmpty && s.shopping.isEmpty)) {
      return NotLinked(
        app: AppId.flat,
        error: s.error,
        pitch: 'Whose turn it is and what to buy, from the Flatastic you share at home.',
      );
    }

    final Widget body = switch (_tab) {
      _Tab.chores => s.chores.isEmpty
          ? Empty(tr('No chores'), hint: tr('Chores are set up in Flatastic.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                for (final c in s.sorted)
                  Builder(builder: (context) {
                    final due = choreDue(c.dueIn);
                    final mine = c.userId == s.me;
                    return RowTile(
                      key: ValueKey(c.id),
                      leading: Check(
                        value: false,
                        label: c.title,
                        onTap: () {
                          thud();
                          f.doneChore(c);
                          os.toast(tr('Chore done · +{n} points', {'n': c.points}));
                        },
                      ),
                      trailing: mine
                          ? null
                          : OsIconButton(
                              Icons.add_task_rounded,
                              tooltip: tr('Make it a task'),
                              filled: false,
                              size: 40,
                              color: Tk.ink3,
                              onTap: () {
                                ref.read(tasksProvider.notifier).add(Task(name: c.title));
                                os.toast(tr('Added to Tasks'));
                              },
                            ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: sans(15.5, w: 480)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Label(mine ? tr('Your turn') : s.mate(c.userId),
                                    color: mine ? context.accent : Tk.ink3),
                                if (due.$1.isNotEmpty) ...[
                                  const SizedBox(width: 9),
                                  Label(due.$1, color: due.$2 ? Tk.signal : Tk.ink3),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
      _Tab.shopping => s.shopping.isEmpty
          ? Empty(tr('The list is empty'), hint: tr('Add what the flat needs below.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                for (final i in [...s.toBuy, for (final x in s.shopping) if (x.bought) x])
                  RowTile(
                    key: ValueKey(i.id),
                    leading: Check(value: i.bought, label: i.name, onTap: () => f.toggleItem(i)),
                    trailing: OsIconButton(
                      Icons.close_rounded,
                      tooltip: tr('Delete'),
                      filled: false,
                      size: 40,
                      color: Tk.ink3,
                      onTap: () => f.removeItem(i),
                    ),
                    onTap: () => f.toggleItem(i),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      style: sans(
                        15.5,
                        color: i.bought ? Tk.ink3 : Tk.ink,
                        decoration: i.bought ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      child: Text(i.name),
                    ),
                  ),
              ],
            ),
      _Tab.people => ListView(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
          children: [
            for (final m in [...s.mates]..sort((a, b) => b.points.compareTo(a.points)))
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.id == s.me ? '${m.name} · ${tr('You')}' : m.name,
                              style: sans(16, w: 600)),
                          const SizedBox(height: 9),
                          DotBar(
                            s.mates.isEmpty
                                ? 0
                                : m.points /
                                    s.mates
                                        .map((e) => e.points)
                                        .fold<int>(1, (a, b) => a > b ? a : b),
                            count: 16,
                            dot: 4.2,
                          ),
                        ],
                      ),
                    ),
                    DotText(m.points.toString().padLeft(2, '0'), dot: 3.4, gap: 1.4),
                  ],
                ),
              ),
          ],
        ),
    };

    return AppPane(
      app: AppId.flat,
      sub: s.name.isEmpty ? null : s.name,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: OsSeg<_Tab>(
              value: _tab,
              items: {
                _Tab.chores: tr('Chores'),
                _Tab.shopping: '${tr('Shopping')} · ${s.toBuy.length}',
                _Tab.people: tr('Flatmates'),
              },
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: Motion.reduced ? 1 : 200),
              child: KeyedSubtree(key: ValueKey(_tab), child: body),
            ),
          ),
        ],
      ),
      bottom: _tab == _Tab.shopping
          ? QuickAdd(hint: tr('Add to the shopping list'), onAdd: f.addItem)
          : null,
    );
  }
}
