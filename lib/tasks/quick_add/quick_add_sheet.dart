import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens quick add from anywhere. Replaced by the sheet from T5.2; until then
/// it opens the full task form.
Future<void> showQuickAddSheet(
  BuildContext context, {
  String? initialText,
}) async {
  context.push('/tasks/new');
}
