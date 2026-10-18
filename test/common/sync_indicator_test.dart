import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tududa/common/widgets/offline_banner.dart';
import 'package:tududa/common/widgets/sync_indicator.dart';
import 'package:tududa/core/sync/sync_status.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';

import 'sync_ui_harness.dart';

Future<void> pumpIndicator(WidgetTester tester, SyncStatus s) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(actions: const [SyncIndicator()]),
          body: const OfflineBanner(),
        ),
      ),
      GoRoute(
        path: '/more/sync',
        builder: (_, _) => const Scaffold(body: Text('sync screen')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncStatusProvider.overrideWith(() => FakeSyncStatus(s))],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

void main() {
  const cases = <(String, SyncStatus, String, IconData?)>[
    ('idle', SyncStatus(), 'All changes synced', Icons.check),
    (
      'idle pending',
      SyncStatus(pendingCount: 2),
      '2 changes waiting to sync',
      Icons.sync,
    ),
    ('syncing', SyncStatus(phase: SyncPhase.syncing), 'Syncing', null),
    (
      'offline',
      SyncStatus(phase: SyncPhase.offline, pendingCount: 3),
      'Offline, 3 changes waiting to sync',
      Icons.cloud_off,
    ),
    (
      'error',
      SyncStatus(phase: SyncPhase.error, failedCount: 1),
      'Sync problem, 1 change failed',
      Icons.warning_amber_rounded,
    ),
    (
      'stuck',
      SyncStatus(stuckCount: 2),
      'Sync problem, 2 changes failed',
      Icons.warning_amber_rounded,
    ),
    (
      'signed out',
      SyncStatus(phase: SyncPhase.signedOut, pendingCount: 1),
      'Signed out, 1 change waiting to sync',
      Icons.lock_outline,
    ),
  ];

  for (final (name, status, label, icon) in cases) {
    testWidgets('indicator: $name', (tester) async {
      await pumpIndicator(tester, status);
      expect(find.bySemanticsLabel(label), findsWidgets);
      if (icon != null) {
        expect(
          find.descendant(
            of: find.byType(SyncIndicator),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
        );
      } else {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
    });
  }

  testWidgets('indicator meets the tap target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpIndicator(tester, const SyncStatus(pendingCount: 1));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('indicator opens the sync screen', (tester) async {
    await pumpIndicator(tester, const SyncStatus());
    await tester.tap(find.byType(SyncIndicator));
    await tester.pumpAndSettle();
    expect(find.text('sync screen'), findsOneWidget);
  });

  group('banner', () {
    testWidgets('hidden when idle or syncing', (tester) async {
      await pumpIndicator(tester, const SyncStatus(pendingCount: 2));
      expect(find.text('Sync now'), findsNothing);
      expect(tester.getSize(find.byType(OfflineBanner)).height, 0);
    });

    testWidgets('shown when offline with Sync now', (tester) async {
      await pumpIndicator(
        tester,
        const SyncStatus(phase: SyncPhase.offline, pendingCount: 3),
      );
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Offline, 3 changes waiting to sync'), findsOneWidget);
    });

    testWidgets('shown when signed out or stuck with Retry', (tester) async {
      await pumpIndicator(tester, const SyncStatus(phase: SyncPhase.signedOut));
      expect(find.text('Retry'), findsOneWidget);
      await pumpIndicator(tester, const SyncStatus(stuckCount: 1));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('announces as a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIndicator(tester, const SyncStatus(phase: SyncPhase.offline));
      expect(
        find.semantics.byPredicate(
          (n) =>
              n.label == 'Offline, nothing waiting to sync' &&
              n.flagsCollection.isLiveRegion,
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  testWidgets('banner does not overflow at 2.0 text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith(
            () => FakeSyncStatus(
              const SyncStatus(phase: SyncPhase.offline, pendingCount: 12),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: Column(children: [OfflineBanner()])),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
