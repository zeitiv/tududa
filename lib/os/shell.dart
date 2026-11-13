import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/providers/auth_provider.dart';
import '../data/links.dart';
import '../data/session.dart';
import '../data/tududi.dart';
import 'apps/flat.dart';
import 'apps/inbox.dart';
import 'apps/karakeep.dart';
import 'apps/memos.dart';
import 'apps/notes.dart';
import 'apps/projects.dart';
import 'apps/settings.dart';
import 'apps/tasks.dart';
import 'capture.dart';
import 'kit/backdrop.dart';
import 'kit/controls.dart';
import 'kit/dots.dart';
import 'kit/glass.dart';
import 'kit/motion.dart';
import 'kit/tokens.dart';
import 'l10n.dart';
import 'os.dart';
import 'wall.dart';
import 'window.dart';

Widget appBody(AppId app) => switch (app) {
      AppId.tasks => const TasksApp(),
      AppId.projects => const ProjectsApp(),
      AppId.notes => const NotesApp(),
      AppId.inbox => const InboxApp(),
      AppId.karakeep => const KarakeepApp(),
      AppId.memos => const MemosApp(),
      AppId.flat => const FlatApp(),
      AppId.settings => const SettingsApp(),
    };

/// The system: the room, the wall of cards, the windows over it, the
/// status bar, the dock, and the capture bar above everything.
class OsShell extends ConsumerStatefulWidget {
  const OsShell({super.key});

  @override
  ConsumerState<OsShell> createState() => _OsShellState();
}

class _OsShellState extends ConsumerState<OsShell> with WidgetsBindingObserver {
  Timer? _sync;
  final FocusNode _focus = FocusNode(debugLabel: 'shell');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await Future.wait([
        ref.read(karakeepProvider.notifier).restore(),
        ref.read(memosProvider.notifier).restore(),
        ref.read(flatProvider.notifier).restore(),
        ref.read(tasksProvider.notifier).load(),
        ref.read(projectsProvider.notifier).load(),
        ref.read(areasProvider.notifier).load(),
        ref.read(notesProvider.notifier).load(),
        ref.read(inboxProvider.notifier).load(),
      ]);
      if (mounted) ref.read(tasksProvider.notifier).loadDone();
    });
    // Live: everything is fetched again every minute while the app is up.
    _sync = Timer.periodic(const Duration(seconds: 60), (_) => syncAll(ref));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) syncAll(ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final os = ref.watch(osProvider);
    final ctl = ref.read(osProvider.notifier);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => ctl.setCapture(true),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => ctl.setCapture(true),
        const SingleActivator(LogicalKeyboardKey.escape): ctl.closeTop,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: PopScope(
          canPop: os.open.isEmpty && !os.capture,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) ctl.closeTop();
          },
          child: Scaffold(
            backgroundColor: Tk.bg,
            resizeToAvoidBottomInset: false,
            body: LayoutBuilder(builder: (context, box) => _layout(context, box.biggest, os, ctl)),
          ),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, Size size, OsState os, OsNotifier ctl) {
    final wide = size.width >= Tk.wide;
    final pad = MediaQuery.paddingOf(context);
    final live = os.open;
    final any = live.isNotEmpty;

    // Where the windows stand.
    final stage = wide
        ? Rect.fromLTRB(104, pad.top + 68, size.width - 22, size.height - 22)
        : Rect.fromLTRB(6, pad.top + 6, size.width - 6, size.height - 6);
    final fit = wide ? (stage.width / 430).floor().clamp(1, 3) : 1;
    if (ctl.max != fit) {
      ctl.max = fit;
      WidgetsBinding.instance.addPostFrameCallback((_) => ctl.fit());
    }
    final slots = <AppId, Rect>{};
    if (any) {
      final n = live.length.clamp(1, fit);
      const gap = 16.0;
      final each = ((stage.width - gap * (n - 1)) / n).clamp(0.0, n == 1 ? 900.0 : 720.0);
      final total = each * n + gap * (n - 1);
      var x = stage.left + (stage.width - total) / 2;
      for (final w in live.skip(live.length - n)) {
        slots[w.app] = Rect.fromLTWH(
          x.roundToDouble(), stage.top, each.floorToDouble(), stage.height.floorToDouble());
        x += each + gap;
      }
    }
    final fallback = slots.isEmpty ? stage : slots.values.last;

    return Stack(
      children: [
        const Positioned.fill(child: Backdrop()),
        Positioned.fill(
          child: SpringBuilder(
            value: any ? 1 : 0,
            spec: Spec.gentle,
            child: IgnorePointer(ignoring: any, child: ExcludeSemantics(excluding: any, child: Wall(wide: wide))),
            builder: (context, v, child) =>
                Transform.scale(scale: 1 - 0.05 * v.clamp(0.0, 1.2), child: child),
          ),
        ),
        // The room dims behind open windows; a tap on it goes home.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !any,
            child: GestureDetector(
              onTap: ctl.home,
              child: AnimatedOpacity(
                opacity: any ? 1 : 0,
                duration: Duration(milliseconds: Motion.reduced ? 1 : 320),
                child: const ColoredBox(color: Color(0x99050608)),
              ),
            ),
          ),
        ),
        Positioned(
          top: pad.top,
          left: 0,
          right: 0,
          child: StatusBar(wide: wide),
        ),
        for (final w in os.wins)
          WindowFrame(
            key: ValueKey(w.app),
            win: w,
            slot: slots[w.app] ?? fallback,
            phone: !wide,
            child: appBody(w.app),
          ),
        if (wide)
          Positioned(left: 20, top: pad.top + 68, bottom: 22, child: const Center(child: Dock(wide: true)))
        else
          Positioned(
            left: 0,
            right: 0,
            bottom: pad.bottom + 14,
            child: SpringBuilder(
              value: any ? 1 : 0,
              spec: Spec.fluid,
              child: const Center(child: Dock(wide: false)),
              builder: (context, v, child) =>
                  Transform.translate(offset: Offset(0, v * 130), child: child),
            ),
          ),
        Positioned.fill(child: CaptureLayer(wide: wide)),
        Positioned(
          left: 16,
          right: 16,
          bottom: pad.bottom + (wide ? 28 : 96) + MediaQuery.viewInsetsOf(context).bottom,
          child: const ToastHost(),
        ),
      ],
    );
  }
}

Color lampColor(Link s) => switch (s) {
      Link.live => Tk.ok,
      Link.busy => Tk.warn,
      Link.error => Tk.signal,
      Link.off => const Color(0x40FFFFFF),
    };

/// The strip along the top: the wordmark and the time on a dot matrix, the
/// capture bar, and a lamp for every service.
class StatusBar extends ConsumerStatefulWidget {
  final bool wide;
  const StatusBar({super.key, required this.wide});

  @override
  ConsumerState<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends ConsumerState<StatusBar> {
  late Timer _timer;
  String _time = DateFormat('HH:mm').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateFormat('HH:mm').format(DateTime.now());
      if (now != _time) setState(() => _time = now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final auth = ref.watch(authProvider);
    final tududi = auth.demo
        ? Link.live
        : tasks.error != null
            ? Link.error
            : tasks.loaded
                ? Link.live
                : Link.busy;
    final lamps = <(String, Link)>[
      (auth.demo ? 'Demo' : 'Tududi', tududi),
      ('Karakeep', ref.watch(karakeepProvider.select((s) => s.status))),
      ('Memos', ref.watch(memosProvider.select((s) => s.status))),
      ('Flatastic', ref.watch(flatProvider.select((s) => s.status))),
    ];
    final ctl = ref.read(osProvider.notifier);
    final status = Builder(
      builder: (context) => Pressable(
        onTap: () => ctl.open(AppId.settings, origin: rectOf(context)),
        label: tr('Connections'),
        scale: 0.94,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (name, link) in lamps) ...[
                Tooltip(
                  message: '$name · ${tr(link.name)}',
                  child: Lamp(lampColor(link), pulse: link == Link.live),
                ),
                if (widget.wide) ...[
                  const SizedBox(width: 3),
                  Label(name, color: link == Link.off ? Tk.ink3 : Tk.ink2, size: 9.5),
                  const SizedBox(width: 12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
    final clock = DotText(_time, dot: widget.wide ? 2.6 : 2.4, gap: 1.2);

    if (!widget.wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 10, 0),
        child: Row(children: [clock, const Spacer(), status]),
      );
    }
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            const DotText('TUDUDA', dot: 2.6, gap: 1.2),
            const Spacer(),
            Pressable(
              onTap: () => ctl.setCapture(true),
              label: tr('Capture or search'),
              scale: 0.97,
              radius: BorderRadius.circular(21),
              child: Glass(
                radius: 21,
                blur: 20,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 340,
                  height: 42,
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 18, color: Tk.ink2),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(tr('Capture or search'), style: sans(14, color: Tk.ink3)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: Tk.rule),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('⌘K', style: mono(10, ls: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            status,
            const SizedBox(width: 6),
            clock,
          ],
        ),
      ),
    );
  }
}

/// The dock: a capsule of glass with the apps in it. The lit dot marks
/// what is open; the round button in the accent captures.
class Dock extends ConsumerWidget {
  final bool wide;
  const Dock({super.key, required this.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final os = ref.watch(osProvider);
    final ctl = ref.read(osProvider.notifier);
    final list = wide
        ? AppId.values
        : const [AppId.tasks, AppId.projects, AppId.inbox, AppId.notes];

    Widget item(AppId id) {
      final on = os.isOpen(id);
      return Builder(
        builder: (context) => Tooltip(
          message: tr(apps[id]!.name),
          preferBelow: false,
          child: Pressable(
            onTap: () => ctl.toggle(id, origin: rectOf(context)),
            label: tr(apps[id]!.name),
            scale: 0.84,
            lift: 1.08,
            radius: BorderRadius.circular(16),
            builder: (context, hover, down) => SizedBox(
              width: wide ? 50 : 54,
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: on ? 0.12 : (hover ? 0.07 : 0)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(apps[id]!.icon, size: 22, color: on ? Tk.ink : Tk.ink2),
                  ),
                  Positioned(
                    left: wide ? 0 : null,
                    bottom: wide ? null : 0,
                    child: SpringBuilder(
                      value: on ? 1 : 0,
                      spec: Spec.bouncy,
                      builder: (context, v, _) => Transform.scale(
                        scale: v.clamp(0.0, 1.4),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: context.accent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final capture = Tooltip(
      message: tr('Capture'),
      child: Pressable(
        onTap: () => ctl.setCapture(true),
        label: tr('Capture'),
        scale: 0.86,
        lift: 1.06,
        radius: BorderRadius.circular(26),
        child: Container(
          width: wide ? 46 : 52,
          height: wide ? 46 : 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.accent),
          child: const Icon(Icons.add_rounded, color: Tk.bg, size: 26),
        ),
      ),
    );

    final children = wide
        ? [
            capture,
            const SizedBox(height: 10),
            for (final id in list) ...[
              if (id == AppId.karakeep || id == AppId.settings)
                Container(
                  width: 22,
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  color: Tk.rule,
                ),
              item(id),
            ],
          ]
        : [item(list[0]), item(list[1]), const SizedBox(width: 6), capture, const SizedBox(width: 6), item(list[2]), item(list[3])];

    return Glass(
      radius: wide ? 32 : 34,
      blur: 30,
      shadow: true,
      fill: const Color(0xB3101216),
      padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 10, vertical: wide ? 10 : 8),
      child: wide
          ? Column(mainAxisSize: MainAxisSize.min, children: children)
          : Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// One line of feedback, up from the bottom, sometimes with an undo.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(osProvider.select((s) => s.toast));
    return IgnorePointer(
      ignoring: toast == null,
      child: SpringBuilder(
        value: toast == null ? 0 : 1,
        spec: Spec.bouncy,
        builder: (context, v, _) {
          if (v < 0.01 && toast == null) return const SizedBox.shrink();
          return Transform.translate(
            offset: Offset(0, (1 - v) * 120),
            child: Center(
              child: toast == null
                  ? const SizedBox.shrink()
                  : Material(
                      type: MaterialType.transparency,
                      child: Glass(
                        key: ValueKey(toast.id),
                        radius: 22,
                        blur: 26,
                        shadow: true,
                        fill: const Color(0xE616181E),
                        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Lamp(context.accent, size: 6),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(toast.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: sans(14, w: 500)),
                              ),
                            ),
                            if (toast.action != null) ...[
                              const SizedBox(width: 10),
                              Pressable(
                                onTap: () {
                                  toast.onAction?.call();
                                  ref.read(osProvider.notifier).clearToast();
                                },
                                label: toast.action,
                                child: Container(
                                  height: 36,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(toast.action!,
                                      style: sans(14, w: 650, color: context.accent)),
                                ),
                              ),
                            ] else
                              const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
