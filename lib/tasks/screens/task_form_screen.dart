import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../areas/providers/area_provider.dart';
import '../../common/widgets/surface_card.dart';
import '../../core/api/patch.dart' show Patch;
import '../../core/design/tokens.dart';
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../../tags/providers/tag_provider.dart';
import '../data/task_patch.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import '../domain/task_labels.dart';
import '../providers/project_options_provider.dart';
import '../providers/task_provider.dart';
import '../quick_add/quick_add_support.dart';
import '../quick_add/recurrence_text.dart';
import '../domain/recurrence/recurrence_rule.dart';
import '../widgets/api_error_message.dart';
import '../widgets/date_time_pickers.dart';
import '../widgets/recurrence_editor_sheet.dart';
import '../widgets/task_field_chips.dart';

/// Task create/edit form.
class TaskFormScreen extends ConsumerStatefulWidget {
  /// The task's uid when editing.
  final String? taskId;

  /// Project to file a new task under: a project uid (`String`). Other types
  /// (the router used to pass a numeric id) are ignored.
  final Object? defaultProjectId;

  /// What quick add recognised, used to prefill a new task ("More options").
  final QuickAddDraft? draft;

  const TaskFormScreen({
    super.key,
    this.taskId,
    this.defaultProjectId,
    this.draft,
  });

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _estimateController = TextEditingController();
  final _tagController = TextEditingController();

  Priority _priority = Priority.low;
  TaskStatus _status = TaskStatus.notStarted;
  CalendarDate? _dueDate;
  LocalTime? _dueTime;
  DateTime? _deferUntil;
  DateTime? _reminder;
  ProjectUid? _projectUid;
  String? _projectName;
  AreaUid? _areaUid;
  List<String> _tags = [];
  RecurrenceRule _rule = RecurrenceRule.none();

  bool _loading = false;
  bool _saving = false;

  /// Set once the screen is leaving, so the dirty guard lets it pop.
  bool _closing = false;
  bool _submitted = false;
  bool _notePreview = false;
  late final bool _isEdit = widget.taskId != null;

  /// The task as loaded, to send only what the user changed.
  Task? _original;

  /// [_snapshot] of the untouched form, to tell whether it is dirty.
  String _initial = '';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadTask();
      return;
    }
    if (widget.defaultProjectId case final String uid when uid.isNotEmpty) {
      _projectUid = ProjectUid(uid);
    }
    _initial = _snapshot();
    final d = widget.draft;
    if (d != null) _applyDraft(d);
  }

  void _applyDraft(QuickAddDraft d) {
    _nameController.text = d.name;
    _noteController.text = d.note ?? '';
    _dueDate = d.date;
    _dueTime = d.date == null ? null : d.time;
    _priority = d.priority ?? _priority;
    if (d.project != null) {
      _projectUid = d.project!.uid;
      _projectName = d.project!.name;
    }
    _areaUid = d.area?.uid ?? _areaUid;
    _tags = [...d.tags];
    final rule = d.recurrence;
    if (rule != null && rule.isRecurring) {
      _rule = rule;
      // A repeating task needs an anchor date.
      _dueDate ??= ref.read(taskDayProvider).date;
    }
  }

  String _snapshot() => [
    _nameController.text,
    _noteController.text,
    _estimateController.text,
    _priority,
    _status,
    _dueDate,
    _dueTime,
    _deferUntil,
    _reminder,
    _projectUid?.value,
    _areaUid?.value,
    _tags.join('\u0001'),
    _rule,
  ].join('|');

  bool get _dirty => _snapshot() != _initial;

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(context.l10n, error))),
    );
  }

  Future<void> _loadTask() async {
    setState(() => _loading = true);
    // Listen while loading so the auto-disposed provider is not torn down
    // before its first value arrives.
    final provider = taskDetailProvider(TaskUid(widget.taskId!));
    final keepAlive = ref.listenManual(provider, (_, _) {});
    try {
      final task = await ref.read(provider.future);
      if (!mounted) return;
      _nameController.text = task.name;
      _noteController.text = task.note ?? '';
      _estimateController.text = task.estimatedMinutes?.toString() ?? '';
      setState(() {
        _original = task;
        _priority = task.priority;
        _status = task.status;
        _dueDate = task.dueDate;
        _dueTime = task.dueTime;
        _deferUntil = task.deferUntil?.toLocal();
        _reminder = task.reminderAt?.toLocal();
        _projectUid = task.projectUid;
        _projectName = task.projectName;
        _areaUid = task.areaUid;
        _tags = [for (final t in task.tags) t.name];
        _rule = ruleFromTask(task);
        _loading = false;
        _initial = _snapshot();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e);
    } finally {
      keepAlive.close();
    }
  }

  int? get _estimate => int.tryParse(_estimateController.text.trim());

  String? _deferError(AppLocalizations l) =>
      _deferUntil != null &&
          _dueDate != null &&
          CalendarDate.fromDateTime(_deferUntil!).isAfter(_dueDate!)
      ? l.taskEditDeferAfterDue
      : null;

  String? _recurError(AppLocalizations l) =>
      _rule.isRecurring && _dueDate == null ? l.taskEditRecurNeedsDue : null;

  static Patch<T> _opt<T>(T? v) =>
      v == null ? const Patch.clear() : Patch.set(v as T);

  TaskPatch _buildPatch(Task o) {
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    final dueChanged = _dueDate != o.dueDate;
    final time = _dueDate == null ? null : _dueTime;
    // Tududi drops the due time when only the date is sent, so resend it with
    // a changed date.
    final timeChanged = time != o.dueTime;
    final tagsChanged =
        _tags.length != o.tags.length ||
        !_tags.toSet().containsAll(o.tags.map((t) => t.name));
    final oldRule = ruleFromTask(o);
    final ruleChanged = _rule != oldRule;
    final f = _rule.toBackendFields();
    final recurring = _rule.isRecurring;
    Patch<T> r<T>(String key) => !ruleChanged
        ? const Patch.unset()
        : (recurring ? _opt<T>(f[key] as T?) : const Patch.clear());
    return TaskPatch(
      name: name != o.name ? Patch.set(name) : const Patch.unset(),
      note: note == (o.note ?? '')
          ? const Patch.unset()
          : (note.isEmpty ? const Patch.clear() : Patch.set(note)),
      status: _status != o.status ? Patch.set(_status) : const Patch.unset(),
      priority: _priority != o.priority
          ? Patch.set(_priority)
          : const Patch.unset(),
      dueDate: !dueChanged ? const Patch.unset() : _opt(_dueDate),
      dueTime: dueChanged || timeChanged
          ? (time != null
                ? Patch.set(time)
                : (o.dueTime != null
                      ? const Patch.clear()
                      : const Patch.unset()))
          : const Patch.unset(),
      deferUntil: _deferUntil == o.deferUntil?.toLocal()
          ? const Patch.unset()
          : _opt(_deferUntil),
      reminderAt: _reminder == o.reminderAt?.toLocal()
          ? const Patch.unset()
          : _opt(_reminder),
      estimatedMinutes: _estimate == o.estimatedMinutes
          ? const Patch.unset()
          : _opt(_estimate),
      projectUid: _projectUid == o.projectUid
          ? const Patch.unset()
          : _opt<ProjectUid>(_projectUid),
      areaUid: _areaUid == o.areaUid
          ? const Patch.unset()
          : _opt<AreaUid>(_areaUid),
      tags: tagsChanged ? Patch.set(List.of(_tags)) : const Patch.unset(),
      recurrenceType: ruleChanged
          ? Patch.set(_rule.type.backendValue)
          : const Patch.unset(),
      recurrenceInterval: r<int>('recurrence_interval'),
      recurrenceEndDate: !ruleChanged
          ? const Patch.unset()
          : _opt(recurring ? _rule.endDate : null),
      recurrenceWeekday: r<int>('recurrence_weekday'),
      recurrenceWeekdays: r<List<int>>('recurrence_weekdays'),
      recurrenceMonthDay: r<int>('recurrence_month_day'),
      recurrenceWeekOfMonth: r<int>('recurrence_week_of_month'),
      completionBased: _rule.completionBased == o.completionBased
          ? const Patch.unset()
          : Patch.set(_rule.completionBased),
    );
  }

  NewTask _buildNew() {
    final note = _noteController.text.trim();
    final f = _rule.toBackendFields();
    final recurring = _rule.isRecurring;
    return NewTask(
      name: _nameController.text.trim(),
      note: note.isEmpty ? null : note,
      priority: _priority,
      status: _status,
      dueDate: _dueDate,
      dueTime: _dueDate == null ? null : _dueTime,
      deferUntil: _deferUntil,
      reminderAt: _reminder,
      estimatedMinutes: _estimate,
      projectUid: _projectUid,
      areaUid: _areaUid,
      tags: _tags,
      recurrenceType: recurring ? _rule.type.backendValue : null,
      recurrenceInterval: recurring ? _rule.interval : null,
      recurrenceEndDate: recurring ? _rule.endDate : null,
      recurrenceWeekday: recurring ? f['recurrence_weekday'] as int? : null,
      recurrenceWeekdays: recurring
          ? f['recurrence_weekdays'] as List<int>?
          : null,
      recurrenceMonthDay: recurring ? f['recurrence_month_day'] as int? : null,
      recurrenceWeekOfMonth: recurring
          ? f['recurrence_week_of_month'] as int?
          : null,
      completionBased: recurring ? _rule.completionBased : null,
    );
  }

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _deferError(l) != null || _recurError(l) != null) return;

    final actions = ref.read(taskActionsProvider);
    final TaskResult<Task> result;
    setState(() => _saving = true);
    if (_isEdit) {
      final original = _original;
      if (original == null) {
        setState(() => _saving = false);
        return;
      }
      final patch = _buildPatch(original);
      if (patch.isEmpty) {
        setState(() {
          _saving = false;
          _closing = true;
        });
        popScreen(context);
        return;
      }
      result = await actions.update(original.uid, patch);
    } else {
      result = await actions.create(_buildNew());
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _closing = result.ok;
    });
    if (result.ok) {
      popScreen(context);
    } else {
      _showError(result.error!);
    }
  }

  Future<void> _confirmDiscard() async {
    final l = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.taskEditDiscardTitle),
        content: Text(l.taskEditDiscardBody),
        actions: [
          TextButton(
            key: const Key('formKeepEditing'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.taskEditKeepEditing),
          ),
          FilledButton(
            key: const Key('formDiscard'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.taskEditDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _closing = true);
      popScreen(context);
    }
  }

  Future<void> _editRecurrence() async {
    final today = ref.read(taskDayProvider).date;
    final rule = await showRecurrenceEditorSheet(
      context,
      initial: _rule,
      anchor: _dueDate ?? today,
    );
    if (rule == null || !mounted) return;
    setState(() {
      _rule = rule;
      // A repeating task needs a date to repeat from.
      if (rule.isRecurring) _dueDate ??= today;
    });
  }

  void _addTag(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return;
    if (!_tags.any((t) => t.toLowerCase() == name.toLowerCase())) {
      setState(() => _tags = [..._tags, name]);
    }
    _tagController.clear();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _estimateController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final theme = Theme.of(context);
    final f = DateFormats(Localizations.localeOf(context));
    final projects = ref.watch(projectOptionsProvider).value ?? const [];
    final areas = ref.watch(areaListProvider).value ?? const [];
    final knownTags = ref.watch(tagListProvider).value ?? const [];
    final projectName =
        projects.where((p) => p.uid == _projectUid).firstOrNull?.name ??
        _projectName;
    final areaName = areas.where((a) => a.uid == _areaUid).firstOrNull?.name;
    final gap = SizedBox(height: t.space3);

    Widget section(List<Widget> children) => Padding(
      padding: EdgeInsets.only(bottom: t.space3),
      child: SurfaceCard(
        padding: EdgeInsets.all(t.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );

    final suggestions = [
      for (final tag in knownTags)
        if (!_tags.any((x) => x.toLowerCase() == tag.name.toLowerCase()))
          tag.name,
    ].take(8);

    return PopScope(
      canPop: !_dirty || _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? l.taskFormTitleEdit : l.taskFormTitleNew),
          actions: [
            TextButton(
              key: const Key('formSave'),
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.taskFormSave),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    child: ListView(
                      padding: EdgeInsets.all(t.space4),
                      children: [
                        section([
                          TextFormField(
                            key: const Key('formName'),
                            controller: _nameController,
                            autofocus: !_isEdit,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: l.taskFormNameLabel,
                              hintText: l.taskFormNameHint,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? l.taskFormNameRequired
                                : null,
                          ),
                          gap,
                          Text(
                            l.taskFormPriority,
                            style: theme.textTheme.labelLarge,
                          ),
                          SizedBox(height: t.space2),
                          Wrap(
                            spacing: t.space2,
                            runSpacing: t.space2,
                            children: [
                              for (final p in Priority.values)
                                ChoiceChip(
                                  key: Key('formPriority-${p.name}'),
                                  avatar: Icon(
                                    Icons.flag_rounded,
                                    size: 16,
                                    color: taskPriorityColor(t, p),
                                  ),
                                  label: Text(taskPriorityLabel(l, p)),
                                  selected: _priority == p,
                                  onSelected: (_) =>
                                      setState(() => _priority = p),
                                ),
                            ],
                          ),
                          gap,
                          DropdownButtonFormField<TaskStatus>(
                            key: ValueKey(_status),
                            initialValue: _status,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l.taskFormStatus,
                              prefixIcon: const Icon(
                                Icons.radio_button_checked_outlined,
                              ),
                            ),
                            items: [
                              for (final s in const [
                                TaskStatus.notStarted,
                                TaskStatus.planned,
                                TaskStatus.inProgress,
                                TaskStatus.waiting,
                                TaskStatus.cancelled,
                                TaskStatus.done,
                              ])
                                DropdownMenuItem(
                                  value: s,
                                  child: Text(taskStatusLabel(l, s)),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _status = v);
                            },
                          ),
                        ]),
                        section([
                          PickerField(
                            key: const Key('formDue'),
                            icon: Icons.calendar_today_outlined,
                            label: l.taskFormDueDate,
                            value: _dueDate == null
                                ? null
                                : f.fullDate(_dueDate!),
                            errorText: _submitted ? _recurError(l) : null,
                            onTap: () async {
                              final d = await pickCalendarDate(
                                context,
                                initial: _dueDate,
                              );
                              if (d != null) setState(() => _dueDate = d);
                            },
                            onClear: () => setState(() {
                              _dueDate = null;
                              _dueTime = null;
                            }),
                          ),
                          if (_dueDate != null)
                            PickerField(
                              key: const Key('formDueTime'),
                              icon: Icons.access_time,
                              label: l.taskEditDueTime,
                              value: _dueTime == null
                                  ? null
                                  : f.time(_dueTime!),
                              onTap: () async {
                                final v = await pickLocalTime(
                                  context,
                                  initial: _dueTime,
                                );
                                if (v != null) setState(() => _dueTime = v);
                              },
                              onClear: () => setState(() => _dueTime = null),
                            ),
                          PickerField(
                            key: const Key('formDefer'),
                            icon: Icons.schedule_outlined,
                            label: l.taskFormDeferUntil,
                            value: _deferUntil == null
                                ? null
                                : f.fullDate(
                                    CalendarDate.fromDateTime(_deferUntil!),
                                  ),
                            errorText: _submitted ? _deferError(l) : null,
                            onTap: () async {
                              final d = await pickCalendarDate(
                                context,
                                initial: _deferUntil == null
                                    ? null
                                    : CalendarDate.fromDateTime(_deferUntil!),
                              );
                              if (d != null) {
                                setState(
                                  () => _deferUntil = d.toLocalDateTime(),
                                );
                              }
                            },
                            onClear: () => setState(() => _deferUntil = null),
                          ),
                          PickerField(
                            key: const Key('formReminder'),
                            icon: Icons.notifications_none_rounded,
                            label: l.taskEditReminder,
                            value: _reminder == null
                                ? null
                                : f.dateTime(_reminder!),
                            onTap: () async {
                              final v = await pickDateTime(
                                context,
                                initial: _reminder,
                              );
                              if (v != null) setState(() => _reminder = v);
                            },
                            onClear: () => setState(() => _reminder = null),
                          ),
                          gap,
                          TextFormField(
                            key: const Key('formEstimate'),
                            controller: _estimateController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l.taskEditEstimateLabel,
                              prefixIcon: const Icon(Icons.timer_outlined),
                            ),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return null;
                              final n = int.tryParse(s);
                              return n == null || n <= 0
                                  ? l.taskEditEstimateInvalid
                                  : null;
                            },
                          ),
                        ]),
                        section([
                          _PickTile(
                            key: const Key('formProject'),
                            icon: Icons.folder_outlined,
                            label: l.taskFormProject,
                            value: _projectUid == null
                                ? null
                                : (projectName ?? l.taskFormProjectSelected),
                            onTap: () async {
                              final r = await _pickOne<ProjectUid>(
                                title: l.taskFormProject,
                                selected: _projectUid,
                                options: [
                                  for (final p in projects)
                                    (value: p.uid, label: p.name),
                                ],
                              );
                              if (r != null) {
                                setState(() {
                                  _projectUid = r.value;
                                  _projectName = null;
                                });
                              }
                            },
                          ),
                          _PickTile(
                            key: const Key('formArea'),
                            icon: Icons.layers_outlined,
                            label: l.taskEditArea,
                            value: _areaUid == null
                                ? null
                                : (areaName ?? l.taskFormProjectSelected),
                            onTap: () async {
                              final r = await _pickOne<AreaUid>(
                                title: l.taskEditArea,
                                selected: _areaUid,
                                options: [
                                  for (final a in areas)
                                    (value: a.uid, label: a.name),
                                ],
                              );
                              if (r != null) {
                                setState(() => _areaUid = r.value);
                              }
                            },
                          ),
                          gap,
                          Text(
                            l.taskEditTags,
                            style: theme.textTheme.labelLarge,
                          ),
                          SizedBox(height: t.space2),
                          if (_tags.isNotEmpty)
                            Wrap(
                              spacing: t.space2,
                              runSpacing: t.space1,
                              children: [
                                for (final tag in _tags)
                                  InputChip(
                                    key: Key('formTag-$tag'),
                                    label: Text(tag),
                                    onDeleted: () => setState(
                                      () => _tags = [
                                        for (final x in _tags)
                                          if (x != tag) x,
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('formTagField'),
                                  controller: _tagController,
                                  decoration: InputDecoration(
                                    hintText: l.taskEditTagHint,
                                    prefixIcon: const Icon(Icons.sell_outlined),
                                  ),
                                  onSubmitted: _addTag,
                                ),
                              ),
                              IconButton(
                                tooltip: l.taskEditTagAdd,
                                icon: const Icon(Icons.add),
                                onPressed: () => _addTag(_tagController.text),
                              ),
                            ],
                          ),
                          if (suggestions.isNotEmpty)
                            Wrap(
                              spacing: t.space2,
                              children: [
                                for (final name in suggestions)
                                  ActionChip(
                                    label: Text(name),
                                    onPressed: () => _addTag(name),
                                  ),
                              ],
                            ),
                        ]),
                        section([
                          _PickTile(
                            key: const Key('formRecurrence'),
                            icon: Icons.repeat,
                            label: l.taskFormRecurrence,
                            value: _rule.isRecurring
                                ? recurrenceSummary(l, f, _rule)
                                : null,
                            noneLabel: l.quickAddRepeatNone,
                            onTap: _editRecurrence,
                          ),
                        ]),
                        section([
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.taskFormNoteLabel,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              SegmentedButton<bool>(
                                key: const Key('formNoteMode'),
                                showSelectedIcon: false,
                                segments: [
                                  ButtonSegment(
                                    value: false,
                                    label: Text(l.noteV2ModeEdit),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text(l.noteV2ModePreview),
                                  ),
                                ],
                                selected: {_notePreview},
                                onSelectionChanged: (s) =>
                                    setState(() => _notePreview = s.first),
                              ),
                            ],
                          ),
                          gap,
                          if (_notePreview)
                            _noteText.trim().isEmpty
                                ? Text(
                                    l.noteV2PreviewEmpty,
                                    key: const Key('formNotePreviewEmpty'),
                                  )
                                : MarkdownBody(
                                    key: const Key('formNotePreview'),
                                    data: _noteText,
                                    styleSheet: MarkdownStyleSheet.fromTheme(
                                      theme,
                                    ).copyWith(p: theme.textTheme.bodyMedium),
                                  )
                          else
                            TextFormField(
                              key: const Key('formNote'),
                              controller: _noteController,
                              minLines: 4,
                              maxLines: 10,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: l.taskFormNoteHint,
                                alignLabelWithHint: true,
                              ),
                            ),
                        ]),
                        SizedBox(height: t.space12),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String get _noteText => _noteController.text;

  /// Bottom sheet that picks one of [options] or "None". Null when dismissed.
  Future<({T? value})?> _pickOne<T>({
    required String title,
    required T? selected,
    required List<({T value, String label})> options,
  }) {
    final l = context.l10n;
    return showModalBottomSheet<({T? value})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.clear),
            title: Text(l.taskFormNone),
            selected: selected == null,
            onTap: () => Navigator.pop(ctx, (value: null)),
          ),
          for (final o in options)
            ListTile(
              leading: const Icon(Icons.chevron_right),
              title: Text(o.label),
              selected: o.value == selected,
              trailing: o.value == selected ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, (value: o.value)),
            ),
        ],
      ),
    );
  }
}

/// A row that opens a picker: icon, label and current value ("None" if unset).
class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.noneLabel,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? noneLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(
                      value ?? noneLabel ?? context.l10n.taskFormNone,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
