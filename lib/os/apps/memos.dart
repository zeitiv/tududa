import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/links.dart';
import '../../data/tududi.dart';
import '../../tasks/models/task_model.dart';
import '../kit/controls.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../wall.dart' show ago;
import '../window.dart';
import 'karakeep.dart' show NotLinked;
import 'notes.dart' show mdStyle;
import 'tasks.dart';

class MemosApp extends ConsumerWidget {
  const MemosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(memosProvider);
    final m = ref.read(memosProvider.notifier);
    final os = ref.read(osProvider.notifier);
    if (s.status == Link.off || (s.status == Link.error && s.items.isEmpty)) {
      return NotLinked(
        app: AppId.memos,
        error: s.error,
        pitch: 'A stream of quick thoughts from your Memos server. Write one in a second.',
      );
    }
    final list = s.sorted;
    return AppPane(
      app: AppId.memos,
      sub: tr('{n} memos', {'n': list.length}),
      body: s.status == Link.busy && list.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: Loading())
          : list.isEmpty
              ? Empty(tr('No memos yet'), hint: tr('Write the first one below.'))
              : RefreshIndicator(
                  onRefresh: m.refresh,
                  color: context.accent,
                  backgroundColor: const Color(0xFF1A1C22),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final memo = list[i];
                      return Enter(
                        key: ValueKey(memo.name),
                        i: i,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.fromLTRB(16, 14, 6, 4),
                          decoration: BoxDecoration(
                            color: Tk.fill,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: memo.pinned ? context.accent.withValues(alpha: 0.5) : Tk.rule,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: MarkdownBody(data: memo.content, styleSheet: mdStyle(context)),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Label([
                                      if (memo.pinned) tr('Pinned'),
                                      ago(memo.time),
                                      ...memo.tags.take(2).map((t) => '#$t'),
                                    ].where((e) => e.isNotEmpty).join(' · ')),
                                  ),
                                  OsIconButton(
                                    memo.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                    tooltip: tr('Pin'),
                                    filled: false,
                                    size: 40,
                                    color: memo.pinned ? context.accent : Tk.ink3,
                                    onTap: () => m.save(memo.copyWith(pinned: !memo.pinned)),
                                  ),
                                  OsIconButton(
                                    Icons.add_task_rounded,
                                    tooltip: tr('Make it a task'),
                                    filled: false,
                                    size: 40,
                                    color: Tk.ink3,
                                    onTap: () {
                                      final lines = memo.content.trim().split('\n');
                                      ref.read(tasksProvider.notifier).add(Task(
                                            name: lines.first.replaceAll(RegExp(r'[*_#`]'), '').trim(),
                                            note: lines.length > 1 ? memo.content : null,
                                          ));
                                      thud();
                                      os.toast(tr('Added to Tasks'),
                                          action: tr('Open'), onAction: () => os.open(AppId.tasks));
                                    },
                                  ),
                                  OsIconButton(
                                    Icons.edit_outlined,
                                    tooltip: tr('Edit'),
                                    filled: false,
                                    size: 40,
                                    color: Tk.ink3,
                                    onTap: () => showOsSheet(context, (_) => _MemoEditor(memo)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottom: QuickAdd(hint: tr('What is on your mind?'), maxLines: 4, onAdd: m.add),
    );
  }
}

class _MemoEditor extends ConsumerStatefulWidget {
  final Memo memo;
  const _MemoEditor(this.memo);

  @override
  ConsumerState<_MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends ConsumerState<_MemoEditor> {
  late final _text = TextEditingController(text: widget.memo.content);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.read(memosProvider.notifier);
    return SheetBody(
      label: 'Memos',
      title: tr('Memo'),
      actions: [
        OsButton(tr('Delete'), danger: true, onTap: () {
          Navigator.of(context).pop();
          m.remove(widget.memo);
          ref.read(osProvider.notifier).toast(tr('Memo deleted'));
        }),
        OsButton(tr('Save'), primary: true, onTap: () {
          Navigator.of(context).pop();
          m.save(widget.memo.copyWith(content: _text.text.trim()));
        }),
      ],
      children: [OsField(controller: _text, maxLines: 12, minLines: 4, autofocus: true)],
    );
  }
}
