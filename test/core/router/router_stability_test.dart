import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/auth/providers/auth_provider.dart';
import 'package:tududa/core/router/app_router.dart';

class FakeAuthNotifier extends AuthNotifier {
  void set(AuthState s) => state = s;
}

void main() {
  test('routerProvider is stable across auth changes', () async {
    final fake = FakeAuthNotifier();
    final container = ProviderContainer(
      overrides: [authProvider.overrideWith((ref) => fake)],
    );
    addTearDown(container.dispose);

    final before = container.read(routerProvider);
    fake.set(const AuthState(status: AuthStatus.loading));
    fake.set(
      const AuthState(
        status: AuthStatus.unauthenticated,
        serverUrl: 'https://example.com',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(identical(container.read(routerProvider), before), isTrue);

    fake.set(const AuthState(status: AuthStatus.authenticated));
    await Future<void>.delayed(Duration.zero);
    expect(identical(container.read(routerProvider), before), isTrue);
  });
}
