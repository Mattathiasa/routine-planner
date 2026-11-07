import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/resin_controller.dart';
import '../data/resin_repository.dart';
import '../data/resin_providers.dart';
import 'resin_formatting.dart';

String _describeEvent(ResinActivityEntry event) {
  final description = switch (event.kind) {
    'sync' => 'Synced with game',
    'spend' => event.label != null ? 'Spent ${event.cost} · ${event.label}' : 'Spent ${event.cost}',
    'craftCondensed' => 'Crafted Condensed Resin',
    'useFragile' => 'Used Fragile Resin',
    'useCondensed' => 'Used Condensed Resin',
    'useTransient' => 'Used Transient Resin',
    _ => event.kind,
  };
  return event.isUndo ? 'Undo: $description' : description;
}

class ResinActivitySection extends ConsumerWidget {
  const ResinActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(resinRecentEventsProvider);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlg,
          AppSpacing.mlg,
          AppSpacing.xlg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Activity', style: textTheme.headlineMedium),
                TextButton(
                  onPressed: () => _undoLast(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Undo last'),
                ),
              ],
            ),
            eventsAsync.when(
              data: (events) => Column(
                children: [
                  for (final event in events)
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.divider)),
                      ),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                formatTime(event.occurredAt),
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(_describeEvent(event), style: textTheme.titleMedium),
                            ),
                            Text('${event.resultingV}', style: textTheme.headlineLarge),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _undoLast(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(resinControllerProvider.notifier).undoLast();
    } on NothingToUndoException {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to undo.')));
    } on UndoNotSupportedException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Can't undo this action (${e.kind}).")));
    }
  }
}
