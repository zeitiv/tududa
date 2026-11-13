import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/tududi.dart';
import '../../tasks/models/task_model.dart';
import '../kit/controls.dart';
import '../kit/motion.dart';
import '../kit/tokens.dart';
import '../l10n.dart';
import '../os.dart';
import '../wall.dart' show ago;
import '../window.dart';
import 'tasks.dart';

class InboxApp extends ConsumerWidget {
  const InboxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(inboxProvider);
    final inbox = ref.read(inboxProvider.notifier);
    return AppPane(
      app: AppId.inbox,
      sub: tr('{n} to sort', {'n': s.items.length}),
      body: !s.loaded && s.loading
          ? const Padding(padding: EdgeInsets.all(16), child: Loading())
          : s.items.isEmpty
              ? Empty(tr('Inbox zero'), hint: tr('Drop anything here and decide later what it is.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                  itemCount: s.items.length,
                  itemBuilder: (context, i) {
                    final item = s.items[i];
                    return Enter(
                      key: ValueKey(item.uid ?? item.id),
                      i: i,
                      child: RowTile(
                        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OsIconButton(
                              Icons.add_task_rounded,
                              tooltip: tr('Make it a task'),
                              filled: false,
                              color: context.accent,
                              onTap: () {
                                thud();
                                ref.read(tasksProvider.notifier).add(Task(name: item.content));
                                inbox.process(item);
                                ref.read(osProvider.notifier).toast(tr('Moved to Tasks'),
                                    action: tr('Open'),
                                    onAction: () =>
                                        ref.read(osProvider.notifier).open(AppId.tasks));
                              },
                            ),
                            OsIconButton(
                              Icons.close_rounded,
                              tooltip: tr('Delete'),
                              filled: false,
                              onTap: () => inbox.remove(item),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.content, style: sans(15.5, height: 1.3)),
                            const SizedBox(height: 4),
                            Label(ago(item.createdAt)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      bottom: QuickAdd(hint: tr('Drop something in'), onAdd: inbox.add),
    );
  }
}
