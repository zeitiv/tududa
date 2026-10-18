import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_error.dart';
import '../../core/utils/constants.dart';
import '../../settings/providers/settings_provider.dart';

/// Why a server address could not be used (as opposed to an [ApiError]
/// from talking to it).
sealed class ServerConfigError implements Exception {
  const ServerConfigError(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The text is empty or cannot be turned into an http(s) URL.
final class InvalidServerUrlError extends ServerConfigError {
  const InvalidServerUrlError(super.message);
}

/// Plain `http://` was used without `allowInsecure: true`. The UI shows a
/// confirmation and retries with the flag set.
final class InsecureServerError extends ServerConfigError {
  const InsecureServerError(this.url)
    : super('Plain HTTP is not encrypted: $url');
  final String url;
}

final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

/// Turns user input into `scheme://host[:port][/path]` with no trailing
/// slash and no trailing `/api` (the client appends it). Adds `https://` when
/// no scheme is given. Throws [InvalidServerUrlError].
String normalizeServerUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) {
    throw const InvalidServerUrlError('Enter a server address');
  }
  if (!_scheme.hasMatch(text)) text = 'https://$text';

  final Uri uri;
  try {
    uri = Uri.parse(text);
  } on FormatException {
    throw const InvalidServerUrlError('That is not a valid address');
  }
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      text.contains(RegExp(r'\s'))) {
    throw const InvalidServerUrlError('That is not a valid address');
  }

  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (path.toLowerCase().endsWith('/api')) {
    path = path.substring(0, path.length - 4).replaceAll(RegExp(r'/+$'), '');
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  return '${uri.scheme}://$host$port$path';
}

bool isInsecureServerUrl(String normalized) => normalized.startsWith('http://');

/// What the server told us about itself.
class ServerInfo {
  const ServerInfo({required this.url, required this.isInsecure, this.version});
  final String url;
  final bool isInsecure;
  final String? version;
}

/// Checks that a URL is a reachable Tududi server (`GET /api/health`, then
/// best-effort `GET /api/version`) using a bare client: no cookies, no
/// re-auth, no retries.
class ServerValidator {
  ServerValidator({this._adapter});
  final HttpClientAdapter? _adapter;

  /// Throws [InvalidServerUrlError], [InsecureServerError] or an [ApiError]
  /// (network/timeout/server) when the server cannot be used.
  Future<ServerInfo> validate(
    String input, {
    bool allowInsecure = false,
  }) async {
    final url = normalizeServerUrl(input);
    final insecure = isInsecureServerUrl(url);
    if (insecure && !allowInsecure) throw InsecureServerError(url);

    final dio = Dio(
      BaseOptions(
        baseUrl: '$url/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {Headers.acceptHeader: Headers.jsonContentType},
      ),
    );
    if (_adapter != null) dio.httpClientAdapter = _adapter;
    try {
      try {
        await dio.get<Object?>('/health');
      } on DioException catch (e) {
        throw ApiError.fromDio(e);
      }
      String? version;
      try {
        final res = await dio.get<Object?>('/version');
        final data = res.data;
        if (data is Map && data['version'] != null) {
          version = data['version'].toString();
        }
      } on DioException {
        // /api/version is optional.
      }
      return ServerInfo(url: url, isInsecure: insecure, version: version);
    } finally {
      dio.close();
    }
  }
}

/// The configured server.
class ServerConfig {
  const ServerConfig({required this.url, this.allowInsecure = false});
  final String url;
  final bool allowInsecure;

  @override
  bool operator ==(Object other) =>
      other is ServerConfig &&
      other.url == url &&
      other.allowInsecure == allowInsecure;

  @override
  int get hashCode => Object.hash(url, allowInsecure);
}

const _allowInsecureKey = 'server_allow_insecure';

/// Persists the server URL (key `server_url`, unchanged from earlier
/// versions) and the explicit plain-HTTP opt-in.
class ServerConfigNotifier extends Notifier<ServerConfig?> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ServerConfig? build() {
    final url = _prefs.getString(AppConstants.serverUrlKey);
    if (url == null || url.isEmpty) return null;
    return ServerConfig(
      url: url,
      allowInsecure: _prefs.getBool(_allowInsecureKey) ?? false,
    );
  }

  Future<void> set(ServerConfig config) async {
    await _prefs.setString(AppConstants.serverUrlKey, config.url);
    await _prefs.setBool(_allowInsecureKey, config.allowInsecure);
    state = config;
  }

  Future<void> clear() async {
    await _prefs.remove(AppConstants.serverUrlKey);
    await _prefs.remove(_allowInsecureKey);
    state = null;
  }
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfig?>(
      ServerConfigNotifier.new,
    );
