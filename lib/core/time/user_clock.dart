import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_date.dart';

/// "What day is it for the user?" Combines the user's IANA zone with the
/// measured offset between the device clock and the server clock.
///
/// Inject [now] in tests. [now] must return the real instant (zone-agnostic;
/// UTC or local both work).
class UserClock {
  UserClock({
    DateTime Function()? now,
    String? zoneName,
    this.serverSkew = Duration.zero,
  }) : _now = now ?? DateTime.now {
    _ensureInitialized();
    _location = _resolve(zoneName);
  }

  /// Builds a clock using the profile zone [zoneName] when valid, else the
  /// device zone (flutter_timezone), else UTC.
  static Future<UserClock> create({
    DateTime Function()? now,
    String? zoneName,
    Duration serverSkew = Duration.zero,
    Future<String> Function()? deviceZone,
  }) async {
    _ensureInitialized();
    var name = zoneName;
    if (!_isValid(name)) {
      try {
        name = await (deviceZone ?? _deviceZone)();
      } catch (_) {
        name = null;
      }
    }
    return UserClock(now: now, zoneName: name, serverSkew: serverSkew);
  }

  static Future<String> _deviceZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  static bool _initialized = false;
  static void _ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static bool _isValid(String? name) {
    if (name == null || name.isEmpty) return false;
    _ensureInitialized();
    try {
      tz.getLocation(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  static tz.Location _resolve(String? name) =>
      _isValid(name) ? tz.getLocation(name!) : tz.UTC;

  final DateTime Function() _now;
  late tz.Location _location;

  /// IANA name of the zone in use (`UTC` when none could be resolved).
  String get zoneName => _location.name;
  set zoneName(String? name) => _location = _resolve(name);

  /// `serverTime - deviceTime`. Added to the device clock.
  Duration serverSkew;

  /// The current moment (skew-corrected) in the user's zone.
  tz.TZDateTime nowInZone() =>
      tz.TZDateTime.from(_now().add(serverSkew), _location);

  /// Today's calendar date in the user's zone.
  CalendarDate today() => CalendarDate.fromDateTime(nowInZone());
}
