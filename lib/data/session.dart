import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../os/os.dart';
import 'links.dart';
import 'tududi.dart';

/// Fetches everything again: Tududi and whichever links are live.
Future<void> syncAll(WidgetRef ref) async {
  await Future.wait([
    ref.read(tasksProvider.notifier).load(),
    ref.read(projectsProvider.notifier).load(),
    ref.read(areasProvider.notifier).load(),
    ref.read(notesProvider.notifier).load(),
    ref.read(inboxProvider.notifier).load(),
    ref.read(karakeepProvider.notifier).refresh(),
    ref.read(memosProvider.notifier).refresh(),
    ref.read(flatProvider.notifier).refresh(),
  ]);
}

/// Forgets everything held for the session, after signing out.
void resetAll(WidgetRef ref) {
  ref.invalidate(tasksProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(areasProvider);
  ref.invalidate(notesProvider);
  ref.invalidate(inboxProvider);
  ref.invalidate(karakeepProvider);
  ref.invalidate(memosProvider);
  ref.invalidate(flatProvider);
  ref.invalidate(osProvider);
}
