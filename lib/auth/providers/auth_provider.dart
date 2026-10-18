import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/user.dart';
import '../session/auth_messages.dart';
import '../session/server_config.dart';
import '../session/session_controller.dart';

/// Authentication state
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final String? serverUrl;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.serverUrl,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    String? serverUrl,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

AuthState _fromSession(SessionState session, String? serverUrl) {
  return switch (session) {
    SessionUnknown() => AuthState(serverUrl: serverUrl),
    SessionNoServer() => AuthState(
      status: AuthStatus.unauthenticated,
      serverUrl: serverUrl,
    ),
    SessionSignedOut() || SessionExpired() => AuthState(
      status: AuthStatus.unauthenticated,
      serverUrl: serverUrl,
    ),
    SessionAuthenticating() => AuthState(
      status: AuthStatus.loading,
      serverUrl: serverUrl,
    ),
    SessionSignedIn(:final user) => AuthState(
      status: AuthStatus.authenticated,
      user: user,
      serverUrl: serverUrl,
    ),
  };
}

/// Thin adapter that exposes [SessionController] in the old [AuthState]
/// shape for the router, settings and startup code. New code should use
/// [sessionControllerProvider] directly.
class AuthNotifier extends StateNotifier<AuthState> {
  /// Without a [ref] the notifier is a plain state holder (used by tests).
  AuthNotifier([this._ref]) : super(const AuthState()) {
    final ref = _ref;
    if (ref == null) return;
    state = _fromSession(
      ref.read(sessionControllerProvider),
      ref.read(serverConfigProvider)?.url,
    );
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(serverConfigProvider, (_, _) => _sync());
  }

  final Ref? _ref;

  void _sync() {
    final ref = _ref!;
    final next = _fromSession(
      ref.read(sessionControllerProvider),
      ref.read(serverConfigProvider)?.url,
    );
    // Keep a failure message across the state change it caused.
    state = next.status == AuthStatus.unauthenticated && state.error != null
        ? AuthState(
            status: next.status,
            serverUrl: next.serverUrl,
            error: state.error,
          )
        : next;
  }

  SessionController get _session =>
      _ref!.read(sessionControllerProvider.notifier);

  /// Loads the stored server and session.
  Future<void> checkAuth() => _session.bootstrap();

  /// Returns false and sets [AuthState.error] on failure.
  Future<bool> configureServer(String url, {bool allowInsecure = false}) async {
    try {
      await _session.configureServer(url, allowInsecure: allowInsecure);
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        serverUrl: state.serverUrl,
        error: describeAuthError(e),
      );
      return false;
    }
  }

  /// Returns false and sets [AuthState.error] on failure.
  Future<bool> login(String email, String password) async {
    try {
      await _session.login(email, password);
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        serverUrl: state.serverUrl,
        error: describeAuthError(e),
      );
      return false;
    }
  }

  Future<void> logout() => _session.logout();

  /// Go back to server setup.
  Future<void> clearServerConfig() => _session.clearServer();
}

/// Auth provider (adapter over [sessionControllerProvider]).
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
