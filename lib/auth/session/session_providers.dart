import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/secure_cookie_storage.dart';
import '../../core/platform/session_bridge.dart';
import '../../core/time/user_clock.dart';
import 'server_config.dart';
import 'session_controller.dart';

/// File-backed cookie storage whose directory
/// (`<app documents>/.cookies/`, as before) is resolved on first use, so the
/// jar can be created synchronously.
///
/// Used off Android; on Android cookies live in the native vault
/// ([SecureCookieStorage]).
class LazyFileCookieStorage extends Storage {
  LazyFileCookieStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;
  FileStorage? _inner;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    final dir = await _directory();
    _inner = FileStorage('${dir.path}/.cookies/');
    await _inner!.init(persistSession, ignoreExpires);
  }

  FileStorage get _storage {
    final s = _inner;
    if (s == null) throw StateError('Cookie storage used before init()');
    return s;
  }

  @override
  Future<String?> read(String key) => _storage.read(key);

  @override
  Future<void> write(String key, String value) => _storage.write(key, value);

  @override
  Future<void> delete(String key) => _storage.delete(key);

  @override
  Future<void> deleteAll(List<String> keys) => _storage.deleteAll(keys);
}

/// The session cookie jar shared by every request.
final cookieJarProvider = Provider<CookieJar>(
  (ref) => PersistCookieJar(
    storage: hasNativeBridges
        ? SecureCookieStorage(ref.watch(sessionBridgeProvider))
        : LazyFileCookieStorage(),
  ),
);

/// Validates a server address before it is saved. Tests override
/// [dioTuningProvider] to give it a fake adapter.
final serverValidatorProvider = Provider<ServerValidator>(
  (ref) => ServerValidator(adapter: ref.watch(dioTuningProvider).adapter),
);

/// "What day is it for the user?" One instance for the app: its zone follows
/// the signed-in user's timezone and its skew is fed by the HTTP stack.
final userClockProvider = Provider<UserClock>((ref) {
  final clock = UserClock(now: ref.watch(dioTuningProvider).now);
  ref.listen<String?>(
    sessionControllerProvider.select(
      (s) => s is SessionSignedIn ? s.user.timezone : null,
    ),
    (_, zone) {
      if (zone != null) clock.zoneName = zone;
    },
    fireImmediately: true,
  );
  return clock;
});
