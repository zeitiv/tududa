import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dio configured for the signed-in server (CSRF, re-auth, retry included).
///
/// Repositories read this provider; they never build their own client.
/// Production wiring lives in `lib/auth/session/` (session lane). Tests
/// override it with `makeDio(FakeTududi)` / `TestStack.dio`.
final dioProvider = Provider<Dio>(
  (ref) => throw StateError(
    'dioProvider has no server configured. Override it in tests or wire it '
    'from the session controller.',
  ),
);
