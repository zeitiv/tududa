import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tududi.dart';
import '../../notes/models/note_model.dart';
import '../kit/controls.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../wall.dart' show ago;
import '../window.dart';

MarkdownStyleSheet mdStyle(BuildContext context) => MarkdownStyleSheet(
      p: sans(15, height: 1.5),
      h1: sans(22, w: 680, wdth: 110, height: 1.2),
      h2: sans(18.5, w: 650, wdth: 108, height: 1.25),
      h3: sans(16, w: 650, height: 1.3),
      strong: sans(15, w: 700, height: 1.5),
      em: sans(15, height: 1.5).copyWith(fontStyle: FontStyle.italic),
      a: sans(15, color: context.accent, height: 1.5, decoration: TextDecoration.underline),
      code: mono(13, color: Tk.ink, ls: 0),
      listBullet: sans(15, color: Tk.ink3, height: 1.5),
      blockquote: sans(15, color: Tk.ink2, height: 1.5),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0x40FFFFFF), width: 2)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      codeblockDecoration: BoxDecoration(color: Tk.fill, borderRadius: BorderRadius.circular(10)),
      horizontalRuleDecoration:
          const BoxDecoration(border: Border(top: BorderSide(color: Tk.rule))),
      blockSpacing: 10,
    );

class NotesApp extends ConsumerStatefulWidget {
  const NotesApp({super.key});

  @override
  ConsumerState<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends ConsumerState<NotesApp> {
  Note? _editing;
  bool _new = false;

  @override
  Widget build(BuildContext context) {
    if (_editing != null || _new) {
      return _NoteEditor(
        key: ValueKey(_editing?.id),
        note: _editing,
        onBack: () => setState(() {
          _editing = null;
          _new = false;
        }),
      );
    }
    final s = ref.watch(notesProvider);
    return AppPane(
      app: AppId.notes,
      sub: tr('{n} notes', {'n': s.items.length}),
      actions: [
        OsIconButton(Icons.add_rounded,
            onTap: () => setState(() => _new = true), tooltip: tr('New note')),
      ],
      body: !s.loaded && s.loading
          ? const Padding(padding: EdgeInsets.all(16), child: Loading())
          : s.items.isEmpty
              ? Empty(tr('No notes yet'),
                  hint: tr('Longer thoughts, in Markdown, next to your projects.'),
                  action: OsButton(tr('Write one'), onTap: () => setState(() => _new = true)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  itemCount: s.items.length,
                  itemBuilder: (context, i) {
                    final n = s.items[i];
                    final snippet =
                        (n.content ?? '').replaceAll(RegExp(r'[#*_>`\-]'), '').replaceAll('\n', ' ').trim();
                    return Enter(
                      i: i,
                      child: RowTile(
                        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                        onTap: () => setState(() => _editing = n),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((n.title ?? '').isEmpty ? tr('Untitled') : n.title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: sans(16.5, w: 600, wdth: 106)),
                            if (snippet.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(snippet,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: sans(14, color: Tk.ink2, height: 1.35)),
                            ],
                            const SizedBox(height: 6),
                            Label([
                              if (n.projectName != null) n.projectName!,
                              ago(n.updatedAt ?? n.createdAt),
                            ].where((e) => e.isNotEmpty).join(' · ')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  final Note? note;
  final VoidCallback onBack;
  const _NoteEditor({super.key, this.note, required this.onBack});

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _content = TextEditingController(text: widget.note?.content ?? '');
  late bool _preview = widget.note != null && (widget.note!.content ?? '').isNotEmpty;

  bool get _dirty =>
      _title.text != (widget.note?.title ?? '') || _content.text != (widget.note?.content ?? '');

  /// Leaving saves; there is no save button to forget.
  void _leave() {
    final title = _title.text.trim();
    final content = _content.text;
    final notes = ref.read(notesProvider.notifier);
    if (_dirty && (title.isNotEmpty || content.trim().isNotEmpty)) {
      final n = widget.note;
      if (n == null) {
        notes.add(Note(title: title.isEmpty ? tr('Untitled') : title, content: content));
      } else {
        notes.save(n.copyWith(title: title, content: content));
      }
      ref.read(osProvider.notifier).toast(tr('Note saved'));
    }
    widget.onBack();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return AppPane(
      app: AppId.notes,
      title: n == null ? tr('New note') : tr('Note'),
      sub: n?.projectName,
      onBack: _leave,
      actions: [
        OsIconButton(
          _preview ? Icons.edit_outlined : Icons.visibility_outlined,
          onTap: () => setState(() => _preview = !_preview),
          tooltip: _preview ? tr('Edit') : tr('Preview'),
        ),
        if (n != null)
          OsIconButton(Icons.delete_outline_rounded, tooltip: tr('Delete'), onTap: () {
            ref.read(notesProvider.notifier).remove(n);
            ref.read(osProvider.notifier).toast(tr('Note deleted'));
            widget.onBack();
          }),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              style: sans(24, w: 680, wdth: 110),
              cursorWidth: 1.5,
              decoration: InputDecoration(
                hintText: tr('Title'),
                hintStyle: sans(24, w: 680, wdth: 110, color: Tk.ink3),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _preview
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: () => setState(() => _preview = false),
                      child: SingleChildScrollView(
                        child: MarkdownBody(data: _content.text, styleSheet: mdStyle(context)),
                      ),
                    )
                  : TextField(
                      controller: _content,
                      autofocus: n == null,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: sans(15.5, height: 1.5),
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        hintText: tr('Write in Markdown…'),
                        hintStyle: sans(15.5, color: Tk.ink3),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
