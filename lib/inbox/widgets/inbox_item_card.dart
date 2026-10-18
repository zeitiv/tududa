import 'package:flutter/material.dart';

import '../../common/widgets/surface_card.dart';
import '../../core/design/tokens.dart';
import '../../core/time/calendar_date.dart';
import '../../core/time/date_formatters.dart';
import '../../l10n/l10n_ext.dart';
import '../domain/inbox_item.dart';

/// Overflow menu choices of an inbox card.
enum InboxItemAction { process, ignore, delete }

/// Compact age of an item: "Just now", "5 min ago", "3 h ago", "2 d ago",
/// then the date.
String inboxAgeLabel(
  BuildContext context,
  DateTime? createdAt, {
  DateTime? now,
}) {
  if (createdAt == null) return '';
  final strings = context.l10n;
  final diff = (now ?? DateTime.now()).difference(createdAt);
  if (diff.inMinutes < 1) return strings.inboxV2AgeNow;
  if (diff.inHours < 1) return strings.inboxV2AgeMinutes(diff.inMinutes);
  if (diff.inDays < 1) return strings.inboxV2AgeHours(diff.inHours);
  if (diff.inDays < 7) return strings.inboxV2AgeDays(diff.inDays);
  final local = createdAt.toLocal();
  return DateFormats(Localizations.localeOf(context))
      .mediumDate(CalendarDate(local.year, local.month, local.day));
}

/// One inbox entry as a card: text, age, and the convert / process actions.
class InboxItemCard extends StatelessWidget {
  const InboxItemCard({
    super.key,
    required this.item,
    required this.onConvertToTask,
    required this.onConvertToNote,
    required this.onAction,
    this.now,
  });

  final InboxItem item;
  final VoidCallback onConvertToTask;
  final VoidCallback onConvertToNote;
  final ValueChanged<InboxItemAction> onAction;

  /// Reference time for the age label; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = context.l10n;
    final gap = theme.extension<AppTokens>()?.space3 ?? 12;
    final ignored = item.isIgnored;

    return SurfaceCard(
      margin: EdgeInsets.symmetric(horizontal: gap, vertical: gap / 3),
      color: ignored ? scheme.surfaceContainerLowest : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gap + 4, gap, gap / 2, gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      item.content,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: ignored
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<InboxItemAction>(
                  tooltip: strings.inboxV2ItemActions,
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: InboxItemAction.process,
                      child: Text(strings.inboxMarkProcessed),
                    ),
                    if (!ignored)
                      PopupMenuItem(
                        value: InboxItemAction.ignore,
                        child: Text(strings.inboxIgnore),
                      ),
                    PopupMenuItem(
                      value: InboxItemAction.delete,
                      child: Text(strings.commonDelete),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(right: gap),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  Text(
                    inboxAgeLabel(context, item.createdAt, now: now),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.source != 'manual' && item.source != 'mobile')
                    Text(
                      item.source,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (ignored)
                    Text(
                      strings.inboxV2Ignored,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: gap),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onConvertToTask,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(strings.inboxV2ConvertTask),
                ),
                OutlinedButton.icon(
                  onPressed: onConvertToNote,
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                  label: Text(strings.inboxV2ConvertNote),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
