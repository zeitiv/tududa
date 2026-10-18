import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/common/undo/undo_controller.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('message without token has no Undo action', (t) async {
    late WidgetRef ref;
    late BuildContext ctx;
    await pumpApp(
      t,
      home: Scaffold(
        body: Consumer(
          builder: (context, r, _) {
            ref = r;
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    ref.read(undoControllerProvider).show(ctx, 'Task deleted', null);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });
}
