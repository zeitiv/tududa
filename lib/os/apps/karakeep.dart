import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'tasks.dart';

/// What an app for an unconnected service shows instead of its content.
class NotLinked extends ConsumerWidget {
  final AppId app;
  final String pitch;
  final String? error;
  const NotLinked({super.key, required this.app, required this.pitch, this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPane(
      app: app,
      sub: tr('Not connected'),
      body: Empty(
        error == null ? tr('Connect {name}', {'name': apps[app]!.source}) : tr(error!),
        hint: tr(pitch),
        action: Builder(
          builder: (context) => OsButton(
            tr('Open connections'),
            icon: Icons.add_link_rounded,
            primary: true,
            onTap: () => ref.read(osProvider.notifier).open(AppId.settings, origin: rectOf(context)),
          ),
        ),
      ),
    );
  }
}

enum _Shelf { all, favourites, archive }

class KarakeepApp extends ConsumerStatefulWidget {
  const KarakeepApp({super.key});

  @override
  ConsumerState<KarakeepApp> createState() => _KarakeepAppState();
}

class _KarakeepAppState extends ConsumerState<KarakeepApp> {
  final _query = TextEditingController();
  _Shelf _shelf = _Shelf.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _open(Bookmark b) async {
    if (b.url == null) return;
    final uri = Uri.tryParse(b.url!);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(karakeepProvider);
    final k = ref.read(karakeepProvider.notifier);
    if (s.status == Link.off || (s.status == Link.error && s.items.isEmpty)) {
      return NotLinked(
        app: AppId.karakeep,
        error: s.error,
        pitch: 'Everything you saved in Karakeep, searchable here and one tap from a task.',
      );
    }
    final source = s.found ?? s.items;
    final list = [
      for (final b in source)
        if (switch (_shelf) {
          _Shelf.all => !b.archived,
          _Shelf.favourites => b.fav && !b.archived,
          _Shelf.archive => b.archived,
        })
          b,
    ];
    return AppPane(
      app: AppId.karakeep,
      sub: tr('{n} saved', {'n': s.items.length}),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: OsField(
              controller: _query,
              hint: tr('Search bookmarks'),
              icon: Icons.search_rounded,
              onChanged: k.search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OsSeg<_Shelf>(
              value: _shelf,
              items: {
                _Shelf.all: tr('All'),
                _Shelf.favourites: tr('Favourites'),
                _Shelf.archive: tr('Archive'),
              },
              onChanged: (v) => setState(() => _shelf = v),
            ),
          ),
          Expanded(
            child: s.status == Link.busy && s.items.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Loading())
                : list.isEmpty
                    ? Empty(tr('Nothing here'), hint: tr('Paste a link below to keep it.'))
                    : RefreshIndicator(
                        onRefresh: k.refresh,
                        color: context.accent,
                        backgroundColor: const Color(0xFF1A1C22),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final b = list[i];
                            return RowTile(
                              key: ValueKey(b.id),
                              padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                              onTap: b.url == null ? null : () => _open(b),
                              leading: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _Thumb(b, k.imageHeaders),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OsIconButton(
                                    b.fav ? Icons.star_rounded : Icons.star_outline_rounded,
                                    tooltip: tr('Favourite'),
                                    filled: false,
                                    size: 40,
                                    color: b.fav ? context.accent : Tk.ink3,
                                    onTap: () => k.patch(b, fav: !b.fav),
                                  ),
                                  OsIconButton(
                                    Icons.more_horiz_rounded,
                                    tooltip: tr('More'),
                                    filled: false,
                                    size: 40,
                                    onTap: () => showOsSheet(context, (_) => _BookmarkSheet(b)),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: sans(15, w: 550, height: 1.25)),
                                  const SizedBox(height: 4),
                                  Label([
                                    if (b.host.isNotEmpty) b.host,
                                    ago(b.created),
                                    ...b.tags.take(2).map((t) => '#$t'),
                                  ].where((e) => e.isNotEmpty).join(' · ')),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottom: QuickAdd(hint: tr('Paste a link or write a note'), onAdd: k.add),
    );
  }
}

class _Thumb extends StatelessWidget {
  final Bookmark b;
  final Map<String, String> headers;
  const _Thumb(this.b, this.headers);

  @override
  Widget build(BuildContext context) {
    final letter = (b.host.isNotEmpty ? b.host : b.title).characters.firstOrNull ?? '·';
    final plate = Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Tk.fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Tk.rule),
      ),
      child: b.url == null
          ? const Icon(Icons.sticky_note_2_outlined, size: 20, color: Tk.ink3)
          : Text(letter.toUpperCase(), style: mono(17, color: Tk.ink2, ls: 0)),
    );
    if (b.image == null) return plate;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        b.image!,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        headers: b.image!.contains('/api/assets/') ? headers : null,
        errorBuilder: (_, _, _) => plate,
        loadingBuilder: (_, child, progress) => progress == null ? child : plate,
      ),
    );
  }
}

class _BookmarkSheet extends ConsumerWidget {
  final Bookmark b;
  const _BookmarkSheet(this.b);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = ref.read(karakeepProvider.notifier);
    final os = ref.read(osProvider.notifier);
    void done(VoidCallback run) {
      Navigator.of(context).pop();
      run();
    }

    return SheetBody(
      label: b.host.isEmpty ? 'Karakeep' : b.host,
      title: b.title,
      children: [
        if ((b.text ?? '').isNotEmpty) ...[
          Text(b.text!,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: sans(14.5, color: Tk.ink2, height: 1.45)),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OsButton(tr('Make it a task'), icon: Icons.add_task_rounded, primary: true, onTap: () {
              done(() {
                ref.read(tasksProvider.notifier).add(Task(
                      name: b.title,
                      note: b.url == null ? b.text : '[${b.title}](${b.url})',
                    ));
                os.toast(tr('Added to Tasks'),
                    action: tr('Open'), onAction: () => os.open(AppId.tasks));
              });
            }),
            OsButton(b.archived ? tr('Unarchive') : tr('Archive'),
                icon: Icons.archive_outlined,
                onTap: () => done(() => k.patch(b, archived: !b.archived))),
            OsButton(tr('Delete'),
                danger: true,
                onTap: () => done(() {
                      k.remove(b);
                      os.toast(tr('Bookmark deleted'));
                    })),
          ],
        ),
      ],
    );
  }
}
