import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/backup_service.dart';
import '../data/settings_providers.dart';
import 'backup_file_storage.dart';

class DataSection extends ConsumerWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(catalogVersionProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.card),
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Game catalog', style: textTheme.titleMedium),
                            Text(
                              '${versionAsync.value ?? '—'} · works offline',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("You're on the latest seed catalog.")),
                          );
                        },
                        child: const Text('Check'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
                _DataRow(label: 'Export backup (JSON)', onTap: () => _exportBackup(context, ref)),
                const Divider(height: 1, color: AppColors.divider),
                _DataRow(label: 'Import backup', onTap: () => _confirmImport(context, ref)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profileId = (await ref.read(currentProfileProvider.future)).id;
      final json = await BackupService(
        ref.read(userDatabaseProvider),
      ).exportBackupJson(profileId);
      final path = await exportBackupFile(json);
      messenger.showSnackBar(SnackBar(content: Text('Exported to $path')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  Future<void> _confirmImport(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text("This replaces that account's data with the backup. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await importBackupFile();
      final importedProfileId = await BackupService(
        ref.read(userDatabaseProvider),
      ).importBackupJson(json);
      await ref.read(profileRepositoryProvider).selectProfile(importedProfileId);
      ref.invalidate(currentProfileProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Imported.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $error')));
    }
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
