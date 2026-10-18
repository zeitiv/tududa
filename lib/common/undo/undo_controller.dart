import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../tasks/providers/task_provider.dart';

/// Shows the "Task completed · Undo" snackbar for a task change and reverts
/// the change when the user taps Undo. Matches the outbox undo window.
class UndoController {
  UndoController(this._ref);

  final Ref _ref;

  /// Shows [message] with an Undo action for [token]. A null [token] (nothing
  /// to revert) shows the message alone.
  void show(BuildContext context, String message, UndoToken? token) =>
      showAll(context, message, [?token]);

  /// Like [show] for a change made of several tokens (bulk delete...).
  void showAll(BuildContext context, String message, List<UndoToken> tokens) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final actions = _ref.read(taskActionsProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          action: tokens.isEmpty
              ? null
              : SnackBarAction(
                  label: context.l10n.undoAction,
                  onPressed: () async {
                    for (final t in tokens.reversed) {
                      await actions.undo(t);
                    }
                  },
                ),
        ),
      );
  }
}

final undoControllerProvider = Provider<UndoController>(UndoController.new);
