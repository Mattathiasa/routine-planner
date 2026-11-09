import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/game_server.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';

class AccountsSection extends ConsumerWidget {
  const AccountsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profileListProvider);
    final currentAsync = ref.watch(currentProfileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accounts', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        profilesAsync.when(
          data: (profiles) {
            final currentId = currentAsync.value?.id;
            return RadioGroup<String>(
              groupValue: currentId,
              onChanged: (id) async {
                if (id == null) return;
                await ref.read(profileRepositoryProvider).selectProfile(id);
                ref.invalidate(currentProfileProvider);
              },
              child: ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < profiles.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.divider),
                        _ProfileRow(
                          id: profiles[i].id,
                          displayName: profiles[i].displayName,
                          server: profiles[i].server,
                          canDelete: profiles.length > 1,
                        ),
                      ],
                      const Divider(height: 1, color: AppColors.divider),
                      _AddProfileRow(server: currentAsync.value?.server ?? 'asia'),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text('Error: $error'),
        ),
      ],
    );
  }
}

class _ProfileRow extends ConsumerWidget {
  const _ProfileRow({
    required this.id,
    required this.displayName,
    required this.server,
    required this.canDelete,
  });

  final String id;
  final String displayName;
  final String server;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final serverLabel = GameServer.values.byName(server).label;

    return InkWell(
      onTap: () => RadioGroup.maybeOf<String>(context)?.onChanged(id),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(displayName, style: textTheme.titleMedium),
                  Text(serverLabel, style: textTheme.bodyMedium),
                ],
              ),
            ),
            Radio<String>(value: id),
            PopupMenuButton<_ProfileAction>(
              onSelected: (action) => switch (action) {
                _ProfileAction.rename => _rename(context, ref),
                _ProfileAction.delete => _delete(context, ref),
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: _ProfileAction.rename, child: Text('Rename')),
                PopupMenuItem(
                  value: _ProfileAction.delete,
                  enabled: canDelete,
                  child: Text(canDelete ? 'Delete' : 'Delete (last account)'),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameProfileDialog(initialName: displayName),
    );
    if (newName == null || newName.isEmpty) return;

    await ref.read(profileRepositoryProvider).renameProfile(id, newName);
    ref.invalidate(profileListProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this account?'),
        content: const Text(
          "Its data stays on this device but won't be shown again. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(profileRepositoryProvider).deleteProfile(id);
    ref.invalidate(profileListProvider);
    ref.invalidate(currentProfileProvider);
  }
}

enum _ProfileAction { rename, delete }

class _AddProfileRow extends ConsumerWidget {
  const _AddProfileRow({required this.server});

  final String server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _addProfile(context, ref),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            const Icon(Icons.add, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add account',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProfile(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AddProfileDialog(),
    );
    if (name == null) return;

    final repository = ref.read(profileRepositoryProvider);
    final created = await repository.createProfile(
      displayName: name.isEmpty ? null : name,
      server: server,
    );
    await repository.selectProfile(created.id);
    ref.invalidate(profileListProvider);
    ref.invalidate(currentProfileProvider);
  }
}

class _AddProfileDialog extends StatefulWidget {
  const _AddProfileDialog();

  @override
  State<_AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<_AddProfileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name (optional)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _RenameProfileDialog extends StatefulWidget {
  const _RenameProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameProfileDialog> createState() => _RenameProfileDialogState();
}

class _RenameProfileDialogState extends State<_RenameProfileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename account'),
      content: TextField(
        controller: _controller,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
