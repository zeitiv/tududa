import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/patch.dart' show Patch;
import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../data/task_patch.dart';
import '../domain/new_task.dart';
import '../domain/task.dart';
import '../domain/task_labels.dart';
import '../providers/project_options_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/api_error_message.dart';
import '../../l10n/l10n_ext.dart';

/// Task create/edit form screen.
class TaskFormScreen extends ConsumerStatefulWidget {
  /// The task's uid when editing.
  final String? taskId;

  /// Project to file a new task under: a project uid (`String`). Other types
  /// (the router used to pass a numeric id) are ignored.
  final Object? defaultProjectId;
  const TaskFormScreen({super.key, this.taskId, this.defaultProjectId});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  Priority _priority = Priority.low;
  TaskStatus _status = TaskStatus.notStarted;
  DateTime? _dueDate;
  DateTime? _deferUntil;
  ProjectUid? _projectUid;
  String _recurrenceType = 'none';
  int _recurrenceInterval = 1;
  bool _completionBased = false;
  bool _isLoading = false;
  bool _isEdit = false;

  /// The task as loaded, to send only what the user changed.
  Task? _original;

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      _isEdit = true;
      _loadTask();
    } else if (widget.defaultProjectId case final String uid
        when uid.isNotEmpty) {
      _projectUid = ProjectUid(uid);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(apiErrorMessage(context.l10n, error))),
    );
  }

  Future<void> _loadTask() async {
    setState(() => _isLoading = true);
    try {
      final task = await ref.read(
        taskDetailProvider(TaskUid(widget.taskId!)).future,
      );
      if (!mounted) return;
      _nameController.text = task.name;
      _noteController.text = task.note ?? '';
      setState(() {
        _original = task;
        _priority = task.priority;
        _status = task.status;
        _dueDate = task.dueDate?.toLocalDateTime();
        _deferUntil = task.deferUntil?.toLocal();
        _projectUid = task.projectUid;
        _recurrenceType = task.recurrenceType;
        _recurrenceInterval = task.recurrenceInterval ?? 1;
        _completionBased = task.completionBased;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  CalendarDate? get _dueCalendarDate =>
      _dueDate == null ? null : CalendarDate.fromDateTime(_dueDate!);

  TaskPatch _buildPatch(Task o) {
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();
    final due = _dueCalendarDate;
    final dueChanged = due != o.dueDate;
    final recurring = _recurrenceType != 'none';
    return TaskPatch(
      name: name != o.name ? Patch.set(name) : const Patch.unset(),
      note: note == (o.note ?? '')
          ? const Patch.unset()
          : (note.isEmpty ? const Patch.clear() : Patch.set(note)),
      status: _status != o.status ? Patch.set(_status) : const Patch.unset(),
      priority: _priority != o.priority
          ? Patch.set(_priority)
          : const Patch.unset(),
      // Tududi drops the due time when only the date is sent, so resend the
      // existing time with a changed date (and clear it with the date).
      dueDate: !dueChanged
          ? const Patch.unset()
          : (due == null ? const Patch.clear() : Patch.set(due)),
      dueTime: dueChanged && due != null && o.dueTime != null
          ? Patch.set(o.dueTime!)
          : const Patch.unset(),
      deferUntil: _deferUntil == o.deferUntil?.toLocal()
          ? const Patch.unset()
          : (_deferUntil == null
                ? const Patch.clear()
                : Patch.set(_deferUntil!)),
      projectUid: _projectUid == o.projectUid
          ? const Patch.unset()
          : (_projectUid == null
                ? const Patch.clear()
                : Patch.set(_projectUid!)),
      recurrenceType: _recurrenceType != o.recurrenceType
          ? Patch.set(_recurrenceType)
          : const Patch.unset(),
      recurrenceInterval: !recurring
          ? (o.recurrenceInterval == null
                ? const Patch.unset()
                : const Patch.clear())
          : (_recurrenceInterval != o.recurrenceInterval
                ? Patch.set(_recurrenceInterval)
                : const Patch.unset()),
      completionBased: _completionBased != o.completionBased
          ? Patch.set(_completionBased)
          : const Patch.unset(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final actions = ref.read(taskActionsProvider);
    final TaskResult<Task> result;
    if (_isEdit) {
      final original = _original;
      if (original == null) return;
      setState(() => _isLoading = true);
      result = await actions.update(original.uid, _buildPatch(original));
    } else {
      setState(() => _isLoading = true);
      final note = _noteController.text.trim();
      final recurring = _recurrenceType != 'none';
      result = await actions.create(
        NewTask(
          name: _nameController.text.trim(),
          note: note.isEmpty ? null : note,
          priority: _priority,
          status: _status,
          dueDate: _dueCalendarDate,
          deferUntil: _deferUntil,
          projectUid: _projectUid,
          recurrenceType: recurring ? _recurrenceType : null,
          recurrenceInterval: recurring ? _recurrenceInterval : null,
          completionBased: recurring ? _completionBased : null,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.ok) {
      context.pop();
    } else {
      _showError(result.error!);
    }
  }

  Future<void> _pickDate({required bool isDueDate}) async {
    final initial = isDueDate ? _dueDate : _deferUntil;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _deferUntil = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectOptionsProvider).value ?? const [];
    final strings = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? strings.taskFormTitleEdit : strings.taskFormTitleNew,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.taskFormSave),
          ),
        ],
      ),
      body: _isLoading && _isEdit
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Name
                  TextFormField(
                    controller: _nameController,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: strings.taskFormNameLabel,
                      hintText: strings.taskFormNameHint,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? strings.taskFormNameRequired
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Priority
                  Text(
                    strings.taskFormPriority,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<Priority>(
                    segments: [
                      ButtonSegment(
                        value: Priority.low,
                        label: Text(taskPriorityLabel(strings, Priority.low)),
                        icon: const Icon(Icons.arrow_downward, size: 16),
                      ),
                      ButtonSegment(
                        value: Priority.medium,
                        label: Text(
                          taskPriorityLabel(strings, Priority.medium),
                        ),
                        icon: const Icon(Icons.remove, size: 16),
                      ),
                      ButtonSegment(
                        value: Priority.high,
                        label: Text(taskPriorityLabel(strings, Priority.high)),
                        icon: const Icon(Icons.arrow_upward, size: 16),
                      ),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (v) =>
                        setState(() => _priority = v.first),
                  ),
                  const SizedBox(height: 20),

                  // Status
                  Text(
                    strings.taskFormStatus,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TaskStatus>(
                    key: ValueKey(_status),
                    initialValue:
                        _statusOptions(strings).any((o) => o.value == _status)
                        ? _status
                        : null,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.radio_button_checked_outlined),
                    ),
                    items: _statusOptions(strings)
                        .map(
                          (option) => DropdownMenuItem<TaskStatus>(
                            value: option.value,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Due Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(strings.taskFormDueDate),
                    subtitle: Text(
                      _dueDate != null
                          ? DateFormat.yMMMd(locale).format(_dueDate!)
                          : strings.taskFormNotSet,
                    ),
                    trailing: _dueDate != null
                        ? IconButton(
                            tooltip: strings.taskFormClearTooltip,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _dueDate = null),
                          )
                        : null,
                    onTap: () => _pickDate(isDueDate: true),
                  ),

                  // Defer Until
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(strings.taskFormDeferUntil),
                    subtitle: Text(
                      _deferUntil != null
                          ? DateFormat.yMMMd(locale).format(_deferUntil!)
                          : strings.taskFormNotSet,
                    ),
                    trailing: _deferUntil != null
                        ? IconButton(
                            tooltip: strings.taskFormClearTooltip,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _deferUntil = null),
                          )
                        : null,
                    onTap: () => _pickDate(isDueDate: false),
                  ),

                  const Divider(height: 32),

                  // Project
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(strings.taskFormProject),
                    subtitle: Text(
                      _projectUid != null
                          ? projects
                                    .where((p) => p.uid == _projectUid)
                                    .firstOrNull
                                    ?.name ??
                                _original?.projectName ??
                                strings.taskFormProjectSelected
                          : strings.taskFormNone,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showProjectPicker(strings),
                  ),

                  const Divider(height: 32),

                  // Recurrence
                  Text(
                    strings.taskFormRecurrence,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _recurrenceType,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(strings.taskFormNone),
                      ),
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text(strings.taskRecurDaily),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text(strings.taskRecurWeekly),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text(strings.taskRecurMonthly),
                      ),
                      DropdownMenuItem(
                        value: 'monthly_weekday',
                        child: Text(strings.taskRecurMonthlyWeekday),
                      ),
                      DropdownMenuItem(
                        value: 'monthly_last_day',
                        child: Text(strings.taskRecurMonthlyLastDay),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _recurrenceType = v ?? 'none'),
                  ),

                  if (_recurrenceType != 'none') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('${strings.taskFormEvery} '),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: '$_recurrenceInterval',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n > 0) _recurrenceInterval = n;
                            },
                          ),
                        ),
                        Text(' ${_recurrenceUnitLabel(strings)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.taskFormCompletionBased),
                      subtitle: Text(strings.taskFormCompletionBasedHint),
                      value: _completionBased,
                      onChanged: (v) => setState(() => _completionBased = v),
                    ),
                  ],

                  const Divider(height: 32),

                  // Note
                  TextFormField(
                    controller: _noteController,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: strings.taskFormNoteLabel,
                      hintText: strings.taskFormNoteHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  String _recurrenceUnitLabel(AppLocalizations strings) {
    switch (_recurrenceType) {
      case 'daily':
        return strings.taskFormUnitDays(_recurrenceInterval);
      case 'weekly':
        return strings.taskFormUnitWeeks(_recurrenceInterval);
      default:
        return strings.taskFormUnitMonths(_recurrenceInterval);
    }
  }

  List<({TaskStatus value, String label})> _statusOptions(
    AppLocalizations strings,
  ) {
    return [
      for (final s in const [
        TaskStatus.notStarted,
        TaskStatus.planned,
        TaskStatus.inProgress,
        TaskStatus.waiting,
        TaskStatus.cancelled,
        TaskStatus.done,
      ])
        (value: s, label: taskStatusLabel(strings, s)),
    ];
  }

  void _showProjectPicker(AppLocalizations strings) {
    final projects = ref.read(projectOptionsProvider).value ?? const [];
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.clear),
            title: Text(strings.taskFormNone),
            onTap: () {
              setState(() => _projectUid = null);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ...projects.map(
            (p) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(p.name),
              trailing: p.uid == _projectUid
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() => _projectUid = p.uid);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
