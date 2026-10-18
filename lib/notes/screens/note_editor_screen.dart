import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/patch.dart' show Patch;
import '../../core/ids.dart';
import '../data/note_patch.dart';
import '../domain/note.dart';
import '../providers/note_provider.dart';
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
      if (mounted) context.pop();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? strings.noteEdit : strings.noteNew),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: strings.commonDelete,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
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

                const Divider(),

                // Content
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
                  spacing: 10,
                  children: _colors.map((c) {
                    final isSelected = _color == c;
                    final displayColor = c != null
                        ? Color(
                            int.parse(
                              'FF${c.replaceFirst('#', '')}',
                              radix: 16,
                            ),
                          )
                        : theme.colorScheme.surface;
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 36,
                        height: 36,
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
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Project
                DropdownButtonFormField<String?>(
                  initialValue: _projectUid,
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
                        child: Text(p.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _projectUid = v;
                    _projectChanged = true;
                  }),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
