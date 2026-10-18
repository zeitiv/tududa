import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/quick_add/quick_add_parser.dart';
import '../domain/recurrence/describe.dart';
import '../domain/task.dart';
import '../domain/task_labels.dart';
import '../providers/project_options_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/api_error_message.dart';
import 'quick_add_support.dart';
import 'recurrence_editor.dart';
import 'recurrence_text.dart';

/// Opens quick add from anywhere as a modal bottom sheet. "More options"
/// opens the full task form.
Future<void> showQuickAddSheet(
  BuildContext context, {
  String? initialText,
}) async {
  final router = GoRouter.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => QuickAddSheet(
      initialText: initialText,
      onMoreOptions: router == null
          ? null
          : (draft) {
              final project = draft.project?.uid.value;
              router.push(
                project == null
                    ? '/tasks/new'
                    : '/tasks/new?projectId=${Uri.encodeQueryComponent(project)}',
              );
            },
    ),
  );
}

/// Quick add: type a sentence, see what was recognised, save. Depends only on
/// providers and l10n, so it also runs in the home-screen widget's engine.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initialText,
    this.onClose,
    this.onMoreOptions,
    this.onSaved,
  });

  final String? initialText;

  /// Called to dismiss the sheet (after saving or on close). Defaults to
  /// popping the enclosing route.
  final VoidCallback? onClose;

  /// Called after the sheet closed, with what was typed. When null the
  /// "More options" button is hidden.
  final void Function(QuickAddDraft draft)? onMoreOptions;

  /// Called after each successful save.
  final void Function(Task task)? onSaved;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  final _focus = FocusNode();
  final _noteController = TextEditingController();

  /// Token start offset -> the token text, for chips the user un-matched.
  final Map<int, String> _disabled = {};
  String _lastText = '';
  QuickAddManual _manual = const QuickAddManual();
  bool _showNote = false;
  bool _addAnother = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lastText = _text.text;
    _text.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Keeps un-matched offsets pointing at the same text after an edit.
  void _onTextChanged() {
    final now = _text.text;
    final old = _lastText;
    if (now == old) return;
    var p = 0;
    while (p < old.length && p < now.length && old[p] == now[p]) {
      p++;
    }
    final delta = now.length - old.length;
    final moved = <int, String>{};
    _disabled.forEach((start, text) {
      final s = start < p ? start : start + delta;
      if (s >= 0 && now.startsWith(text, s)) moved[s] = text;
    });
    _disabled
      ..clear()
      ..addAll(moved);
    _lastText = now;
    setState(() => _error = null);
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _save(ParseResult parsed, QuickAddLookups lookups) async {
    final draft = mergeQuickAdd(parsed, _manual, lookups);
    if (!draft.canSave || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final actions = ref.read(taskActionsProvider);
    final result = await createFromDraft(ref, draft);
    if (!mounted) return;
    final task = result.value;
    if (!result.ok || task == null) {
      setState(() {
        _saving = false;
        _error = apiErrorMessage(l10n, result.error!);
      });
      return;
    }
    widget.onSaved?.call(task);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.quickAddAdded(task.name)),
          action: SnackBarAction(
            label: l10n.quickAddUndo,
            onPressed: () => actions.delete(task.uid),
          ),
        ),
      );
    if (_addAnother) {
      _disabled.clear();
      _noteController.clear();
      _text.value = TextEditingValue.empty;
      _lastText = '';
      setState(() {
        _saving = false;
        _manual = const QuickAddManual();
        _showNote = false;
      });
      _focus.requestFocus();
    } else {
      _close();
    }
  }

  void _unmatch(Iterable<ParsedToken> tokens) => setState(() {
    for (final t in tokens) {
      _disabled[t.start] = t.text;
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final fmt = DateFormats(locale);
    final today = ref.watch(taskDayProvider).date;
    final lookups = ref.watch(quickAddLookupsProvider);
    final parsed = parseQuickAdd(
      text: _text.text,
      today: today,
      locale: locale,
      lookups: lookups,
      disabledStarts: _disabled.keys.toSet(),
    );
    final draft = mergeQuickAdd(parsed, _manual, lookups);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.quickAddTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l.quickAddClose,
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              key: const Key('quickAddField'),
              controller: _text,
              focusNode: _focus,
              autofocus: true,
              maxLines: 1,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l.quickAddHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                _save(parsed, lookups);
                _focus.requestFocus();
              },
            ),
            const SizedBox(height: 8),
            _chips(context, parsed, fmt, today, lookups),
            ..._recurrenceInfo(context, parsed, draft, fmt, today),
            const SizedBox(height: 4),
            _pickers(context, draft, fmt, today, lookups),
            if (_showNote)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  key: const Key('quickAddNote'),
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l.quickAddNoteHint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _manual = _manual.copyWith(note: v)),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      key: const Key('quickAddAnother'),
                      label: Text(l.quickAddAddAnother),
                      selected: _addAnother,
                      onSelected: (v) => setState(() => _addAnother = v),
                    ),
                    if (widget.onMoreOptions != null)
                      TextButton(
                        key: const Key('quickAddMore'),
                        onPressed: () {
                          final cb = widget.onMoreOptions!;
                          _close();
                          cb(draft);
                        },
                        child: Text(l.quickAddMoreOptions),
                      ),
                  ],
                ),
                FilledButton(
                  key: const Key('quickAddSubmit'),
                  onPressed: draft.canSave && !_saving
                      ? () => _save(parsed, lookups)
                      : null,
                  child: Text(l.quickAddSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ chips

  Widget _chips(
    BuildContext context,
    ParseResult parsed,
    DateFormats fmt,
    CalendarDate today,
    QuickAddLookups lookups,
  ) {
    final l = context.l10n;
    final m = _manual;
    final chips = <Widget>[];

    Widget parsedChip(
      String id,
      IconData icon,
      String label,
      Iterable<ParsedToken> tokens,
    ) => ActionChip(
      key: Key('qaChip-$id'),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      tooltip: l.quickAddKeepAsText,
      onPressed: () => _unmatch(tokens),
    );

    Widget manualChip(
      String id,
      IconData icon,
      String label,
      VoidCallback onDelete,
    ) => InputChip(
      key: Key('qaManual-$id'),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onDeleted: onDelete,
    );

    Iterable<ParsedToken> of(TokenKind k) =>
        parsed.tokens.where((t) => t.kind == k);

    // Date.
    if (m.date != null) {
      chips.add(
        manualChip(
          'date',
          Icons.event,
          fmt.relativeDay(m.date!, today, l),
          () => setState(() => _manual = m.copyWith(clearDate: true)),
        ),
      );
    } else if (parsed.dueDate != null) {
      final tokens = of(TokenKind.date);
      chips.add(
        parsedChip(
          'date',
          Icons.event,
          fmt.relativeDay(parsed.dueDate!, today, l),
          tokens,
        ),
      );
    }
    // Time.
    if (m.time != null) {
      chips.add(
        manualChip(
          'time',
          Icons.schedule,
          fmt.time(m.time!),
          () => setState(() => _manual = m.copyWith(clearTime: true)),
        ),
      );
    } else if (parsed.dueTime != null) {
      chips.add(
        parsedChip(
          'time',
          Icons.schedule,
          fmt.time(parsed.dueTime!),
          of(TokenKind.time),
        ),
      );
    }
    // Priority.
    if (m.priority != null) {
      chips.add(
        manualChip(
          'priority',
          Icons.flag,
          taskPriorityLabel(l, m.priority!),
          () => setState(() => _manual = m.copyWith(clearPriority: true)),
        ),
      );
    } else if (parsed.priority != null) {
      chips.add(
        parsedChip(
          'priority',
          Icons.flag,
          taskPriorityLabel(l, priorityOf(parsed.priority!)),
          of(TokenKind.priority),
        ),
      );
    }
    // Project.
    if (m.project != null) {
      chips.add(
        manualChip(
          'project',
          Icons.folder_outlined,
          m.project!.name,
          () => setState(() => _manual = m.copyWith(clearProject: true)),
        ),
      );
    } else if (lookups.project(parsed.projectName) case final p?) {
      chips.add(
        parsedChip(
          'project',
          Icons.folder_outlined,
          p.name,
          of(TokenKind.project),
        ),
      );
    }
    // Area.
    if (m.area != null) {
      chips.add(
        manualChip(
          'area',
          Icons.layers_outlined,
          m.area!.name,
          () => setState(() => _manual = m.copyWith(clearArea: true)),
        ),
      );
    } else if (lookups.area(parsed.areaName) case final a?) {
      chips.add(
        parsedChip('area', Icons.layers_outlined, a.name, of(TokenKind.area)),
      );
    }
    // Tags: parsed ones one chip each, manual ones removable.
    for (final t in of(TokenKind.tag)) {
      chips.add(
        parsedChip('tag-${t.start}', Icons.sell_outlined, '${t.value}', [t]),
      );
    }
    for (final t in m.tags) {
      chips.add(
        manualChip(
          'tag-$t',
          Icons.sell_outlined,
          t,
          () => setState(
            () => _manual = m.copyWith(
              tags: [
                for (final x in m.tags)
                  if (x != t) x,
              ],
            ),
          ),
        ),
      );
    }
    // Recurrence.
    if (m.recurrence != null && m.recurrence!.isRecurring) {
      chips.add(
        manualChip(
          'recurrence',
          Icons.repeat,
          recurrenceSummary(l, fmt, m.recurrence!),
          () => setState(() => _manual = m.copyWith(clearRecurrence: true)),
        ),
      );
    } else if (parsed.recurrence != null) {
      chips.add(
        parsedChip(
          'recurrence',
          Icons.repeat,
          recurrenceSummary(l, fmt, parsed.recurrence!),
          of(TokenKind.recurrence),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }

  List<Widget> _recurrenceInfo(
    BuildContext context,
    ParseResult parsed,
    QuickAddDraft draft,
    DateFormats fmt,
    CalendarDate today,
  ) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall;
    final out = <Widget>[];
    final rule = draft.recurrence;
    if (rule != null && rule.isRecurring) {
      final dates = previewOccurrences(rule, draft.date ?? today, 3);
      if (dates.isNotEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.quickAddNextOccurrences(dates.map(fmt.mediumDate).join(', ')),
              key: const Key('qaRecurrencePreview'),
              style: style,
            ),
          ),
        );
      }
    }
    if (parsed.hint == 'recurrence.yearly_unsupported') {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l.quickAddYearlyUnsupported,
            key: const Key('qaYearlyHint'),
            style: style?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return out;
  }

  // ---------------------------------------------------------------- pickers

  Widget _pickers(
    BuildContext context,
    QuickAddDraft draft,
    DateFormats fmt,
    CalendarDate today,
    QuickAddLookups lookups,
  ) {
    final l = context.l10n;
    final primary = Theme.of(context).colorScheme.primary;

    Widget button(
      String id,
      IconData icon,
      String tooltip,
      VoidCallback? onPressed, {
      bool active = false,
    }) => IconButton(
      key: Key('qaPick-$id'),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: active ? primary : null),
    );

    Widget menu<T>(
      String id,
      IconData icon,
      String tooltip,
      List<(T?, String)> options,
      void Function(T? value) onPick, {
      bool active = false,
    }) => PopupMenuButton<({T? value})>(
      key: Key('qaPick-$id'),
      tooltip: tooltip,
      icon: Icon(icon, color: active ? primary : null),
      onSelected: (c) => onPick(c.value),
      itemBuilder: (_) => [
        for (final (value, label) in options)
          PopupMenuItem(value: (value: value), child: Text(label)),
      ],
    );

    return Wrap(
      children: [
        button('date', Icons.event, l.quickAddPickDate, () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: (draft.date ?? today).toLocalDateTime(),
            firstDate: DateTime(today.year - 1),
            lastDate: DateTime(today.year + 10),
          );
          if (picked != null && mounted) {
            setState(
              () => _manual = _manual.copyWith(
                date: CalendarDate.fromDateTime(picked),
              ),
            );
          }
        }, active: _manual.date != null),
        button('time', Icons.schedule, l.quickAddPickTime, () async {
          final t = draft.time;
          final picked = await showTimePicker(
            context: context,
            initialTime: t == null
                ? TimeOfDay.now()
                : TimeOfDay(hour: t.hour, minute: t.minute),
          );
          if (picked != null && mounted) {
            setState(
              () => _manual = _manual.copyWith(
                time: LocalTime(picked.hour, picked.minute),
              ),
            );
          }
        }, active: _manual.time != null),
        menu<Priority>(
          'priority',
          Icons.flag_outlined,
          l.quickAddPickPriority,
          [
            (null, l.quickAddNone),
            for (final p in Priority.values) (p, taskPriorityLabel(l, p)),
          ],
          (p) => setState(
            () => _manual = p == null
                ? _manual.copyWith(clearPriority: true)
                : _manual.copyWith(priority: p),
          ),
          active: _manual.priority != null,
        ),
        menu<ProjectOption>(
          'project',
          Icons.folder_outlined,
          l.quickAddPickProject,
          [
            (null, l.quickAddNone),
            for (final p in lookups.projects) (p, p.name),
          ],
          (p) => setState(
            () => _manual = p == null
                ? _manual.copyWith(clearProject: true)
                : _manual.copyWith(project: p),
          ),
          active: _manual.project != null,
        ),
        menu<({AreaUid uid, String name})>(
          'area',
          Icons.layers_outlined,
          l.quickAddPickArea,
          [(null, l.quickAddNone), for (final a in lookups.areas) (a, a.name)],
          (a) => setState(
            () => _manual = a == null
                ? _manual.copyWith(clearArea: true)
                : _manual.copyWith(area: a),
          ),
          active: _manual.area != null,
        ),
        button('tags', Icons.sell_outlined, l.quickAddPickTags, () async {
          final picked = await _pickTags(context, lookups.tags, _manual.tags);
          if (picked != null && mounted) {
            setState(() => _manual = _manual.copyWith(tags: picked));
          }
        }, active: _manual.tags.isNotEmpty),
        button('repeat', Icons.repeat, l.quickAddPickRepeat, () async {
          final rule = await showRecurrenceEditor(
            context,
            initial: draft.recurrence,
          );
          if (rule == null || !mounted) return;
          setState(
            () => _manual = rule.isRecurring
                ? _manual.copyWith(recurrence: rule)
                : _manual.copyWith(clearRecurrence: true),
          );
        }, active: _manual.recurrence != null),
        button(
          'note',
          Icons.notes,
          l.quickAddPickNote,
          () => setState(() => _showNote = !_showNote),
          active: _showNote || _manual.note.isNotEmpty,
        ),
      ],
    );
  }

  Future<List<String>?> _pickTags(
    BuildContext context,
    List<String> known,
    List<String> current,
  ) => showDialog<List<String>>(
    context: context,
    builder: (_) => _TagDialog(known: known, selected: current),
  );
}

class _TagDialog extends StatefulWidget {
  const _TagDialog({required this.known, required this.selected});
  final List<String> known;
  final List<String> selected;

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final List<String> _selected = [...widget.selected];
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _toggle(String tag, bool on) => setState(() {
    _selected.removeWhere((t) => t.toLowerCase() == tag.toLowerCase());
    if (on) _selected.add(tag);
  });

  void _addTyped() {
    final name = _field.text.trim().replaceAll(RegExp(r'\s+'), '-');
    if (name.isEmpty) return;
    _toggle(name, true);
    _field.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = [
      ...widget.known,
      for (final t in _selected)
        if (!widget.known.any((k) => k.toLowerCase() == t.toLowerCase())) t,
    ];
    return AlertDialog(
      title: Text(l.quickAddPickTags),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _field,
              decoration: InputDecoration(hintText: l.quickAddTagHint),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTyped(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final t in all)
                  FilterChip(
                    label: Text(t),
                    selected: _selected.any(
                      (s) => s.toLowerCase() == t.toLowerCase(),
                    ),
                    onSelected: (on) => _toggle(t, on),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.taskCancel),
        ),
        FilledButton(
          onPressed: () {
            _addTyped();
            Navigator.pop(context, _selected);
          },
          child: Text(l.quickAddApply),
        ),
      ],
    );
  }
}
