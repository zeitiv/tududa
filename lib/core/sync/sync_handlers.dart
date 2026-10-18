import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../areas/data/area_sync_handler.dart';
import '../../inbox/data/inbox_sync_handler.dart';
import '../../notes/data/note_sync_handler.dart';
import '../../projects/data/project_sync_handler.dart';
import '../../tags/data/tag_sync_handler.dart';
import '../../tasks/data/task_sync_handler.dart';
import 'sync_handler.dart';

/// Every entity handler the engine drives (the composition root of the sync
/// layer). The engine orders them by `SyncEntity.pullOrder` itself. Tests pass
/// handlers straight to `SyncEngine(handlers: ...)` instead.
final syncHandlersProvider = Provider<List<SyncHandler>>(
  (ref) => <SyncHandler>[
    AreaSyncHandler(),
    ProjectSyncHandler(),
    TagSyncHandler(),
    ref.watch(taskSyncHandlerProvider),
    NoteSyncHandler(),
    InboxSyncHandler(),
  ],
);
