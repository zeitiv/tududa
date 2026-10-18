import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/note.dart';
import '../providers/note_provider.dart';
import '../widgets/note_card.dart';
import '../../core/design/tokens.dart';
import '../../l10n/l10n_ext.dart';

/// Whether [note] matches the (already lower-cased, trimmed) [query] in its
/// title, content, project or tags.
bool noteMatches(Note note, String query) {
  if (query.isEmpty) return true;
  bool has(String? s) => s != null && s.toLowerCase().contains(query);
  return has(note.title) ||
      has(note.content) ||
      has(note.projectName) ||
      note.tags.any((t) => has(t.name));
}

/// Notes screen: search, grid / list toggle and colored note cards.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  bool _grid = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(Note note) {
    // Notes not on the server yet open by local id.
    context.push('/notes/${Uri.encodeComponent(note.routeId!)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteState = ref.watch(noteListProvider);
    final all = noteState.value ?? const <Note>[];
    final query = _search.text.trim().toLowerCase();
    final notes = [
      for (final n in all)
        if (noteMatches(n, query)) n,
    ];
    final strings = context.l10n;
    final gap = theme.extension<AppTokens>()?.space3 ?? 12;

    Widget body;
    if (noteState.isLoading && !noteState.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (all.isEmpty || notes.isEmpty) {
      final searching = all.isNotEmpty;
      body = _EmptyView(
        message: searching ? strings.noteV2NoResults : strings.noteEmpty,
        icon: searching ? Icons.search_off_rounded : Icons.note_outlined,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(noteListProvider.notifier).refresh(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = !_grid
                ? 1
                : (constraints.maxWidth / 220).floor().clamp(2, 6);
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gap + 4, 4, gap + 4, 96),
                  sliver: columns == 1
                      ? SliverList.separated(
                          itemCount: notes.length,
                          separatorBuilder: (_, _) => SizedBox(height: gap),
                          itemBuilder: (context, i) => NoteCard(
                            note: notes[i],
                            compact: true,
                            onTap: () => _open(notes[i]),
                          ),
                        )
                      : SliverToBoxAdapter(
                          child: _MasonryColumns(
                            columns: columns,
                            spacing: gap,
                            children: [
                              for (final n in notes)
                                NoteCard(note: n, onTap: () => _open(n)),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.navNotes),
        actions: [
          IconButton(
            tooltip: _grid ? strings.noteV2ViewList : strings.noteV2ViewGrid,
            icon: Icon(
              _grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            ),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gap + 4, 4, gap + 4, gap),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: strings.noteV2Search,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.noteV2ClearSearch,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/notes/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.noteNew),
      ),
    );
  }
}

/// Cards of varying height laid out round-robin in [columns] columns.
class _MasonryColumns extends StatelessWidget {
  const _MasonryColumns({
    required this.columns,
    required this.spacing,
    required this.children,
  });

  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final buckets = List.generate(columns, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      final bucket = buckets[i % columns];
      if (bucket.isNotEmpty) bucket.add(SizedBox(height: spacing));
      bucket.add(children[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) SizedBox(width: spacing),
          Expanded(child: Column(children: buckets[c])),
        ],
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
