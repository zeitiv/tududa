import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/tududi.dart';
import '../../tasks/models/task_model.dart';
import '../kit/controls.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../window.dart';
import 'task_sheet.dart';

const taskStatuses = <int, String>{
  0: 'Not started',
  6: 'Planned',
  1: 'In progress',
  4: 'Waiting',
  2: 'Done',
};

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// A due date as people say it, and whether it has passed.
(String, bool) dueLabel(DateTime due) {
  final diff = dayOf(due.toLocal()).difference(dayOf(DateTime.now())).inDays;
  if (diff < 0) return (tr('{n} d late', {'n': -diff}), true);
  if (diff == 0) return (tr('Today'), false);
  if (diff == 1) return (tr('Tomorrow'), false);
  if (diff < 7) return (DateFormat('EEEE', L.code).format(due.toLocal()), false);
  return (DateFormat('d MMM', L.code).format(due.toLocal()), false);
}

/// A task in a list. Checking it is the moment that should feel good: the
/// ring fills and draws its tick, the line is struck, then the row folds
/// away, and a toast offers to undo it.
class TaskRow extends ConsumerStatefulWidget {
  final Task task;
  final bool compact;
  const TaskRow({super.key, required this.task, this.compact = false});

  @override
  ConsumerState<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<TaskRow> {
  bool? _checked;
  bool _open = true;

  void _toggle() {
    if (_checked != null) return;
    final task = widget.task;
    final done = !task.isCompleted;
    final tasks = ref.read(tasksProvider.notifier);
    final os = ref.read(osProvider.notifier);
    thud();
    setState(() => _checked = done);
    final hold = Motion.reduced ? 0 : 520;
    Future.delayed(Duration(milliseconds: hold), () {
      if (mounted) setState(() => _open = false);
    });
    // The list changes whether or not this row is still on screen.
    Future.delayed(Duration(milliseconds: hold + (Motion.reduced ? 0 : 270)), () {
      tasks.setDone(task, done);
      if (done) {
        os.toast(tr('Done'),
            action: tr('Undo'), onAction: () => tasks.setDone(task.copyWith(status: 2), false));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final checked = _checked ?? t.isCompleted;
    final due = t.dueDate == null ? null : dueLabel(t.dueDate!);
    final meta = <Widget>[
      if (t.priority == 2) const _Dot(Tk.signal) else if (t.priority == 1) const _Dot(Tk.warn),
      if (due != null) Label(due.$1, color: due.$2 && !t.isCompleted ? Tk.signal : Tk.ink3),
      if (t.isRecurring) const Icon(Icons.repeat_rounded, size: 12, color: Tk.ink3),
      if (t.status == 1) Label(tr('In progress'), color: context.accent),
      if (t.status == 4) Label(tr('Waiting')),
      if (t.projectName != null && !widget.compact) Label(t.projectName!),
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 260),
          style: sans(
            15.5,
            w: 480,
            height: 1.25,
            color: checked ? Tk.ink3 : Tk.ink,
            decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
          ),
          child: Text(t.name, maxLines: widget.compact ? 1 : 3, overflow: TextOverflow.ellipsis),
        ),
        if (meta.isNotEmpty && !(widget.compact && due == null && t.priority == 0)) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 9,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: meta,
          ),
        ],
      ],
    );
    final check = Check(value: checked, onTap: _toggle, label: t.name);
    return Fold(
      open: _open,
      child: widget.compact
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(children: [check, Expanded(child: body)]),
            )
          : RowTile(
              leading: check,
              onTap: () => showTaskSheet(context, t),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: body),
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// One field at the foot of a list that adds to it.
class QuickAdd extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onAdd;
  final int maxLines;
  const QuickAdd({super.key, required this.hint, required this.onAdd, this.maxLines = 1});

  @override
  State<QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<QuickAdd> {
  final _c = TextEditingController();
  final _f = FocusNode();

  void _send() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    thud();
    widget.onAdd(text);
    _c.clear();
    _f.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final has = _c.text.trim().isNotEmpty;
    return OsField(
      controller: _c,
      focusNode: _f,
      hint: widget.hint,
      icon: Icons.add_rounded,
      maxLines: widget.maxLines,
      onChanged: (_) => setState(() {}),
      onSubmit: (_) => _send(),
      trailing: SpringBuilder(
        value: has ? 1 : 0,
        spec: Spec.bouncy,
        builder: (context, v, _) => Transform.scale(
          scale: v.clamp(0.0, 1.2),
          child: v < 0.02
              ? const SizedBox.shrink()
              : OsIconButton(
                  Icons.arrow_upward_rounded,
                  onTap: _send,
                  tooltip: tr('Add'),
                  size: 36,
                  color: context.accent,
                ),
        ),
      ),
    );
  }
}

enum _Filter { today, upcoming, all, done }

class TasksApp extends ConsumerStatefulWidget {
  const TasksApp({super.key});

  @override
  ConsumerState<TasksApp> createState() => _TasksAppState();
}

class _TasksAppState extends ConsumerState<TasksApp> {
  _Filter _filter = _Filter.today;
  bool _board = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(tasksProvider);
    final tasks = ref.read(tasksProvider.notifier);
    final list = switch (_filter) {
      _Filter.today => s.todayTasks,
      _Filter.upcoming => s.upcoming,
      _Filter.all => s.open,
      _Filter.done => s.done,
    };
    final empty = switch (_filter) {
      _Filter.today => ('Clear for today', 'Nothing is due. Add something, or enjoy it.'),
      _Filter.upcoming => ('Nothing scheduled', 'Tasks with a date ahead show up here.'),
      _Filter.all => ('No open tasks', 'Add your first one below.'),
      _Filter.done => ('Nothing finished yet', 'What you check off lands here.'),
    };

    final Widget body;
    if (_board) {
      body = _Board(state: s);
    } else if (!s.loaded && s.loading) {
      body = const Padding(padding: EdgeInsets.all(16), child: Loading());
    } else if (!s.loaded && s.error != null) {
      body = Empty(tr('Could not reach Tududi'),
          hint: tr('Check the connection and try again.'),
          action: OsButton(tr('Try again'), onTap: tasks.load));
    } else if (list.isEmpty) {
      body = Empty(tr(empty.$1), hint: tr(empty.$2));
    } else {
      body = RefreshIndicator(
        onRefresh: tasks.load,
        color: context.accent,
        backgroundColor: const Color(0xFF1A1C22),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
          itemCount: list.length,
          itemBuilder: (context, i) => TaskRow(key: ValueKey(list[i].key), task: list[i]),
        ),
      );
    }

    return AppPane(
      app: AppId.tasks,
      sub: tr('{n} open', {'n': s.open.length}),
      actions: [
        OsIconButton(
          _board ? Icons.format_list_bulleted_rounded : Icons.view_week_outlined,
          onTap: () => setState(() => _board = !_board),
          tooltip: _board ? tr('List') : tr('Board'),
        ),
      ],
      body: Column(
        children: [
          if (!_board)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: OsSeg<_Filter>(
                value: _filter,
                items: {
                  _Filter.today: tr('Today'),
                  _Filter.upcoming: tr('Upcoming'),
                  _Filter.all: tr('All'),
                  _Filter.done: tr('Done'),
                },
                onChanged: (f) {
                  setState(() => _filter = f);
                  if (f == _Filter.done && !s.doneLoaded) tasks.loadDone();
                },
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: Motion.reduced ? 1 : 200),
              child: KeyedSubtree(key: ValueKey('$_filter$_board'), child: body),
            ),
          ),
        ],
      ),
      bottom: _filter == _Filter.done && !_board
          ? null
          : QuickAdd(
              hint: tr('Add a task'),
              onAdd: (name) => tasks.add(Task(
                name: name,
                dueDate: _filter == _Filter.today && !_board ? DateTime.now() : null,
              )),
            ),
    );
  }
}

/// The board: a column for each status. A card is dragged from one to
/// another (a long press on touch).
class _Board extends ConsumerWidget {
  final TasksState state;
  const _Board({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.read(tasksProvider.notifier);
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        for (final entry in taskStatuses.entries)
          _Column(
            status: entry.key,
            name: tr(entry.value),
            tasks: entry.key == 2
                ? state.done.take(12).toList()
                : [for (final t in state.open) if (t.status == entry.key) t],
            onDrop: (t) {
              if (t.status == entry.key) return;
              thud();
              tasks.setStatus(t, entry.key);
            },
          ),
      ],
    );
  }
}

class _Column extends StatefulWidget {
  final int status;
  final String name;
  final List<Task> tasks;
  final ValueChanged<Task> onDrop;
  const _Column({
    required this.status,
    required this.name,
    required this.tasks,
    required this.onDrop,
  });

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) {
        setState(() => _over = true);
        return true;
      },
      onLeave: (_) => setState(() => _over = false),
      onAcceptWithDetails: (d) {
        setState(() => _over = false);
        widget.onDrop(d.data);
      },
      builder: (context, _, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 252,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _over ? 0.08 : 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _over ? context.accent : Tk.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Row(
                children: [
                  Expanded(child: Label(widget.name, color: Tk.ink2)),
                  Label(widget.tasks.length.toString().padLeft(2, '0')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [for (final t in widget.tasks) _BoardCard(task: t)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final Task task;
  const _BoardCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = task.dueDate == null ? null : dueLabel(task.dueDate!);
    Widget card({bool lifted = false}) => Container(
          width: 232,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lifted ? const Color(0xFF22252C) : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Tk.rule),
            boxShadow: lifted
                ? const [BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 12))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.name,
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: sans(14.5, height: 1.25)),
              if (due != null || task.projectName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (due != null) Label(due.$1, color: due.$2 ? Tk.signal : Tk.ink3),
                    if (due != null && task.projectName != null) const SizedBox(width: 9),
                    if (task.projectName != null) Flexible(child: Label(task.projectName!)),
                  ],
                ),
              ],
            ],
          ),
        );
    final touch = MediaQuery.of(context).navigationMode == NavigationMode.traditional &&
        (Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS);
    final tappable = Pressable(
      onTap: () => showTaskSheet(context, task),
      scale: 0.97,
      child: card(),
    );
    final feedback = Material(
      type: MaterialType.transparency,
      child: Transform.rotate(angle: 0.03, child: card(lifted: true)),
    );
    final ghost = Opacity(opacity: 0.3, child: card());
    return touch
        ? LongPressDraggable<Task>(
            data: task, feedback: feedback, childWhenDragging: ghost, child: tappable)
        : Draggable<Task>(
            data: task, feedback: feedback, childWhenDragging: ghost, child: tappable);
  }
}
