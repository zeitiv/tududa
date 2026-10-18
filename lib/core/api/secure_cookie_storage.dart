import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/session_bridge.dart';

/// cookie_jar [Storage] that keeps cookies in the native vault through
/// `SessionBridge.readCookies/writeCookies` (one entry per jar key, which is
/// the host name or an index key).
///
/// On first [init] it moves cookies from the old file storage
/// (`<app documents>/.cookies/ie*_ps*/<key>`) into the vault, then deletes
/// that folder so no plaintext cookie stays on disk. The folder is only
/// deleted after every write succeeded.
class SecureCookieStorage extends Storage {
  SecureCookieStorage(
    this._bridge, {
    Future<Directory> Function()? documentsDirectory,
  }) : _documents = documentsDirectory ?? getApplicationDocumentsDirectory;

  final SessionBridge _bridge;
  final Future<Directory> Function() _documents;

  static const _prefix = 'dart-jar/';

  String _key(String key) => '$_prefix$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    try {
      final docs = await _documents();
      await migrateLegacy(
        Directory('${docs.path}/.cookies'),
        persistSession: persistSession,
        ignoreExpires: ignoreExpires,
      );
    } catch (e) {
      // Cookies are a cache of the session: losing them means signing in
      // again silently, never a crash.
      if (kDebugMode) debugPrint('cookie migration failed: ${e.runtimeType}');
    }
  }

  /// Moves the files of [legacy] into the vault, then deletes [legacy].
  /// Only the sub-folder matching the jar's flags is imported (the others
  /// belong to jars with other settings). Idempotent.
  @visibleForTesting
  Future<void> migrateLegacy(
    Directory legacy, {
    required bool persistSession,
    required bool ignoreExpires,
  }) async {
    if (!legacy.existsSync()) return;
    final sub = Directory(
      '${legacy.path}/ie${ignoreExpires ? 1 : 0}_ps${persistSession ? 1 : 0}',
    );
    if (sub.existsSync()) {
      for (final entity in sub.listSync()) {
        if (entity is! File) continue;
        final key = entity.uri.pathSegments.last;
        final value = await entity.readAsString();
        if (value.isEmpty) continue;
        // Never overwrite what the vault already holds.
        if ((await _bridge.readCookies(_key(key))).isEmpty) {
          await _bridge.writeCookies(_key(key), [value]);
        }
      }
    }
    await legacy.delete(recursive: true);
  }

  @override
  Future<String?> read(String key) async {
    final values = await _bridge.readCookies(_key(key));
    return values.isEmpty ? null : values.first;
  }

  @override
  Future<void> write(String key, String value) =>
      _bridge.writeCookies(_key(key), [value]);

  @override
  Future<void> delete(String key) => _bridge.writeCookies(_key(key), const []);

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _bridge.writeCookies(_key(key), const []);
    }
  }
}
