import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Switches account without leaving the screen.
///
/// Resin and Planner are both bound to the selected account, and until now
/// changing it meant a trip to Today's strip or Settings and back. The chips
/// render nothing at all with a single account, so a one-account install sees
/// no change.
class AccountSwitcherBar extends ConsumerWidget {
  const AccountSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profileListProvider);
    final currentId = ref.watch(currentProfileProvider).value?.id;

    return profiles.maybeWhen(
      data: (data) {
        if (data.length < 2) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final profile in data) ...[
                  _AccountChip(
                    label: profile.displayName,
                    selected: profile.id == currentId,
                    onTap: () async {
                      await ref
                          .read(profileRepositoryProvider)
                          .selectProfile(profile.id);
                      ref.invalidate(currentProfileProvider);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: selected,
      button: !selected,
      label: selected ? '$label, selected' : 'Switch to $label',
      child: Material(
        color: selected
            ? context.colors.primaryContainer
            : context.colors.surface,
        borderRadius: AppRadius.pillRadius,
        child: InkWell(
          borderRadius: AppRadius.pillRadius,
          onTap: selected ? null : onTap,
          child: ConstrainedBox(
            // The chips sit in a row of their own, so each one carries the
            // full 48dp tap target rather than relying on a parent's height.
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Center(
                child: Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color: selected
                        ? context.colors.primaryHover
                        : context.colors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
