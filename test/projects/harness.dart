import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tududa/core/api/api_providers.dart';

import '../support/api_stack.dart';
import '../support/fake_tududi/fake_tududi.dart';
import '../support/fake_tududi/routes/projects_routes.dart';

/// A signed-in stack against a [FakeTududi] with the project/area routes.
class ProjectsHarness {
  ProjectsHarness._(this.server, this.stack);

  final FakeTududi server;
  final TestStack stack;
  Dio get dio => stack.dio;

  static Future<ProjectsHarness> create() async {
    final server = FakeTududi()..addUser('a@b.c', 'pw');
    registerProjectRoutes(server);
    final callbacks = FakeAuthCallbacks();
    final stack = TestStack(server, callbacks: callbacks);
    Future<void> login() async {
      await stack.dio.post(
        '/login',
        data: {'email': 'a@b.c', 'password': 'pw'},
      );
    }

    callbacks.onReauth = () async {
      await login();
      return true;
    };
    await login();
    return ProjectsHarness._(server, stack);
  }

  ProviderContainer container() =>
      ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}
