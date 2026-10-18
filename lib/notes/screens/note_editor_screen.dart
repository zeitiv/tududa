import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' show Patch;
import '../../core/ids.dart';
import '../data/note_patch.dart';
import '../domain/note.dart';
import '../providers/note_provider.dart';
import '../widgets/note_card.dart' show parseNoteColor;
import '../../projects/providers/project_provider.dart';
import '../../l10n/l10n_ext.dart';

/// Note editor screen (create/edit) with Markdown support.
class NoteEditorScreen extends ConsumerStatefulWidget {
  /// The note's uid or local id (as in the `/notes/:id` route); null creates
  /// a note.
  final String? noteId;
  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _projectUid;

  /// Only a project the user picked is written back, so a note whose
  /// project has no uid yet keeps it.
  bool _projectChanged = false;
  String? _color;
  bool _isLoading = false;
  bool _isEdit = false;

  /// Markdown preview instead of the content field.
  bool _preview = false;

  /// Tags of the loaded note (shown as chips; edited on the server side).
  List<String> _tagNames = const [];

  // What the form held when it was opened / loaded, for the unsaved guard.
  String _initialTitle = '';
  String _initialContent = '';
  String? _initialColor;
  String? _initialProjectUid;

  /// Set once saved, deleted or discarded so leaving does not ask again.
  bool _leaving = false;
  bool _wasDirty = false;

  bool get _dirty =>
      !_leaving &&
      (_titleController.text != _initialTitle ||
          _contentController.text != _initialContent ||
          _color != _initialColor ||
          _projectUid != _initialProjectUid);

  void _syncDirty() {
    final d = _dirty;
    if (d != _wasDirty) setState(() => _wasDirty = d);
  }

  static const _colors = [
    null,
    '#FFD6D6',
    '#FFE4CC',
    '#FFF3CC',
    '#D6FFD6',
    '#CCE5FF',
    '#E8CCFF',
    '#FFCCE5',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_syncDirty);
    _contentController.addListener(_syncDirty);
    if (widget.noteId != null) {
      _isEdit = true;
      _loadNote();
    }
  }

  /// Resolved from the route id once loaded; all edits go by local id so
  /// notes that have no uid yet can be saved too.
  LocalId? _localId;

  Future<void> _loadNote() async {
    setState(() => _isLoading = true);
    try {
      final note = await ref
          .read(noteRepositoryProvider)
          .findByRouteId(widget.noteId!);
      if (!mounted) return;
      if (note == null) {
        setState(() => _isLoading = false);
        return;
      }
      _localId = note.localId;
      _titleController.text = note.title ?? '';
      _contentController.text = note.content ?? '';
      setState(() {
        _projectUid = note.projectUid?.value;
        _color = note.color;
        _tagNames = [for (final t in note.tags) t.name];
        _initialTitle = _titleController.text;
        _initialContent = _contentController.text;
        _initialColor = _color;
        _initialProjectUid = _projectUid;
        _wasDirty = false;
        _isLoading = false;
      });
    } on ApiError {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final notifier = ref.read(noteListProvider.notifier);
    final projectUid = _projectUid == null ? null : ProjectUid(_projectUid!);

    bool success;
    try {
      if (_isEdit) {
        final id = _localId;
        if (id == null) throw const NotFoundError('Note not found');
        await notifier.updateNoteLocal(
          id,
          NotePatch(
            title: title.isEmpty ? const Patch.clear() : Patch.set(title),
            content: Patch.set(content),
            color: _color == null ? const Patch.clear() : Patch.set(_color!),
            projectUid: !_projectChanged
                ? const Patch.unset()
                : projectUid == null
                ? const Patch.clear()
                : Patch.set(projectUid),
          ),
        );
      } else {
        await notifier.create(
          NoteDraft(
            title: title.isEmpty ? null : title,
            content: content,
            color: _color,
            projectUid: projectUid,
          ),
        );
      }
      success = true;
    } on ApiError {
      success = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _leaving = true;
        context.pop();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.noteSaveFailed)));
      }
    }
  }

  Future<void> _delete() async {
    if (widget.noteId == null || _localId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.noteDeleteTitle),
        content: Text(ctx.l10n.noteDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(noteListProvider.notifier).deleteNoteLocal(_localId!);
      } on ApiError {
        // Stay on the screen so the user can retry.
        return;
      }
      if (mounted) {
        _leaving = true;
        context.pop();
      }
    }
  }

  /// Back with unsaved changes: ask before throwing them away.
  Future<void> _confirmDiscard() async {
    final strings = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.noteV2DiscardTitle),
        content: Text(strings.noteV2DiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.noteV2KeepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.noteV2Discard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _leaving = true;
      context.pop();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectListProvider).value ?? const [];
    final strings = context.l10n;

    final selectedProject = _projectUid == null
        ? null
        : projects.where((p) => p.uid.value == _projectUid).firstOrNull;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? strings.noteEdit : strings.noteNew),
          actions: [
            if (_isEdit)
              IconButton(
                tooltip: strings.commonDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                onPressed: _delete,
              ),
            TextButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.commonSave),
            ),
          ],
        ),
        body: _isLoading && _isEdit
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.titleLarge,
                    decoration: InputDecoration(
                      hintText: strings.noteTitleHint,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      hintStyle: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Project and tag chips
                  if (selectedProject != null || _tagNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (selectedProject != null)
                            Chip(
                              avatar: const Icon(Icons.folder_outlined),
                              label: Text(selectedProject.name),
                            ),
                          for (final tag in _tagNames)
                            Chip(
                              avatar: const Icon(Icons.sell_outlined),
                              label: Text(tag),
                            ),
                        ],
                      ),
                    ),

                  // Edit / preview toggle (chips: the app bar's Save is the
                  // screen's only TextButton)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (preview, icon, label) in [
                        (false, Icons.edit_outlined, strings.noteV2ModeEdit),
                        (
                          true,
                          Icons.visibility_outlined,
                          strings.noteV2ModePreview,
                        ),
                      ])
                        ChoiceChip(
                          avatar: Icon(icon),
                          label: Text(label),
                          selected: _preview == preview,
                          showCheckmark: false,
                          onSelected: (_) {
                            FocusScope.of(context).unfocus();
                            setState(() => _preview = preview);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Content
                  if (_preview)
                    _contentController.text.trim().isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              strings.noteV2PreviewEmpty,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : MarkdownBody(
                            data: _contentController.text,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(p: theme.textTheme.bodyLarge),
                          )
                  else
                    TextFormField(
                      controller: _contentController,
                      maxLines: null,
                      minLines: 12,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: strings.noteContentHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: false,
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),

                  const Divider(height: 32),

                  // Color picker
                  Text(strings.noteColor, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 0,
                    runSpacing: 0,
                    children: _colors.indexed.map((entry) {
                      final (index, c) = entry;
                      final isSelected = _color == c;
                      final displayColor =
                          parseNoteColor(c) ?? theme.colorScheme.surface;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: c == null
                            ? strings.a11yNoteColorNone
                            : strings.a11yNoteColorOption(
                                index,
                                _colors.length - 1,
                              ),
                        child: InkResponse(
                          radius: 24,
                          // 48dp tap target around the 40dp swatch.
                          onTap: () {
                            setState(() => _color = c);
                            _syncDirty();
                          },
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: displayColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: c == null
                                    ? Icon(
                                        Icons.format_color_reset,
                                        size: 16,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      )
                                    : isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Colors.black87,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Project
                  DropdownButtonFormField<String?>(
                    initialValue: _projectUid,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings.noteProject,
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(strings.commonNone),
                      ),
                      ...projects.map(
                        (p) => DropdownMenuItem(
                          value: p.uid.value,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _projectUid = v;
                        _projectChanged = true;
                      });
                      _syncDirty();
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}
