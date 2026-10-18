import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../core/api/api_providers.dart';
import '../../core/utils/constants.dart';
import '../../settings/providers/settings_provider.dart';
import '../domain/user.dart';
import 'credential_store.dart';
import 'server_config.dart';
import 'session_providers.dart';
import 'session_state.dart';

export 'session_state.dart';

/// Owns sign-in state. Also the app's [SessionAuthCallbacks]: the HTTP stack
/// calls [reauthenticate] when a request gets a 401.
///
/// Methods that talk to the server throw [ApiError] (or [ServerConfigError]
/// for [configureServer]); the state is left consistent either way.
class SessionController extends Notifier<SessionState>
    implements SessionAuthCallbacks {
  Completer<bool>? _reauth;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  CredentialStore get _credentials => ref.read(credentialStoreProvider);
  CookieJar get _jar => ref.read(cookieJarProvider);
  Dio get _dio => ref.read(dioProvider);

  @override
  SessionState build() => const SessionUnknown();

  /// Cached profile from the last successful sign-in.
  User? get cachedUser {
    final raw = _prefs.getString(AppConstants.userDataKey);
    if (raw == null) return null;
    try {
      return User.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map<dynamic, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(User user) =>
      _prefs.setString(AppConstants.userDataKey, jsonEncode(user.toJson()));

  /// Decides the initial state from storage and `GET /current_user`.
  Future<void> bootstrap() async {
    final config = ref.read(serverConfigProvider);
    if (config == null) {
      state = const SessionNoServer();
      return;
    }
    final cached = cachedUser;
    try {
      final user = await _fetchCurrentUser();
      if (user == null) {
        state = SessionSignedOut(lastEmail: cached?.email);
      } else {
        await _cacheUser(user);
        state = SessionSignedIn(user);
      }
    } on ApiError catch (e) {
      if (e.isTransient && cached != null && await _hasCookies(config.url)) {
        state = SessionSignedIn(cached, offline: true);
      } else {
        state = SessionSignedOut(lastEmail: cached?.email);
      }
    }
  }

  Future<bool> _hasCookies(String serverUrl) async =>
      (await _jar.loadForRequest(Uri.parse(serverUrl))).isNotEmpty;

  Future<User?> _fetchCurrentUser() => guard(() async {
    final res = await _dio.get<Object?>('/current_user');
    final data = res.data;
    if (data is! Map) throw const FormatException('current_user');
    final raw = data['user'];
    if (raw == null) return null;
    return User.fromJson(Map<String, Object?>.from(raw as Map));
  });

  /// Validates and stores the server. Switching to a different server drops
  /// the old session. Throws [ServerConfigError] or [ApiError].
  Future<ServerInfo> configureServer(
    String input, {
    bool allowInsecure = false,
  }) async {
    final info = await ref
        .read(serverValidatorProvider)
        .validate(input, allowInsecure: allowInsecure);
    final previous = ref.read(serverConfigProvider);
    if (previous?.url != info.url) await _wipeSession();
    await ref
        .read(serverConfigProvider.notifier)
        .set(ServerConfig(url: info.url, allowInsecure: info.isInsecure));
    state = SessionSignedOut(lastEmail: cachedUser?.email);
    return info;
  }

  /// Forgets the server and everything tied to it.
  Future<void> clearServer() async {
    await _wipeSession();
    await ref.read(serverConfigProvider.notifier).clear();
    state = const SessionNoServer();
  }

  /// Signs in. Throws [InvalidCredentialsError], [EmailNotVerifiedError],
  /// [PasswordLoginDisabledError], [RateLimitedError], [NetworkError], ...
  Future<User> login(String email, String password) async {
    final trimmed = email.trim();
    state = SessionAuthenticating(lastEmail: trimmed);
    try {
      // A different account must not inherit the old cookie or credentials.
      await _jar.deleteAll();
      final user = await _postLogin(trimmed, password);
      final old = cachedUser;
      if (old != null && old.uid != user.uid) {
        await _prefs.remove(AppConstants.userDataKey);
      }
      await _credentials.write(Credentials(email: trimmed, password: password));
      await _cacheUser(user);
      state = SessionSignedIn(user);
      return user;
    } on ApiError {
      // The jar was cleared above, so any earlier session is gone too.
      state = SessionSignedOut(lastEmail: trimmed);
      rethrow;
    }
  }

  Future<User> _postLogin(String email, String password) => guard(() async {
    final res = await _dio.post<Object?>(
      '/login',
      data: {'email': email, 'password': password},
    );
    final data = res.data;
    final raw = data is Map ? data['user'] : null;
    if (raw is! Map) throw const FormatException('login response');
    return User.fromJson(Map<String, Object?>.from(raw));
  });

  /// `GET /logout` (the server has no POST), best effort, then wipes the
  /// jar, credentials and cached profile.
  Future<void> logout() async {
    final email = switch (state) {
      SessionSignedIn(:final user) => user.email,
      _ => null,
    };
    try {
      await _dio.get<Object?>('/logout');
    } catch (e) {
      if (kDebugMode) debugPrint('logout request failed: ${e.runtimeType}');
    }
    await _wipeSession();
    state = SessionSignedOut(lastEmail: email);
  }

  Future<void> _wipeSession() async {
    await _jar.deleteAll();
    await _credentials.clear();
    await _prefs.remove(AppConstants.userDataKey);
  }

  /// Renews the session with the stored credentials. Concurrent callers share
  /// one login. Returns false (without expiring) on network trouble; expires
  /// the session when the server refuses the credentials or none are stored.
  @override
  Future<bool> reauthenticate() {
    final running = _reauth;
    if (running != null) return running.future;
    final completer = _reauth = Completer<bool>();
    _doReauth()
        .then(completer.complete, onError: completer.completeError)
        .then((_) => _reauth = null);
    return completer.future;
  }

  Future<bool> _doReauth() async {
    final creds = await _credentials.read();
    if (creds == null) {
      _expire(null);
      return false;
    }
    try {
      final user = await _postLogin(creds.email, creds.password);
      await _cacheUser(user);
      if (state is SessionSignedIn || state is SessionExpired) {
        state = SessionSignedIn(user);
      }
      return true;
    } on InvalidCredentialsError {
      await _credentials.clear();
      _expire(creds.email);
      return false;
    } on ApiError {
      return false;
    }
  }

  void _expire(String? email) {
    final s = state;
    // Only a signed-in session can expire; otherwise login is already shown.
    if (s is SessionSignedIn) {
      state = SessionExpired(lastEmail: email ?? s.user.email);
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
