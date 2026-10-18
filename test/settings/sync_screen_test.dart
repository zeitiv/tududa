import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/db/app_database.dart';
import 'package:tududa/core/sync/merge.dart';
import 'package:tududa/core/sync/sync_status.dart';
import 'package:tududa/l10n/gen/app_localizations.dart';
import 'package:tududa/settings/screens/sync_screen.dart';

import '../common/sync_ui_harness.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  SyncUiHarness h, {
  required List<OutboxEntry> entries,
  Override? outbox,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...h.overrides,
        outbox ??
            outboxEntriesProvider.overrideWith((ref) => Stream.value(entries)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SyncScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('lists queued entries and last synced', (tester) async {
    final h = SyncUiHarness(
      status: SyncStatus(
        phase: SyncPhase.offline,
        lastSyncAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    addTearDown(h.db.close);
    late List<OutboxEntry> entries;
    await tester.runAsync(() async {
      await h.lane.createProject('p1', 'Alpha');
      final id = (await h.db.outboxDao.all()).single.id;
      await h.db.outboxDao.markStuck(id, error: 'Server said no');
      entries = await h.db.outboxDao.all();
    });
    await pumpScreen(tester, h, entries: entries);

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Last synced 5 minutes ago'), findsOneWidget);
    expect(find.text('Project: Create'), findsOneWidget);
    expect(find.text('Stuck - 1 attempt'), findsOneWidget);
    expect(find.text('Server said no'), findsOneWidget);
    expect(find.text('No conflicts to review.'), findsOneWidget);
  });

  testWidgets('empty states and never synced', (tester) async {
    final h = SyncUiHarness();
    addTearDown(h.db.close);
    await pumpScreen(tester, h, entries: const []);
    expect(find.text('Last synced never'), findsOneWidget);
    expect(find.textContaining('Nothing queued'), findsOneWidget);
    expect(find.text('No conflicts to review.'), findsOneWidget);
  });

  testWidgets('loading state', (tester) async {
    final h = SyncUiHarness();
    addTearDown(h.db.close);
    await pumpScreen(
      tester,
      h,
      entries: const [],
      outbox: outboxEntriesProvider.overrideWith(
        (ref) => const Stream<List<OutboxEntry>>.empty(),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error state', (tester) async {
    final h = SyncUiHarness();
    addTearDown(h.db.close);
    await pumpScreen(
      tester,
      h,
      entries: const [],
      outbox: outboxEntriesProvider.overrideWith(
        (ref) => Stream<List<OutboxEntry>>.error('db broke'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('db broke'), findsOneWidget);
  });

  testWidgets('Retry runs retryNow and a sync', (tester) async {
    final h = SyncUiHarness();
    addTearDown(h.db.close);
    late List<OutboxEntry> entries;
    await tester.runAsync(() async {
      await h.lane.createProject('p1', 'Alpha');
      final id = (await h.db.outboxDao.all()).single.id;
      await h.db.outboxDao.markStuck(id, error: 'boom');
      entries = await h.db.outboxDao.all();
    });
    await pumpScreen(tester, h, entries: entries);

    // Drift needs the real zone: call the handler outside fake-async.
    await tester.runAsync(() async {
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Retry'))
          .onPressed!();
      for (var i = 0; i < 100; i++) {
        if ((await h.db.outboxDao.all()).isEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(h.handler.calls, contains('push create p1'));
    expect(await tester.runAsync(h.db.outboxDao.all), isEmpty);
  });

  testWidgets('Discard confirms, rolls back and removes', (tester) async {
    final h = SyncUiHarness();
    addTearDown(h.db.close);
    late List<OutboxEntry> entries;
    await tester.runAsync(() async {
      await h.lane.createProject('p1', 'Alpha');
      entries = await h.db.outboxDao.all();
    });
    await pumpScreen(tester, h, entries: entries);

    Future<void> openDialog() async {
      await tester.runAsync(() async {
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Discard'))
            .onPressed!();
      });
      await tester.pumpAndSettle();
    }

    await openDialog();
    expect(find.text('Discard this change?'), findsOneWidget);

    // Cancel keeps it.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.handler.calls.where((c) => c.startsWith('rollback')), isEmpty);

    await openDialog();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    expect(h.handler.calls, contains('rollback create p1'));
    expect(await tester.runAsync(h.db.outboxDao.all), isEmpty);
  });

  testWidgets('notices are listed and can be dismissed', (tester) async {
    final h = SyncUiHarness(
      status: const SyncStatus(
        notices: [
          ConflictNotice.rolledBack(
            entity: 'project',
            localId: 'p1',
            message: 'Invalid name',
          ),
        ],
      ),
    );
    addTearDown(h.db.close);
    await pumpScreen(tester, h, entries: const []);
    expect(find.text('Project: change - server version kept'), findsOneWidget);
    expect(find.text('Invalid name'), findsOneWidget);

    // Dismiss goes to the (real) engine, which has no notices; just verify
    // the action is wired and does not throw.
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
  });

  testWidgets('2.0 text scale does not overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = SyncUiHarness(
      status: const SyncStatus(
        phase: SyncPhase.error,
        lastError: 'Something rather long went wrong while syncing',
        notices: [
          ConflictNotice.rolledBack(
            entity: 'project',
            localId: 'p1',
            message: 'A long explanatory message about the conflict',
          ),
        ],
      ),
    );
    addTearDown(h.db.close);
    late List<OutboxEntry> entries;
    await tester.runAsync(() async {
      await h.lane.createProject('p1', 'Alpha');
      final id = (await h.db.outboxDao.all()).single.id;
      await h.db.outboxDao.markFailed(
        id,
        error: 'Network error while sending',
        nextAttemptAt: DateTime.now().add(const Duration(minutes: 1)),
      );
      entries = await h.db.outboxDao.all();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          outboxEntriesProvider.overrideWith((ref) => Stream.value(entries)),
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
          home: const SyncScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
