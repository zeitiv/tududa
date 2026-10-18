import '../../core/platform/session_bridge.dart';
import 'credential_store.dart';

/// [CredentialStore] backed by the native vault (Keystore-encrypted), reached
/// through the `tududa/session` bridge.
///
/// The vault is written by `SessionBridge.provision` (which also needs the
/// server and account), which `SessionController` calls on every sign-in, so
/// [write] is deliberately a no-op: it must not create a second copy.
/// [clear] wipes the whole vault (credentials, cookies, widget cache).
///
/// SECURITY: never log what [read] returns.
class NativeCredentialStore implements CredentialStore {
  NativeCredentialStore(this._bridge);
  final SessionBridge _bridge;

  @override
  Future<Credentials?> read() async {
    try {
      final c = await _bridge.getCredentials();
      if (c == null || c.email.isEmpty || c.password.isEmpty) return null;
      return Credentials(email: c.email, password: c.password);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Credentials credentials) async {}

  @override
  Future<void> clear() async {
    try {
      await _bridge.clear();
    } catch (_) {
      // Best effort: the caller is already tearing the session down.
    }
  }
}
