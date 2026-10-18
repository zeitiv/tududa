import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/note_provider.dart';
import '../domain/note.dart';
import '../../common/widgets/glass_container.dart';
import '../../l10n/strings.dart';

/// Notes list screen with card/grid layout.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final noteState = ref.watch(noteListProvider);
    final notes = noteState.value ?? const <Note>[];
    final strings = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(strings.notes)),
      body: noteState.isLoading && !noteState.hasValue
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.note_outlined,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.noNotesYet,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(noteListProvider.notifier).refresh(),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _NoteCard(
                    note: note,
                    onTap: () {
                      context.push(
                        '/notes/${Uri.encodeComponent(note.uid.value)}',
                      );
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/notes/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.newNote),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const _NoteCard({required this.note, required this.onTap});

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final value = int.tryParse(hex, radix: 16);
    return value != null ? Color(value) : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteColor = _parseColor(note.color);

    return GlassContainer(
      color: noteColor ?? theme.colorScheme.surface,
      opacity: noteColor != null ? 0.3 : 0.15,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.title != null && note.title!.isNotEmpty)
                Text(
                  note.title!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (note.title != null && note.title!.isNotEmpty)
                const SizedBox(height: 6),
              Expanded(
                child: Text(
                  note.content ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (note.projectName != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              note.projectName!,
                              style: theme.textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (note.updatedAt != null)
                    Text(
                      DateFormat.MMMd().format(note.updatedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
