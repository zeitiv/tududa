import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/widgets/surface_card.dart';
import '../../core/design/tokens.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/search_query.dart';
import '../domain/search_result.dart';
import '../providers/search_provider.dart';

/// Syntax helpers offered as chips under the field.
const _suggestions = ['#', '+', '~', 'is:overdue', 'is:today', 'priority:high'];

/// Global search: debounced server search with a local offline fallback.
/// Keys: `search.field`, `search.clear`, `search.offline`, `search.recent`,
/// `search.recentClear`, `search.suggestion.<token>`, `search.type.<name|all>`,
/// `search.group.<type>`, `search.hit.<uid>`, `search.retry`.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    final initial = widget.initialQuery;
    if (initial != null && initial.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(searchControllerProvider.notifier)
              .setText(initial, immediate: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setText(String text, {bool immediate = false}) {
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    ref
        .read(searchControllerProvider.notifier)
        .setText(text, immediate: immediate);
    setState(() {});
  }

  void _remember() => ref
      .read(recentSearchesProvider.notifier)
      .add(ref.read(searchControllerProvider).text);

  void _addToken(String token) {
    final raw = _controller.text;
    final isSymbol = token.length == 1 || token.endsWith(':');
    final next = raw.isEmpty || raw.endsWith(' ')
        ? '$raw$token'
        : '$raw $token';
    _setText(next, immediate: !isSymbol);
    _focus.requestFocus();
  }

  void _open(SearchResult hit) {
    _remember();
    switch (hit) {
      case TaskHit(:final uid):
        context.push('/tasks/${uid.value}');
      case ProjectHit(:final uid):
        context.push('/projects/${uid.value}');
      case NoteHit(:final uid):
        context.push('/notes/${uid.value}');
      case AreaHit():
        context.push('/more/areas');
      case TagHit(:final name):
        _setText(ParsedSearch.tagToken(name), immediate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final state = ref.watch(searchControllerProvider);
    final empty = ParsedSearch.parse(state.text).isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('search.field'),
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('search.clear'),
                    tooltip: l10n.searchClear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _setText('');
                      _focus.requestFocus();
                    },
                  ),
          ),
          onChanged: (v) {
            ref.read(searchControllerProvider.notifier).setText(v);
            setState(() {});
          },
          onSubmitted: (v) {
            ref
                .read(searchControllerProvider.notifier)
                .setText(v, immediate: true);
            _remember();
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChipRow(
            children: [
              for (final s in _suggestions)
                ActionChip(
                  key: Key('search.suggestion.$s'),
                  label: Text(s),
                  onPressed: () => _addToken(s),
                ),
            ],
          ),
          if (!empty)
            _ChipRow(
              children: [
                ChoiceChip(
                  key: const Key('search.type.all'),
                  label: Text(l10n.searchTypeAll),
                  selected: state.types.isEmpty,
                  onSelected: (_) => ref
                      .read(searchControllerProvider.notifier)
                      .setTypes(const {}),
                ),
                for (final t in SearchType.values)
                  ChoiceChip(
                    key: Key('search.type.${t.name}'),
                    label: Text(_typeLabel(context, t)),
                    selected: state.types.contains(t),
                    onSelected: (_) => ref
                        .read(searchControllerProvider.notifier)
                        .setTypes({t}),
                  ),
              ],
            ),
          if (state.offline && !empty)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space4,
                vertical: tokens.space1,
              ),
              child: SurfaceCard(
                key: const Key('search.offline'),
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: EdgeInsets.all(tokens.space3),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    SizedBox(width: tokens.space2),
                    Expanded(
                      child: Text(
                        l10n.searchOfflineBanner,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (state.phase == SearchPhase.loading && !empty)
            const LinearProgressIndicator(),
          Expanded(child: _body(context, state, empty)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, SearchState state, bool empty) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    if (empty) return _recent(context);
    if (state.phase == SearchPhase.error) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.searchError, textAlign: TextAlign.center),
              SizedBox(height: tokens.space3),
              FilledButton.tonal(
                key: const Key('search.retry'),
                onPressed: ref.read(searchControllerProvider.notifier).retry,
                child: Text(l10n.searchRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (state.results.isEmpty) {
      if (state.phase != SearchPhase.data) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space6),
          child: Text(
            l10n.searchNoResults(state.text.trim()),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final groups = <SearchType, List<SearchResult>>{};
    for (final r in state.results) {
      groups.putIfAbsent(r.type, () => []).add(r);
    }
    return ListView(
      padding: EdgeInsets.all(tokens.space4),
      children: [
        for (final e in groups.entries) ...[
          Padding(
            key: Key('search.group.${e.key.name}'),
            padding: EdgeInsets.only(top: tokens.space3, bottom: tokens.space2),
            child: Text(
              '${_typeLabel(context, e.key)} (${e.value.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SurfaceCard(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  for (final hit in e.value)
                    _HitRow(hit: hit, onTap: () => _open(hit)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _recent(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final recent = ref.watch(recentSearchesProvider);
    if (recent.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(tokens.space6),
          child: Text(
            l10n.searchIntro,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView(
      key: const Key('search.recent'),
      padding: EdgeInsets.all(tokens.space4),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.searchRecent, style: theme.textTheme.titleSmall),
            ),
            TextButton(
              key: const Key('search.recentClear'),
              onPressed: ref.read(recentSearchesProvider.notifier).clear,
              child: Text(l10n.searchRecentClear),
            ),
          ],
        ),
        SurfaceCard(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final q in recent)
                  ListTile(
                    key: Key('search.recent.$q'),
                    leading: const Icon(Icons.history),
                    title: Text(q),
                    onTap: () => _setText(q, immediate: true),
                    trailing: IconButton(
                      tooltip: l10n.searchRemoveRecent,
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          ref.read(recentSearchesProvider.notifier).remove(q),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _typeLabel(BuildContext context, SearchType t) {
  final l10n = context.l10n;
  return switch (t) {
    SearchType.task => l10n.searchTypeTasks,
    SearchType.project => l10n.searchTypeProjects,
    SearchType.area => l10n.searchTypeAreas,
    SearchType.note => l10n.searchTypeNotes,
    SearchType.tag => l10n.searchTypeTags,
  };
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space4,
        vertical: tokens.space1,
      ),
      child: Row(
        children: [
          for (final c in children)
            Padding(
              padding: EdgeInsets.only(right: tokens.space2),
              child: c,
            ),
        ],
      ),
    );
  }
}

class _HitRow extends StatelessWidget {
  const _HitRow({required this.hit, required this.onTap});
  final SearchResult hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final (icon, uid, subtitle) = switch (hit) {
      TaskHit(:final uid, :final dueDate, :final projectName, :final status) =>
        (
          status == 'done'
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          uid.value,
          [
            ?projectName,
            if (dueDate != null)
              MaterialLocalizations.of(context)
                  .formatMediumDate(dueDate.toLocalDateTime()),
          ].join(' · '),
        ),
      ProjectHit(:final uid, :final description) => (
        Icons.folder_outlined,
        uid.value,
        description ?? '',
      ),
      AreaHit(:final uid, :final description) => (
        Icons.layers_outlined,
        uid.value,
        description ?? '',
      ),
      NoteHit(:final uid, :final description) => (
        Icons.sticky_note_2_outlined,
        uid.value,
        description ?? '',
      ),
      TagHit(:final uid) => (Icons.sell_outlined, uid.value, ''),
    };
    return ListTile(
      key: Key('search.hit.$uid'),
      leading: Icon(
        icon,
        color: hit is TaskHit && (hit as TaskHit).status == 'done'
            ? tokens.success
            : scheme.onSurfaceVariant,
      ),
      title: Text(hit.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
