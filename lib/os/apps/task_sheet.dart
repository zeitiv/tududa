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
import 'tasks.dart';

/// Opens a task to edit it, or an empty one to write.
Future<void> showTaskSheet(BuildContext context, Task? task, {int? projectId}) {
  return showOsSheet(context, (_) => _TaskEditor(task: task, projectId: projectId));
}

class _TaskEditor extends ConsumerStatefulWidget {
  final Task? task;
  final int? projectId;
  const _TaskEditor({this.task, this.projectId});

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  late final _name = TextEditingController(text: widget.task?.name ?? '');
  late final _note = TextEditingController(text: widget.task?.note ?? '');
  late int _status = widget.task?.status ?? 0;
  late int _priority = widget.task?.priority ?? 0;
  late DateTime? _due = widget.task?.dueDate;
  late int? _project = widget.task?.projectId ?? widget.projectId;
  late String _repeat = widget.task?.recurrenceType ?? 'none';
  List<Task> _steps = const [];

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _steps = t.subtasks ?? const [];
      ref.read(tasksProvider.notifier).subtasks(t).then((s) {
        if (mounted) setState(() => _steps = s);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final tasks = ref.read(tasksProvider.notifier);
    final projects = ref.read(projectsProvider).items;
    String? projectName;
    for (final p in projects) {
      if (p.id == _project) projectName = p.name;
    }
    final base = widget.task ?? Task(name: name);
    final next = base.copyWith(
      name: name,
      note: _note.text.trim(),
      status: _status,
      priority: _priority,
      dueDate: _due,
      clearDue: _due == null,
      projectId: _project,
      projectName: projectName,
      clearProject: _project == null,
      recurrenceType: _repeat,
      subtasks: _steps,
    );
    thud();
    Navigator.of(context).pop();
    if (_isNew) {
      tasks.add(next);
    } else if (next.isCompleted != base.isCompleted) {
      tasks.save(next.copyWith(status: base.status)).then((_) => tasks.setStatus(next.copyWith(status: base.status), _status));
    } else {
      tasks.save(next);
    }
  }

  void _delete() {
    final t = widget.task!;
    final tasks = ref.read(tasksProvider.notifier);
    Navigator.of(context).pop();
    tasks.remove(t);
    ref.read(osProvider.notifier).toast(tr('Task deleted'));
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 6),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day, 12));
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider.select((s) => s.items));
    final today = dayOf(DateTime.now());
    DateTime at(int days) => DateTime(today.year, today.month, today.day + days, 12);
    bool isDay(int days) => _due != null && dayOf(_due!.toLocal()) == dayOf(at(days));
    final custom = _due != null && !isDay(0) && !isDay(1) && !isDay(7);

    Widget chips(List<Widget> kids) => Wrap(spacing: 8, runSpacing: 8, children: kids);

    return SheetBody(
      label: 'Tududi',
      title: _isNew ? tr('New task') : tr('Task'),
      actions: [
        if (!_isNew) OsButton(tr('Delete'), danger: true, onTap: _delete),
        OsButton(tr('Save'), primary: true, onTap: _save),
      ],
      children: [
        OsField(
          controller: _name,
          hint: tr('What needs doing?'),
          autofocus: _isNew,
          big: true,
          maxLines: 3,
          onSubmit: (_) => _save(),
        ),
        const SizedBox(height: 10),
        OsField(controller: _note, hint: tr('Notes (Markdown)'), maxLines: 6, minLines: 2),
        Section(tr('When')),
        chips([
          OsChip(tr('Today'), on: isDay(0), onTap: () => setState(() => _due = at(0))),
          OsChip(tr('Tomorrow'), on: isDay(1), onTap: () => setState(() => _due = at(1))),
          OsChip(tr('In a week'), on: isDay(7), onTap: () => setState(() => _due = at(7))),
          OsChip(
            custom ? DateFormat('d MMM y', L.code).format(_due!.toLocal()) : tr('Pick a date'),
            icon: Icons.event_outlined,
            on: custom,
            onTap: _pick,
          ),
          if (_due != null)
            OsChip(tr('No date'), icon: Icons.close_rounded, onTap: () => setState(() => _due = null)),
        ]),
        Section(tr('Priority')),
        OsSeg<int>(
          value: _priority,
          items: {0: tr('Low'), 1: tr('Medium'), 2: tr('High')},
          onChanged: (v) => setState(() => _priority = v),
        ),
        Section(tr('Status')),
        chips([
          for (final e in taskStatuses.entries)
            OsChip(tr(e.value), on: _status == e.key, onTap: () => setState(() => _status = e.key)),
        ]),
        if (projects.isNotEmpty) ...[
          Section(tr('Project')),
          chips([
            OsChip(tr('None'), on: _project == null, onTap: () => setState(() => _project = null)),
            for (final p in projects)
              OsChip(p.name, on: _project == p.id, onTap: () => setState(() => _project = p.id)),
          ]),
        ],
        Section(tr('Repeat')),
        chips([
          for (final e in const {
            'none': 'Never',
            'daily': 'Daily',
            'weekly': 'Weekly',
            'monthly': 'Monthly',
          }.entries)
            OsChip(tr(e.value), on: _repeat == e.key, onTap: () => setState(() => _repeat = e.key)),
        ]),
        if (!_isNew) ...[
          Section(tr('Steps')),
          for (var i = 0; i < _steps.length; i++)
            Row(
              children: [
                Check(
                  value: _steps[i].isCompleted,
                  size: 20,
                  label: _steps[i].name,
                  onTap: () {
                    final s = _steps[i];
                    final done = !s.isCompleted;
                    setState(() => _steps = [
                          for (var j = 0; j < _steps.length; j++)
                            j == i ? s.copyWith(status: done ? 2 : 0) : _steps[j],
                        ]);
                    ref.read(tasksProvider.notifier).setSubtaskDone(s, done);
                  },
                ),
                Expanded(
                  child: Text(
                    _steps[i].name,
                    style: sans(
                      14.5,
                      color: _steps[i].isCompleted ? Tk.ink3 : Tk.ink,
                      decoration: _steps[i].isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          QuickAdd(
            hint: tr('Add a step'),
            onAdd: (name) async {
              final step = await ref.read(tasksProvider.notifier).addSubtask(widget.task!, name);
              if (step != null && mounted) setState(() => _steps = [..._steps, step]);
            },
          ),
        ],
      ],
    );
  }
}
