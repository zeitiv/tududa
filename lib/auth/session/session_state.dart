import '../domain/user.dart';

/// Where the user is in the sign-in lifecycle.
sealed class SessionState {
  const SessionState();
}

/// Bootstrap has not finished.
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// No server URL stored yet.
final class SessionNoServer extends SessionState {
  const SessionNoServer();
}

/// Server known, nobody signed in. [lastEmail] pre-fills the login form.
final class SessionSignedOut extends SessionState {
  const SessionSignedOut({this.lastEmail});
  final String? lastEmail;
}

/// A login request is in flight.
final class SessionAuthenticating extends SessionState {
  const SessionAuthenticating({this.lastEmail});
  final String? lastEmail;
}

/// [offline] is true when the server was unreachable and [user] comes from
/// the local cache.
final class SessionSignedIn extends SessionState {
  const SessionSignedIn(this.user, {this.offline = false});
  final User user;
  final bool offline;
}

/// The server rejected the session and silent re-login was impossible or
/// refused. The user has to sign in again.
final class SessionExpired extends SessionState {
  const SessionExpired({this.lastEmail});
  final String? lastEmail;
}
