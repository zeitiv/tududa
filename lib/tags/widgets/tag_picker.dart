import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/tag_provider.dart';

/// Wrap of filter chips over all known tags. Reports the new set of selected
/// tag names whenever one is toggled.
class TagPicker extends ConsumerWidget {
  const TagPicker({super.key, required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagListProvider);
    return tags.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const SizedBox.shrink(),
      data: (list) => Wrap(
        spacing: 8,
        children: [
          for (final t in list)
            FilterChip(
              label: Text(t.name),
              selected: selected.contains(t.name),
              onSelected: (on) => onChanged([
                for (final n in selected)
                  if (n != t.name) n,
                if (on) t.name,
              ]),
            ),
        ],
      ),
    );
  }
}
