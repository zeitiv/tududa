import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_handler.dart';

/// Every entity handler the engine drives. Filled in by the M3 integration
/// task (T3.Z); the engine orders them by `SyncEntity.pullOrder` itself. Tests
/// pass handlers straight to `SyncEngine(handlers: ...)` instead.
final syncHandlersProvider = Provider<List<SyncHandler>>((ref) => []);
