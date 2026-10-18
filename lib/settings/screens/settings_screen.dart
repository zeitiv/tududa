import 'package:flutter/material.dart';

import '../../common/widgets/sync_indicator.dart' show syncStatusLabel;
import '../../core/db/app_database.dart';
import '../../core/sync/sync_status.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../../l10n/l10n_ext.dart';

/// Settings / More screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final strings = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsMore)),
      body: ListView(
        children: [
          // User info card
          if (user != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.secondaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      user.initials,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          _SectionHeader(title: strings.listMoreSection),

          for (final (icon, label, path) in [
            (Icons.warning_amber_rounded, strings.listOverdue, '/overdue'),
            (Icons.cloud_outlined, strings.taskFilterSomeday, '/someday'),
            (
              Icons.check_circle_outline,
              strings.taskFilterCompleted,
              '/completed',
            ),
            (Icons.list_rounded, strings.listAllTasks, '/tasks'),
            (Icons.sticky_note_2_outlined, strings.navNotes, '/notes'),
            (Icons.layers_outlined, strings.settingsAreas, '/more/areas'),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(path),
            ),
          // No tags screen exists yet.
          ListTile(
            enabled: false,
            leading: const Icon(Icons.sell_outlined),
            title: Text(strings.listTags),
            subtitle: Text(strings.listComingSoon),
          ),

          _SectionHeader(title: strings.settingsNavigation),

          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(strings.settingsAreas),
            subtitle: Text(strings.settingsAreasDesc),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/areas'),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(strings.syncTitle),
            subtitle: Text(
              syncStatusLabel(strings, ref.watch(syncStatusProvider)),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/more/sync'),
          ),

          _SectionHeader(title: strings.settingsPreferences),

          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(strings.settingsAppearance),
            trailing: DropdownButton<AppThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text(strings.settingsThemeSystem),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text(strings.settingsThemeLight),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text(strings.settingsThemeDark),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setThemeMode(val);
              },
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome_outlined),
            title: Text(strings.settingsDynamicColor),
            subtitle: Text(strings.settingsDynamicColorHint),
            value: settings.dynamicColor,
            onChanged: notifier.setDynamicColor,
          ),

          ListTile(
            leading: const Icon(Icons.contrast_outlined),
            title: Text(strings.settingsContrast),
            trailing: DropdownButton<ContrastLevel>(
              value: settings.contrast,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: ContrastLevel.standard,
                  child: Text(strings.settingsContrastStandard),
                ),
                DropdownMenuItem(
                  value: ContrastLevel.medium,
                  child: Text(strings.settingsContrastMedium),
                ),
                DropdownMenuItem(
                  value: ContrastLevel.high,
                  child: Text(strings.settingsContrastHigh),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setContrast(val);
              },
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off_outlined),
            title: Text(strings.settingsReduceMotion),
            subtitle: Text(strings.settingsReduceMotionHint),
            value: settings.reduceMotion,
            onChanged: notifier.setReduceMotion,
          ),

          ListTile(
            leading: const Icon(Icons.density_medium_outlined),
            title: Text(strings.settingsDensity),
            trailing: DropdownButton<DensityLevel>(
              value: settings.density,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: DensityLevel.comfortable,
                  child: Text(strings.settingsDensityComfortable),
                ),
                DropdownMenuItem(
                  value: DensityLevel.compact,
                  child: Text(strings.settingsDensityCompact),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setDensity(val);
              },
            ),
          ),

          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(strings.settingsLanguage),
            trailing: DropdownButton<AppLanguage>(
              value: settings.language,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: AppLanguage.system,
                  child: Text(strings.settingsLanguageSystem),
                ),
                // Endonyms: each language is shown in its own language.
                const DropdownMenuItem(
                  value: AppLanguage.en,
                  child: Text('English'),
                ),
                const DropdownMenuItem(
                  value: AppLanguage.de,
                  child: Text('Deutsch'),
                ),
                const DropdownMenuItem(
                  value: AppLanguage.zh,
                  child: Text('中文'),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setLanguage(val);
              },
            ),
          ),

          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(strings.settingsTimezone),
            subtitle: Text(user?.timezone ?? 'UTC'),
          ),

          _SectionHeader(title: strings.settingsIntegrations),

          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Telegram'),
            subtitle: Text(
              user?.telegramChatId != null
                  ? strings.settingsTelegramConnected
                  : strings.settingsTelegramNotConfigured,
            ),
          ),

          _SectionHeader(title: strings.settingsServer),

          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(strings.settingsServerUrl),
            subtitle: Text(
              authState.serverUrl ?? strings.settingsServerNotConfigured,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.settingsAbout),
            subtitle: Text(strings.settingsAboutSubtitle),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Tududa',
                applicationVersion: '1.0.1',
                applicationLegalese: '© 2024 Chris Veleris. MIT License.',
              );
            },
          ),

          const Divider(height: 32),

          // Logout
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text(
              strings.settingsSignOut,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () async {
              // Signing out deletes the local copy, so warn about changes
              // that have not reached the server yet.
              final counts = await ref
                  .read(appDatabaseProvider)
                  .outboxDao
                  .countsNow();
              final unsynced = counts.pending + counts.failed + counts.stuck;
              if (!context.mounted) return;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(strings.settingsSignOut),
                  content: Text(
                    unsynced == 0
                        ? strings.settingsSignOutConfirm
                        : '${strings.settingsSignOutConfirm}\n\n${strings.settingsSignOutUnsynced(unsynced)}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(strings.settingsCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(strings.settingsSignOut),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
