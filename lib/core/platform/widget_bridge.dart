import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_bridge.dart' show hasNativeBridges;

/// A completion the home-screen widget made and the server confirmed.
class WidgetChange {
  const WidgetChange({
    required this.seq,
    required this.uid,
    required this.status,
    required this.atMillis,
  });
  final int seq;
  final String uid;
  final int status;
  final int atMillis;

  @override
  String toString() => 'WidgetChange($seq, $uid, $status)';
}

/// Dart side of `tududa/widget` and `tududa/widget/events` (contract:
/// android/CHANNELS.md). Every method is best effort for callers: the widget
/// is optional UI, so failures must not break the app.
abstract class WidgetBridge {
  /// Re-renders the home-screen widgets.
  Future<void> refresh();

  /// Shows a local, not yet synced status change on the widget only.
  Future<void> overlay(String uid, int status);

  /// Log entries with `seq > sinceSeq`, ordered by `seq`.
  Future<List<WidgetChange>> pendingChanges(int sinceSeq);

  /// Deletes log entries with `seq <= seq`.
  Future<void> ack(int seq);

  /// Latest change sequence number: once on listen, then per logged change.
  Stream<int> get changes;
}

class MethodChannelWidgetBridge implements WidgetBridge {
  MethodChannelWidgetBridge({MethodChannel? channel, EventChannel? events})
    : _channel = channel ?? const MethodChannel('tududa/widget'),
      _events = events ?? const EventChannel('tududa/widget/events');

  final MethodChannel _channel;
  final EventChannel _events;

  @override
  Future<void> refresh() => _channel.invokeMethod<void>('refresh', {});

  @override
  Future<void> overlay(String uid, int status) =>
      _channel.invokeMethod<void>('overlay', {'uid': uid, 'status': status});

  @override
  Future<List<WidgetChange>> pendingChanges(int sinceSeq) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'pendingChanges',
      {'sinceSeq': sinceSeq},
    );
    return [
      for (final m in raw ?? const <Map<Object?, Object?>>[])
        WidgetChange(
          seq: (m['seq'] as num).toInt(),
          uid: m['uid'] as String,
          status: (m['status'] as num).toInt(),
          atMillis: (m['atMillis'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  @override
  Future<void> ack(int seq) => _channel.invokeMethod<void>('ack', {'seq': seq});

  @override
  Stream<int> get changes =>
      _events.receiveBroadcastStream().map((e) => (e as num).toInt());
}

/// In-memory bridge for tests and non-Android platforms.
class InMemoryWidgetBridge implements WidgetBridge {
  final List<WidgetChange> _log = [];
  final StreamController<int> _controller = StreamController<int>.broadcast();
  int _seq = 0;

  int refreshCount = 0;
  final List<({String uid, int status})> overlays = [];
  final List<int> acks = [];

  /// Simulates a widget completion confirmed by the server.
  WidgetChange logChange(String uid, int status, {int atMillis = 0}) {
    final c = WidgetChange(
      seq: ++_seq,
      uid: uid,
      status: status,
      atMillis: atMillis,
    );
    _log.add(c);
    _controller.add(_seq);
    return c;
  }

  List<WidgetChange> get log => List.unmodifiable(_log);

  @override
  Future<void> refresh() async => refreshCount++;

  @override
  Future<void> overlay(String uid, int status) async =>
      overlays.add((uid: uid, status: status));

  @override
  Future<List<WidgetChange>> pendingChanges(int sinceSeq) async => [
    for (final c in _log)
      if (c.seq > sinceSeq) c,
  ];

  @override
  Future<void> ack(int seq) async {
    acks.add(seq);
    _log.removeWhere((c) => c.seq <= seq);
  }

  @override
  Stream<int> get changes async* {
    yield _seq;
    yield* _controller.stream;
  }
}

final widgetBridgeProvider = Provider<WidgetBridge>(
  (ref) =>
      hasNativeBridges ? MethodChannelWidgetBridge() : InMemoryWidgetBridge(),
);
