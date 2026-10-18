import '../../auth/providers/auth_provider.dart';

const _loginPath = '/login';
const _serverConfigPath = '/server-config';
const _homePath = '/today';

bool _isAuthPath(String path) =>
    path == _loginPath || path == _serverConfigPath;

/// True if [from] is an internal, non-auth path that is safe to redirect to.
bool isSafeFromPath(String? from) {
  if (from == null || from.isEmpty) return false;
  if (!from.startsWith('/') || from.startsWith('//')) return false;
  if (from.contains('\\')) return false;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
  return !_isAuthPath(uri.path);
}

/// Pure redirect decision for the auth flow. Returns null for no redirect.
String? authRedirect({
  required AuthStatus status,
  required bool hasServer,
  required Uri location,
}) {
  if (status == AuthStatus.loading || status == AuthStatus.initial) {
    return null;
  }

  final path = location.path;
  final isAuthRoute = _isAuthPath(path);

  if (status != AuthStatus.authenticated) {
    if (!hasServer) {
      return path == _serverConfigPath ? null : _serverConfigPath;
    }
    if (isAuthRoute) return null;
    return Uri(
      path: _loginPath,
      queryParameters: {'from': location.toString()},
    ).toString();
  }

  // Authenticated, redirect away from auth pages
  if (isAuthRoute) {
    final from = location.queryParameters['from'];
    return isSafeFromPath(from) ? from : _homePath;
  }
  return null;
}
