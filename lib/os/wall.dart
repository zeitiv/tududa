import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/providers/auth_provider.dart';
import '../data/links.dart';
import '../data/tududi.dart';
import 'apps/tasks.dart';
import 'kit/controls.dart';
import 'kit/dots.dart';
import 'kit/glass.dart';
import 'kit/motion.dart';
import 'kit/tokens.dart';
import 'l10n.dart';
import 'os.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String ago(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr('now');
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  if (d.inDays < 7) return '${d.inDays} d';
  return DateFormat('d MMM', L.code).format(t);
}

/// Home: a wall of cards, one for each part of the system, each showing
/// what matters there now. A card opens into its app.
class Wall extends ConsumerWidget {
  final bool wide;
  const Wall({super.key, required this.wide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pad = MediaQuery.paddingOf(context);
    final user = ref.watch(authProvider.select((s) => s.user));
    final hour = DateTime.now().hour;
    final hello = hour < 5
        ? 'Good night'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
    final name = (user?.name ?? '').trim();
    const gap = 14.0;

    final header = Enter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(DateFormat('EEEE d MMMM', L.code).format(DateTime.now())),
          const SizedBox(height: 8),
          Text(
            name.isEmpty ? tr(hello) : '${tr(hello)}, $name',
            maxLines: 2,
            style: sans(wide ? 44 : 32, w: 700, wdth: 116, height: 1.05, ls: -0.5),
          ),
        ],
      ),
    );

    Widget row(List<Widget> kids, {double? height}) => SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < kids.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: kids[i]),
              ],
            ],
          ),
        );

    final Widget grid;
    if (wide) {
      const h = 182.0;
      grid = SizedBox(
        height: h * 2 + gap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 10, child: _TodayCard(i: 1, rows: 4, fixed: true)),
            const SizedBox(width: gap),
            Expanded(
              flex: 9,
              child: Column(
                children: [
                  Expanded(child: row(const [_InboxCard(i: 2), _ProjectsCard(i: 3)])),
                  const SizedBox(height: gap),
                  const Expanded(child: _FlatCard(i: 5)),
                ],
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              flex: 9,
              child: Column(
                children: [
                  const Expanded(child: _KarakeepCard(i: 4)),
                  const SizedBox(height: gap),
                  Expanded(child: row(const [_MemosCard(i: 6), _NotesCard(i: 7)])),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      grid = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TodayCard(i: 1, rows: 3),
          const SizedBox(height: gap),
          row(const [_InboxCard(i: 2), _ProjectsCard(i: 3)], height: 164),
          const SizedBox(height: gap),
          const SizedBox(height: 164, child: _FlatCard(i: 4)),
          const SizedBox(height: gap),
          const SizedBox(height: 172, child: _KarakeepCard(i: 5)),
          const SizedBox(height: gap),
          row(const [_MemosCard(i: 6), _NotesCard(i: 7)], height: 164),
        ],
      );
    }

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              wide ? 128 : 16,
              pad.top + (wide ? 104 : 62),
              wide ? 40 : 16,
              pad.bottom + (wide ? 40 : 120),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, SizedBox(height: wide ? 34 : 22), grid],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card on the wall: glass that arrives in its turn and opens its app.
class _Card extends ConsumerWidget {
  final int i;
  final AppId app;
  final Widget child;
  const _Card({required this.i, required this.app, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Enter(
      i: i,
      dy: 26,
      builder: (context, v) => GlassCard(
        opacity: v,
        label: tr(apps[app]!.name),
        onTap: (origin) => ref.read(osProvider.notifier).open(app, origin: origin),
        child: Opacity(opacity: v, child: child),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  final AppId app;
  final Link? link;
  const _Head(this.app, {this.link});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(apps[app]!.icon, size: 15, color: Tk.ink3),
        const SizedBox(width: 7),
        Expanded(child: Label(tr(apps[app]!.name))),
        if (link != null && link != Link.off)
          Lamp(
            link == Link.live ? Tk.ok : (link == Link.error ? Tk.signal : Tk.warn),
            size: 5,
          ),
      ],
    );
  }
}

/// What a card for an unconnected service shows.
class _Connect extends ConsumerWidget {
  final AppId app;
  final int i;
  final String pitch;
  const _Connect({required this.app, required this.i, required this.pitch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Enter(
      i: i,
      dy: 26,
      builder: (context, v) => GlassCard(
        opacity: v,
        label: tr('Connect {name}', {'name': apps[app]!.source}),
        onTap: (origin) => ref.read(osProvider.notifier).open(AppId.settings, origin: origin),
        child: Opacity(
          opacity: v,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Head(app),
              const Spacer(),
              Text(tr(pitch),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sans(14, color: Tk.ink2, height: 1.3)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.add_link_rounded, size: 16, color: context.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(tr('Connect {name}', {'name': apps[app]!.source}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(13.5, w: 600, color: context.accent)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  final int i;
  final int rows;

  /// In a card of a set height, what does not fit is cut, never an error.
  final bool fixed;
  const _TodayCard({required this.i, required this.rows, this.fixed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(tasksProvider);
    final flat = ref.watch(flatProvider);
    final today = s.todayTasks;
    final done = s.doneToday;
    final total = today.length + done;
    final chores = [for (final c in flat.mine) if ((c.dueIn ?? 1 << 30) < 86400) c];
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 15, color: Tk.ink3),
              const SizedBox(width: 7),
              Expanded(child: Label(tr('Today'))),
              Label(tr('{n} done', {'n': done})),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              DotText(_two(today.length), dot: 6.5, gap: 2.4),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    today.isEmpty ? tr('Nothing left for today') : tr('left for today'),
                    style: sans(14.5, color: Tk.ink2),
                  ),
                ),
              ),
              Ring(total == 0 ? 0 : done / total, size: 52, stroke: 3.5),
            ],
          ),
          const SizedBox(height: 12),
          if (!s.loaded && s.loading)
            const Padding(padding: EdgeInsets.only(top: 4), child: Loading(rows: 2))
          else
            for (final t in today.take(rows)) TaskRow(key: ValueKey(t.key), task: t, compact: true),
          if (today.length > rows)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 4),
              child: Label(tr('+ {n} more', {'n': today.length - rows})),
            ),
          if (chores.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: Tk.rule),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 15, color: Tk.ink3),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chores.map((c) => c.title).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: sans(13.5, color: Tk.ink2),
                  ),
                ),
                Label(tr('Your turn'), color: chores.any((c) => c.late) ? Tk.signal : Tk.ink3),
              ],
            ),
          ],
        ],
    );
    return _Card(
      i: i,
      app: AppId.tasks,
      child: fixed
          ? SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: content)
          : content,
    );
  }
}

/// The small cards: a count on the dot matrix and the latest line.
class _CountCard extends StatelessWidget {
  final int i;
  final AppId app;
  final int count;
  final String line;
  final Widget? foot;
  const _CountCard({
    required this.i,
    required this.app,
    required this.count,
    required this.line,
    this.foot,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      i: i,
      app: app,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(app),
          const Spacer(),
          DotText(_two(count), dot: 4.4, gap: 1.8),
          const SizedBox(height: 12),
          foot ??
              Text(line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sans(13.5, color: Tk.ink2, height: 1.3)),
        ],
      ),
    );
  }
}

class _InboxCard extends ConsumerWidget {
  final int i;
  const _InboxCard({required this.i});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inboxProvider.select((s) => s.items));
    return _CountCard(
      i: i,
      app: AppId.inbox,
      count: items.length,
      line: items.isEmpty ? tr('Inbox zero') : items.first.content,
    );
  }
}

class _ProjectsCard extends ConsumerWidget {
  final int i;
  const _ProjectsCard({required this.i});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(projectsProvider.select((s) => s.items));
    final active = [for (final p in items) if (p.status != 'done' && p.status != 'cancelled') p];
    final top = active.isEmpty ? null : active.first;
    return _CountCard(
      i: i,
      app: AppId.projects,
      count: active.length,
      line: tr('No projects yet'),
      foot: top == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(top.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, color: Tk.ink2)),
                const SizedBox(height: 8),
                DotBar(top.progress, count: 12, dot: 3.6),
              ],
            ),
    );
  }
}

class _NotesCard extends ConsumerWidget {
  final int i;
  const _NotesCard({required this.i});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notesProvider.select((s) => s.items));
    return _CountCard(
      i: i,
      app: AppId.notes,
      count: items.length,
      line: items.isEmpty ? tr('No notes yet') : (items.first.title ?? ''),
    );
  }
}

class _MemosCard extends ConsumerWidget {
  final int i;
  const _MemosCard({required this.i});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(memosProvider);
    if (s.status == Link.off) {
      return _Connect(app: AppId.memos, i: i, pitch: 'Quick thoughts, kept on your server.');
    }
    final latest = s.sorted.isEmpty ? null : s.sorted.first;
    return _Card(
      i: i,
      app: AppId.memos,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(AppId.memos, link: s.status),
          const SizedBox(height: 12),
          Text(
            latest?.content.replaceAll(RegExp(r'[*_#>`]'), '') ?? tr('No memos yet'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: sans(14, color: Tk.ink, height: 1.35),
          ),
          const Spacer(),
          Label(latest == null ? '' : ago(latest.time)),
        ],
      ),
    );
  }
}

class _KarakeepCard extends ConsumerWidget {
  final int i;
  const _KarakeepCard({required this.i});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(karakeepProvider);
    if (s.status == Link.off) {
      return _Connect(
          app: AppId.karakeep, i: i, pitch: 'Links and clippings you saved, searchable from here.');
    }
    final items = [for (final b in s.items) if (!b.archived) b];
    return _Card(
      i: i,
      app: AppId.karakeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(AppId.karakeep, link: s.status),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Expanded(
              child: Center(child: Text(tr('Nothing saved yet'), style: sans(14, color: Tk.ink3))),
            )
          else
            for (final b in items.take(3))
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: b.fav ? context.accent : const Color(0x55FFFFFF),
                      ),
                    ),
                    Expanded(
                      child: Text(b.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14.5, w: 500)),
                    ),
                    const SizedBox(width: 10),
                    Label(b.host.isEmpty ? tr('Note') : b.host, size: 9.5),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _FlatCard extends ConsumerWidget {
  final int i;
  const _FlatCard({required this.i});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(flatProvider);
    if (s.status == Link.off) {
      return _Connect(
          app: AppId.flat, i: i, pitch: 'Chores and the shopping list you share at home.');
    }
    final next = s.sorted.isEmpty ? null : s.sorted.first;
    final mine = next != null && next.userId == s.me;
    return _Card(
      i: i,
      app: AppId.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Head(AppId.flat, link: s.status),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(
                      next == null
                          ? tr('Chores')
                          : '${tr('Next chore')} · ${mine ? tr('You') : s.mate(next.userId)}',
                      color: next != null && next.late ? Tk.signal : Tk.ink3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      next?.title ?? tr('All done'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: sans(17, w: 600, wdth: 106, height: 1.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DotText(_two(s.toBuy.length), dot: 3.6, gap: 1.5),
                  const SizedBox(height: 7),
                  Label(tr('to buy')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
