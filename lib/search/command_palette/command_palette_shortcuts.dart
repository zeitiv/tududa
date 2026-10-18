import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'command_palette.dart';

/// Opens the command palette with Ctrl+K / Cmd+K anywhere below it.
class CommandPaletteShortcuts extends StatelessWidget {
  const CommandPaletteShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              showCommandPalette(context),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              showCommandPalette(context),
        },
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}
