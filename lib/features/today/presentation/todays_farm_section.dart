import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/today_view_models.dart';
import 'farm_domain_card.dart';
import '../../../core/widgets/app_status_views.dart';

class TodaysFarmSection extends StatelessWidget {
  const TodaysFarmSection({super.key, required this.farmCards});

  final List<FarmDomainCardData> farmCards;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final taskCount = farmCards.fold<int>(
      0,
      (sum, card) => sum + card.rows.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's farm", style: textTheme.headlineLarge),
            Text(
              '$taskCount task${taskCount == 1 ? '' : 's'}',
              style: textTheme.bodyLarge?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (farmCards.isEmpty)
          const AppEmptyView(
            icon: Icons.bedtime_outlined,
            title: 'Nothing to farm today',
            caption: 'No planner target needs a domain that is open on this server day. Enjoy the rest.',
          )
        else
          for (var i = 0; i < farmCards.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            FarmDomainCard(data: farmCards[i]),
          ],
      ],
    );
  }
}
