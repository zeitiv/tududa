import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/time/calendar_date.dart';
import '../../l10n/l10n_ext.dart';
import '../providers/task_provider.dart';
import '../widgets/api_error_message.dart';
import 'quick_add_support.dart';

/// A single-line "add a task" field for the end of a list. Understands the
/// same phrases as the quick-add sheet; [defaultDue] and [defaultProject]
/// apply when the text does not name its own.
class InlineAddRow extends ConsumerStatefulWidget {
  const InlineAddRow({super.key, this.defaultDue, this.defaultProject});

  final CalendarDate? defaultDue;
  final ProjectUid? defaultProject;

  @override
  ConsumerState<InlineAddRow> createState() => _InlineAddRowState();
}

class _InlineAddRowState extends ConsumerState<InlineAddRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _saving) return;
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final lookups = ref.read(quickAddLookupsProvider);
    final parsed = parseQuickAdd(
      text: text,
      today: ref.read(taskDayProvider).date,
      locale: locale,
      lookups: lookups,
    );
    final draft = mergeQuickAdd(parsed, const QuickAddManual(), lookups);
    if (!draft.canSave) return;
    setState(() => _saving = true);
    final result = await createFromDraft(
      ref,
      draft,
      defaultDue: widget.defaultDue,
      defaultProject: widget.defaultProject,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.ok) {
      _controller.clear();
    } else {
      messenger?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(l10n, result.error!))),
      );
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the name lookups loaded while the row is on screen.
    ref.watch(quickAddLookupsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        key: const Key('inlineAddField'),
        controller: _controller,
        focusNode: _focus,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: context.l10n.quickAddInlineHint,
          prefixIcon: const Icon(Icons.add),
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
