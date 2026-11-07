import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/settings_providers.dart';

class PlannerSettingsSection extends ConsumerWidget {
  const PlannerSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsSnapshotProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Planner', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        settingsAsync.when(
          data: (settings) => ClipRRect(
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
                              Text('World Level', style: textTheme.titleMedium),
                              Text('Used for run estimates in v2', style: textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        _WorldLevelStepper(
                          value: settings.worldLevel,
                          onChanged: (value) async {
                            final profileId = (await ref.read(currentProfileProvider.future)).id;
                            await ref.read(settingsRepositoryProvider).updateWorldLevel(profileId, value);
                            ref.invalidate(settingsSnapshotProvider);
                          },
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
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
                              Text('Totals-only mode', style: textTheme.titleMedium),
                              Text(
                                'Skip inventory and show full material totals',
                                style: textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: settings.totalsOnlyMode,
                          onChanged: (value) async {
                            final profileId = (await ref.read(currentProfileProvider.future)).id;
                            await ref
                                .read(settingsRepositoryProvider)
                                .updateTotalsOnlyMode(profileId, value);
                            ref.invalidate(settingsSnapshotProvider);
                          },
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          loading: () => const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text('Error: $error'),
        ),
      ],
    );
  }
}

class _WorldLevelStepper extends StatelessWidget {
  const _WorldLevelStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: Icons.remove,
              semanticLabel: 'Lower World Level',
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 30,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            _StepButton(
              icon: Icons.add,
              semanticLabel: 'Raise World Level',
              onPressed: value < 9 ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.semanticLabel, required this.onPressed});

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(11)),
          onTap: onPressed,
          child: Semantics(
            label: semanticLabel,
            button: true,
            child: Icon(icon, size: 16, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
