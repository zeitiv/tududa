import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/links.dart';
import '../data/tududi.dart';
import '../tasks/models/task_model.dart';
import 'apps/task_sheet.dart';
import 'capture_logic.dart';
import 'kit/controls.dart';
import 'kit/glass.dart';
import 'kit/motion.dart';
import 'kit/tokens.dart';
import 'l10n.dart';
import 'os.dart';

const _targets = <Target, (String, IconData, AppId)>{
  Target.task: ('Task', Icons.check_circle_outline_rounded, AppId.tasks),
  Target.inbox: ('Inbox', Icons.inbox_outlined, AppId.inbox),
  Target.memo: ('Memo', Icons.bolt_outlined, AppId.memos),
  Target.bookmark: ('Bookmark', Icons.bookmark_outline_rounded, AppId.karakeep),
  Target.shopping: ('Shopping', Icons.shopping_basket_outlined, AppId.flat),
};

/// One field for everything. Type a line: it guesses where it belongs
/// (a link is a bookmark, "buy …" goes on the shopping list) and Enter
/// sends it there. The same field searches what is already in the system.
class CaptureLayer extends ConsumerWidget {
  final bool wide;
  const CaptureLayer({super.key, required this.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(osProvider.select((s) => s.capture));
    final pad = MediaQuery.paddingOf(context);
    return SpringBuilder(
      value: on ? 1 : 0,
      spec: const Spec(380, 30),
      builder: (context, v, _) {
        if (!on && v < 0.02) return const SizedBox.shrink();
        final t = v.clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => ref.read(osProvider.notifier).setCapture(false),
                child: ColoredBox(color: Color.fromRGBO(4, 5, 7, 0.62 * t)),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, pad.top + (wide ? 96 : 10), 12, 0),
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * -28),
                  child: Transform.scale(
                    scale: 0.95 + 0.05 * v,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Glass(
                          radius: 26,
                          blur: 36,
                          shadow: true,
                          opacity: t,
                          fill: const Color(0xE012141A),
                          child: Opacity(
                            opacity: t,
                            child: on ? const _CapturePanel() : const SizedBox(height: 120),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Hit {
  final IconData icon;
  final String title;
  final String source;
  final void Function(BuildContext context) open;
  const _Hit(this.icon, this.title, this.source, this.open);
}

class _CapturePanel extends ConsumerStatefulWidget {
  const _CapturePanel();

  @override
  ConsumerState<_CapturePanel> createState() => _CapturePanelState();
}

class _CapturePanelState extends ConsumerState<_CapturePanel> {
  final _text = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _key);
  Target? _manual;

  Set<Target> get _on => {
        Target.task,
        Target.inbox,
        if (ref.read(memosProvider).status == Link.live) Target.memo,
        if (ref.read(karakeepProvider).status == Link.live) Target.bookmark,
        if (ref.read(flatProvider).status == Link.live) Target.shopping,
      };

  Target get _target {
    final on = _on;
    if (_manual != null && on.contains(_manual)) return _manual!;
    return suggest(_text.text, on);
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      final on = [for (final t in Target.values) if (_on.contains(t)) t];
      final step = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
      setState(() => _manual = on[(on.indexOf(_target) + step) % on.length]);
      tick();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      ref.read(osProvider.notifier).setCapture(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    // The shell already holds the focus, so autofocus alone would be ignored.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final target = _target;
    final os = ref.read(osProvider.notifier);
    final (name, _, app) = _targets[target]!;
    thud();
    os.setCapture(false);
    os.toast(
      tr('Saved to {where}', {'where': tr(apps[app]!.name)}),
      action: tr('Open'),
      onAction: () => os.open(app),
    );
    final ok = await switch (target) {
      Target.task => ref.read(tasksProvider.notifier).add(Task(name: text)),
      Target.inbox => ref.read(inboxProvider.notifier).add(text),
      Target.memo => ref.read(memosProvider.notifier).add(text),
      Target.bookmark => ref.read(karakeepProvider.notifier).add(text),
      Target.shopping => ref.read(flatProvider.notifier).addItem(shoppingName(text)),
    };
    if (!ok) os.toast(tr('Could not save to {where}', {'where': tr(name)}));
  }

  List<_Hit> _search(String q) {
    if (q.length < 2) return const [];
    final n = q.toLowerCase();
    bool has(String? s) => s != null && s.toLowerCase().contains(n);
    final os = ref.read(osProvider.notifier);
    final hits = <_Hit>[
      for (final t in ref.read(tasksProvider).open)
        if (has(t.name))
          _Hit(Icons.check_circle_outline_rounded, t.name, 'Tududi', (context) {
            os.open(AppId.tasks);
            showTaskSheet(context, t);
          }),
      for (final p in ref.read(projectsProvider).items)
        if (has(p.name)) _Hit(Icons.layers_outlined, p.name, 'Tududi', (_) => os.open(AppId.projects)),
      for (final note in ref.read(notesProvider).items)
        if (has(note.title) || has(note.content))
          _Hit(Icons.notes_rounded, note.title ?? '', 'Tududi', (_) => os.open(AppId.notes)),
      for (final b in ref.read(karakeepProvider).items)
        if (has(b.title) || has(b.url))
          _Hit(Icons.bookmark_outline_rounded, b.title, 'Karakeep', (_) => os.open(AppId.karakeep)),
      for (final m in ref.read(memosProvider).items)
        if (has(m.content))
          _Hit(Icons.bolt_outlined, m.content.split('\n').first, 'Memos', (_) => os.open(AppId.memos)),
      for (final i in ref.read(flatProvider).shopping)
        if (has(i.name))
          _Hit(Icons.shopping_basket_outlined, i.name, 'Flatastic', (_) => os.open(AppId.flat)),
    ];
    return hits.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final on = _on;
    final target = _target;
    final hits = _search(_text.text.trim());
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            focusNode: _focus,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: sans(20, w: 500, height: 1.3),
            cursorWidth: 1.5,
            decoration: InputDecoration(
              hintText: tr('A task, a thought, a link…'),
              hintStyle: sans(20, color: Tk.ink3),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
            ),
          ),
          // Wrapped, so the chosen destination is never off the edge.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [

                for (final t in Target.values)
                  if (on.contains(t))
                    OsChip(
                        tr(_targets[t]!.$1),
                        icon: _targets[t]!.$2,
                        on: t == target,
                        onTap: () {
                          setState(() => _manual = t);
                          _focus.requestFocus();
                        },
                    ),
            ],
          ),
          if (hits.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(padding: const EdgeInsets.only(left: 6, bottom: 4), child: Label(tr('Already here'))),
            for (final h in hits)
              Pressable(
                onTap: () {
                  ref.read(osProvider.notifier).setCapture(false);
                  h.open(context);
                },
                scale: 0.985,
                builder: (context, hover, down) => Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: hover ? 0.06 : 0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(h.icon, size: 17, color: Tk.ink3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(h.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14.5)),
                      ),
                      Label(h.source, size: 9.5),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Label(
                  context.isWide ? tr('Enter to save · Tab to change where') : tr('Pick where it goes'),
                  size: 9.5,
                ),
              ),
              OsButton(
                tr('Save'),
                icon: Icons.arrow_upward_rounded,
                primary: true,
                onTap: _text.text.trim().isEmpty ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
