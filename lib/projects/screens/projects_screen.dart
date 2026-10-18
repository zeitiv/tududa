import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/project_provider.dart';
import '../models/project_model.dart';
import '../../core/theme/app_theme.dart';
import '../../common/widgets/glass_container.dart';
import '../../l10n/strings.dart';

/// Projects list screen with card layout.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectState = ref.watch(projectListProvider);
    final projects = projectState.value ?? const <Project>[];
    final strings = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(strings.projects)),
      body: projectState.isLoading && !projectState.hasValue
          ? const Center(child: CircularProgressIndicator())
          : projectState.hasError && !projectState.hasValue
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Error: ${projectState.error}'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(projectListProvider.notifier).refresh(),
                    child: Text(strings.retry),
                  ),
                ],
              ),
            )
          : projects.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.noProjectsYet,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => ref.read(projectListProvider.notifier).refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  return _ProjectCard(
                    project: projects[index],
                    onTap: () =>
                        context.push('/projects/${projects[index].uid.value}'),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/projects/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.newProject),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = AppTheme.getProjectStatusColor(
      project.status,
      theme.colorScheme,
    );

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (project.pinToSidebar)
                    Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  if (project.priorityName != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.flag_rounded,
                        size: 16,
                        color: AppTheme.getStringPriorityColor(
                          project.priorityName,
                          theme.colorScheme,
                        ),
                      ),
                    ),
                ],
              ),
              if (project.description != null &&
                  project.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  project.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      project.statusDisplay,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (project.areaName != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.layers_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(project.areaName!, style: theme.textTheme.bodySmall),
                  ],
                  const Spacer(),
                  if (project.taskCount != null)
                    Text(
                      '${project.completedTaskCount ?? 0}/${project.taskCount} tasks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (project.taskCount != null && project.taskCount! > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
