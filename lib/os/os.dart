import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The apps of the system, and which service each one speaks to.
enum AppId { tasks, projects, notes, inbox, karakeep, memos, flat, settings }

class AppMeta {
  final String name;
  final String source;
  final IconData icon;
  const AppMeta(this.name, this.source, this.icon);
}

const apps = <AppId, AppMeta>{
  AppId.tasks: AppMeta('Tasks', 'Tududi', Icons.check_circle_outline_rounded),
  AppId.projects: AppMeta('Projects', 'Tududi', Icons.layers_outlined),
  AppId.notes: AppMeta('Notes', 'Tududi', Icons.notes_rounded),
  AppId.inbox: AppMeta('Inbox', 'Tududi', Icons.inbox_outlined),
  AppId.karakeep: AppMeta('Bookmarks', 'Karakeep', Icons.bookmark_outline_rounded),
  AppId.memos: AppMeta('Memos', 'Memos', Icons.bolt_outlined),
  AppId.flat: AppMeta('Household', 'Flatastic', Icons.home_outlined),
  AppId.settings: AppMeta('Settings', 'System', Icons.tune_rounded),
};

/// An open window: which app, and where on screen it grew out of.
class Win {
  final AppId app;
  final Rect? origin;
  final bool closing;
  const Win(this.app, {this.origin, this.closing = false});
}

class OsToast {
  final int id;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const OsToast(this.id, this.text, {this.action, this.onAction});
}

class OsState {
  final List<Win> wins;
  final bool capture;
  final OsToast? toast;
  const OsState({this.wins = const [], this.capture = false, this.toast});

  OsState copyWith({List<Win>? wins, bool? capture, OsToast? toast, bool clearToast = false}) =>
      OsState(
        wins: wins ?? this.wins,
        capture: capture ?? this.capture,
        toast: clearToast ? null : (toast ?? this.toast),
      );

  List<Win> get open => [for (final w in wins) if (!w.closing) w];
  bool isOpen(AppId a) => wins.any((w) => w.app == a && !w.closing);
}

class OsNotifier extends StateNotifier<OsState> {
  OsNotifier() : super(const OsState());

  /// How many windows fit side by side; the shell sets it from the screen.
  int max = 1;
  int _toasts = 0;

  void open(AppId app, {Rect? origin}) {
    if (state.isOpen(app)) return;
    var wins = [for (final w in state.wins) if (w.app != app) w, Win(app, origin: origin)];
    final live = [for (final w in wins) if (!w.closing) w];
    if (live.length > max) {
      final drop = live.take(live.length - max).map((w) => w.app).toSet();
      wins = [
        for (final w in wins)
          drop.contains(w.app) ? Win(w.app, origin: w.origin, closing: true) : w,
      ];
    }
    state = state.copyWith(wins: wins, capture: false);
  }

  void toggle(AppId app, {Rect? origin}) =>
      state.isOpen(app) ? close(app) : open(app, origin: origin);

  void close(AppId app) {
    state = state.copyWith(wins: [
      for (final w in state.wins)
        w.app == app ? Win(w.app, origin: w.origin, closing: true) : w,
    ]);
  }

  /// Returns false when there was nothing to close.
  bool closeTop() {
    if (state.capture) {
      setCapture(false);
      return true;
    }
    final live = state.open;
    if (live.isEmpty) return false;
    close(live.last.app);
    return true;
  }

  void home() {
    state = state.copyWith(
      wins: [for (final w in state.wins) Win(w.app, origin: w.origin, closing: true)],
    );
  }

  /// A window has finished leaving.
  void gone(AppId app) {
    state = state.copyWith(wins: [
      for (final w in state.wins) if (!(w.app == app && w.closing)) w,
    ]);
  }

  /// Keeps to [max] windows after the screen got narrower.
  void fit() {
    final live = state.open;
    if (live.length <= max) return;
    for (final w in live.take(live.length - max)) {
      close(w.app);
    }
  }

  void setCapture(bool on) => state = state.copyWith(capture: on);

  void toast(String text, {String? action, VoidCallback? onAction}) {
    final id = ++_toasts;
    state = state.copyWith(toast: OsToast(id, text, action: action, onAction: onAction));
    Future.delayed(Duration(milliseconds: action == null ? 2600 : 4600), () {
      if (mounted && state.toast?.id == id) state = state.copyWith(clearToast: true);
    });
  }

  void clearToast() => state = state.copyWith(clearToast: true);
}

final osProvider = StateNotifierProvider<OsNotifier, OsState>((ref) => OsNotifier());
