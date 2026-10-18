import '../fake_tududi.dart';

/// Extension point for milestone lanes.
///
/// To teach the fake server new endpoints, add a file named
/// `<name>_routes.dart` in this directory exposing a [RouteRegistrar], e.g.
///
/// ```dart
/// void registerProjectRoutes(FakeTududi s) {
///   s.route('GET', '/projects', (ctx) => FakeTududi.json(200, {...}));
/// }
/// ```
///
/// and append it to [registrars] below. Every new [FakeTududi] instance runs
/// all registrars after the built-in routes (later registrations win).
typedef RouteRegistrar = void Function(FakeTududi server);

final List<RouteRegistrar> registrars = <RouteRegistrar>[];
