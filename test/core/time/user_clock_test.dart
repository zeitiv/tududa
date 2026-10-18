import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/core/time/user_clock.dart';

void main() {
  UserClock clockAt(
    DateTime utc,
    String zone, [
    Duration skew = Duration.zero,
  ]) => UserClock(now: () => utc, zoneName: zone, serverSkew: skew);

  group('Pacific/Kiritimati (UTC+14)', () {
    test('23:59 local is still the previous UTC day', () {
      final c = clockAt(DateTime.utc(2025, 3, 10, 9, 59), 'Pacific/Kiritimati');
      expect(c.nowInZone().hour, 23);
      expect(c.today(), const CalendarDate(2025, 3, 10));
    });
    test('00:01 local is the next calendar day', () {
      final c = clockAt(DateTime.utc(2025, 3, 10, 10, 1), 'Pacific/Kiritimati');
      expect(c.nowInZone().hour, 0);
      expect(c.today(), const CalendarDate(2025, 3, 11));
    });
  });

  group('America/Los_Angeles', () {
    test('23:59 local (PDT) -> same day', () {
      final c = clockAt(
        DateTime.utc(2025, 3, 11, 6, 59),
        'America/Los_Angeles',
      );
      expect(c.today(), const CalendarDate(2025, 3, 10));
    });
    test('00:01 local -> next day', () {
      final c = clockAt(DateTime.utc(2025, 3, 11, 7, 1), 'America/Los_Angeles');
      expect(c.today(), const CalendarDate(2025, 3, 11));
    });
    test('winter offset (PST) shifts the boundary by an hour', () {
      expect(
        clockAt(
          DateTime.utc(2025, 1, 15, 7, 59),
          'America/Los_Angeles',
        ).today(),
        const CalendarDate(2025, 1, 14),
      );
      expect(
        clockAt(DateTime.utc(2025, 1, 15, 8, 1), 'America/Los_Angeles').today(),
        const CalendarDate(2025, 1, 15),
      );
    });
  });

  group('server skew', () {
    test('device two minutes behind pushes past midnight', () {
      final device = DateTime.utc(2025, 3, 11, 6, 58);
      expect(
        clockAt(device, 'America/Los_Angeles').today(),
        const CalendarDate(2025, 3, 10),
      );
      expect(
        clockAt(
          device,
          'America/Los_Angeles',
          const Duration(minutes: 2),
        ).today(),
        const CalendarDate(2025, 3, 11),
      );
    });
    test('device ahead (negative skew) pulls back before midnight', () {
      final device = DateTime.utc(2025, 3, 10, 10, 2);
      final c = clockAt(device, 'Pacific/Kiritimati');
      expect(c.today(), const CalendarDate(2025, 3, 11));
      c.serverSkew = const Duration(minutes: -5);
      expect(c.today(), const CalendarDate(2025, 3, 10));
    });
    test('works with a local-time DateTime too', () {
      final c = UserClock(
        now: () => DateTime.utc(2025, 3, 10, 10, 1).toLocal(),
        zoneName: 'Pacific/Kiritimati',
      );
      expect(c.today(), const CalendarDate(2025, 3, 11));
    });
  });

  group('zone resolution', () {
    test('unknown or missing zone falls back to UTC', () {
      expect(clockAt(DateTime.utc(2025), 'Mars/Olympus').zoneName, 'UTC');
      expect(UserClock(now: () => DateTime.utc(2025)).zoneName, 'UTC');
    });
    test('create(): profile zone wins', () async {
      final c = await UserClock.create(
        zoneName: 'Europe/Berlin',
        deviceZone: () async => 'Asia/Tokyo',
      );
      expect(c.zoneName, 'Europe/Berlin');
    });
    test(
      'create(): device zone when profile zone is missing or invalid',
      () async {
        for (final z in [null, '', 'Nope/Nope']) {
          final c = await UserClock.create(
            zoneName: z,
            deviceZone: () async => 'Asia/Tokyo',
          );
          expect(c.zoneName, 'Asia/Tokyo');
        }
      },
    );
    test('create(): UTC when the device zone lookup fails', () async {
      final c = await UserClock.create(
        deviceZone: () async => throw StateError('x'),
      );
      expect(c.zoneName, 'UTC');
    });
    test('zoneName can be changed', () {
      final c = clockAt(DateTime.utc(2025, 3, 10, 10, 1), 'UTC');
      expect(c.today(), const CalendarDate(2025, 3, 10));
      c.zoneName = 'Pacific/Kiritimati';
      expect(c.today(), const CalendarDate(2025, 3, 11));
    });
  });
}
