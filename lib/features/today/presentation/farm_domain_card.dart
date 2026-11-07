import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../application/today_view_models.dart';
import 'farm_task_row.dart';

class FarmDomainCard extends StatelessWidget {
  const FarmDomainCard({super.key, required this.data});

  final FarmDomainCardData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.name, style: textTheme.titleLarge),
                    Text(
                      data.scheduleLabel,
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!data.alwaysOpen) const _OpenPill(),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          for (var i = 0; i < data.rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            FarmTaskRow(row: data.rows[i], costResin: data.costResin),
          ],
        ],
      ),
    );
  }
}

class _OpenPill extends StatelessWidget {
  const _OpenPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: AppColors.successContainer,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.successDot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Open',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
