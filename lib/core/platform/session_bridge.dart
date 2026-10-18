import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Credentials as the native vault returns them.
class NativeCredentials {
  const NativeCredentials({
    required this.serverUrl,
    required this.email,
    required this.password,
  });
  final String serverUrl;
  final String email;
  final String password;

  @override
  String toString() =>
      'NativeCredentials(serverUrl: $serverUrl, email: $email, '
      'password: <redacted>)';
}

/// The vault's view of the session (`state` on `tududa/session`).
class SessionBridgeState {
  const SessionBridgeState({
    required this.provisioned,
    this.serverUrl = '',
    this.accountUid = '',
    this.loginFailed = false,
  });
  final bool provisioned;
  final String serverUrl;
  final String accountUid;
  final bool loginFailed;

  static const empty = SessionBridgeState(provisioned: false);
}

/// Dart side of the `tududa/session` channel (contract: android/CHANNELS.md).
///
/// SECURITY: the password only travels through [provision] and
/// [getCredentials]; implementations must never log arguments.
abstract class SessionBridge {
  Future<void> provision({
    required String serverUrl,
    required bool allowInsecureHttp,
    required String email,
    required String password,
    required String accountUid,
  });

  /// Best-effort native logout, then wipes the whole vault.
  Future<void> clear();

  Future<NativeCredentials?> getCredentials();

  Future<List<String>> readCookies(String host);

  /// An empty list removes [host].
  Future<void> writeCookies(String host, List<String> cookies);

  Future<SessionBridgeState> state();
}

/// Talks to `SessionBridge.kt`.
class MethodChannelSessionBridge implements SessionBridge {
  MethodChannelSessionBridge([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('tududa/session');

  final MethodChannel _channel;

  @override
  Future<void> provision({
    required String serverUrl,
    required bool allowInsecureHttp,
    required String email,
    required String password,
    required String accountUid,
  }) => _channel.invokeMethod<void>('provision', {
    'serverUrl': serverUrl,
    'allowInsecureHttp': allowInsecureHttp,
    'email': email,
    'password': password,
    'accountUid': accountUid,
  });

  @override
  Future<void> clear() => _channel.invokeMethod<void>('clear', {});

  @override
  Future<NativeCredentials?> getCredentials() async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'getCredentials',
      {},
    );
    if (raw == null) return null;
    return NativeCredentials(
      serverUrl: raw['serverUrl'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      password: raw['password'] as String? ?? '',
    );
  }

  @override
  Future<List<String>> readCookies(String host) async {
    final raw = await _channel.invokeListMethod<String>('readCookies', {
      'host': host,
    });
    return raw ?? const [];
  }

  @override
  Future<void> writeCookies(String host, List<String> cookies) => _channel
      .invokeMethod<void>('writeCookies', {'host': host, 'cookies': cookies});

  @override
  Future<SessionBridgeState> state() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('state', {});
    if (raw == null) return SessionBridgeState.empty;
    return SessionBridgeState(
      provisioned: raw['provisioned'] as bool? ?? false,
      serverUrl: raw['serverUrl'] as String? ?? '',
      accountUid: raw['accountUid'] as String? ?? '',
      loginFailed: raw['loginFailed'] as bool? ?? false,
    );
  }
}

/// In-memory bridge for tests and non-Android platforms. Records calls in
/// [log] (method names only, never arguments with secrets).
class InMemorySessionBridge implements SessionBridge {
  final List<String> log = [];
  final Map<String, List<String>> cookies = {};
  NativeCredentials? credentials;
  String accountUid = '';
  String serverUrl = '';
  bool allowInsecureHttp = false;
  bool loginFailed = false;
  bool _provisioned = false;

  /// Set to make the next calls throw (simulates a native failure).
  Object? failWith;

  int get provisionCount => log.where((e) => e == 'provision').length;
  int get clearCount => log.where((e) => e == 'clear').length;

  void _enter(String method) {
    log.add(method);
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<void> provision({
    required String serverUrl,
    required bool allowInsecureHttp,
    required String email,
    required String password,
    required String accountUid,
  }) async {
    _enter('provision');
    if (this.accountUid != accountUid || this.serverUrl != serverUrl) {
      cookies.clear();
    }
    this.serverUrl = serverUrl;
    this.allowInsecureHttp = allowInsecureHttp;
    this.accountUid = accountUid;
    loginFailed = false;
    _provisioned = true;
    credentials = NativeCredentials(
      serverUrl: serverUrl,
      email: email,
      password: password,
    );
  }

  @override
  Future<void> clear() async {
    _enter('clear');
    cookies.clear();
    credentials = null;
    accountUid = '';
    serverUrl = '';
    loginFailed = false;
    _provisioned = false;
  }

  @override
  Future<NativeCredentials?> getCredentials() async {
    _enter('getCredentials');
    return credentials;
  }

  @override
  Future<List<String>> readCookies(String host) async {
    _enter('readCookies');
    return List.of(cookies[host] ?? const []);
  }

  @override
  Future<void> writeCookies(String host, List<String> value) async {
    _enter('writeCookies');
    if (value.isEmpty) {
      cookies.remove(host);
    } else {
      cookies[host] = List.of(value);
    }
  }

  @override
  Future<SessionBridgeState> state() async {
    _enter('state');
    return SessionBridgeState(
      provisioned: _provisioned,
      serverUrl: serverUrl,
      accountUid: accountUid,
      loginFailed: loginFailed,
    );
  }
}

/// True when the native vault exists (the Android host app).
bool get hasNativeBridges {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

/// Native vault on Android, a process-local fake elsewhere. Tests override it
/// with an [InMemorySessionBridge].
final sessionBridgeProvider = Provider<SessionBridge>(
  (ref) =>
      hasNativeBridges ? MethodChannelSessionBridge() : InMemorySessionBridge(),
);
