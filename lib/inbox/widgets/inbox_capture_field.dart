import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../l10n/l10n_ext.dart';
import '../providers/inbox_provider.dart';

/// Capture field at the top of the inbox. Writes to the local database, so it
/// works offline; the item syncs later.
class InboxCaptureField extends ConsumerStatefulWidget {
  const InboxCaptureField({super.key});

  @override
  ConsumerState<InboxCaptureField> createState() => _InboxCaptureFieldState();
}

class _InboxCaptureFieldState extends ConsumerState<InboxCaptureField> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(inboxProvider.notifier).capture(text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.inboxV2CaptureFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final tokens = Theme.of(context).extension<AppTokens>();
    final gap = tokens?.space3 ?? 12;
    return Padding(
      padding: EdgeInsets.fromLTRB(gap, gap, gap, gap / 2),
      child: TextField(
        controller: _controller,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: strings.inboxV2CaptureHint,
          prefixIcon: const Icon(Icons.inbox_outlined),
          suffixIcon: IconButton(
            tooltip: strings.inboxV2CaptureSend,
            icon: const Icon(Icons.arrow_upward_rounded),
            onPressed: _busy ? null : _submit,
          ),
        ),
      ),
    );
  }
}
