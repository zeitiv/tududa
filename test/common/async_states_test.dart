import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/common/widgets/async_states.dart';
import 'package:tududa/core/api/api_error.dart';
import 'package:tududa/core/sync/sync_status.dart';

import '../support/pump_app.dart';
import 'sync_ui_harness.dart';

Future<void> _pump(
  WidgetTester tester,
  AsyncValue<List<int>> value, {
  SyncStatus status = const SyncStatus(),
  VoidCallback? onRetry,
  Locale? locale,
  double textScale = 1.0,
}) => pumpApp(
  tester,
  locale: locale,
  overrides: [syncStatusProvider.overrideWith(() => FakeSyncStatus(status))],
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    ),
    child: Scaffold(
      body: AsyncStateView<List<int>>(
        value: value,
        emptyTitle: 'Nothing here',
        emptyHint: 'hint',
        onRetry: onRetry,
        data: (d) => Text('data ${d.length}'),
      ),
    ),
  ),
);

void main() {
  testWidgets('loading shows the skeleton', (tester) async {
    await _pump(tester, const AsyncLoading());
    expect(find.byType(SkeletonList), findsOneWidget);
  });

  testWidgets('data is shown', (tester) async {
    await _pump(tester, const AsyncData([1, 2]));
    expect(find.text('data 2'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester, const AsyncData(<int>[]));
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('hint'), findsOneWidget);
  });

  testWidgets('empty while offline shows the offline state', (tester) async {
    await _pump(
      tester,
      const AsyncData(<int>[]),
      status: const SyncStatus(phase: SyncPhase.offline),
    );
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.text('Nothing here'), findsNothing);
  });

  testWidgets('typed error shows a localized message and retries', (
    tester,
  ) async {
    var retried = 0;
    await _pump(
      tester,
      AsyncError<List<int>>(const NetworkError(), StackTrace.empty),
      onRetry: () => retried++,
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('connect', findRichText: true), findsWidgets);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  for (final loc in const [Locale('de'), Locale('zh')]) {
    testWidgets('${loc.languageCode} error at text scale 2.0', (tester) async {
      await _pump(
        tester,
        AsyncError<List<int>>(const TimeoutError(), StackTrace.empty),
        onRetry: () {},
        locale: loc,
        textScale: 2.0,
      );
      expect(find.byType(ErrorState), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
