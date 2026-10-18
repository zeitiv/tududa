import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Email and password kept so an expired session can be renewed silently.
///
/// SECURITY: the password must never be written to SharedPreferences, files
/// or logs. [toString] redacts it; keep it that way.
class Credentials {
  const Credentials({required this.email, required this.password});
  final String email;
  final String password;

  @override
  String toString() => 'Credentials(email: $email, password: <redacted>)';
}

/// Where [Credentials] live. Implementations must be secure storage or
/// memory only.
abstract class CredentialStore {
  Future<Credentials?> read();
  Future<void> write(Credentials credentials);
  Future<void> clear();
}

/// Lives as long as the process; lost on restart (the user signs in again
/// once the session cookie expires).
class InMemoryCredentialStore implements CredentialStore {
  Credentials? _value;

  @override
  Future<Credentials?> read() async => _value;

  @override
  Future<void> write(Credentials credentials) async => _value = credentials;

  @override
  Future<void> clear() async => _value = null;
}

/// Stores nothing, so silent re-login is disabled.
class NoopCredentialStore implements CredentialStore {
  const NoopCredentialStore();

  @override
  Future<Credentials?> read() async => null;

  @override
  Future<void> write(Credentials credentials) async {}

  @override
  Future<void> clear() async {}
}

/// In memory for now; milestone 7 swaps in the native secure vault.
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => InMemoryCredentialStore(),
);
