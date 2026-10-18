import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/common/widgets/async_states.dart';
import 'package:tududa/common/widgets/offline_banner.dart';
import 'package:tududa/common/widgets/sync_indicator.dart';
import 'package:tududa/core/sync/sync_status.dart';

import 'a11y_support.dart';

class _Status extends SyncStatusNotifier {
  _Status(this.value);
  final SyncStatus value;
  @override
  SyncStatus build() => value;
}

/// The shared loading / empty / offline / error states and the sync widgets
/// (offline banner, sync indicator) in every status.
void main() {
  final states = <String, Widget Function()>{
    'skeleton': () => const SkeletonList(rows: 3),
    'empty': () => const EmptyState(
      icon: Icons.inbox_outlined,
      title: 'All clear',
      hint: 'Add tasks with quick add.',
    ),
    'offline': () => OfflineState(onRetry: () {}),
    'error': () => ErrorState(error: Exception('boom'), onRetry: () {}),
  };
  final statuses = <String, SyncStatus>{
    'offline': const SyncStatus(phase: SyncPhase.offline, pendingCount: 3),
    'signed_out': const SyncStatus(phase: SyncPhase.signedOut),
    'stuck': const SyncStatus(stuckCount: 2),
    'waiting': const SyncStatus(pendingCount: 4),
    'idle': const SyncStatus(),
  };

  for (final brightness in a11yBrightnesses) {
    for (final locale in a11yLocales) {
      final label = '${brightness.name} ${locale.languageCode}';

      for (final s in states.entries) {
        a11yTest('${s.key} state $label', (tester, rig, data) async {
          await pumpA11y(
            tester,
            rig,
            home: Scaffold(body: s.value()),
            brightness: brightness,
            locale: locale,
          );
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        });
      }

      for (final s in statuses.entries) {
        a11yTest('sync ${s.key} $label', (tester, rig, data) async {
          await pumpA11y(
            tester,
            rig,
            home: Scaffold(
              appBar: AppBar(actions: const [SyncIndicator()]),
              body: const Column(children: [OfflineBanner()]),
            ),
            brightness: brightness,
            locale: locale,
            overrides: [
              syncStatusProvider.overrideWith(() => _Status(s.value)),
            ],
          );
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        });
      }
    }
  }
}
