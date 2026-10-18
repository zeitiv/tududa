import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../l10n/l10n_ext.dart';
import '../../core/api/patch.dart' as pt;
import '../data/area_api.dart';
import '../providers/area_provider.dart';
import '../models/area_model.dart';

/// Areas management screen.
class AreasScreen extends ConsumerStatefulWidget {
  const AreasScreen({super.key});

  @override
  ConsumerState<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends ConsumerState<AreasScreen> {
  void _showError(ApiError e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.areaNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: ctx.l10n.areaName,
                hintText: ctx.l10n.areaNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: ctx.l10n.areaDescriptionOptional,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.areaCancel),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await ref
                      .read(areaListProvider.notifier)
                      .create(
                        NewArea(
                          name: nameController.text.trim(),
                          description: descController.text.trim().isEmpty
                              ? null
                              : descController.text.trim(),
                        ),
                      );
                } on ApiError catch (e) {
                  _showError(e);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(ctx.l10n.areaCreate),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Area area) {
    final nameController = TextEditingController(text: area.name);
    final descController = TextEditingController(text: area.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.areaEdit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: ctx.l10n.areaName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: ctx.l10n.areaDescription),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.areaCancel),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await ref
                      .read(areaListProvider.notifier)
                      .edit(
                        area.uid,
                        AreaPatch(
                          name: pt.Patch.set(nameController.text.trim()),
                          description: descController.text.trim().isEmpty
                              ? const pt.Patch.clear()
                              : pt.Patch.set(descController.text.trim()),
                        ),
                      );
                } on ApiError catch (e) {
                  _showError(e);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(ctx.l10n.areaSave),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final areaState = ref.watch(areaListProvider);
    final areas = areaState.value ?? const <Area>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.areasTitle)),
      body: areaState.isLoading && !areaState.hasValue
          ? const Center(child: CircularProgressIndicator())
          : areaState.hasError && !areaState.hasValue
          ? Center(
              child: Text(context.l10n.areaLoadError('${areaState.error}')),
            )
          : areas.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.areasEmpty,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.areasEmptyHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(areaListProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: areas.length,
                itemBuilder: (context, index) {
                  final area = areas[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.layers,
                        color: theme.colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    title: Text(area.name),
                    subtitle: area.description != null
                        ? Text(
                            area.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          _showEditDialog(area);
                        } else if (action == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(ctx.l10n.areaDeleteTitle),
                              content: Text(ctx.l10n.areaDeleteMessage),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(ctx.l10n.areaCancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(ctx.l10n.areaDeleteAction),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await ref
                                  .read(areaListProvider.notifier)
                                  .delete(area.uid);
                            } on ApiError catch (e) {
                              _showError(e);
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(context.l10n.areaEditAction),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.l10n.areaDeleteAction),
                        ),
                      ],
                    ),
                    onTap: () => _showEditDialog(area),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        tooltip: context.l10n.areaAddTooltip,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
