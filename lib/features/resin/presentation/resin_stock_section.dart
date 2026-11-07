import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/resin_controller.dart';
import '../domain/resin_engine.dart';

/// "In stock": Condensed / Fragile / Transient. The mock's "2 / 5" implies
/// a condensed-resin cap, but no such cap exists anywhere in the schema
/// (confirmed: it's hardcoded sample text in the mock with no backing
/// data) — shown as a plain count instead, consistent with showing honest
/// data over a fabricated number.
class ResinStockSection extends ConsumerWidget {
  const ResinStockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resinAsync = ref.watch(resinControllerProvider);
    final now = ref.watch(clockProvider).nowUtc();

    return resinAsync.when(
      data: (state) {
        final unexpiredBatches = state.transient
            .where((batch) => batch.expiresAt.isAfter(now))
            .toList();
        String? expiryLabel;
        if (unexpiredBatches.isNotEmpty) {
          final soonest = unexpiredBatches
              .map((b) => b.expiresAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          final days = soonest.difference(now).inDays;
          expiryLabel = 'Expires in $days d';
        }

        return Row(
          children: [
            Expanded(
              child: _StockTile(
                background: AppColors.tilePurpleBackground,
                iconColor: AppColors.tilePurpleIcon,
                icon: Icons.auto_awesome,
                count: '${state.condensed}',
                label: 'Condensed',
                subLabel: '${ResinEngine.condensedResinValue} each',
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: _StockTile(
                background: AppColors.tileAmberBackground,
                iconColor: AppColors.tileAmberIcon,
                icon: Icons.bolt,
                count: '${state.fragile}',
                label: 'Fragile',
                subLabel: '+${ResinEngine.fragileOrTransientResinValue} each',
              ),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: _StockTile(
                background: AppColors.tileBlueBackground,
                iconColor: AppColors.tileBlueIcon,
                icon: Icons.hourglass_bottom,
                count: '${unexpiredBatches.length}',
                label: 'Transient',
                subLabel: expiryLabel,
                subLabelColor: AppColors.warning,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 108),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.background,
    required this.iconColor,
    required this.icon,
    required this.count,
    required this.label,
    this.subLabel,
    this.subLabelColor,
  });

  final Color background;
  final Color iconColor;
  final IconData icon;
  final String count;
  final String label;
  final String? subLabel;
  final Color? subLabelColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.xxl)),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mlg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: background,
                borderRadius: AppRadius.tileRadius,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: AppSpacing.smd),
            Text(count, style: textTheme.headlineLarge),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (subLabel != null)
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: subLabelColor != null ? FontWeight.w600 : FontWeight.normal,
                  color: subLabelColor ?? AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
