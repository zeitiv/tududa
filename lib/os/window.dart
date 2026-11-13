import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kit/controls.dart';
import 'kit/glass.dart';
import 'kit/motion.dart';
import 'kit/tokens.dart';
import 'l10n.dart';
import 'os.dart';

/// A window. It grows out of whatever opened it (a card on the wall, an
/// icon in the dock) into its slot, on springs, and shrinks back there
/// when it closes. Its content is laid out once at the slot's size and
/// scaled with the pane, so nothing reflows while it moves. On a phone it
/// can be dragged down by its header: it follows the finger, and a flick or
/// a long pull lets it go.
class WindowFrame extends ConsumerStatefulWidget {
  final Win win;
  final Rect slot;
  final bool phone;
  final Widget child;

  const WindowFrame({
    super.key,
    required this.win,
    required this.slot,
    required this.phone,
    required this.child,
  });

  @override
  ConsumerState<WindowFrame> createState() => WindowFrameState();
}

class WindowFrameState extends ConsumerState<WindowFrame> with SingleTickerProviderStateMixin {
  // left, top, width, height, presence.
  late final Springs _s;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late Rect _slot = widget.slot;
  Offset _drag = Offset.zero;
  bool _dragging = false;
  bool _gone = false;

  bool get phone => widget.phone;

  Rect get _away {
    final o = widget.win.origin;
    if (o != null && o.width > 0) return o;
    return Rect.fromCenter(
      center: _slot.center + const Offset(0, 60),
      width: _slot.width * 0.9,
      height: _slot.height * 0.9,
    );
  }

  List<double> _vals(Rect r, double o) => [r.left, r.top, r.width, r.height, o];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _s = Springs(_vals(_away, 0), spec: const Spec(300, 29));
    _aim(_slot, 1);
  }

  @override
  void didUpdateWidget(WindowFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.win.closing) {
      if (!oldWidget.win.closing) {
        _s.spec = const Spec(380, 36);
        _aim(_away, 0);
      }
      return;
    }
    if (widget.slot != _slot) {
      _slot = widget.slot;
      if (!_dragging) _aim(_slot, 1);
    }
  }

  void _aim(Rect r, double o) {
    final t = _vals(r, o);
    for (var i = 0; i < 5; i++) {
      _s.target[i] = t[i];
    }
    if (Motion.reduced) {
      _s.jump(t);
      if (o == 0) _leave();
      if (mounted) setState(() {});
      return;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _leave() {
    if (_gone) return;
    _gone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(osProvider.notifier).gone(widget.win.app);
    });
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    final moving = _s.step(dt);
    if (widget.win.closing && (!moving || _s.x[4] < 0.04)) {
      _ticker.stop();
      _leave();
    } else if (!moving) {
      _ticker.stop();
    }
    setState(() {});
  }

  void close() => ref.read(osProvider.notifier).close(widget.win.app);

  // The header's drag, on a phone.
  void dragStart() {
    if (!phone) return;
    _dragging = true;
    _drag = Offset.zero;
    _ticker.stop();
  }

  void dragUpdate(Offset delta) {
    if (!_dragging) return;
    _drag += delta;
    final dy = math.max(0.0, _drag.dy);
    final k = 1 - (dy / _slot.height).clamp(0.0, 1.0) * 0.4;
    final w = _slot.width * k;
    final h = _slot.height * k;
    _s.jump([_slot.left + (_slot.width - w) / 2 + _drag.dx * 0.5, _slot.top + dy, w, h, 1]);
    setState(() {});
  }

  void dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    _s.v[1] = velocity;
    if (_drag.dy > 120 || velocity > 700) {
      thud();
      close();
    } else {
      _aim(_slot, 1);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = math.max(8.0, _s.x[2]);
    final h = math.max(8.0, _s.x[3]);
    final o = _s.x[4].clamp(0.0, 1.0);
    final scale = w / _slot.width;
    return Positioned(
      left: _s.x[0],
      top: _s.x[1],
      width: w,
      height: h,
      child: IgnorePointer(
        ignoring: widget.win.closing,
        child: Glass(
          radius: 30,
          blur: 34,
          shadow: true,
          opacity: o,
          fill: const Color(0xD60F1116),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: _slot.width,
            maxWidth: _slot.width,
            minHeight: _slot.height,
            maxHeight: _slot.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: Opacity(
                opacity: Curves.easeIn.transform(o),
                child: _WindowScope(state: this, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowScope extends InheritedWidget {
  final WindowFrameState state;
  const _WindowScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(_WindowScope old) => false;
}

/// What every app shows inside its window: a header (where it is from, its
/// name, its actions, close) over its content.
class AppPane extends StatelessWidget {
  final AppId app;
  final String? title;
  final String? sub;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Widget body;
  final Widget? bottom;

  const AppPane({
    super.key,
    required this.app,
    required this.body,
    this.title,
    this.sub,
    this.actions = const [],
    this.onBack,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final frame = context.getInheritedWidgetOfExactType<_WindowScope>()?.state;
    final phone = frame?.phone ?? false;
    final meta = apps[app]!;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 10 : 22, phone ? 6 : 18, 12, 10),
      child: Row(
        children: [
          if (onBack != null)
            OsIconButton(Icons.arrow_back_rounded,
                onTap: onBack, tooltip: tr('Back'), filled: false),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(sub == null ? meta.source : '${meta.source} · $sub'),
                const SizedBox(height: 4),
                Text(
                  title ?? tr(meta.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(25, w: 680, wdth: 112, height: 1.1),
                ),
              ],
            ),
          ),
          ...actions,
          const SizedBox(width: 4),
          OsIconButton(Icons.close_rounded, onTap: frame?.close, tooltip: tr('Close')),
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: phone ? (_) => frame!.dragStart() : null,
              onVerticalDragUpdate: phone ? (d) => frame!.dragUpdate(d.delta) : null,
              onVerticalDragEnd: phone ? (d) => frame!.dragEnd(d.primaryVelocity ?? 0) : null,
              child: Column(
                children: [
                  if (phone)
                    Container(
                      width: 38,
                      height: 4.5,
                      margin: const EdgeInsets.only(top: 9),
                      decoration: BoxDecoration(
                        color: const Color(0x52FFFFFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  header,
                ],
              ),
            ),
            Expanded(child: body),
            if (bottom != null)
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: bottom),
          ],
        ),
      ),
    );
  }
}

/// A row in a list: it lights under a pointer and gives when pressed.
class RowTile extends StatelessWidget {
  final Widget? leading;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const RowTile({
    super.key,
    this.leading,
    required this.child,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(6, 6, 8, 6),
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      builder: (context, hover, down) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: padding,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: down ? 0.08 : (hover ? 0.05 : 0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ?leading,
            Expanded(child: child),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A row that folds away when it leaves the list.
class Fold extends StatelessWidget {
  final bool open;
  final Widget child;
  final VoidCallback? onClosed;
  const Fold({super.key, required this.open, required this.child, this.onClosed});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: open ? 1 : 0),
      duration: Duration(milliseconds: Motion.reduced ? 1 : 260),
      curve: Curves.easeInOutCubic,
      onEnd: () {
        if (!open) onClosed?.call();
      },
      child: child,
      builder: (context, v, child) => v >= 1
          ? child!
          : ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: v,
                child: Opacity(opacity: v, child: child),
              ),
            ),
    );
  }
}
