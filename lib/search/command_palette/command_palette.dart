import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import 'commands.dart';

export 'command_palette_shortcuts.dart';
export 'commands.dart';

_PaletteDialogState? _current;

/// Shows the command palette: a text field plus ranked commands. Arrow keys
/// move, Enter runs, Esc closes; taps work too. Does nothing if already open.
Future<void> showCommandPalette(BuildContext context) async {
  if (_current?.mounted ?? false) return;
  final container = ProviderScope.containerOf(context);
  final l10n = context.l10n;
  final commands = buildPaletteCommands(l10n);
  final chosen = await showDialog<_Choice>(
    context: context,
    barrierLabel: l10n.paletteTitle,
    builder: (_) => _PaletteDialog(container: container, commands: commands),
  );
  if (chosen != null && context.mounted) {
    await chosen.command.run(
      PaletteContext(
        context: context,
        container: container,
        query: chosen.query,
      ),
    );
  }
}

class _Choice {
  const _Choice(this.command, this.query);
  final PaletteCommand command;
  final String query;
}

class _PaletteDialog extends StatefulWidget {
  const _PaletteDialog({required this.container, required this.commands});

  final ProviderContainer container;
  final List<PaletteCommand> commands;

  @override
  State<_PaletteDialog> createState() => _PaletteDialogState();
}

class _PaletteDialogState extends State<_PaletteDialog> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<PaletteCommand> _items = const [];
  List<PaletteCommand> _found = const [];
  int _selected = 0;
  int _seq = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _current = this;
    _items = rankCommands(widget.commands, '');
  }

  @override
  void dispose() {
    if (_current == this) _current = null;
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      final ranked = rankCommands(widget.commands, _controller.text);
      // Typed text can always be searched, whatever the fuzzy match says.
      final search = widget.commands.where((c) => c.id == 'search');
      _items = [
        ...ranked,
        if (_controller.text.trim().isNotEmpty &&
            !ranked.any((c) => c.id == 'search'))
          ...search,
        ..._found,
      ];
      _selected = 0;
    });
  }

  Future<void> _onChanged(String text) async {
    final seq = ++_seq;
    _found = const [];
    _refresh();
    if (text.trim().length < 2) return;
    final l10n = context.l10n;
    List<PaletteCommand> found;
    try {
      found = await findPaletteItems(widget.container, l10n, text);
    } catch (_) {
      return;
    }
    if (!mounted || seq != _seq) return;
    _found = found;
    _refresh();
  }

  void _move(int delta) {
    if (_items.isEmpty) return;
    setState(() => _selected = (_selected + delta) % _items.length);
    if (_scroll.hasClients) {
      const h = 48.0;
      final top = _selected * h;
      final pos = _scroll.position;
      if (top < pos.pixels) {
        _scroll.jumpTo(top);
      } else if (top + h > pos.pixels + pos.viewportDimension) {
        _scroll.jumpTo(top + h - pos.viewportDimension);
      }
    }
  }

  void _run(int i) {
    if (_done || i < 0 || i >= _items.length) return;
    _done = true;
    Navigator.of(context).pop(_Choice(_items[i], _controller.text));
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      _run(_selected);
    } else if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.paletteTitle,
        child: Material(
          type: MaterialType.card,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: FocusScope(
              child: Focus(
                canRequestFocus: false,
                onKeyEvent: _onKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.go,
                        decoration: InputDecoration(
                          hintText: l10n.paletteHint,
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                        onChanged: _onChanged,
                        onSubmitted: (_) => _run(_selected),
                      ),
                    ),
                    const Divider(height: 1),
                    Semantics(
                      liveRegion: true,
                      label: l10n.paletteResultCount(_items.length),
                      child: const SizedBox(width: double.infinity),
                    ),
                    Flexible(
                      child: _items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.paletteEmpty,
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              shrinkWrap: true,
                              itemCount: _items.length,
                              itemBuilder: (context, i) => _row(context, i),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int i) {
    final c = _items[i];
    final selected = i == _selected;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: l10n.paletteItemPosition(
        c.kind == null ? c.label : '${c.kind}: ${c.label}',
        i + 1,
        _items.length,
      ),
      excludeSemantics: true,
      onTap: () => _run(i),
      child: ListTile(
        key: ValueKey('palette-${c.id}'),
        dense: true,
        selected: selected,
        selectedTileColor: scheme.secondaryContainer,
        leading: Icon(c.icon),
        title: Text(c.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: c.kind == null ? null : Text(c.kind!),
        onTap: () => _run(i),
      ),
    );
  }
}
