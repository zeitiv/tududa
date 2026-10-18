import 'package:flutter/material.dart';

import '../../common/widgets/surface_card.dart';
import '../../core/design/component_states.dart' show ensureContrast;
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/note.dart';

/// Parses `#RRGGBB` / `RRGGBB` / `AARRGGBB`; null when absent or invalid.
Color? parseNoteColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value != null ? Color(value) : null;
}

/// The card background of a note: its colour blended into the surface so the
/// theme's text colours keep their contrast in light and dark mode.
Color noteSurfaceColor(ColorScheme scheme, String? hex) {
  final c = parseNoteColor(hex);
  if (c == null) return scheme.surfaceContainerLow;
  final dark = scheme.brightness == Brightness.dark;
  return Color.alphaBlend(
    c.withValues(alpha: dark ? 0.22 : 0.45),
    scheme.surface,
  );
}

/// A note as a card; used in the grid and in the list layout.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.compact = false,
  });

  final Note note;
  final VoidCallback onTap;

  /// List layout: fewer content lines.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = context.l10n;
    final bg = noteSurfaceColor(scheme, note.color);
    final onBg = ensureContrast(scheme.onSurface, [bg]);
    final muted = ensureContrast(scheme.onSurfaceVariant, [bg]);
    final title = note.title?.trim() ?? '';
    final content = note.content?.trim() ?? '';
    final updated = note.updatedAt?.toLocal();

    return SurfaceCard(
      color: bg,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? strings.noteV2Untitled : title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: title.isEmpty ? muted : onBg,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    content,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: compact ? 3 : 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (note.projectName != null)
                      _MetaChip(
                        icon: Icons.folder_outlined,
                        label: note.projectName!,
                        color: muted,
                      ),
                    for (final tag in note.tags.take(3))
                      _MetaChip(
                        icon: Icons.sell_outlined,
                        label: tag.name,
                        color: muted,
                      ),
                    if (updated != null)
                      Text(
                        DateFormats(Localizations.localeOf(context)).mediumDate(
                          CalendarDate(
                            updated.year,
                            updated.month,
                            updated.day,
                          ),
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
