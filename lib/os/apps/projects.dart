import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../areas/models/area_model.dart';
import '../../data/tududi.dart';
import '../../projects/models/project_model.dart';
import '../../tasks/models/task_model.dart';
import '../kit/controls.dart';
import '../kit/dots.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../window.dart';
import 'tasks.dart';

const projectStatuses = <String, String>{
  'not_started': 'Not started',
  'planned': 'Planned',
  'in_progress': 'In progress',
  'waiting': 'Waiting',
  'done': 'Done',
};

class ProjectsApp extends ConsumerStatefulWidget {
  const ProjectsApp({super.key});

  @override
  ConsumerState<ProjectsApp> createState() => _ProjectsAppState();
}

class _ProjectsAppState extends ConsumerState<ProjectsApp> {
  int? _area;
  int? _openId;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(projectsProvider);
    final areas = ref.watch(areasProvider.select((a) => a.items));
    Project? open;
    for (final p in s.items) {
      if (p.id == _openId && _openId != null) open = p;
    }
    if (open != null) {
      return _ProjectDetail(project: open, onBack: () => setState(() => _openId = null));
    }
    final list = [for (final p in s.items) if (_area == null || p.areaId == _area) p];
    return AppPane(
      app: AppId.projects,
      sub: tr('{n} projects', {'n': s.items.length}),
      actions: [
        OsIconButton(Icons.add_rounded,
            onTap: () => showOsSheet(context, (_) => _ProjectEditor(areaId: _area)),
            tooltip: tr('New project')),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: Row(
              children: [
                OsChip(tr('All'), on: _area == null, onTap: () => setState(() => _area = null)),
                for (final a in areas) ...[
                  const SizedBox(width: 8),
                  OsChip(
                    a.name,
                    on: _area == a.id,
                    onTap: () => setState(() => _area = a.id),
                    onLongPress: () => showOsSheet(context, (_) => _AreaEditor(area: a)),
                  ),
                ],
                const SizedBox(width: 8),
                OsChip(tr('Area'),
                    icon: Icons.add_rounded,
                    onTap: () => showOsSheet(context, (_) => const _AreaEditor())),
              ],
            ),
          ),
          Expanded(
            child: !s.loaded && s.loading
                ? const Padding(padding: EdgeInsets.all(16), child: Loading())
                : list.isEmpty
                    ? Empty(tr('No projects yet'),
                        hint: tr('A project gathers the tasks and notes for one outcome.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return Enter(
                            i: i,
                            child: RowTile(
                              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                              onTap: () => setState(() => _openId = p.id),
                              leading: Padding(
                                padding: const EdgeInsets.only(right: 14),
                                child: Ring(
                                  p.progress,
                                  size: 46,
                                  child: Text('${(p.progress * 100).round()}',
                                      style: mono(11, color: Tk.ink2, ls: 0)),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Tk.ink3),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: sans(16.5, w: 600, wdth: 106)),
                                  const SizedBox(height: 4),
                                  Label([
                                    tr(projectStatuses[p.status] ?? p.status),
                                    if (p.areaName != null) p.areaName!,
                                    if (p.taskCount != null)
                                      '${p.completedTaskCount ?? 0}/${p.taskCount}',
                                  ].join(' · ')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetail extends ConsumerWidget {
  final Project project;
  final VoidCallback onBack;
  const _ProjectDetail({required this.project, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = [
      for (final t in ref.watch(tasksProvider.select((s) => s.open)))
        if (t.projectId == project.id) t,
    ];
    final notes = [
      for (final n in ref.watch(notesProvider.select((s) => s.items)))
        if (n.projectId == project.id) n,
    ];
    return AppPane(
      app: AppId.projects,
      title: project.name,
      sub: tr(projectStatuses[project.status] ?? project.status),
      onBack: onBack,
      actions: [
        OsIconButton(Icons.edit_outlined,
            onTap: () => showOsSheet(
                context, (_) => _ProjectEditor(project: project, onDeleted: onBack)),
            tooltip: tr('Edit')),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((project.description ?? '').isNotEmpty) ...[
                  Text(project.description!, style: sans(15, color: Tk.ink2, height: 1.4)),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    DotText('${(project.progress * 100).round()}%', dot: 3.4, gap: 1.4),
                    const SizedBox(width: 16),
                    Expanded(child: DotBar(project.progress, count: 18, dot: 4.4)),
                  ],
                ),
                Section(tr('Tasks')),
              ],
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(tr('No open tasks'), style: sans(14, color: Tk.ink3)),
            ),
          for (final t in tasks) TaskRow(key: ValueKey(t.key), task: t),
          if (notes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Section(tr('Notes')),
            ),
            for (final n in notes)
              RowTile(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                onTap: () => ref.read(osProvider.notifier).open(AppId.notes),
                leading: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.notes_rounded, size: 18, color: Tk.ink3),
                ),
                child: Text(n.title ?? '', style: sans(15)),
              ),
          ],
        ],
      ),
      bottom: QuickAdd(
        hint: tr('Add a task'),
        onAdd: (name) => ref
            .read(tasksProvider.notifier)
            .add(Task(name: name, projectId: project.id, projectName: project.name)),
      ),
    );
  }
}

class _ProjectEditor extends ConsumerStatefulWidget {
  final Project? project;
  final int? areaId;
  final VoidCallback? onDeleted;
  const _ProjectEditor({this.project, this.areaId, this.onDeleted});

  @override
  ConsumerState<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends ConsumerState<_ProjectEditor> {
  late final _name = TextEditingController(text: widget.project?.name ?? '');
  late final _about = TextEditingController(text: widget.project?.description ?? '');
  late String _status = widget.project?.status ?? 'not_started';
  late int? _area = widget.project?.areaId ?? widget.areaId;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final n = ref.read(projectsProvider.notifier);
    final p = widget.project;
    Navigator.of(context).pop();
    thud();
    if (p == null) {
      n.add(Project(name: name, description: _about.text.trim(), status: _status, areaId: _area));
    } else {
      n.save(p.copyWith(
          name: name, description: _about.text.trim(), status: _status, areaId: _area));
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider.select((a) => a.items));
    final p = widget.project;
    return SheetBody(
      label: 'Tududi',
      title: p == null ? tr('New project') : tr('Project'),
      actions: [
        if (p != null)
          OsButton(tr('Delete'), danger: true, onTap: () {
            Navigator.of(context).pop();
            widget.onDeleted?.call();
            ref.read(projectsProvider.notifier).remove(p);
            ref.read(osProvider.notifier).toast(tr('Project deleted'));
          }),
        OsButton(tr('Save'), primary: true, onTap: _save),
      ],
      children: [
        OsField(controller: _name, hint: tr('Name'), big: true, autofocus: p == null),
        const SizedBox(height: 10),
        OsField(controller: _about, hint: tr('What is it for?'), maxLines: 4, minLines: 2),
        Section(tr('Status')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in projectStatuses.entries)
            OsChip(tr(e.value), on: _status == e.key, onTap: () => setState(() => _status = e.key)),
        ]),
        if (areas.isNotEmpty) ...[
          Section(tr('Area')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in areas)
              OsChip(a.name, on: _area == a.id, onTap: () => setState(() => _area = a.id)),
          ]),
        ],
      ],
    );
  }
}

class _AreaEditor extends ConsumerStatefulWidget {
  final Area? area;
  const _AreaEditor({this.area});

  @override
  ConsumerState<_AreaEditor> createState() => _AreaEditorState();
}

class _AreaEditorState extends ConsumerState<_AreaEditor> {
  late final _name = TextEditingController(text: widget.area?.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final n = ref.read(areasProvider.notifier);
    Navigator.of(context).pop();
    widget.area == null ? n.add(name) : n.save(widget.area!.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.area;
    return SheetBody(
      label: 'Tududi',
      title: a == null ? tr('New area') : tr('Area'),
      actions: [
        if (a != null)
          OsButton(tr('Delete'), danger: true, onTap: () {
            Navigator.of(context).pop();
            ref.read(areasProvider.notifier).remove(a);
          }),
        OsButton(tr('Save'), primary: true, onTap: _save),
      ],
      children: [
        OsField(
          controller: _name,
          hint: tr('Work, Home, Health…'),
          big: true,
          autofocus: true,
          onSubmit: (_) => _save(),
        ),
        const SizedBox(height: 8),
        Text(tr('An area groups projects. Press and hold one to rename it.'),
            style: sans(13.5, color: Tk.ink3, height: 1.4)),
      ],
    );
  }
}
